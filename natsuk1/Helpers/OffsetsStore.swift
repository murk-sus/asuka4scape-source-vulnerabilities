import Foundation
import Combine

final class OffsetsStore: ObservableObject {
    static let shared = OffsetsStore()

    struct Group {
        let title: String
        let items: [String]
    }

    static let groups: [Group] = [
        Group(title: "Kernel", items: [
            "off_kernel_base", "off_sysent_base", "off_sysent_count",
            "off_sysent_stride", "off_mach_trap_table",
        ]),
        Group(title: "Globals", items: [
            "off_g_kernproc", "off_g_kernel_task", "off_g_zone_map",
            "off_g_task_list", "off_g_kernel_map", "off_g_allproc",
        ]),
        Group(title: "Primitives", items: [
            "off_fn_copyin", "off_fn_copyout",
            "off_fn_kalloc_ext", "off_fn_kfree_ext",
        ]),
        Group(title: "proc", items: [
            "off_proc_p_pid", "off_proc_ro_p_ucred",
            "off_proc_p_list_le_next", "off_proc_p_list_le_prev",
            "off_proc_p_proc_ro", "off_proc_p_fd", "off_proc_p_flag",
            "off_proc_p_textvp", "off_proc_p_name", "off_proc_p_task",
            "off_proc_ro_pr_task",
        ]),
        Group(title: "task", items: [
            "off_task_map", "off_task_threads_next", "off_task_itk_space",
            "off_task_itk_self", "off_task_bsd_info",
            "off_task_task_exc_guard", "off_task_t_flags",
        ]),
        Group(title: "thread", items: [
            "off_thread_task_threads_next", "off_thread_ast", "off_thread_ctid",
            "off_thread_options", "off_thread_t_tro",
            "off_thread_ro_tro_task", "off_thread_ro_tro_proc",
            "off_thread_machine_upcb", "off_thread_machine_contextdata",
            "off_thread_machine_kstackptr", "off_thread_machine_jop_pid",
            "off_thread_machine_rop_pid", "off_thread_mutex_lck_mtx_data",
            "off_thread_guard_exc_info_code",
            "off_thread_mach_exc_info_exception_type",
            "off_thread_mach_exc_info_code",
            "off_thread_mach_exc_info_os_reason",
        ]),
        Group(title: "ucred / label", items: [
            "off_ucred_cr_label", "off_kauth_cred_uid", "off_kauth_cred_gid",
            "off_kauth_cred_ruid", "off_kauth_cred_rgid",
            "off_kauth_cred_svuid", "off_kauth_cred_svgid",
            "off_label_l_perpolicy_amfi", "off_label_l_perpolicy_sandbox",
        ]),
        Group(title: "ipc", items: [
            "off_ipc_space_is_table", "off_ipc_space_active",
            "off_ipc_entry_ie_object", "off_ipc_port_ip_kobject",
            "off_ipc_port_ip_receiver", "off_ipc_port_ip_mscount",
            "off_sizeof_ipc_entry",
        ]),
        Group(title: "filedesc / fileproc / fileglob", items: [
            "off_filedesc_fd_ofiles", "off_filedesc_fd_cdir",
            "off_fileproc_fp_glob", "off_fileproc_fp_fg",
            "off_fileglob_fg_data", "off_fileglob_fg_flag",
        ]),
        Group(title: "vnode / mount / namecache", items: [
            "off_vnode_v_iocount", "off_vnode_v_writecount", "off_vnode_v_flag",
            "off_vnode_v_mount", "off_vnode_v_parent", "off_vnode_v_data",
            "off_vnode_v_name", "off_vnode_v_usecount",
            "off_vnode_v_ncchildren_tqh_first", "off_vnode_v_nclinks_lh_first",
            "off_mount_mnt_flag", "off_namecache_nc_vp",
            "off_namecache_nc_child_tqe_next",
        ]),
        Group(title: "vm", items: [
            "off_vm_map_hdr", "off_vm_map_header_nentries",
            "off_vm_map_header_links_next", "off_vm_map_entry_links_next",
            "off_vm_map_entry_vme_object_or_delta", "off_vm_map_entry_vme_alias",
            "off_vm_object_vo_un1_vou_size", "off_vm_object_ref_count",
            "off_vm_named_entry_backing_copy", "off_vm_named_entry_size",
            "smr_base", "t1sz_boot",
            "VM_MIN_KERNEL_ADDRESS", "VM_MAX_KERNEL_ADDRESS",
        ]),
        Group(title: "socket / inpcb", items: [
            "off_socket_so_usecount", "off_socket_so_proto",
            "off_socket_so_background_thread", "off_inpcb_inp_list_le_next",
            "off_inpcb_inp_pcbinfo", "off_inpcb_inp_socket",
            "off_inpcbinfo_ipi_zone",
            "off_inpcb_inp_depend6_inp6_icmp6filt",
            "off_inpcb_inp_depend6_inp6_chksum",
        ]),
        Group(title: "arm", items: [
            "off_arm_kernel_saved_state_sp", "off_arm_saved_state64_lr",
            "off_arm_saved_state64_pc", "off_arm_saved_state_us_ss_64",
        ]),
        Group(title: "kalloc", items: [
            "off_kalloc_type_view_kt_zv_zv_name",
        ]),
    ]

