import Foundation

final class KernelcacheParser {

    static let shared = KernelcacheParser()
    private init() {}

    struct Result {
        var symbols: [String: UInt64] = [:]
        var kernelBase: UInt64 = 0
    }

    enum ParseError: Error {
        case badMagic
        case noKernel
    }

    private let targets: [String: String] = [
        "_sysent":           "off_sysent_base",
        "_mach_trap_table":  "off_mach_trap_table",
        "_copyin":           "off_fn_copyin",
        "_copyout":          "off_fn_copyout",
        "_kalloc_ext":       "off_fn_kalloc_ext",
        "_kfree_ext":        "off_fn_kfree_ext",
        "_kernproc":         "off_g_kernproc",
        "_kernel_task":      "off_g_kernel_task",
        "_zone_map":         "off_g_zone_map",
        "_allproc":          "off_g_allproc",
        "_chroot":           "off_g_chroot",
        "_cs_enforcement":   "off_g_cs_enforcement",
        "_mac_policy":       "off_g_mac_policy",
    ]

    func parse(url: URL) throws -> [String: String] {
        let data = try Data(contentsOf: url)
        let result = try walk(data: data)

        var out: [String: String] = [:]
        out["off_kernel_base"] = String(format: "0x%llX", result.kernelBase)
        for (sym, key) in targets {
            if let v = result.symbols[sym] {
                out[key] = String(format: "0x%llX", v)
            }
        }
        return out
    }

    private func walk(data: Data) throws -> Result {
        var result = Result()

        let magic: UInt32 = read(data, 0)

        if magic == 0xCAFEBABE || magic == 0xBEBAFECA {
            return try walkFat(data: data, result: &result)
        }

        if magic == 0xFEEDFACF {
            try walkMachO(data: data, headerOffset: 0, result: &result)
        } else {
            throw ParseError.badMagic
        }

        guard result.kernelBase != 0 else { throw ParseError.noKernel }
        return result
    }

    private func walkFat(data: Data, result: inout Result) throws -> Result {
        let nfat: UInt32 = read(data, 4)

        for i in 0..<Int(nfat) {
            let archOff = 8 + i * 20
            let cpuType: UInt32 = read(data, archOff)
            let offset: UInt32 = read(data, archOff + 8)

            if cpuType == 0x0100000C || cpuType == 0x01000007 {
                let hMagic: UInt32 = read(data, Int(offset))
                if hMagic == 0xFEEDFACF {
                    try walkMachO(data: data, headerOffset: Int(offset), result: &result)
                    break
                }
            }
        }

        guard result.kernelBase != 0 else { throw ParseError.noKernel }
        return result
    }

    private func walkMachO(data: Data, headerOffset: Int, result: inout Result) throws {
        let hMagic: UInt32 = read(data, headerOffset)
        guard hMagic == 0xFEEDFACF else { return }

        let ncmds: UInt32 = read(data, headerOffset + 16)
        let sizeofcmds: UInt32 = read(data, headerOffset + 20)
        var lcOff = headerOffset + 32
        let lcEnd = lcOff + Int(sizeofcmds)

        var cmdIdx = 0
        while lcOff < lcEnd && cmdIdx < Int(ncmds) {
            let cmd: UInt32 = read(data, lcOff)
            let cmdsize: UInt32 = read(data, lcOff + 4)
            guard cmdsize > 0 else { break }

            if cmd == 0x35 {
                let vmaddr: UInt64 = read(data, lcOff + 8)
                let fileoff: UInt64 = read(data, lcOff + 16)
                let entryIdOff: UInt32 = read(data, lcOff + 24)
                let entryId = readCString(data, lcOff + Int(entryIdOff))

                if entryId == "com.apple.kernel" {
                    result.kernelBase = vmaddr
                }

                parseKext(data: data, fileoff: Int(fileoff), into: &result)
            }
            lcOff += Int(cmdsize)
            cmdIdx += 1
        }
    }

    private func parseKext(data: Data, fileoff: Int, into result: inout Result) {
        let magic: UInt32 = read(data, fileoff)
        guard magic == 0xFEEDFACF else { return }

        let ncmds: UInt32 = read(data, fileoff + 16)
        let sizeofcmds: UInt32 = read(data, fileoff + 20)
        var lcOff = fileoff + 32
        let lcEnd = lcOff + Int(sizeofcmds)

        var symoff: UInt32 = 0
        var nsyms: UInt32 = 0
        var stroff: UInt32 = 0
        var strsize: UInt32 = 0

        var cmdIdx = 0
        while lcOff < lcEnd && cmdIdx < Int(ncmds) {
            let cmd: UInt32 = read(data, lcOff)
            let cmdsize: UInt32 = read(data, lcOff + 4)
            guard cmdsize > 0 else { break }

            if cmd == 0x2 {
                symoff  = read(data, lcOff + 8)
                nsyms   = read(data, lcOff + 12)
                stroff  = read(data, lcOff + 16)
                strsize = read(data, lcOff + 20)
            }
            lcOff += Int(cmdsize)
            cmdIdx += 1
        }

        guard nsyms > 0, strsize > 0 else { return }

        var symOff = fileoff + Int(symoff)
        let strOff = fileoff + Int(stroff)

        for _ in 0..<nsyms {
            let n_strx: UInt32 = read(data, symOff)
            let n_value: UInt64 = read(data, symOff + 8)

            if n_strx > 0 && Int(n_strx) < Int(strsize) {
                let name = readCString(data, strOff + Int(n_strx))
                if targets[name] != nil && result.symbols[name] == nil {
                    result.symbols[name] = n_value
                }
            }
            symOff += 16
        }
    }

    private func read<T>(_ data: Data, _ offset: Int) -> T {
        data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: T.self) }
    }

    private func readCString(_ data: Data, _ offset: Int) -> String {
        var end = offset
        while end < data.count && data[end] != 0 { end += 1 }
        return String(data: data.subdata(in: offset..<end), encoding: .utf8) ?? ""
    }
}
