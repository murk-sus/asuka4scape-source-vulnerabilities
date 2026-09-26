
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

## 15 Full BSD syscall table 0..557

Safety: S=safe, C=codesign-kill, B=sandbox, U=unknown.

### syscall 0: syscall
- number: 0
- name: syscall
- safety: U
- args: indirect
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 1: exit
- number: 1
- name: exit
- safety: S
- args: status
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 2: fork
- number: 2
- name: fork
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 3: read
- number: 3
- name: read
- safety: S
- args: fd buf nbyte
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 4: write
- number: 4
- name: write
- safety: S
- args: fd buf nbyte
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 5: open
- number: 5
- name: open
- safety: S
- args: path flags mode
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 6: close
- number: 6
- name: close
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 7: wait4
- number: 7
- name: wait4
- safety: B
- args: pid status options rusage
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 8: creat
- number: 8
- name: creat
- safety: B
- args: path mode
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 9: link
- number: 9
- name: link
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 10: unlink
- number: 10
- name: unlink
- safety: S
- args: path
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 11: execve
- number: 11
- name: execve
- safety: B
- args: path argv envp
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 12: chdir
- number: 12
- name: chdir
- safety: S
- args: path
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 13: fchdir
- number: 13
- name: fchdir
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 14: mknod
- number: 14
- name: mknod
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 15: chmod
- number: 15
- name: chmod
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 16: chown
- number: 16
- name: chown
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 17: getfsstat
- number: 17
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 18: getpid
- number: 18
- name: getpid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 19: getppid
- number: 19
- name: getppid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 20: getpid
- number: 20
- name: getpid
- safety: S
- args: (dup)
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 21: access
- number: 21
- name: access
- safety: S
- args: path mode
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 22: geteuid
- number: 22
- name: geteuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 23: getegid
- number: 23
- name: getegid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 24: getuid
- number: 24
- name: getuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 25: geteuid
- number: 25
- name: geteuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 26: getgid
- number: 26
- name: getgid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 27: getegid
- number: 27
- name: getegid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 28: getgroups
- number: 28
- name: getgroups
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 29: getpgrp
- number: 29
- name: getpgrp
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 30: setpgid
- number: 30
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 31: setreuid
- number: 31
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 32: setregid
- number: 32
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 33: getgroups
- number: 33
- name: getgroups
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 34: setgroups
- number: 34
- name: setgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 35: getlogin
- number: 35
- name: getlogin
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 36: setlogin
- number: 36
- name: setlogin
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 37: acct
- number: 37
- name: acct
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 38: sigpending
- number: 38
- name: sigpending
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 39: sigprocmask
- number: 39
- name: sigprocmask
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 40: sigaction
- number: 40
- name: sigaction
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 41: sigpend
- number: 41
- name: sigpend
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 42: sigsuspend
- number: 42
- name: sigsuspend
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 43: sigstack
- number: 43
- name: sigstack
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 44: kill
- number: 44
- name: kill
- safety: B
- args: pid sig
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 45: killpg
- number: 45
- name: killpg
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 46: setpgrp
- number: 46
- name: setpgrp
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 47: setuid
- number: 47
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 48: setgid
- number: 48
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 49: seteuid
- number: 49
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 50: setegid
- number: 50
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 51: setreuid
- number: 51
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 52: getuid
- number: 52
- name: getuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 53: geteuid
- number: 53
- name: geteuid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 54: getgid
- number: 54
- name: getgid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 55: getegid
- number: 55
- name: getegid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 56: getpid
- number: 56
- name: getpid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 57: getppid
- number: 57
- name: getppid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 58: getpgid
- number: 58
- name: getpgid
- safety: S
- args: pid
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 59: setpgid
- number: 59
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 60: getlogin
- number: 60
- name: getlogin
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 61: setlogin
- number: 61
- name: setlogin
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 62: getrlimit
- number: 62
- name: getrlimit
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 63: setrlimit
- number: 63
- name: setrlimit
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 64: getrusage
- number: 64
- name: getrusage
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 65: gettimeofday
- number: 65
- name: gettimeofday
- safety: S
- args: tv tz
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 66: settimeofday
- number: 66
- name: settimeofday
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 67: adjtime
- number: 67
- name: adjtime
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 68: getitimer
- number: 68
- name: getitimer
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 69: setitimer
- number: 69
- name: setitimer
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 70: getdtablesize
- number: 70
- name: getdtablesize
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 71: select
- number: 71
- name: select
- safety: S
- args: nfds rf wf ef tv
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 72: dup
- number: 72
- name: dup
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 73: dup2
- number: 73
- name: dup2
- safety: S
- args: fd fd2
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 74: fcntl
- number: 74
- name: fcntl
- safety: S
- args: fd cmd arg
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 75: ioctl
- number: 75
- name: ioctl
- safety: U
- args: fd req arg (varies)
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 76: pipe
- number: 76
- name: pipe
- safety: S
- args: fds
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 77: socketpair
- number: 77
- name: socketpair
- safety: S
- args: domain type proto pf
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 78: unlinkat
- number: 78
- name: unlinkat
- safety: S
- args: -- CAUTION: kills on some contexts
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 79: getpriority
- number: 79
- name: getpriority
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 80: setpriority
- number: 80
- name: setpriority
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 81: getdents
- number: 81
- name: getdents
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 82: getdirentries
- number: 82
- name: getdirentries
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 83: getdirentriesattr
- number: 83
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 84: getdirentries
- number: 84
- name: getdirentries
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 85: readv
- number: 85
- name: readv
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 86: writev
- number: 86
- name: writev
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 87: getdents64
- number: 87
- name: getdents64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 88: getdirentries64
- number: 88
- name: getdirentries64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 89: setdents64
- number: 89
- name: setdents64
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 90: fsync
- number: 90
- name: fsync
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 91: fdatasync
- number: 91
- name: fdatasync
- safety: S
- args: fd
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 92: sync
- number: 92
- name: sync
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 93: ffsctl
- number: 93
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 94: fattach
- number: 94
- name: fattach
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 95: fdetach
- number: 95
- name: fdetach
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 96: semctl
- number: 96
- name: semctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 97: semget
- number: 97
- name: semget
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 98: semop
- number: 98
- name: semop
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 99: msgctl
- number: 99
- name: msgctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 100: msgget
- number: 100
- name: msgget
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 101: msgsnd
- number: 101
- name: msgsnd
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 102: msgrcv
- number: 102
- name: msgrcv
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 103: shmat
- number: 103
- name: shmat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 104: shmctl
- number: 104
- name: shmctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 105: shmdt
- number: 105
- name: shmdt
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 106: shmget
- number: 106
- name: shmget
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 107: shm_open
- number: 107
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 108: shm_unlink
- number: 108
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 109: sem_open
- number: 109
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 110: sem_close
- number: 110
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 111: sem_unlink
- number: 111
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 112: sem_wait
- number: 112
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 113: sem_trywait
- number: 113
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 114: sem_post
- number: 114
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 115: sem_getvalue
- number: 115
- name: sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 116: sem_init
- number: 116
- name: sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 117: sem_destroy
- number: 117
- name: sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 118: open_extended
- number: 118
- name: open_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 119: umask_extended
- number: 119
- name: umask_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 120: stat_extended
- number: 120
- name: stat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 121: lstat_extended
- number: 121
- name: lstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 122: fstat_extended
- number: 122
- name: fstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 123: chmod_extended
- number: 123
- name: chmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 124: fchmod_extended
- number: 124
- name: fchmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 125: access_extended
- number: 125
- name: access_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 126: setattrlist
- number: 126
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 127: getattrlist
- number: 127
- name: getattrlist
- safety: S
- args: path alist attrBuf size
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 128: getdirentriesattr
- number: 128
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 129: waitid
- number: 129
- name: waitid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 130: searchfs
- number: 130
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 131: quotactl
- number: 131
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 132: nfssvc
- number: 132
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 133: fstatfs
- number: 133
- name: fstatfs
- safety: S
- args: fd st
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 134: getfsstat
- number: 134
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 135: getvfsstat
- number: 135
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 136: fstatfs64
- number: 136
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 137: statfs
- number: 137
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 138: statfs64
- number: 138
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 139: getfsstat64
- number: 139
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 140: getvfsstat64
- number: 140
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 141: fgetattrlist
- number: 141
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 142: fsetattrlist
- number: 142
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 143: exchangedata
- number: 143
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 144: getxattr
- number: 144
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 145: fgetxattr
- number: 145
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 146: setxattr
- number: 146
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 147: fsetxattr
- number: 147
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 148: removexattr
- number: 148
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 149: fremovexattr
- number: 149
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 150: listxattr
- number: 150
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 151: flistxattr
- number: 151
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 152: fsctl
- number: 152
- name: fsctl
- safety: U
- args: fd cmd arg (varies)
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 153: initgroups
- number: 153
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 154: posix_spawn
- number: 154
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 155: ffsctl
- number: 155
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 156: setxattr
- number: 156
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 157: fsetxattr
- number: 157
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 158: getxattr
- number: 158
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 159: fgetxattr
- number: 159
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 160: removexattr
- number: 160
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 161: fremovexattr
- number: 161
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 162: listxattr
- number: 162
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 163: flistxattr
- number: 163
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 164: fsctl
- number: 164
- name: fsctl
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 165: getxattr
- number: 165
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 166: fgetxattr
- number: 166
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 167: setxattr
- number: 167
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 168: fsetxattr
- number: 168
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 169: csops
- number: 169
- name: csops
- safety: C
- args: pid op addr size -- SIGKILL if ad-hoc
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 170: csops_audittoken
- number: 170
- name: csops_audittoken
- safety: C
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 171: waitid_nocancel
- number: 171
- name: waitid_nocancel
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 172: exchangedata
- number: 172
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 173: readlink
- number: 173
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 174: readlinkat
- number: 174
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 175: kdebug_trace
- number: 175
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 176: kdebug_trace_string
- number: 176
- name: kdebug_trace_string
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 177: setgid
- number: 177
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 178: setegid
- number: 178
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 179: seteuid
- number: 179
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 180: setreuid
- number: 180
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 181: setuid
- number: 181
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 182: setregid
- number: 182
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 183: getattrlistbulk
- number: 183
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 184: madvise
- number: 184
- name: madvise
- safety: S
- args: addr len advice
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 185: mincore
- number: 185
- name: mincore
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 186: getattrlist
- number: 186
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 187: getattrlistbulk
- number: 187
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 188: openat
- number: 188
- name: openat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 189: openat_nocancel
- number: 189
- name: openat_nocancel
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 190: renameat
- number: 190
- name: renameat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 191: faccessat
- number: 191
- name: faccessat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 192: fchmodat
- number: 192
- name: fchmodat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 193: fchownat
- number: 193
- name: fchownat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 194: fstatat
- number: 194
- name: fstatat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 195: fstatat64
- number: 195
- name: fstatat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 196: linkat
- number: 196
- name: linkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 197: unlinkat
- number: 197
- name: unlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 198: readlinkat
- number: 198
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 199: symlinkat
- number: 199
- name: symlinkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 200: mkdirat
- number: 200
- name: mkdirat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 201: getattrlistat
- number: 201
- name: getattrlistat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 202: getpgid
- number: 202
- name: getpgid
- safety: S
- args: pid
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 203: setpgid
- number: 203
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 204: madvise
- number: 204
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 205: mkfifo
- number: 205
- name: mkfifo
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 206: shm_open
- number: 206
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 207: shm_unlink
- number: 207
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 208: sem_open
- number: 208
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 209: sem_close
- number: 209
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 210: sem_unlink
- number: 210
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 211: sem_wait
- number: 211
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 212: sem_trywait
- number: 212
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 213: sem_post
- number: 213
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 214: sysctl
- number: 214
- name: sysctl
- safety: S
- args: name namelen old oldlen new newlen
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 215: sysctl
- number: 215
- name: sysctl
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 216: sysctlbyname
- number: 216
- name: sysctlbyname
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 217: getattrlist
- number: 217
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 218: setattrlist
- number: 218
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 219: getdirentriesattr
- number: 219
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 220: exchangedata
- number: 220
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 221: searchfs
- number: 221
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 222: quotactl
- number: 222
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 223: nfssvc
- number: 223
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 224: fstatfs
- number: 224
- name: fstatfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 225: getfsstat
- number: 225
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 226: getvfsstat
- number: 226
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 227: fstatfs64
- number: 227
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 228: statfs
- number: 228
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 229: statfs64
- number: 229
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 230: getfsstat64
- number: 230
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 231: getvfsstat64
- number: 231
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 232: fgetattrlist
- number: 232
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 233: fsetattrlist
- number: 233
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 234: exchangedata
- number: 234
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 235: getxattr
- number: 235
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 236: fgetxattr
- number: 236
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 237: setxattr
- number: 237
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 238: fsetxattr
- number: 238
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 239: removexattr
- number: 239
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 240: fremovexattr
- number: 240
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 241: listxattr
- number: 241
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 242: flistxattr
- number: 242
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 243: fsctl
- number: 243
- name: fsctl
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 244: initgroups
- number: 244
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 245: posix_spawn
- number: 245
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 246: ffsctl
- number: 246
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 247: getattrlistbulk
- number: 247
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 248: readlink
- number: 248
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 249: readlinkat
- number: 249
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 250: kdebug_trace
- number: 250
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 251: setgid
- number: 251
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 252: setegid
- number: 252
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 253: seteuid
- number: 253
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 254: setreuid
- number: 254
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 255: setuid
- number: 255
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 256: setregid
- number: 256
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 257: getattrlistbulk
- number: 257
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 258: madvise
- number: 258
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 259: mincore
- number: 259
- name: mincore
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 260: getattrlist
- number: 260
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 261: getattrlistbulk
- number: 261
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 262: openat
- number: 262
- name: openat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 263: openat_nocancel
- number: 263
- name: openat_nocancel
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 264: renameat
- number: 264
- name: renameat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 265: faccessat
- number: 265
- name: faccessat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 266: fchmodat
- number: 266
- name: fchmodat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 267: fchownat
- number: 267
- name: fchownat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 268: fstatat
- number: 268
- name: fstatat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 269: fstatat64
- number: 269
- name: fstatat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 270: linkat
- number: 270
- name: linkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 271: unlinkat
- number: 271
- name: unlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 272: readlinkat
- number: 272
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 273: symlinkat
- number: 273
- name: symlinkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 274: mkdirat
- number: 274
- name: mkdirat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 275: getattrlistat
- number: 275
- name: getattrlistat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 276: getpgid
- number: 276
- name: getpgid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 277: setpgid
- number: 277
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 278: madvise
- number: 278
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 279: mkfifo
- number: 279
- name: mkfifo
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 280: shm_open
- number: 280
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 281: shm_unlink
- number: 281
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 282: sem_open
- number: 282
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 283: sem_close
- number: 283
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 284: sem_unlink
- number: 284
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 285: sem_wait
- number: 285
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 286: gettid
- number: 286
- name: gettid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 287: sem_trywait
- number: 287
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 288: sem_post
- number: 288
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 289: sem_getvalue
- number: 289
- name: sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 290: sem_init
- number: 290
- name: sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 291: sem_destroy
- number: 291
- name: sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 292: open_extended
- number: 292
- name: open_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 293: umask_extended
- number: 293
- name: umask_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 294: stat_extended
- number: 294
- name: stat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 295: lstat_extended
- number: 295
- name: lstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 296: fstat_extended
- number: 296
- name: fstat_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 297: chmod_extended
- number: 297
- name: chmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 298: fchmod_extended
- number: 298
- name: fchmod_extended
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 299: access_extended
- number: 299
- name: access_extended
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 300: setattrlist
- number: 300
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 301: getattrlist
- number: 301
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 302: getdirentriesattr
- number: 302
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 303: waitid
- number: 303
- name: waitid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 304: searchfs
- number: 304
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 305: quotactl
- number: 305
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 306: nfssvc
- number: 306
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 307: fstatfs
- number: 307
- name: fstatfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 308: getfsstat
- number: 308
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 309: getvfsstat
- number: 309
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 310: fstatfs64
- number: 310
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 311: statfs
- number: 311
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 312: statfs64
- number: 312
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 313: getfsstat64
- number: 313
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 314: getvfsstat64
- number: 314
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 315: fgetattrlist
- number: 315
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 316: fsetattrlist
- number: 316
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 317: exchangedata
- number: 317
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 318: getxattr
- number: 318
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 319: fgetxattr
- number: 319
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 320: setxattr
- number: 320
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 321: fsetxattr
- number: 321
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 322: removexattr
- number: 322
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 323: fremovexattr
- number: 323
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 324: listxattr
- number: 324
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 325: flistxattr
- number: 325
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 326: fsctl
- number: 326
- name: fsctl
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 327: initgroups
- number: 327
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 328: posix_spawn
- number: 328
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 329: ffsctl
- number: 329
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 330: getattrlistbulk
- number: 330
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 331: readlink
- number: 331
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 332: readlinkat
- number: 332
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 333: kdebug_trace
- number: 333
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 334: setgid
- number: 334
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 335: setegid
- number: 335
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 336: proc_info
- number: 336
- name: proc_info
- safety: C
- args: callnum pid flavor arg size -- SIGKILL
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 337: task_name_for_pid
- number: 337
- name: task_name_for_pid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 338: task_for_pid
- number: 338
- name: task_for_pid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 339: pid_for_task
- number: 339
- name: pid_for_task
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 340: mac_syscall
- number: 340
- name: mac_syscall
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 341: kqueue
- number: 341
- name: kqueue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 342: kevent
- number: 342
- name: kevent
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 343: workq_open
- number: 343
- name: workq_open
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 344: workq_kernreturn
- number: 344
- name: workq_kernreturn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 345: kevent64
- number: 345
- name: kevent64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 346: __old_sem_wait
- number: 346
- name: __old_sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 347: __old_sem_trywait
- number: 347
- name: __old_sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 348: __old_sem_post
- number: 348
- name: __old_sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 349: __old_sem_getvalue
- number: 349
- name: __old_sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 350: __old_sem_init
- number: 350
- name: __old_sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 351: __old_sem_destroy
- number: 351
- name: __old_sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 352: kqueue
- number: 352
- name: kqueue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 353: kevent
- number: 353
- name: kevent
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 354: workq_open
- number: 354
- name: workq_open
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 355: workq_kernreturn
- number: 355
- name: workq_kernreturn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 356: kevent64
- number: 356
- name: kevent64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 357: mach_continuous_time
- number: 357
- name: mach_continuous_time
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 358: mach_wait_until
- number: 358
- name: mach_wait_until
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 359: mk_timer_create
- number: 359
- name: mk_timer_create
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 360: mk_timer_destroy
- number: 360
- name: mk_timer_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 361: mk_timer_arm
- number: 361
- name: mk_timer_arm
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 362: mk_timer_cancel
- number: 362
- name: mk_timer_cancel
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 363: __old_psynch_mutexwait
- number: 363
- name: __old_psynch_mutexwait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 364: __old_psynch_mutexdrop
- number: 364
- name: __old_psynch_mutexdrop
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 365: __old_psynch_cvbwait
- number: 365
- name: __old_psynch_cvbwait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 366: __old_psynch_cvsignal
- number: 366
- name: __old_psynch_cvsignal
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 367: __old_psynch_cvbroad
- number: 367
- name: __old_psynch_cvbroad
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 368: __old_psynch_cvclrprepost
- number: 368
- name: __old_psynch_cvclrprepost
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 369: __old_psynch_cvwait
- number: 369
- name: __old_psynch_cvwait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 370: __old_psynch_cvsignal
- number: 370
- name: __old_psynch_cvsignal
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 371: __old_psynch_cvbroad
- number: 371
- name: __old_psynch_cvbroad
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 372: __old_psynch_cvclrprepost
- number: 372
- name: __old_psynch_cvclrprepost
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 373: __old_psynch_cvwait
- number: 373
- name: __old_psynch_cvwait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 374: __old_psynch_rw_rdlock
- number: 374
- name: __old_psynch_rw_rdlock
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 375: __old_psynch_rw_wrlock
- number: 375
- name: __old_psynch_rw_wrlock
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 376: __old_psynch_rw_unlock
- number: 376
- name: __old_psynch_rw_unlock
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 377: __old_psynch_rw_longrdlock
- number: 377
- name: __old_psynch_rw_longrdlock
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 378: __old_psynch_rw_yieldwrlock
- number: 378
- name: __old_psynch_rw_yieldwrlock
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 379: __old_psynch_rw_downgrade
- number: 379
- name: __old_psynch_rw_downgrade
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 380: __old_psynch_rw_upgrade
- number: 380
- name: __old_psynch_rw_upgrade
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 381: __old_psynch_rw_unlock2
- number: 381
- name: __old_psynch_rw_unlock2
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 382: getentropy
- number: 382
- name: getentropy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 383: getentropy
- number: 383
- name: getentropy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 384: gettid
- number: 384
- name: gettid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 385: proc_info
- number: 385
- name: proc_info
- safety: C
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 386: proc_info
- number: 386
- name: proc_info
- safety: C
- ad-hoc: NEVER call, AMFI SIGKILLs the process
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 387: setattrlist
- number: 387
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 388: getattrlist
- number: 388
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 389: getattrlistbulk
- number: 389
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 390: readlink
- number: 390
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 391: readlinkat
- number: 391
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 392: kdebug_trace
- number: 392
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 393: mkfifo
- number: 393
- name: mkfifo
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 394: shm_open
- number: 394
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 395: shm_unlink
- number: 395
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 396: sem_open
- number: 396
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 397: sem_close
- number: 397
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 398: sem_unlink
- number: 398
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 399: sem_wait
- number: 399
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 400: sem_trywait
- number: 400
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 401: sem_post
- number: 401
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 402: sem_getvalue
- number: 402
- name: sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 403: sem_init
- number: 403
- name: sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 404: sem_destroy
- number: 404
- name: sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 405: shm_open
- number: 405
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 406: shm_unlink
- number: 406
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 407: getattrlist
- number: 407
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 408: setattrlist
- number: 408
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 409: getdirentriesattr
- number: 409
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 410: waitid
- number: 410
- name: waitid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 411: searchfs
- number: 411
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 412: quotactl
- number: 412
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 413: nfssvc
- number: 413
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 414: fstatfs
- number: 414
- name: fstatfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 415: getfsstat
- number: 415
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 416: getvfsstat
- number: 416
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 417: fstatfs64
- number: 417
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 418: statfs
- number: 418
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 419: statfs64
- number: 419
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 420: getfsstat64
- number: 420
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 421: getvfsstat64
- number: 421
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 422: fgetattrlist
- number: 422
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 423: fsetattrlist
- number: 423
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 424: exchangedata
- number: 424
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 425: getxattr
- number: 425
- name: getxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 426: fgetxattr
- number: 426
- name: fgetxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 427: setxattr
- number: 427
- name: setxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 428: fsetxattr
- number: 428
- name: fsetxattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 429: removexattr
- number: 429
- name: removexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 430: fremovexattr
- number: 430
- name: fremovexattr
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 431: listxattr
- number: 431
- name: listxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 432: flistxattr
- number: 432
- name: flistxattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 433: fsctl
- number: 433
- name: fsctl
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 434: initgroups
- number: 434
- name: initgroups
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 435: posix_spawn
- number: 435
- name: posix_spawn
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 436: ffsctl
- number: 436
- name: ffsctl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 437: getattrlistbulk
- number: 437
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 438: readlink
- number: 438
- name: readlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 439: readlinkat
- number: 439
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 440: kdebug_trace
- number: 440
- name: kdebug_trace
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 441: setgid
- number: 441
- name: setgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 442: setegid
- number: 442
- name: setegid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 443: seteuid
- number: 443
- name: seteuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 444: setreuid
- number: 444
- name: setreuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 445: setuid
- number: 445
- name: setuid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 446: setregid
- number: 446
- name: setregid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 447: getattrlistbulk
- number: 447
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 448: madvise
- number: 448
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 449: mincore
- number: 449
- name: mincore
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 450: getattrlist
- number: 450
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 451: getattrlistbulk
- number: 451
- name: getattrlistbulk
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 452: openat
- number: 452
- name: openat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 453: openat_nocancel
- number: 453
- name: openat_nocancel
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 454: renameat
- number: 454
- name: renameat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 455: faccessat
- number: 455
- name: faccessat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 456: fchmodat
- number: 456
- name: fchmodat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 457: fchownat
- number: 457
- name: fchownat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 458: fstatat
- number: 458
- name: fstatat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 459: fstatat64
- number: 459
- name: fstatat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 460: linkat
- number: 460
- name: linkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 461: unlinkat
- number: 461
- name: unlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 462: readlinkat
- number: 462
- name: readlinkat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 463: symlinkat
- number: 463
- name: symlinkat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 464: mkdirat
- number: 464
- name: mkdirat
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 465: getattrlistat
- number: 465
- name: getattrlistat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 466: getpgid
- number: 466
- name: getpgid
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 467: setpgid
- number: 467
- name: setpgid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 468: madvise
- number: 468
- name: madvise
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 469: mkfifo
- number: 469
- name: mkfifo
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 470: shm_open
- number: 470
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 471: shm_unlink
- number: 471
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 472: sem_open
- number: 472
- name: sem_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 473: sem_close
- number: 473
- name: sem_close
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 474: sem_unlink
- number: 474
- name: sem_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 475: sem_wait
- number: 475
- name: sem_wait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 476: sem_trywait
- number: 476
- name: sem_trywait
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 477: sem_post
- number: 477
- name: sem_post
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 478: sem_getvalue
- number: 478
- name: sem_getvalue
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 479: sem_init
- number: 479
- name: sem_init
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 480: sem_destroy
- number: 480
- name: sem_destroy
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 481: shm_open
- number: 481
- name: shm_open
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 482: shm_unlink
- number: 482
- name: shm_unlink
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 483: getattrlist
- number: 483
- name: getattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 484: setattrlist
- number: 484
- name: setattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 485: getdirentriesattr
- number: 485
- name: getdirentriesattr
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 486: waitid
- number: 486
- name: waitid
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 487: searchfs
- number: 487
- name: searchfs
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 488: quotactl
- number: 488
- name: quotactl
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 489: nfssvc
- number: 489
- name: nfssvc
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 490: fstatfs
- number: 490
- name: fstatfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 491: getfsstat
- number: 491
- name: getfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 492: getvfsstat
- number: 492
- name: getvfsstat
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 493: fstatfs64
- number: 493
- name: fstatfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 494: statfs
- number: 494
- name: statfs
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 495: statfs64
- number: 495
- name: statfs64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 496: getfsstat64
- number: 496
- name: getfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 497: getvfsstat64
- number: 497
- name: getvfsstat64
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 498: fgetattrlist
- number: 498
- name: fgetattrlist
- safety: S
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 499: fsetattrlist
- number: 499
- name: fsetattrlist
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 500: exchangedata
- number: 500
- name: exchangedata
- safety: B
- ad-hoc: may SIGSYS under sandbox; test only if allowlisted
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 501: necp_open
- number: 501
- name: necp_open
- safety: S
- args: flags
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 502: necp_client_action
- number: 502
- name: necp_client_action
- safety: S
- args: fd op uuid uuid_len buf buf_len
- ad-hoc: safe from signed app on iOS 27
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 503: reserved_503
- number: 503
- name: reserved_503
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 504: reserved_504
- number: 504
- name: reserved_504
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 505: reserved_505
- number: 505
- name: reserved_505
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 506: reserved_506
- number: 506
- name: reserved_506
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 507: reserved_507
- number: 507
- name: reserved_507
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 508: reserved_508
- number: 508
- name: reserved_508
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 509: reserved_509
- number: 509
- name: reserved_509
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 510: reserved_510
- number: 510
- name: reserved_510
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 511: reserved_511
- number: 511
- name: reserved_511
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 512: reserved_512
- number: 512
- name: reserved_512
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 513: reserved_513
- number: 513
- name: reserved_513
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 514: reserved_514
- number: 514
- name: reserved_514
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 515: reserved_515
- number: 515
- name: reserved_515
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 516: reserved_516
- number: 516
- name: reserved_516
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 517: reserved_517
- number: 517
- name: reserved_517
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 518: reserved_518
- number: 518
- name: reserved_518
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 519: reserved_519
- number: 519
- name: reserved_519
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 520: reserved_520
- number: 520
- name: reserved_520
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 521: reserved_521
- number: 521
- name: reserved_521
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 522: reserved_522
- number: 522
- name: reserved_522
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 523: reserved_523
- number: 523
- name: reserved_523
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 524: reserved_524
- number: 524
- name: reserved_524
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 525: reserved_525
- number: 525
- name: reserved_525
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 526: reserved_526
- number: 526
- name: reserved_526
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 527: reserved_527
- number: 527
- name: reserved_527
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 528: reserved_528
- number: 528
- name: reserved_528
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 529: reserved_529
- number: 529
- name: reserved_529
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 530: reserved_530
- number: 530
- name: reserved_530
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 531: reserved_531
- number: 531
- name: reserved_531
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 532: reserved_532
- number: 532
- name: reserved_532
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 533: reserved_533
- number: 533
- name: reserved_533
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 534: reserved_534
- number: 534
- name: reserved_534
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 535: reserved_535
- number: 535
- name: reserved_535
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 536: reserved_536
- number: 536
- name: reserved_536
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 537: reserved_537
- number: 537
- name: reserved_537
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 538: reserved_538
- number: 538
- name: reserved_538
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 539: reserved_539
- number: 539
- name: reserved_539
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 540: reserved_540
- number: 540
- name: reserved_540
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 541: reserved_541
- number: 541
- name: reserved_541
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 542: reserved_542
- number: 542
- name: reserved_542
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 543: reserved_543
- number: 543
- name: reserved_543
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 544: reserved_544
- number: 544
- name: reserved_544
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 545: reserved_545
- number: 545
- name: reserved_545
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 546: reserved_546
- number: 546
- name: reserved_546
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 547: reserved_547
- number: 547
- name: reserved_547
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 548: reserved_548
- number: 548
- name: reserved_548
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 549: reserved_549
- number: 549
- name: reserved_549
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 550: reserved_550
- number: 550
- name: reserved_550
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 551: reserved_551
- number: 551
- name: reserved_551
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 552: reserved_552
- number: 552
- name: reserved_552
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 553: reserved_553
- number: 553
- name: reserved_553
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 554: reserved_554
- number: 554
- name: reserved_554
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 555: reserved_555
- number: 555
- name: reserved_555
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 556: reserved_556
- number: 556
- name: reserved_556
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.

