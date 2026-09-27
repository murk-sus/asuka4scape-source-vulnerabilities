## PROJECT IDENTITY

natsuk1: on-device iOS kernel research toolkit plus AirTraffic exploit.
- target: iPhone14,5 (iPhone 13, A15) / iOS 27.0 / build 24A437
- kernel: xnu-13432.2.10~2 / RELEASE_ARM64_T8110 / arm64e
- signing: ad-hoc, empty entitlements, works on LiveContainer and SideStore
- license: MIT, author murk-sus

What it does:
- pairs the iPhone as host via RPPairing on the 10.7.0.x tunnel
- opens RSD tunnel, enumerates services (AFC, ATC, StreamingZip)
- uploads a symlink payload via StreamingZip plus AFC
- drives AirTraffic ATC sync (Grappa token, AssetManifest, FileComplete)
- reads back a canary through the symlink target to confirm the write
- NECP probes for kernel info disclosure (KASLR via op 0x0D)
- full NECP / IOKit / BSD-syscall taint analysis of the kernelcache

Stack:
- SwiftUI app: natsuk1/natsuk1.swift, Views/, Helpers/
- C probes: natsuk1/Exploit/necp.c, nk_api.c
- ObjC: natsuk1/Exploit/GrappaHelper.m
- AirliftFFI stub: natsuk1/External/AirliftFFI.xcframework/ios-arm64/
- Offsets DB: natsuk1/Offsets/
- CI: fix_and_release.yml (build) plus extract_offsets.yml (analysis)

## OFFSETS FOR PRIMITIVES (VERIFIED)

These are the ONLY verified addresses for iPhone14,5 / iOS 27.0 /
24A437. If a script reports a different value, the script is wrong.

Kernel base and slide:
- KERNEL_BASE  = 0xFFFFFFF007004000
- KERNEL_SLIDE = 0x3D00000
- SYSENT_BASE  = 0xFFFFFFF007C19270 (NOT 0x...A0, that is +2 off)

Sysent layout (stride 24 bytes):
- sy_call at +0x00 (u64, ptrauth-signed)
- sy_arg at +0x08 (u32 or u16)
- flags at +0x10 (u32)
- sy_narg at +0x14 (u16)

PAC unwrap formula (verified twice):
- sy_call_unwrapped = KERNEL_BASE + (raw AND 0xFFFFFFFF)
- sysent[503] -> necp_open
- sysent[502] -> getentropy
- sysent[0] -> exit (with correct base)

Sink addresses:
- kalloc_type = 0xFFFFFFF00A200988
- kalloc_zone = 0xFFFFFFF00A20141C
- copyin      = 0xFFFFFFF00A368EC0
- copyout     = 0xFFFFFFF00A369A3C
- memmove     = 0xFFFFFFF00AA40D30
- memset      = 0xFFFFFFF00AA40EE0

NECP function addresses:
- necp_open               = 0xFFFFFFF00A4E411C
- necp_client_action      = 0xFFFFFFF00A4E5C28
- necp_match_policy       = 0xFFFFFFF00A4F75D8
- necp_session_open       = 0xFFFFFFF00A4B4C3C
- necp_session_action     = 0xFFFFFFF00A4BD438
- necp_client_add_flow    = 0xFFFFFFF00A4E843C
- necp_client_remove_flow = 0xFFFFFFF00A4E93C4
- necp_client_add_client  = 0xFFFFFFF00A4E60DC
- necp_client_copy_result = 0xFFFFFFF00A4E7BE8
- necp_client_copy_list   = 0xFFFFFFF00A4E80FC

Syscall numbers (OFFICIAL, do not shift):
- 490..500 mach_eventlink family
- 500 = getentropy (async variant, second getentropy)
- 501 = necp_open
- 502 = necp_client_action
- 503 = work_interval_ctl
- 504 = getentropy (async)
- 505 = __nexus_open
- 506 = __nexus_register
- 507 = __nexus_deregister
- 508 = __nexus_create
- 509 = __nexus_destroy
- 510 = __nexus_get_opt
- 511 = __nexus_set_opt
- 512 = __channel_open
- 513 = __channel_get_info
- 514 = __channel_sync
- 515 = __channel_get_opt
- 516 = __channel_set_opt
- 517 = ulock_wait
- 518 = ulock_wake
- 546 = ulock_wait2

App syscall constants in necp.c are CORRECT (501/502). Do NOT
change them. The parser was reading a shifted base, not the
syscall numbers.

