import Foundation

final class KernelcacheParser {

    static let shared = KernelcacheParser()
    private init() {}

    func parse(url: URL) throws -> [String: String] {
        guard xpf_start_with_kernel_path(url.path) == 0 else {
            let err = String(cString: xpf_get_error())
            throw NSError(domain: "KernelcacheParser", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "xpf start error: \(err)"])
        }

        let sets: [UnsafePointer<CChar>?] = [
            UnsafePointer(strdup("base")),
            UnsafePointer(strdup("translation")),
            UnsafePointer(strdup("struct")),
            nil
        ]

        guard let dict = xpf_construct_offset_dictionary(sets) else {
            let err = String(cString: xpf_get_error())
            xpf_stop()
            throw NSError(domain: "KernelcacheParser", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "xpf dict failed: \(err)"])
        }

        var result: [String: String] = [:]
        let base = gXPF.kernelBase

        result["off_kernel_base"] = String(format: "0x%llX", base)

        let map: [(String, String)] = [
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
            let v = xpf_item_resolve(xpfKey)
            if v != 0 {
                result[ourKey] = String(format: "0x%llX", v)
            }
        }

        xpf_stop()
        return result
    }
}
