
## AUTO-GENERATED RESEARCH RULES

Rewritten by workflow on every push. Read first. Never violate.

### 0. MANDATORY - USE INTERNET ON EVERY REQUEST

- Before answering ANY question, search the web for latest:
  - iOS 27.0 kernel internals, XNU changelog, Apple security advisories
  - blacktop/ipsw version notes and CLI syntax
  - blacktop/symbolicator updates and signature availability
  - Ghidra 12.x release notes and headless API
  - LiveContainer / SideStore / AltStore / TrollStore iOS 27 compat
  - SwiftUI iOS 27 regressions (List, NavigationStack, AttributeGraph)
  - NECP, mbuf, socket, IOKit bugs papers from 2025-2026
  - Apple developer forums iOS 27 beta crash threads
- If you cannot use internet, say so explicitly.
- Never claim a version does not exist without checking.
- Never claim an API exists without checking current syntax.
- Cite URL when stating a fact that could change.

### 1. Update
- date: 2026-09-26
- device: iPhone14,5 / iOS 27.0 / 24A437
- kernel: xnu-13432.2.10~2/RELEASE_ARM64_T8110
- signature: ad-hoc, empty entitlements

### 2. NECP status

Working:
- op=0x03 returns 1 byte
- op=0x04 and op=0x1A return full 280-byte TLV
- op=0x0D returns user VA

Closed:
- op=0x05 copy_list -> -1
- op=0x0C copy_parameters -> -1
- op=0x0F copy_update -> -1
- op=0x18/0x19 signed_id -> empty/-1
- TLV overflow len=0xffffffff -> rejected
- add_flow size 0x24..0xF0, 0xF1+ -> -1
- double-free remove_flow x2 -> ret=0 but copy_result=1 byte
- copy_result_inner kptr count=0
- copy_interface idx 1..10 -> ret=0 no data

### 3. Caller graph

necp_flow_alloc      0xA346E70
  callers: 0xA346474, 0xA348180
necp_handler_big     0xA3D91B4
  caller:  0xA3D9174
necp_get_tlv         0xA4C2034
  caller:  0xA4C113C (9 BL)
necp_open            0xA4E411C
  not BL-called, dispatcher BR/BLR
necp_client_action   0xA4E5C28
  not BL-called, dispatcher BR/BLR
syscall_dispatcher   0xA6CEB84

### 4. Potential integer overflow

necp_flow_alloc 0xA346E70:
  uVar6 = min(user_count, 0x80)
  iVar1 = (uVar6 + param_3) * 0x14|0x18
  kalloc_type_necp_flow(iVar1)
  copyin(user_ptr, buf, uVar6 * 0x14|0x18)
If param_3 wraps int32 -> alloc < copyin -> heap overflow.
param_3 origin: need FUN_fffffff00a346474 decompile.

sbappendcontrol 0xA788A24, sbappendrecord 0xA7873B8:
  uVar12 += (int)mbuf[3] (32-bit, no overflow check)
Not exploitable via sendmsg (kernel rejects >2GB chains).

### 5. Confirmed safe

sooptcopyin       0xA77FD2C  maxlen checked before copyin
necp_handler_big  0xA3D91B4  checks uVar21 >= 0x2001, sizes match
necp_client_add_flow 0xA4E843C  rejects uVar24 in 0xBF..0xF0
necp_update_cache 0xA4EBD58  user ptr only via copyin

### 6. iOS 27 runtime crashes

SIGKILL - CODESIGNING (AMFI) - never call from ad-hoc:
  proc_info(336) any flavor
  csops(169) any op
  task_info flavor sweep 1..40
  mach_port_names with count > 32

SIGSYS (sandbox) - never do:
  blind syscall sweep 0..558 (dies on syscall 78)

Safe whitelist:
  getpid(20) getuid(24) getgid(47) getppid(39)
  geteuid(25) getegid(43) gettid(286) getpgid(202)

socket / getsockopt / setsockopt / sysctl / uname always safe.

### 7. Signature

Empty entitlements <dict></dict> required for LiveContainer.
Non-empty com.apple.private.* -> AMFI kills process.
ldid -Snatsuk1/Resources/natsuk1.entitlements
Works: Sideloadly, AltStore, TrollStore, ESign, LiveContainer.
Does NOT work: LC with privileged entitlements.

### 8. Build gotchas

- #include <mach/mach_vm.h> -> mach_vm.h unsupported in iPhoneOS SDK 26.5.
  Declare manually:
    extern kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t,
        mach_vm_size_t, mach_vm_address_t, mach_vm_size_t*);
    extern kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t,
        vm_offset_t, mach_msg_type_number_t);
    extern kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t,
        mach_vm_size_t, boolean_t, vm_prot_t);
- TCP_KEEPINIT / TCP_FASTOPEN_KEY / SO_REUSEPORT_LF / SO_NO_CHECK not in SDK.
- @MainActor + nonisolated(unsafe) static let shared -> compile error.
  Use final class Foo: ObservableObject, @unchecked Sendable,
      static let shared, private init().
- sysctlbyname("hw.memsize") returns UInt64.
- nk_offsets.h MUST define NK_SYSENT_BASE and NK_SYSENT_COUNT
  (nk_api.c references them).

### 9. SwiftUI iOS 27

- .overlay(RespringView()) - never. WKWebView always loaded,
  GPU spam -> CA UAF -> SIGSEGV. Use UIHostingController.present.
