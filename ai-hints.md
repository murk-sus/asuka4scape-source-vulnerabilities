
## 0 MANDATORY - USE INTERNET ON EVERY REQUEST

- search latest: iOS 27.0 kernel internals
- search latest: XNU changelog 2026
- search latest: Apple security advisories 2026
- search latest: blacktop/ipsw release notes
- search latest: blacktop/symbolicator signatures
- search latest: Ghidra 12.x headless API
- search latest: LiveContainer/SideStore/AltStore/TrollStore iOS 27
- search latest: SwiftUI iOS 27 regressions
- search latest: NECP bugs 2025-2026
- search latest: mbuf bugs 2025-2026
- search latest: socket bugs 2025-2026
- search latest: IOKit bugs 2025-2026
- search latest: Apple dev forums iOS 27 crashes
- if offline: say so. Do not guess.
- cite URL for any fact that can change.

## 1 Update

- date: 2026-09-27
- device: iPhone14,5 / iOS 27.0 / 24A437
- kernel: xnu-13432.2.10~2/RELEASE_ARM64_T8110
- signature: ad-hoc, empty entitlements

## 2 NECP status

Working:
- op=0x03 -> 1 byte
- op=0x04 -> 280-byte TLV
- op=0x1A -> 280-byte TLV
- op=0x0D -> user VA
Closed:
- op=0x05 copy_list -> -1
- op=0x0C copy_parameters -> -1
- op=0x0F copy_update -> -1
- op=0x18 get_signed_id -> empty
- op=0x19 set_signed_id -> -1
- TLV overflow -> rejected
- add_flow 0x24..0xF0 ok; 0xF1+ -> -1
- remove_flow x2 -> ret=0, copy_result=1
- copy_result_inner kptr count=0
- copy_interface 1..10 -> ret=0 no data

## 3 Caller graph

- necp_flow_alloc: 0xA346E70 callers 0xA346474 0xA348180
- necp_handler_big: 0xA3D91B4 caller 0xA3D9174
- necp_get_tlv: 0xA4C2034 caller 0xA4C113C (9 BL)
- necp_open: 0xA4E411C dispatcher BR/BLR
- necp_client_action: 0xA4E5C28 dispatcher BR/BLR
- syscall_dispatcher: 0xA6CEB84

## 4 Potential integer overflow

necp_flow_alloc 0xA346E70:
  uVar6 = min(user_count, 0x80)
  iVar1 = (uVar6 + param_3) * 0x14|0x18
  kalloc_type_necp_flow(iVar1)
  copyin(user_ptr, buf, uVar6 * 0x14|0x18)
If param_3 wraps int32 -> alloc < copyin -> heap overflow.
param_3 origin: decompile FUN_fffffff00a346474.
flow_alloc_overflow_attempt no longer masks with 0xFFFF.

## 5 Confirmed safe

- sooptcopyin 0xA77FD2C maxlen checked
- necp_handler_big 0xA3D91B4 uVar21>=0x2001
- necp_client_add_flow 0xA4E843C rejects 0xBF..0xF0
- necp_update_cache 0xA4EBD58 user ptr via copyin only

## 6 iOS 27 runtime crashes

SIGKILL CODESIGNING (never from ad-hoc):
- proc_info(336) any flavor
- csops(169) any op
- task_info flavor sweep 1..40
- mach_port_names count>32
SIGSYS sandbox (never do):
- blind syscall sweep 0..558 (dies on syscall 78)
Safe whitelist:
- getpid=20
- getuid=24
- getgid=47
- getppid=39
- geteuid=25
- getegid=43
- gettid=286
- getpgid=202
- socket/getsockopt/setsockopt/sysctl/uname always safe

## 7 Signature

- empty entitlements <dict></dict> for LiveContainer
- non-empty com.apple.private.* -> AMFI kills
- ldid -Snatsuk1/Resources/natsuk1.entitlements
- works: Sideloadly AltStore TrollStore ESign LiveContainer
- does NOT work: LiveContainer with privileged entitlements

## 8 Build gotchas

- mach_vm.h missing in SDK 26.5 -> declare manually
- TCP_KEEPINIT etc missing in SDK
- @MainActor + nonisolated(unsafe) static shared -> error
- sysctlbyname hw.memsize -> UInt64
- nk_offsets.h must define NK_SYSENT_BASE, NK_SYSENT_COUNT
- GrappaHelper static tokens MUST stay: array collapse breaks fallback

## 9 SwiftUI iOS 27

- .overlay(RespringView) -> CA UAF -> SIGSEGV
- List { if cond { Section } else { Section } } -> crash
- .scaleEffect inside if -> _ConditionalContent breaks
- @Published from Task{} -> race -> UAF

## 10 Offsets

- KBASE 0xFFFFFFF007004000
- SLIDE 0x3D00000
- SYSENT_BASE 0xFFFFFFF007C192A0
- necp_open 0xFFFFFFF00A4E411C
- necp_client_action 0xFFFFFFF00A4E5C28
- necp_client_add_flow 0xFFFFFFF00A4E843C
- necp_client_remove_client 0xFFFFFFF00A4E76F4
- necp_client_remove_flow 0xFFFFFFF00A4E93C4
- necp_client_copy_list 0xFFFFFFF00A4E80FC
- necp_client_copy_result 0xFFFFFFF00A4E7BE8
- necp_client_copy_result_inner 0xFFFFFFF00A4F26F0
- necp_client_copy_interface 0xFFFFFFF00A4EAC7C
- necp_client_copy_update 0xFFFFFFF00A4EC264
- necp_client_sysctl_arena 0xFFFFFFF00A4EB704
- necp_get_tlv_at_offset 0xFFFFFFF00A4C2034
- necp_flow_alloc 0xFFFFFFF00A346E70
- necp_handler_big 0xFFFFFFF00A3D91B4
- necp_update_cache 0xFFFFFFF00A4EBD58
- necp_per_flow_copy 0xFFFFFFF00A4F2E70
- sooptcopyin 0xFFFFFFF00A77FD2C
- sbappendcontrol 0xFFFFFFF00A788A24
- sbappendrecord 0xFFFFFFF00A7873B8
- sbappendstream 0xFFFFFFF00A78811C
- copyin 0xFFFFFFF00A368EC0
- copyout 0xFFFFFFF00A369A3C
- kalloc_type 0xFFFFFFF00A200988
- kfree_type 0xFFFFFFF00A201000
- kalloc_type_necp_flow 0xFFFFFFF007C62E68
- flow_alloc_caller_1 0xFFFFFFF00A346474
- flow_alloc_caller_2 0xFFFFFFF00A348180
- handler_big_caller 0xFFFFFFF00A3D9174
- tlv_wrapper 0xFFFFFFF00A4C113C
- syscall_dispatcher 0xFFFFFFF00A6CEB84

