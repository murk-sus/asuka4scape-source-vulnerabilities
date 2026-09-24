import Foundation

final class KernelcacheParser {

    static let shared = KernelcacheParser()
    private init() {}

    func parse(url: URL) throws -> [String: String] {
        let kernelPath = url.path

        let docs = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
        let sptmPath = docs.appendingPathComponent("images/sptm.im4p").path
        let txmPath  = docs.appendingPathComponent("images/txm.im4p").path

        let hasSptm = FileManager.default.fileExists(atPath: sptmPath)
        let hasTxm  = FileManager.default.fileExists(atPath: txmPath)

        let rc: Int32 = kernelPath.withCString { kp in
            if hasSptm && hasTxm {
                return sptmPath.withCString { sp in
                    txmPath.withCString { tp in
                        xpf_start_with_kernel_path(kp, sp, tp)
                    }
                }
            } else {
                return xpf_start_with_kernel_path(kp, nil, nil)
            }
        }

        guard rc == 0 else {
            let err = String(cString: xpf_get_error())
            throw NSError(domain: "KernelcacheParser", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "xpf start error: \(err)"])
        }

        let basePtr = strdup("base")
        let transPtr = strdup("translation")
        let structPtr = strdup("struct")

        var sets: [UnsafePointer<CChar>?] = [
            UnsafePointer(basePtr),
            UnsafePointer(transPtr),
            UnsafePointer(structPtr),
            nil
        ]

        _ = sets.withUnsafeMutableBufferPointer { buf -> xpc_object_t? in
            return xpf_construct_offset_dictionary(buf.baseAddress!)
        }

        free(basePtr)
        free(transPtr)
        free(structPtr)

        var result: [String: String] = [:]

        let map: [(String, String)] = [
            ("kernelBase",                   "off_kernel_base"),
            ("kernelSymbol.sysent",          "off_sysent_base"),
            ("kernelSymbol.mach_trap_table", "off_mach_trap_table"),
            ("kernelSymbol.copyin",          "off_fn_copyin"),
            ("kernelSymbol.copyout",         "off_fn_copyout"),
            ("kernelSymbol.kalloc_ext",      "off_fn_kalloc_ext"),
            ("kernelSymbol.kfree_ext",       "off_fn_kfree_ext"),
            ("kernelSymbol.kernproc",        "off_g_kernproc"),
            ("kernelSymbol.kernel_task",     "off_g_kernel_task"),
            ("kernelSymbol.zone_map",        "off_g_zone_map"),
            ("kernelSymbol.allproc",         "off_g_allproc"),
            ("kernelSymbol.chroot",          "off_g_chroot"),
            ("kernelSymbol.cs_enforcement",  "off_g_cs_enforcement"),
            ("kernelSymbol.mac_policy",      "off_g_mac_policy"),
        ]

        for (xpfKey, ourKey) in map {
            let v = xpfKey.withCString { xpf_item_resolve($0) }
            if v != 0 {
                result[ourKey] = String(format: "0x%llX", v)
            }
        }

        xpf_stop()
        return result
    }
}