## MANDATORY BEHAVIOR

For every user message, before answering:

1. Use web search. Latest on iOS 27 kernel internals, XNU changelog
   2026, Apple security advisories 2026, blacktop/ipsw release notes,
   Ghidra 12.x headless API, Jython 2.7 compat, LiveContainer /
   SideStore / AltStore / TrollStore iOS 27 status, SwiftUI iOS 27
   regressions, NECP / mbuf / socket / IOKit bugs 2025-2026.
2. Use extended reasoning. Enumerate alternatives, weigh tradeoffs,
   then commit. No hedging.
3. If web search unavailable, say so explicitly at the top.
4. Cite source URLs for any fact that could change.
5. Never claim a version does not exist without checking.
6. Never claim an API exists without checking current syntax.
7. Never guess offsets. Only use values from this file or verified
   by Ghidra on the exact kernelcache.

## NECP STATUS

Working: op 0x03 returns 1 byte, op 0x04 and 0x1A return 280-byte
TLV, op 0x0D returns user VA (KASLR leak).

Closed: op 0x05 / 0x0C / 0x0F return -1, op 0x18 empty, op 0x19 -1,
TLV overflow rejected, add_flow len in [0x24, 0xF0] accepted,
remove_flow twice ret=0, copy_result_inner kptr count 0.

Taint verdict (v48): 24 sources scanned, all propagate. 649
findings, every depth=0 sink bounded. Both deep kalloc sites
(0xA1C6B80, 0xA3ACA70) are internal parsers with CARRY4 checks.
NECP as user-facing primitive: CLOSED.

## IOKIT STATUS

- iokit_user_client_trap calls io_connect_method (0xA9AD62C)
  - param_3 in [0x18, 0x800] with CARRY8 + cap 0x800
  - copyin to stack buffer 0x800, bounded: CLOSED
- is_io_service_open_extended: no depth-0 sinks reachable
- Per-driver externalMethod tables and MIG Mach-routine handlers
  NOT scanned. Remaining IOKit surface.

## BSD SYSCALL STATUS

300 syscalls passed narg>0 filter, 87 sources produced findings.
Depth-0 copyin sites reviewed (9 functions), all bounded:
- 0xA6CEB4C ioctl-family, cap 0x1fff
- 0xA78D724 recvmsg, iovlen < 0x401
- 0xA74BF88 ioctl-family, cap 0x1fff
- 0xA74EA2C / 0xA74E884 forward to kdebug loggers, bounded
- 0xA70E210 cap 0x10, stack only
- 0xA78AE18 / 0xA78A1E8 cap 0x80 stack, or 0xA78A39C cap 0xff
- 0xA743B90 cap 0x800

BSD syscalls as user-facing primitive: CLOSED for shallow paths.

## NEW ATTACK SURFACE (iOS 27 additions)

These syscalls are new in iOS 27 and were not present in prior
versions. Young code, smaller audience, weaker review. Highest
priority for primitive hunting.

- 505..511: __nexus_open / register / deregister / create / destroy
            / get_opt / set_opt (7 syscalls, driver-kit-like)
- 512..516: __channel_open / get_info / sync / get_opt / set_opt
            (5 syscalls, userspace channel API)
- 517..518: ulock_wait / ulock_wake
- 546: ulock_wait2

Next taint scan target: 505..518 plus 546. Same methodology as
NECP v48.

## WHAT A PRIMITIVE LOOKS LIKE

Real primitive requires ALL of:
1. user-controlled size in kalloc_type / kalloc_zone
2. no pre-validation between decode and alloc
3. copyin / copyout / memmove with size that does not match allocation

Common false positives:
- ioctl cmd >> 16 AND mask, capped at 0x1fff before alloc
- if (size > CONST) return error immediately before
- (user_a + user_b) * CONST with CARRY4 / CARRY8 check
- stack buffer fixed N, size checked against N
- SoftwareBreakpoint(0x5519) on mismatch (hardening trap)

## TAINT METHOD

Sources: user-controlled parameter functions.
Sinks: kalloc_type, kalloc_zone, copyin, copyout, memmove, memset.

1. HighFunction from DecompInterface
2. Parameter varnodes via hf.getLocalSymbolMap()
3. Compare varnodes by key addr.toString() plus colon plus str(size)
4. Iterate hf.getPcodeOps(): input tainted implies output tainted
5. PcodeOp.CALL resolve target via getInput(0).isAddress()
6. If sink, check size-arg varnode, else recurse with tainted idx
7. Cap depth, worklist, total time