## 11 Extract Offsets repo

- repo murk-sus/Hu-Tao-and-natsuki-anime-music-player
- workflow extract_offsets.yml
- script scripts/kernel_rw.py
- artifacts result.txt offsets.json kernel.log symbols.json
- ipsw kernel symbolicate --signatures symbolicator/kernel/27.0 --json KERNEL
- format {<decimal_addr>: <name>}
- jython 2.7: isinstance(x, basestring)
- no tabs, only 4 spaces
- validate: python3 -c 'import ast,sys; ast.parse(...)'

## 12 YAML rules

- one workflow: fix_and_release.yml
- no C/Swift heredoc > 30 lines
- no rewriting sources from workflow
- all heredoc indented 10 spaces
- endmarker on 10 spaces
- grep -q -e pattern
- do not delete cached dirs

## 13 Next steps

- decompile FUN_fffffff00a346474, FUN_fffffff00a348180
- trace param_3 for necp_flow_alloc
- decompile syscall dispatcher 0xA6CEB84 case 501/502
- decompile FUN_fffffff00a4c113c TLV wrapper
- search IOKit IOSurface IOConnectCallMethod IOHIDEvent
- mbuf m_copydata mbuf_copydata with user lengths

## 14 What NOT to do

- no fix_and_test.yml or build_and_release.yml
- no rewriting sources from workflow
- no hashFiles cache keys on kernelcache
- no blind syscall sweep
- no proc_info/csops/task_info sweep/mach_port_names
- no non-empty entitlements
- no @Published mutation from Task{}
- no RespringView in SwiftUI tree
- no al_device_respring without gate
- no commit of natsuk1.xcodeproj
- no trust of offsets without Ghidra
- no answer without web search first
- no deleting ghidra/kernelcache/symbolicator
- no collapsing GrappaHelper token array to NULL

## 15 Full BSD syscall table 0..557

Safety: S=safe, C=codesign-kill, B=sandbox, U=unknown.

