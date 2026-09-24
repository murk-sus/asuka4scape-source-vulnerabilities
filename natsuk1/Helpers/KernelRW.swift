import Foundation

final class KernelRW {

    static let shared = KernelRW()
    private init() {}

    var ready: Bool { nk_krw_ready() != 0 }
    var lastError: String { String(cString: nk_krw_error()) }

    @discardableResult
    func bootstrap() -> Bool {
        return nk_krw_init() == 0
    }

    func read64(_ addr: UInt64) -> UInt64? {
        let v = nk_kread64(addr)
        return v == 0 ? nil : v
    }

    func write64(_ addr: UInt64, _ value: UInt64) -> Bool {
        return nk_kwrite64(addr, value) == 0
    }

    func read(_ addr: UInt64, size: Int) -> Data? {
        var buf = [UInt8](repeating: 0, count: size)
        let rc = nk_kread(addr, &buf, size)
        guard rc == 0 else { return nil }
        return Data(buf)
    }

    func write(_ addr: UInt64, data: Data) -> Bool {
        let bytes = [UInt8](data)
        return nk_kwrite(addr, bytes, bytes.count) == 0
    }

    func testRoundTrip() -> String {
        guard bootstrap() else {
            return "bootstrap failed: \\(lastError)"
        }
        let baseStr = OffsetsStore.shared.value(for: "off_kernel_base")
        guard baseStr.hasPrefix("0x"),
              let baseAddr = UInt64(baseStr.dropFirst(2), radix: 16),
              baseAddr != 0 else {
            return "bad off_kernel_base value: \\(baseStr)"
        }
        guard let original = read64(baseAddr) else {
            return "read 0x\\(String(baseAddr, radix: 16)) failed: \\(lastError)"
        }
        guard write64(baseAddr, original) else {
            return "write 0x\\(String(baseAddr, radix: 16)) failed: \\(lastError)"
        }
        guard let verify = read64(baseAddr) else {
            return "re-read after write failed: \\(lastError)"
        }
        if verify == original {
            return String(format: "OK - read/write at 0x%llX value 0x%llX", baseAddr, original)
        } else {
            return String(format: "MISMATCH at 0x%llX: wrote 0x%llX read 0x%llX", baseAddr, original, verify)
        }
    }
}