## HOW TO WRITE GHIDRA JYTHON SCRIPTS

- Never use plus between quotes and identifiers. Use percent
  formatting: log("[-] %s" % e)
- Never put 0x at position 0 of a tuple. Use int("...", 16) constants.
- Use .get() not bracket in assignment: v = SINK_MAP.get(target)
- PcodeOpAST has no getAddress(). Use getSeqnum().getTarget().
- Call ensure_function for un-decompiled addresses.
- Parameter varnodes: hf.getLocalSymbolMap() only.
- Varnode identity: vn_key string, never Java object identity.
- Wrap Ghidra imports in try/except with HAS_* flags.
- One DecompInterface cached in module global.
- decompileFunction has timeout: 30-45 sec medium, 90 sec large.
- Wrap main in try/except, write FATAL to output file.
- Validate syntax: python3 -c "import ast,sys; ast.parse(open(...).read())"

## WORKFLOW

Only two workflows: fix_and_release.yml (build) and extract_offsets.yml
(analysis). Cache: ghidra, ipsw, symbolicator, kernelcache,
ghidra_project. Warm run 3-6 min. Never hashFiles on kernelcache.

kernel_rw.py writes exactly ONE file: result.txt.

## LOGGING FOR EXPLOIT (necp.c)

The necp.c logging uses nk_logx tag plus message. Every line goes
through the Swift callback into AppState.log and to CrashLog.

Rules:
- Log every syscall result with errno: LI("PRE", "fd=%d errno=%d", fd, errno)
- Log raw return values from every NECP op: LI("RECAP", "op=0x%02x ret=%d", op, ret)
- Log every byte buffer length: LI("RECAP", "op=0x%02x got=%d bytes", op, ret)
- Log hexdumps only when ret is in range (0, 600]
- Log kptr scans separately: LO("SCAN", "[%04x] = 0x%llx", offset, value)
- Wrap each probe in TRACE("name") so log flow is visible
- Never log more than 2048 bytes per hexdump — Swift UI truncates
- Use percent formatting everywhere, never string concatenation
- Every probe ends with done or error marker for grepping

## GRAPPA / RPPAIRING CONFIRMED WORKING

tunnel 10.7.0.1:49152 via raw RPPairing, RSD 85 services, AFC,
StreamingZip, ATC Capabilities/InstalledAssets/AssetMetrics/
SyncAllowed, Grappa 84 bytes from static fallback, ReadyForSync,
AssetManifest, FileComplete 3/3, canary readback matches.

Do NOT collapse kAuthenticGrappaTokens to NULL. Do NOT expect
host-side Grappa on iOS. Do NOT treat SyncFailed as fatal.

## UI / SWIFTUI iOS 27

- overlay(RespringView()) causes CA UAF and SIGSEGV
- List with conditional Section else Section crashes
- scaleEffect inside if breaks ConditionalContent
- Published mutation from Task causes race and UAF
- RuntimeView must not show green when slide/base equal dash
- respring button lives only in ToolsView

## NEXT STEPS

1. Taint-scan syscalls 505..518 and 546 (new iOS 27 API)
2. Scan IOKit per-driver externalMethod dispatch tables
3. Scan MIG Mach-routine handlers
4. If all closed statically, pivot to concurrency analysis

Do not spend more than 2-3 attempts on the same primitive.

## WHAT NOT TO DO

- Do not change SYS_NECP_OPEN/ACTION in necp.c to 503/504
- Do not create fix_and_test.yml or build_and_release.yml
- Do not use hashFiles on kernelcache
- Do not run blind syscall sweeps
- Do not call proc_info, csops, task_info sweep, mach_port_names
- Do not use non-empty entitlements
- Do not mutate Published from Task
- Do not put RespringView in the SwiftUI tree
- Do not commit natsuk1.xcodeproj
- Do not trust offsets without Ghidra verification
- Do not answer without web search first
- Do not delete ghidra / ghidra_project / kernelcache / symbolicator
- Do not collapse the Grappa token array to NULL
- Do not use plus between string literals and identifiers in Jython
- Do not use bracket access on dict or list in assignment position
- Do not put 0x literals at position 0 of a tuple
- Do not put content at column 0 inside a YAML run pipe block