### syscall 0: reserved_0
- number: 0
- name: reserved_0
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 1: exit
- number: 1
- name: exit
- safety: S
- args: status
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 2: fork
- number: 2
- name: fork
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 3: read
- number: 3
- name: read
- safety: S
- args: fd buf nbyte
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 4: write
- number: 4
- name: write
- safety: S
- args: fd buf nbyte
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 5: open
- number: 5
- name: open
- safety: S
- args: path flags mode
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 6: close
- number: 6
- name: close
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 7: wait4
- number: 7
- name: wait4
- safety: B
- args: pid status options rusage
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 8: reserved_8
- number: 8
- name: reserved_8
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 9: link
- number: 9
- name: link
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 10: unlink
- number: 10
- name: unlink
- safety: S
- args: path
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 11: execve
- number: 11
- name: execve
- safety: B
- args: path argv envp
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 12: chdir
- number: 12
- name: chdir
- safety: S
- args: path
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 13: fchdir
- number: 13
- name: fchdir
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 14: mknod
- number: 14
- name: mknod
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 15: chmod
- number: 15
- name: chmod
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 16: chown
- number: 16
- name: chown
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 17: getfsstat
- number: 17
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 18: getpid
- number: 18
- name: getpid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 19: getppid
- number: 19
- name: getppid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 20: getpid
- number: 20
- name: getpid
- safety: S
- args: dup
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 21: access
- number: 21
- name: access
- safety: S
- args: path mode
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 22: geteuid
- number: 22
- name: geteuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 23: getegid
- number: 23
- name: getegid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 24: getuid
- number: 24
- name: getuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 25: geteuid
- number: 25
- name: geteuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 26: getgid
- number: 26
- name: getgid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 27: getegid
- number: 27
- name: getegid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 28: getgroups
- number: 28
- name: getgroups
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 29: getpgrp
- number: 29
- name: getpgrp
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 30: setpgid
- number: 30
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 31: setreuid
- number: 31
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 32: setregid
- number: 32
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 33: getgroups
- number: 33
- name: getgroups
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 34: setgroups
- number: 34
- name: setgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 35: getlogin
- number: 35
- name: getlogin
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 36: setlogin
- number: 36
- name: setlogin
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 37: acct
- number: 37
- name: acct
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 38: sigpending
- number: 38
- name: sigpending
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 39: sigprocmask
- number: 39
- name: sigprocmask
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 40: sigaction
- number: 40
- name: sigaction
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 41: reserved_41
- number: 41
- name: reserved_41
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 42: reserved_42
- number: 42
- name: reserved_42
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 43: reserved_43
- number: 43
- name: reserved_43
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 44: kill
- number: 44
- name: kill
- safety: B
- args: pid sig
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 45: killpg
- number: 45
- name: killpg
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 46: setpgrp
- number: 46
- name: setpgrp
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 47: setuid
- number: 47
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 48: setgid
- number: 48
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 49: seteuid
- number: 49
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 50: setegid
- number: 50
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 51: reserved_51
- number: 51
- name: reserved_51
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 52: reserved_52
- number: 52
- name: reserved_52
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 53: reserved_53
- number: 53
- name: reserved_53
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 54: reserved_54
- number: 54
- name: reserved_54
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 55: reserved_55
- number: 55
- name: reserved_55
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 56: reserved_56
- number: 56
- name: reserved_56
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 57: reserved_57
- number: 57
- name: reserved_57
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 58: getpgid
- number: 58
- name: getpgid
- safety: S
- args: pid
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 59: reserved_59
- number: 59
- name: reserved_59
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 60: getlogin
- number: 60
- name: getlogin
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 61: reserved_61
- number: 61
- name: reserved_61
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 62: getrlimit
- number: 62
- name: getrlimit
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 63: setrlimit
- number: 63
- name: setrlimit
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 64: getrusage
- number: 64
- name: getrusage
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 65: gettimeofday
- number: 65
- name: gettimeofday
- safety: S
- args: tv tz
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 66: settimeofday
- number: 66
- name: settimeofday
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 67: adjtime
- number: 67
- name: adjtime
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 68: getitimer
- number: 68
- name: getitimer
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 69: setitimer
- number: 69
- name: setitimer
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 70: getdtablesize
- number: 70
- name: getdtablesize
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 71: select
- number: 71
- name: select
- safety: S
- args: nfds rf wf ef tv
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 72: dup
- number: 72
- name: dup
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 73: dup2
- number: 73
- name: dup2
- safety: S
- args: fd fd2
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 74: fcntl
- number: 74
- name: fcntl
- safety: S
- args: fd cmd arg
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 75: ioctl
- number: 75
- name: ioctl
- safety: U
- args: fd req arg varies
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 76: pipe
- number: 76
- name: pipe
- safety: S
- args: fds
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 77: socketpair
- number: 77
- name: socketpair
- safety: S
- args: domain type proto pf
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 78: unlinkat
- number: 78
- name: unlinkat
- safety: S
- args: CAUTION kills in some contexts
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 79: getpriority
- number: 79
- name: getpriority
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 80: setpriority
- number: 80
- name: setpriority
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 81: getdents
- number: 81
- name: getdents
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 82: getdirentries
- number: 82
- name: getdirentries
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 83: reserved_83
- number: 83
- name: reserved_83
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 84: getdirentries
- number: 84
- name: getdirentries
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 85: readv
- number: 85
- name: readv
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 86: writev
- number: 86
- name: writev
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 87: getdents64
- number: 87
- name: getdents64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 88: getdirentries64
- number: 88
- name: getdirentries64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 89: reserved_89
- number: 89
- name: reserved_89
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 90: fsync
- number: 90
- name: fsync
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 91: fdatasync
- number: 91
- name: fdatasync
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 92: sync
- number: 92
- name: sync
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 93: ffsctl
- number: 93
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 94: reserved_94
- number: 94
- name: reserved_94
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 95: reserved_95
- number: 95
- name: reserved_95
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 96: semctl
- number: 96
- name: semctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 97: semget
- number: 97
- name: semget
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 98: semop
- number: 98
- name: semop
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 99: msgctl
- number: 99
- name: msgctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 100: msgget
- number: 100
- name: msgget
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 101: msgsnd
- number: 101
- name: msgsnd
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 102: msgrcv
- number: 102
- name: msgrcv
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 103: shmat
- number: 103
- name: shmat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 104: shmctl
- number: 104
- name: shmctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 105: shmdt
- number: 105
- name: shmdt
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 106: shmget
- number: 106
- name: shmget
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 107: shm_open
- number: 107
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 108: shm_unlink
- number: 108
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 109: sem_open
- number: 109
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 110: sem_close
- number: 110
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 111: sem_unlink
- number: 111
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 112: sem_wait
- number: 112
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 113: sem_trywait
- number: 113
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 114: sem_post
- number: 114
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 115: sem_getvalue
- number: 115
- name: sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 116: sem_init
- number: 116
- name: sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 117: sem_destroy
- number: 117
- name: sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 118: open_extended
- number: 118
- name: open_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 119: umask_extended
- number: 119
- name: umask_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 120: stat_extended
- number: 120
- name: stat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 121: lstat_extended
- number: 121
- name: lstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 122: fstat_extended
- number: 122
- name: fstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 123: chmod_extended
- number: 123
- name: chmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 124: fchmod_extended
- number: 124
- name: fchmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 125: access_extended
- number: 125
- name: access_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 126: setattrlist
- number: 126
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 127: getattrlist
- number: 127
- name: getattrlist
- safety: S
- args: path alist attrBuf size
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 128: reserved_128
- number: 128
- name: reserved_128
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 129: waitid
- number: 129
- name: waitid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 130: searchfs
- number: 130
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 131: quotactl
- number: 131
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 132: nfssvc
- number: 132
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 133: fstatfs
- number: 133
- name: fstatfs
- safety: S
- args: fd st
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 134: getfsstat
- number: 134
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 135: getvfsstat
- number: 135
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 136: fstatfs64
- number: 136
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 137: statfs
- number: 137
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 138: statfs64
- number: 138
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 139: getfsstat64
- number: 139
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 140: getvfsstat64
- number: 140
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 141: fgetattrlist
- number: 141
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 142: fsetattrlist
- number: 142
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 143: exchangedata
- number: 143
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 144: getxattr
- number: 144
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 145: fgetxattr
- number: 145
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 146: setxattr
- number: 146
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 147: fsetxattr
- number: 147
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 148: removexattr
- number: 148
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 149: fremovexattr
- number: 149
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 150: listxattr
- number: 150
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 151: flistxattr
- number: 151
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 152: fsctl
- number: 152
- name: fsctl
- safety: U
- args: fd cmd arg varies
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 153: initgroups
- number: 153
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 154: posix_spawn
- number: 154
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 155: ffsctl
- number: 155
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 156: setxattr
- number: 156
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 157: fsetxattr
- number: 157
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 158: getxattr
- number: 158
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 159: fgetxattr
- number: 159
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 160: removexattr
- number: 160
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 161: fremovexattr
- number: 161
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 162: listxattr
- number: 162
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 163: flistxattr
- number: 163
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 164: reserved_164
- number: 164
- name: reserved_164
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 165: reserved_165
- number: 165
- name: reserved_165
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 166: reserved_166
- number: 166
- name: reserved_166
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 167: reserved_167
- number: 167
- name: reserved_167
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 168: reserved_168
- number: 168
- name: reserved_168
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 169: csops
- number: 169
- name: csops
- safety: C
- args: pid op addr size SIGKILL ad-hoc
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 170: csops_audittoken
- number: 170
- name: csops_audittoken
- safety: C
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 171: reserved_171
- number: 171
- name: reserved_171
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 172: reserved_172
- number: 172
- name: reserved_172
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 173: readlink
- number: 173
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 174: readlinkat
- number: 174
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 175: kdebug_trace
- number: 175
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 176: reserved_176
- number: 176
- name: reserved_176
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 177: setgid
- number: 177
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 178: setegid
- number: 178
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 179: seteuid
- number: 179
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 180: setreuid
- number: 180
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 181: setuid
- number: 181
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 182: setregid
- number: 182
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 183: getattrlistbulk
- number: 183
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 184: madvise
- number: 184
- name: madvise
- safety: S
- args: addr len advice
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 185: mincore
- number: 185
- name: mincore
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 186: getattrlist
- number: 186
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 187: getattrlistbulk
- number: 187
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 188: openat
- number: 188
- name: openat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 189: openat_nocancel
- number: 189
- name: openat_nocancel
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 190: renameat
- number: 190
- name: renameat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 191: faccessat
- number: 191
- name: faccessat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 192: fchmodat
- number: 192
- name: fchmodat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 193: fchownat
- number: 193
- name: fchownat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 194: fstatat
- number: 194
- name: fstatat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 195: fstatat64
- number: 195
- name: fstatat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 196: linkat
- number: 196
- name: linkat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 197: unlinkat
- number: 197
- name: unlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 198: readlinkat
- number: 198
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 199: symlinkat
- number: 199
- name: symlinkat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 200: mkdirat
- number: 200
- name: mkdirat
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 201: getattrlistat
- number: 201
- name: getattrlistat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 202: getpgid
- number: 202
- name: getpgid
- safety: S
- args: pid
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 203: setpgid
- number: 203
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 204: madvise
- number: 204
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 205: mkfifo
- number: 205
- name: mkfifo
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 206: reserved_206
- number: 206
- name: reserved_206
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 207: reserved_207
- number: 207
- name: reserved_207
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 208: reserved_208
- number: 208
- name: reserved_208
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 209: reserved_209
- number: 209
- name: reserved_209
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 210: reserved_210
- number: 210
- name: reserved_210
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 211: reserved_211
- number: 211
- name: reserved_211
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 212: reserved_212
- number: 212
- name: reserved_212
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 213: reserved_213
- number: 213
- name: reserved_213
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 214: sysctl
- number: 214
- name: sysctl
- safety: S
- args: name namelen old oldlen new newlen
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 215: reserved_215
- number: 215
- name: reserved_215
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 216: sysctlbyname
- number: 216
- name: sysctlbyname
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 217: reserved_217
- number: 217
- name: reserved_217
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 218: reserved_218
- number: 218
- name: reserved_218
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 219: reserved_219
- number: 219
- name: reserved_219
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 220: exchangedata
- number: 220
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 221: searchfs
- number: 221
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 222: quotactl
- number: 222
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 223: nfssvc
- number: 223
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 224: fstatfs
- number: 224
- name: fstatfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 225: getfsstat
- number: 225
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 226: getvfsstat
- number: 226
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 227: fstatfs64
- number: 227
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 228: statfs
- number: 228
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 229: statfs64
- number: 229
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 230: getfsstat64
- number: 230
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 231: getvfsstat64
- number: 231
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 232: fgetattrlist
- number: 232
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 233: fsetattrlist
- number: 233
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 234: exchangedata
- number: 234
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 235: getxattr
- number: 235
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 236: fgetxattr
- number: 236
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 237: setxattr
- number: 237
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 238: fsetxattr
- number: 238
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 239: removexattr
- number: 239
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 240: fremovexattr
- number: 240
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 241: listxattr
- number: 241
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 242: flistxattr
- number: 242
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 243: fsctl
- number: 243
- name: fsctl
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 244: initgroups
- number: 244
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 245: posix_spawn
- number: 245
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 246: ffsctl
- number: 246
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 247: getattrlistbulk
- number: 247
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 248: readlink
- number: 248
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 249: readlinkat
- number: 249
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 250: kdebug_trace
- number: 250
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 251: reserved_251
- number: 251
- name: reserved_251
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 252: reserved_252
- number: 252
- name: reserved_252
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 253: reserved_253
- number: 253
- name: reserved_253
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 254: reserved_254
- number: 254
- name: reserved_254
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 255: reserved_255
- number: 255
- name: reserved_255
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 256: reserved_256
- number: 256
- name: reserved_256
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 257: reserved_257
- number: 257
- name: reserved_257
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 258: reserved_258
- number: 258
- name: reserved_258
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 259: reserved_259
- number: 259
- name: reserved_259
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 260: reserved_260
- number: 260
- name: reserved_260
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 261: reserved_261
- number: 261
- name: reserved_261
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 262: reserved_262
- number: 262
- name: reserved_262
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 263: reserved_263
- number: 263
- name: reserved_263
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 264: reserved_264
- number: 264
- name: reserved_264
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 265: reserved_265
- number: 265
- name: reserved_265
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 266: reserved_266
- number: 266
- name: reserved_266
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 267: reserved_267
- number: 267
- name: reserved_267
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 268: reserved_268
- number: 268
- name: reserved_268
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 269: reserved_269
- number: 269
- name: reserved_269
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 270: reserved_270
- number: 270
- name: reserved_270
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 271: reserved_271
- number: 271
- name: reserved_271
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 272: reserved_272
- number: 272
- name: reserved_272
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 273: reserved_273
- number: 273
- name: reserved_273
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 274: reserved_274
- number: 274
- name: reserved_274
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 275: reserved_275
- number: 275
- name: reserved_275
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 276: reserved_276
- number: 276
- name: reserved_276
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 277: reserved_277
- number: 277
- name: reserved_277
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 278: reserved_278
- number: 278
- name: reserved_278
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 279: reserved_279
- number: 279
- name: reserved_279
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 280: reserved_280
- number: 280
- name: reserved_280
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 281: reserved_281
- number: 281
- name: reserved_281
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 282: reserved_282
- number: 282
- name: reserved_282
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 283: reserved_283
- number: 283
- name: reserved_283
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 284: reserved_284
- number: 284
- name: reserved_284
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 285: reserved_285
- number: 285
- name: reserved_285
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 286: gettid
- number: 286
- name: gettid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 287: reserved_287
- number: 287
- name: reserved_287
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 288: reserved_288
- number: 288
- name: reserved_288
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 289: reserved_289
- number: 289
- name: reserved_289
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 290: reserved_290
- number: 290
- name: reserved_290
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 291: reserved_291
- number: 291
- name: reserved_291
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 292: reserved_292
- number: 292
- name: reserved_292
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 293: reserved_293
- number: 293
- name: reserved_293
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 294: reserved_294
- number: 294
- name: reserved_294
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 295: reserved_295
- number: 295
- name: reserved_295
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 296: reserved_296
- number: 296
- name: reserved_296
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 297: reserved_297
- number: 297
- name: reserved_297
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 298: reserved_298
- number: 298
- name: reserved_298
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 299: reserved_299
- number: 299
- name: reserved_299
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 300: reserved_300
- number: 300
- name: reserved_300
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 301: reserved_301
- number: 301
- name: reserved_301
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 302: reserved_302
- number: 302
- name: reserved_302
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 303: reserved_303
- number: 303
- name: reserved_303
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 304: reserved_304
- number: 304
- name: reserved_304
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 305: reserved_305
- number: 305
- name: reserved_305
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 306: reserved_306
- number: 306
- name: reserved_306
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 307: reserved_307
- number: 307
- name: reserved_307
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 308: reserved_308
- number: 308
- name: reserved_308
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 309: reserved_309
- number: 309
- name: reserved_309
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 310: reserved_310
- number: 310
- name: reserved_310
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 311: reserved_311
- number: 311
- name: reserved_311
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 312: reserved_312
- number: 312
- name: reserved_312
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 313: reserved_313
- number: 313
- name: reserved_313
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 314: reserved_314
- number: 314
- name: reserved_314
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 315: reserved_315
- number: 315
- name: reserved_315
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 316: reserved_316
- number: 316
- name: reserved_316
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 317: reserved_317
- number: 317
- name: reserved_317
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 318: reserved_318
- number: 318
- name: reserved_318
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 319: reserved_319
- number: 319
- name: reserved_319
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 320: reserved_320
- number: 320
- name: reserved_320
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 321: reserved_321
- number: 321
- name: reserved_321
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 322: reserved_322
- number: 322
- name: reserved_322
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 323: reserved_323
- number: 323
- name: reserved_323
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 324: reserved_324
- number: 324
- name: reserved_324
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 325: reserved_325
- number: 325
- name: reserved_325
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 326: reserved_326
- number: 326
- name: reserved_326
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 327: reserved_327
- number: 327
- name: reserved_327
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 328: reserved_328
- number: 328
- name: reserved_328
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 329: reserved_329
- number: 329
- name: reserved_329
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 330: reserved_330
- number: 330
- name: reserved_330
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 331: reserved_331
- number: 331
- name: reserved_331
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 332: reserved_332
- number: 332
- name: reserved_332
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 333: reserved_333
- number: 333
- name: reserved_333
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 334: reserved_334
- number: 334
- name: reserved_334
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 335: reserved_335
- number: 335
- name: reserved_335
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 336: proc_info
- number: 336
- name: proc_info
- safety: C
- args: callnum pid flavor arg size SIGKILL
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 337: task_name_for_pid
- number: 337
- name: task_name_for_pid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 338: task_for_pid
- number: 338
- name: task_for_pid
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 339: pid_for_task
- number: 339
- name: pid_for_task
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 340: mac_syscall
- number: 340
- name: mac_syscall
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 341: kqueue
- number: 341
- name: kqueue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 342: kevent
- number: 342
- name: kevent
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 343: workq_open
- number: 343
- name: workq_open
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 344: workq_kernreturn
- number: 344
- name: workq_kernreturn
- safety: B
- ad-hoc: may SIGSYS under sandbox
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 345: kevent64
- number: 345
- name: kevent64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 346: reserved_346
- number: 346
- name: reserved_346
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 347: reserved_347
- number: 347
- name: reserved_347
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 348: reserved_348
- number: 348
- name: reserved_348
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 349: reserved_349
- number: 349
- name: reserved_349
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 350: reserved_350
- number: 350
- name: reserved_350
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 351: reserved_351
- number: 351
- name: reserved_351
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 352: reserved_352
- number: 352
- name: reserved_352
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 353: reserved_353
- number: 353
- name: reserved_353
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 354: reserved_354
- number: 354
- name: reserved_354
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 355: reserved_355
- number: 355
- name: reserved_355
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 356: reserved_356
- number: 356
- name: reserved_356
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 357: reserved_357
- number: 357
- name: reserved_357
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 358: reserved_358
- number: 358
- name: reserved_358
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 359: reserved_359
- number: 359
- name: reserved_359
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 360: reserved_360
- number: 360
- name: reserved_360
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 361: reserved_361
- number: 361
- name: reserved_361
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 362: reserved_362
- number: 362
- name: reserved_362
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 363: reserved_363
- number: 363
- name: reserved_363
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 364: reserved_364
- number: 364
- name: reserved_364
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 365: reserved_365
- number: 365
- name: reserved_365
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 366: reserved_366
- number: 366
- name: reserved_366
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 367: reserved_367
- number: 367
- name: reserved_367
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 368: reserved_368
- number: 368
- name: reserved_368
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 369: reserved_369
- number: 369
- name: reserved_369
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 370: reserved_370
- number: 370
- name: reserved_370
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 371: reserved_371
- number: 371
- name: reserved_371
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 372: reserved_372
- number: 372
- name: reserved_372
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 373: reserved_373
- number: 373
- name: reserved_373
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 374: reserved_374
- number: 374
- name: reserved_374
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 375: reserved_375
- number: 375
- name: reserved_375
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 376: reserved_376
- number: 376
- name: reserved_376
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 377: reserved_377
- number: 377
- name: reserved_377
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 378: reserved_378
- number: 378
- name: reserved_378
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 379: reserved_379
- number: 379
- name: reserved_379
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 380: reserved_380
- number: 380
- name: reserved_380
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 381: reserved_381
- number: 381
- name: reserved_381
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 382: getentropy
- number: 382
- name: getentropy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 383: reserved_383
- number: 383
- name: reserved_383
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 384: gettid
- number: 384
- name: gettid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 385: reserved_385
- number: 385
- name: reserved_385
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 386: reserved_386
- number: 386
- name: reserved_386
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 387: reserved_387
- number: 387
- name: reserved_387
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 388: reserved_388
- number: 388
- name: reserved_388
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 389: reserved_389
- number: 389
- name: reserved_389
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 390: reserved_390
- number: 390
- name: reserved_390
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 391: reserved_391
- number: 391
- name: reserved_391
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 392: reserved_392
- number: 392
- name: reserved_392
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 393: reserved_393
- number: 393
- name: reserved_393
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 394: reserved_394
- number: 394
- name: reserved_394
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 395: reserved_395
- number: 395
- name: reserved_395
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 396: reserved_396
- number: 396
- name: reserved_396
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 397: reserved_397
- number: 397
- name: reserved_397
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 398: reserved_398
- number: 398
- name: reserved_398
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 399: reserved_399
- number: 399
- name: reserved_399
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 400: reserved_400
- number: 400
- name: reserved_400
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 401: reserved_401
- number: 401
- name: reserved_401
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 402: reserved_402
- number: 402
- name: reserved_402
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 403: reserved_403
- number: 403
- name: reserved_403
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 404: reserved_404
- number: 404
- name: reserved_404
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 405: reserved_405
- number: 405
- name: reserved_405
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 406: reserved_406
- number: 406
- name: reserved_406
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 407: reserved_407
- number: 407
- name: reserved_407
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 408: reserved_408
- number: 408
- name: reserved_408
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 409: reserved_409
- number: 409
- name: reserved_409
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 410: reserved_410
- number: 410
- name: reserved_410
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 411: reserved_411
- number: 411
- name: reserved_411
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 412: reserved_412
- number: 412
- name: reserved_412
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 413: reserved_413
- number: 413
- name: reserved_413
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 414: reserved_414
- number: 414
- name: reserved_414
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 415: reserved_415
- number: 415
- name: reserved_415
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 416: reserved_416
- number: 416
- name: reserved_416
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 417: reserved_417
- number: 417
- name: reserved_417
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 418: reserved_418
- number: 418
- name: reserved_418
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 419: reserved_419
- number: 419
- name: reserved_419
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 420: reserved_420
- number: 420
- name: reserved_420
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 421: reserved_421
- number: 421
- name: reserved_421
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 422: reserved_422
- number: 422
- name: reserved_422
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 423: reserved_423
- number: 423
- name: reserved_423
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 424: reserved_424
- number: 424
- name: reserved_424
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 425: reserved_425
- number: 425
- name: reserved_425
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 426: reserved_426
- number: 426
- name: reserved_426
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 427: reserved_427
- number: 427
- name: reserved_427
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 428: reserved_428
- number: 428
- name: reserved_428
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 429: reserved_429
- number: 429
- name: reserved_429
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 430: reserved_430
- number: 430
- name: reserved_430
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 431: reserved_431
- number: 431
- name: reserved_431
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 432: reserved_432
- number: 432
- name: reserved_432
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 433: reserved_433
- number: 433
- name: reserved_433
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 434: reserved_434
- number: 434
- name: reserved_434
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 435: reserved_435
- number: 435
- name: reserved_435
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 436: reserved_436
- number: 436
- name: reserved_436
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 437: reserved_437
- number: 437
- name: reserved_437
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 438: reserved_438
- number: 438
- name: reserved_438
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 439: reserved_439
- number: 439
- name: reserved_439
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 440: reserved_440
- number: 440
- name: reserved_440
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 441: reserved_441
- number: 441
- name: reserved_441
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 442: reserved_442
- number: 442
- name: reserved_442
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 443: reserved_443
- number: 443
- name: reserved_443
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 444: reserved_444
- number: 444
- name: reserved_444
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 445: reserved_445
- number: 445
- name: reserved_445
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 446: reserved_446
- number: 446
- name: reserved_446
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 447: reserved_447
- number: 447
- name: reserved_447
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 448: reserved_448
- number: 448
- name: reserved_448
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 449: reserved_449
- number: 449
- name: reserved_449
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 450: reserved_450
- number: 450
- name: reserved_450
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 451: reserved_451
- number: 451
- name: reserved_451
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 452: reserved_452
- number: 452
- name: reserved_452
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 453: reserved_453
- number: 453
- name: reserved_453
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 454: reserved_454
- number: 454
- name: reserved_454
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 455: reserved_455
- number: 455
- name: reserved_455
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 456: reserved_456
- number: 456
- name: reserved_456
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 457: reserved_457
- number: 457
- name: reserved_457
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 458: reserved_458
- number: 458
- name: reserved_458
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 459: reserved_459
- number: 459
- name: reserved_459
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 460: reserved_460
- number: 460
- name: reserved_460
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 461: reserved_461
- number: 461
- name: reserved_461
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 462: reserved_462
- number: 462
- name: reserved_462
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 463: reserved_463
- number: 463
- name: reserved_463
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 464: reserved_464
- number: 464
- name: reserved_464
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 465: reserved_465
- number: 465
- name: reserved_465
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 466: reserved_466
- number: 466
- name: reserved_466
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 467: reserved_467
- number: 467
- name: reserved_467
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 468: reserved_468
- number: 468
- name: reserved_468
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 469: reserved_469
- number: 469
- name: reserved_469
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 470: reserved_470
- number: 470
- name: reserved_470
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 471: reserved_471
- number: 471
- name: reserved_471
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 472: reserved_472
- number: 472
- name: reserved_472
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 473: reserved_473
- number: 473
- name: reserved_473
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 474: reserved_474
- number: 474
- name: reserved_474
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 475: reserved_475
- number: 475
- name: reserved_475
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 476: reserved_476
- number: 476
- name: reserved_476
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 477: reserved_477
- number: 477
- name: reserved_477
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 478: reserved_478
- number: 478
- name: reserved_478
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 479: reserved_479
- number: 479
- name: reserved_479
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 480: reserved_480
- number: 480
- name: reserved_480
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 481: reserved_481
- number: 481
- name: reserved_481
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 482: reserved_482
- number: 482
- name: reserved_482
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 483: reserved_483
- number: 483
- name: reserved_483
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 484: reserved_484
- number: 484
- name: reserved_484
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 485: reserved_485
- number: 485
- name: reserved_485
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 486: reserved_486
- number: 486
- name: reserved_486
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 487: reserved_487
- number: 487
- name: reserved_487
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 488: reserved_488
- number: 488
- name: reserved_488
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 489: reserved_489
- number: 489
- name: reserved_489
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 490: reserved_490
- number: 490
- name: reserved_490
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 491: reserved_491
- number: 491
- name: reserved_491
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 492: reserved_492
- number: 492
- name: reserved_492
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 493: reserved_493
- number: 493
- name: reserved_493
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 494: reserved_494
- number: 494
- name: reserved_494
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 495: reserved_495
- number: 495
- name: reserved_495
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 496: reserved_496
- number: 496
- name: reserved_496
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 497: reserved_497
- number: 497
- name: reserved_497
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 498: reserved_498
- number: 498
- name: reserved_498
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 499: reserved_499
- number: 499
- name: reserved_499
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 500: reserved_500
- number: 500
- name: reserved_500
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 501: necp_open
- number: 501
- name: necp_open
- safety: S
- args: flags
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 502: necp_client_action
- number: 502
- name: necp_client_action
- safety: S
- args: fd op uuid uuid_len buf buf_len
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 503: reserved_503
- number: 503
- name: reserved_503
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 504: reserved_504
- number: 504
- name: reserved_504
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 505: reserved_505
- number: 505
- name: reserved_505
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 506: reserved_506
- number: 506
- name: reserved_506
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 507: reserved_507
- number: 507
- name: reserved_507
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 508: reserved_508
- number: 508
- name: reserved_508
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 509: reserved_509
- number: 509
- name: reserved_509
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 510: reserved_510
- number: 510
- name: reserved_510
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 511: reserved_511
- number: 511
- name: reserved_511
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 512: reserved_512
- number: 512
- name: reserved_512
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 513: reserved_513
- number: 513
- name: reserved_513
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 514: reserved_514
- number: 514
- name: reserved_514
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 515: reserved_515
- number: 515
- name: reserved_515
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 516: reserved_516
- number: 516
- name: reserved_516
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 517: reserved_517
- number: 517
- name: reserved_517
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 518: reserved_518
- number: 518
- name: reserved_518
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 519: reserved_519
- number: 519
- name: reserved_519
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 520: reserved_520
- number: 520
- name: reserved_520
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 521: reserved_521
- number: 521
- name: reserved_521
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 522: reserved_522
- number: 522
- name: reserved_522
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 523: reserved_523
- number: 523
- name: reserved_523
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 524: reserved_524
- number: 524
- name: reserved_524
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 525: reserved_525
- number: 525
- name: reserved_525
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 526: reserved_526
- number: 526
- name: reserved_526
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 527: reserved_527
- number: 527
- name: reserved_527
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 528: reserved_528
- number: 528
- name: reserved_528
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 529: reserved_529
- number: 529
- name: reserved_529
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 530: reserved_530
- number: 530
- name: reserved_530
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 531: reserved_531
- number: 531
- name: reserved_531
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 532: reserved_532
- number: 532
- name: reserved_532
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 533: reserved_533
- number: 533
- name: reserved_533
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 534: reserved_534
- number: 534
- name: reserved_534
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 535: reserved_535
- number: 535
- name: reserved_535
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 536: reserved_536
- number: 536
- name: reserved_536
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 537: reserved_537
- number: 537
- name: reserved_537
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 538: reserved_538
- number: 538
- name: reserved_538
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 539: reserved_539
- number: 539
- name: reserved_539
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 540: reserved_540
- number: 540
- name: reserved_540
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 541: reserved_541
- number: 541
- name: reserved_541
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 542: reserved_542
- number: 542
- name: reserved_542
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 543: reserved_543
- number: 543
- name: reserved_543
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 544: reserved_544
- number: 544
- name: reserved_544
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 545: reserved_545
- number: 545
- name: reserved_545
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 546: reserved_546
- number: 546
- name: reserved_546
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 547: reserved_547
- number: 547
- name: reserved_547
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 548: reserved_548
- number: 548
- name: reserved_548
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 549: reserved_549
- number: 549
- name: reserved_549
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 550: reserved_550
- number: 550
- name: reserved_550
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 551: reserved_551
- number: 551
- name: reserved_551
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 552: reserved_552
- number: 552
- name: reserved_552
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 553: reserved_553
- number: 553
- name: reserved_553
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 554: reserved_554
- number: 554
- name: reserved_554
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 555: reserved_555
- number: 555
- name: reserved_555
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 556: reserved_556
- number: 556
- name: reserved_556
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.