### syscall 557: reserved_557
- number: 557
- name: reserved_557
- safety: U
- ad-hoc: unknown; test in a disposable container first
- common-mistakes: forgetting errno check after call;
  passing uninitialized socklen/size pointer; using NUL-terminated
  string where API expects length-prefixed; reusing fd across fork.


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


## 17 MobileGestalt keys 0x00..0xC8

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
- fix: keep every Python string literal on one line; if you must split, use implicit concat
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### BUILD FAILED with no error text
- why: xcodebuild -quiet hides details
- fix: rerun without -quiet, or grep the xcactivitylog
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Undefined symbols _al_pairing_run_host
- why: AirliftFFI stub missing or not linked
- fix: run the Vendor AirliftFFI step; verify libairlift_ffi.a exists
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### nonisolated(unsafe) with @MainActor
- why: Swift strict concurrency error
- fix: use final class Foo: ObservableObject, @unchecked Sendable
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### SIGKILL CODESIGNING at launch
- why: AMFI killed on proc_info/csops/task_info sweep
- fix: remove those calls; do not call them from ad-hoc builds
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### SIGSYS at first syscall
- why: sandbox denies syscall 78 or nearby
- fix: do not blind-sweep syscalls; stick to allowlist
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### ldid: Invalid plist
- why: entitlements file malformed or missing XML declaration
- fix: regenerate entitlements from the workflow step
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Payload missing
- why: cp -R of .app failed because app not found
- fix: verify APP_PATH is a directory containing Info.plist
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### natsuk1.xcodeproj committed
- why: gitignore did not apply
- fix: add natsuk1.xcodeproj/ to .gitignore and git rm --cached
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying

### Cache restore loses DerivedData
- why: cache key changed on every push
- fix: use restore-keys with prefix to fall back
- never: re-run the same failing step 3 times
- always: capture the raw tool output before retrying