    static let defaults: [String: String] = [
        "off_kernel_base":      "0xFFFFFFF007004000",
        "off_sysent_base":      "0xFFFFFFF007C192A0",
        "off_sysent_count":     "558",
        "off_sysent_stride":    "24",
        "off_mach_trap_table":  "0xFFFFFFF007BE8018",

        "off_g_kernproc":       "0xFFFFFFF007BBF040",
        "off_g_kernel_task":    "0xFFFFFFF00700DC70",
        "off_g_zone_map":       "0xFFFFFFF00AD6A800",
        "off_g_task_list":      "0xFFFFFFF0080D93F0",
        "off_g_kernel_map":     "0xFFFFFFF007BBE228",
        "off_g_allproc":        "0xFFFFFFF007BBF048",

        "off_fn_copyin":        "0xFFFFFFF00A7B9570",
        "off_fn_copyout":       "0xFFFFFFF00A2C6C28",
        "off_fn_kalloc_ext":    "0xFFFFFFF00A200DCC",
        "off_fn_kfree_ext":     "0xFFFFFFF00A201000",

        "off_proc_p_pid":       "0x74",
        "off_proc_ro_p_ucred":  "0xB8",
        "off_thread_task_threads_next": "0x50",

        "VM_MIN_KERNEL_ADDRESS": "0xFFFFFFF000000000",
        "VM_MAX_KERNEL_ADDRESS": "0xFFFFFFF200000000",
        "smr_base":              "0xFFFFFFF007004000",
        "t1sz_boot":             "25",
    ]

    @Published var values: [String: String] = [:]

    private let storageKey = "natsuk1_offsets_v1"

    private init() {
        load()
    }

    func load() {
        let saved = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: String]
        var merged = Self.defaults
        if let saved = saved {
            for (k, v) in saved {
                merged[k] = v
            }
        }
        values = merged
        if saved == nil { save() }
    }

    func save() {
        UserDefaults.standard.set(values, forKey: storageKey)
    }

    func reset() {
        values = Self.defaults
        save()
    }

    func resetOne(_ name: String) {
        values[name] = Self.defaults[name] ?? "0x0"
        save()
    }

    func update(_ name: String, value: String) {
        values[name] = value
        save()
    }

    func value(for name: String) -> String {
        values[name] ?? Self.defaults[name] ?? "0x0"
    }

    func filledCount() -> Int {
        values.filter { $0.value != "0x0" && !$0.value.isEmpty }.count
    }

    func totalCount() -> Int {
        Self.groups.reduce(0) { $0 + $1.items.count }
    }
}