### syscall 557: reserved_557
- number: 557
- name: reserved_557
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check; passing
  uninitialized socklen pointer; using NUL-terminated string
  where API expects length-prefixed; reusing fd across fork.


## 16 NECP op table 0x01..0x1B

### NECP op 0x01: ADD_CLIENT
- opcode: 0x01
- symbol: add_client
- observed: ret 0
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x02: REMOVE_CLIENT
- opcode: 0x02
- symbol: remove_client
- observed: ret 0
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x03: COPY_RESULT
- opcode: 0x03
- symbol: copy_result
- observed: 1 byte
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x04: COPY_RESULT_ALT
- opcode: 0x04
- symbol: copy_result_alt
- observed: 280B TLV
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x05: COPY_LIST
- opcode: 0x05
- symbol: copy_list
- observed: -1
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x06: REQUEST_NEXUS
- opcode: 0x06
- symbol: request_nexus
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x07: AGENT_ACTION
- opcode: 0x07
- symbol: agent_action
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x08: COPY_AGENT
- opcode: 0x08
- symbol: copy_agent
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x09: COPY_INTERFACE
- opcode: 0x09
- symbol: copy_interface
- observed: ret=0 no data
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x0B: COPY_ROUTE_STATS
- opcode: 0x0B
- symbol: copy_route_stats
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x0C: COPY_PARAMETERS
- opcode: 0x0C
- symbol: copy_parameters
- observed: -1
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x0D: SYSCTL_ARENA
- opcode: 0x0D
- symbol: sysctl_arena
- observed: user VA
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x0E: UPDATE_CACHE
- opcode: 0x0E
- symbol: update_cache
- observed: kptr via copyin
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x0F: COPY_UPDATE
- opcode: 0x0F
- symbol: copy_update
- observed: -1
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x10: COPY_RESULT_LONG
- opcode: 0x10
- symbol: copy_result_long
- observed: 280B TLV
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x11: ADD_FLOW
- opcode: 0x11
- symbol: add_flow
- observed: 0x24..0xF0 ok
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x12: REMOVE_FLOW
- opcode: 0x12
- symbol: remove_flow
- observed: double-free ret 0
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x13: CLAIM
- opcode: 0x13
- symbol: claim
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x14: SIGN
- opcode: 0x14
- symbol: sign
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x15: GET_IFACE_ADDR
- opcode: 0x15
- symbol: get_iface_addr
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x16: COPY_AGENT_ALT
- opcode: 0x16
- symbol: copy_agent_alt
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x17: VALIDATE
- opcode: 0x17
- symbol: validate
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x18: GET_SIGNED_ID
- opcode: 0x18
- symbol: get_signed_id
- observed: empty
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x19: SET_SIGNED_ID
- opcode: 0x19
- symbol: set_signed_id
- observed: -1
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x1A: COPY_RESULT_LONG2
- opcode: 0x1A
- symbol: copy_result_long2
- observed: 280B TLV
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout

### NECP op 0x1B: GET_FLOW_STATS
- opcode: 0x1B
- symbol: get_flow_stats
- observed: unknown
- signature: syscall(502, fd, op, uuid, ulen, buf, blen)
- uuid: 16 bytes, 8/8 halves
- buf: user pointer, kernel copyin/copyout depending on op
- never mix op codes; each op has its own arg layout


## 17 MobileGestalt keys

- ProductType (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ProductVersion (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BuildVersion (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- MarketingName (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- UserAssignedDeviceName (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- DeviceName (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ModelNumber (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- RegionCode (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- RegionInfo (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SerialNumber (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- UniqueDeviceID (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- IMEI (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- MEID (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ICCID (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- WiFiAddress (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BluetoothAddress (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- EthernetMacAddress (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BasebandVersion (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BasebandChipId (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BasebandSerialNumber (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- HWModel (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- CPUArchitecture (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- CPUType (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BoardId (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ChipID (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- DeviceSupportsApplePencil (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- DeviceSupportsFaceTime (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- HasBaseband (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- HasBattery (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- HasCellularTelephony (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- IsSimulator (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- PasswordProtected (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ActivationState (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ActivationStateAcknowledged (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- RegulatoryModelNumber (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ReleaseType (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SigningFuse (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SupportsExternalAccessory (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SupportsSiri (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SupportsTouchID (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- SupportsFaceID (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BatteryCurrentCapacity (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BatteryIsCharging (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- BatteryIsFullyCharged (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- DiskUsage (int)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- ScreenDimensions (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- FrontCameraCapturedMTF (float)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- RearCameraCapturedMTF (float)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- WifiChipset (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- WifiVendor (string)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- AirplaneMode (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt

- AssistedGPS (bool)
  - via MGGetStringAnswer / MGGetBoolAnswer / MGGetSInt32Answer
  - never spoof inside the process; only cache for display
  - writes require ldid + com.apple.private.MobileGestalt


## 18 Common errors and fixes

### unterminated string literal
- why: editor mangled a long string literal across lines
- fix: keep every Python string literal on one line
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### BUILD FAILED with no error text
- why: xcodebuild -quiet hides details
- fix: rerun without -quiet, or grep the xcactivitylog
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Undefined symbols _al_pairing_run_host
- why: AirliftFFI stub missing or not linked
- fix: run the Vendor AirliftFFI step
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### nonisolated(unsafe) with @MainActor
- why: Swift strict concurrency error
- fix: use final class Foo: ObservableObject, @unchecked Sendable
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### SIGKILL CODESIGNING at launch
- why: AMFI killed on proc_info/csops/task_info sweep
- fix: remove those calls; do not call from ad-hoc
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### SIGSYS at first syscall
- why: sandbox denies syscall 78 or nearby
- fix: do not blind-sweep syscalls; stick to allowlist
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### ldid: Invalid plist
- why: entitlements file malformed
- fix: regenerate entitlements from workflow step
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Payload missing
- why: cp -R of .app failed
- fix: verify APP_PATH is a directory containing Info.plist
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### natsuk1.xcodeproj committed
- why: gitignore did not apply
- fix: add natsuk1.xcodeproj/ to .gitignore
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Cache restore loses DerivedData
- why: cache key changed on every push
- fix: use restore-keys with prefix to fall back
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### grappa: token generation failed rc=-5
- why: static token array collapsed to NULL, fallback loop skipped
- fix: restore 10 tokens with marker nk-grappa-restored
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### atc sync state SyncFailed
- why: grappa rejected; ATC continues on Ping/Pong non-fatal
- fix: check [nk-grappa-diag] lines before treating as fatal
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying


## 19 Grappa / RPPairing on-device notes

What works from the log:
- tunnel up on 10.7.0.1:49152 via raw RPPairing
- RSD publishes 85 services
- AFC client connects
- StreamingZip extracts
- ATC Capabilities/InstalledAssets/AssetMetrics/SyncAllowed
Grappa path:
- host est via AirTrafficDevice returns nil on iOS
- static token fallback fires
- do NOT collapse token array; fallback loop must run
- look for [nk-grappa-diag] markers after restore