- List { if cond { Section } else { Section } } -> optionalSelectionContainer crash.
- .scaleEffect() inside if -> _ConditionalContent breaks.
- @Published mutation from Task {} -> race -> UAF. Use Timer.scheduledTimer.

### 10. Offsets

KBASE             0xFFFFFFF007004000
SLIDE             0x3D00000
SYSENT_BASE       0xFFFFFFF007C192A0

NECP:
  necp_open                     0xFFFFFFF00A4E411C
  necp_client_action            0xFFFFFFF00A4E5C28
  necp_client_add_flow          0xFFFFFFF00A4E843C
  necp_client_remove_client     0xFFFFFFF00A4E76F4
  necp_client_remove_flow       0xFFFFFFF00A4E93C4
  necp_client_copy_list         0xFFFFFFF00A4E80FC
  necp_client_copy_result       0xFFFFFFF00A4E7BE8
  necp_client_copy_result_inner 0xFFFFFFF00A4F26F0
  necp_client_copy_interface    0xFFFFFFF00A4EAC7C
  necp_client_copy_update       0xFFFFFFF00A4EC264
  necp_client_sysctl_arena      0xFFFFFFF00A4EB704
  necp_get_tlv_at_offset        0xFFFFFFF00A4C2034
  necp_flow_alloc               0xFFFFFFF00A346E70
  necp_handler_big              0xFFFFFFF00A3D91B4
  necp_update_cache             0xFFFFFFF00A4EBD58
  necp_per_flow_copy            0xFFFFFFF00A4F2E70

socket:
  sooptcopyin                   0xFFFFFFF00A77FD2C
  sbappendcontrol               0xFFFFFFF00A788A24
  sbappendrecord                0xFFFFFFF00A7873B8
  sbappendstream                0xFFFFFFF00A78811C

primitives:
  copyin                        0xFFFFFFF00A368EC0
  copyout                       0xFFFFFFF00A369A3C
  kalloc_type                   0xFFFFFFF00A200988
  kfree_type                    0xFFFFFFF00A201000
  kalloc_type_necp_flow         0xFFFFFFF007C62E68

callers:
  flow_alloc_caller_1           0xFFFFFFF00A346474
  flow_alloc_caller_2           0xFFFFFFF00A348180
  handler_big_caller            0xFFFFFFF00A3D9174
  tlv_wrapper                   0xFFFFFFF00A4C113C
  syscall_dispatcher            0xFFFFFFF00A6CEB84

### 11. Extract Offsets repo

Separate repo: murk-sus/Hu-Tao-and-natsuki-anime-music-player
workflow: extract_offsets.yml
script:   scripts/kernel_rw.py
artifacts: result.txt, offsets.json, kernel.log, symbols.json

Symbolication:
  ipsw kernel symbolicate --signatures symbolicator/kernel/27.0 --json KERNEL
  Output path printed to stderr as "Writing symbols as JSON to <path>"
  Format: {"<decimal_addr>": "<name>"}
  symbolicator 27.0 has xnu.json (5.3 MB) + 773 kext json
  loads ~40000 entries

Jython 2.7:
  json.load() returns unicode, use isinstance(x, basestring) not str
  no tabs, only 4 spaces
  validate: python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())"

Ghidra cache keys (static):
  ghidra-12.1.2-jython-v4
  ipsw-3.1.716-v4
  symbolicator-v6
  kernelcache-iPhone14_5-24A437-v4
  ghidra-project-24A437-v4

Never hashFiles('kernelcache/**') in cache key.
Never rm ghidra, ghidra_project, kernelcache, symbolicator in cleanup.

BL scan Jython:
  read __text block with memory.getBytes
  for each 4-byte LE word:
    op = raw & 0xFC000000
    if op == 0x94000000 or op == 0x14000000:
      imm26 = raw & 0x03FFFFFF
      if imm26 & 0x02000000: imm26 -= 0x04000000
      dst = (pc + (imm26 << 2)) & 0xFFFFFFFFFFFFFFFF
      if dst == target: hit

### 12. YAML rules

- One workflow only: fix_and_release.yml
- Do not embed C/Swift in heredoc > 30 lines
- All heredoc lines indent 10 spaces from left
- Endmarker on 10 spaces
- set -e only where critical, exit 0 in diagnostics
- grep -q -e "pattern" (dash-safe)
- Do not delete cached dirs in final cleanup

### 13. Next steps

1. Decompile FUN_fffffff00a346474 and FUN_fffffff00a348180
   - trace param_3 for necp_flow_alloc
   - if user-controlled -> craft PoC with int32 wrap value
2. Decompile syscall dispatcher 0xA6CEB84
   - find case 501 (necp_open) and 502 (necp_client_action)
3. Decompile FUN_fffffff00a4c113c (TLV wrapper)
4. Search IOKit: IOSurface, IOConnectCallMethod, IOHIDEvent
5. mbuf: m_copydata, mbuf_copydata with user lengths

Do not spend more than 2-3 attempts on same primitive.

### 14. What NOT to do

- Do not create fix_and_test.yml or build_and_release.yml
- Do not embed C/Swift in heredoc
- Do not use hashFiles in cache keys
- Do not run blind syscall sweep
- Do not call proc_info / csops / task_info sweep / mach_port_names
- Do not set non-empty entitlements
- Do not mutate @Published from Task {}
- Do not put RespringView in SwiftUI tree
- Do not call al_device_respring
- Do not commit natsuk1.xcodeproj
- Do not trust offsets without Ghidra verification
- Do not answer without web search first
- Do not delete ghidra/ghidra_project/kernelcache/symbolicator in cleanup
