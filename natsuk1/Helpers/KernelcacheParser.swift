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
                          userInfo: [NSLocalizedDescriptionKey: "xpf start: \(err)"])
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

        let dict: xpc_object_t? = sets.withUnsafeMutableBufferPointer { buf -> xpc_object_t? in
            return xpf_construct_offset_dictionary(buf.baseAddress!)
        }

        free(basePtr)
        free(transPtr)
        free(structPtr)

        guard dict != nil else {
            let err = String(cString: xpf_get_error())
            xpf_stop()
            throw NSError(domain: "KernelcacheParser", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "xpf dict nil: \(err)"])
        }

        var result: [String: String] = [:]

        let map: [(String, String)] = [
            ("kernelBase",                              "off_kernel_base"),
            ("kernelEntry",                             "off_kernel_entry"),
            ("kernelConstant.nsysent",                  "off_sysent_count"),
            ("kernelConstant.cpu_ttep",                 "off_cpu_ttep"),
            ("kernelSymbol.kernproc",                   "off_g_kernproc"),
            ("kernelSymbol.allproc",                    "off_g_allproc"),
            ("kernelSymbol.rootvnode",                  "off_g_rootvnode"),
            ("kernelSymbol.kernel_task",                "off_g_kernel_task"),
            ("kernelSymbol.zone_map",                   "off_g_zone_map"),
            ("kernelSymbol.cdevsw",                     "off_g_cdevsw"),
            ("kernelSymbol.pv_head_table",              "off_g_pv_head_table"),
            ("kernelSymbol.cs_enforcement",             "off_g_cs_enforcement"),
            ("kernelSymbol.mac_policy",                 "off_g_mac_policy"),
            ("translation.t1sz_boot",                   "t1sz_boot"),
            ("translation.gVirtBase",                   "smr_base"),
            ("kernelStruct.proc.struct_size",           "procsize"),
            ("kernelStruct.proc.p_pid",                 "off_proc_p_pid"),
            ("kernelStruct.proc.p_ucred",               "off_proc_ro_p_ucred"),
            ("kernelStruct.proc.p_list_le_next",        "off_proc_p_list_le_next"),
            ("kernelStruct.proc.p_list_le_prev",        "off_proc_p_list_le_prev"),
            ("kernelStruct.proc.p_task",                "off_proc_p_task"),
            ("kernelStruct.proc.p_fd",                  "off_proc_p_fd"),
            ("kernelStruct.proc.p_flag",                "off_proc_p_flag"),
            ("kernelStruct.task.map",                   "off_task_map"),
            ("kernelStruct.task.threads_next",          "off_task_threads_next"),
            ("kernelStruct.task.itk_space",             "off_task_itk_space"),
            ("kernelStruct.task.itk_self",              "off_task_itk_self"),
            ("kernelStruct.task.bsd_info",              "off_task_bsd_info"),
            ("kernelStruct.task.t_flags",               "off_task_t_flags"),
            ("kernelStruct.thread.threads_next",        "off_thread_task_threads_next"),
            ("kernelStruct.thread.ast",                 "off_thread_ast"),
            ("kernelStruct.thread.ctid",                "off_thread_ctid"),
            ("kernelStruct.thread.options",             "off_thread_options"),
            ("kernelStruct.thread.machine_upcb",        "off_thread_machine_upcb"),
            ("kernelStruct.thread.machine_contextdata", "off_thread_machine_contextdata"),
            ("kernelStruct.thread.machine_kstackptr",   "off_thread_machine_kstackptr"),
            ("kernelStruct.thread.machine_jop_pid",     "off_thread_machine_jop_pid"),
            ("kernelStruct.thread.machine_rop_pid",     "off_thread_machine_rop_pid"),
            ("kernelStruct.ucred.cr_label",             "off_ucred_cr_label"),
            ("kernelStruct.ipc_space.is_table",         "off_ipc_space_is_table"),
            ("kernelStruct.ipc_entry.ie_object",        "off_ipc_entry_ie_object"),
            ("kernelStruct.ipc_port.ip_kobject",        "off_ipc_port_ip_kobject"),
            ("kernelStruct.ipc_port.ip_receiver",       "off_ipc_port_ip_receiver"),
            ("kernelStruct.fileproc.fp_glob",           "off_fileproc_fp_glob"),
            ("kernelStruct.fileglob.fg_data",           "off_fileglob_fg_data"),
            ("kernelStruct.vnode.v_mount",              "off_vnode_v_mount"),
            ("kernelStruct.vnode.v_parent",             "off_vnode_v_parent"),
            ("kernelStruct.vnode.v_data",               "off_vnode_v_data"),
            ("kernelStruct.vnode.v_name",               "off_vnode_v_name"),
            ("kernelStruct.vnode.v_usecount",           "off_vnode_v_usecount"),
            ("kernelStruct.vnode.v_iocount",            "off_vnode_v_iocount"),
            ("kernelStruct.vnode.v_writecount",         "off_vnode_v_writecount"),
            ("kernelStruct.vnode.v_flag",               "off_vnode_v_flag"),
            ("kernelStruct.mount.mnt_flag",             "off_mount_mnt_flag"),
            ("kernelStruct.socket.so_usecount",         "off_socket_so_usecount"),
            ("kernelStruct.socket.so_proto",            "off_socket_so_proto"),
            ("kernelStruct.inpcb.inp_list_le_next",     "off_inpcb_inp_list_le_next"),
            ("kernelStruct.inpcb.inp_pcbinfo",          "off_inpcb_inp_pcbinfo"),
            ("kernelStruct.inpcb.inp_socket",           "off_inpcb_inp_socket")
        ]

        for (xpfKey, ourKey) in map {
            let v = xpfKey.withCString { xpf_item_resolve($0) }
            if v != 0 {
                result[ourKey] = String(format: "0x%llX", v)
            }
        }

        withExtendedLifetime(dict) {
            xpf_stop()
        }

        return result
    }
}
