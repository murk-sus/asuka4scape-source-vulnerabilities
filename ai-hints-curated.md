## PROJECT IDENTITY

natsuk1 — on-device iOS kernel research toolkit plus AirTraffic exploit.
- target: iPhone14,5 (iPhone 13, A15) / iOS 27.0 / build 24A437
- kernel: xnu-13432.2.10~2 / RELEASE_ARM64_T8110 / arm64e
- signing: ad-hoc, empty entitlements, works on LiveContainer and SideStore
- license: MIT, author murk-sus

What it does:
- pairs the iPhone as host via RPPairing on the 10.7.0.x tunnel
- opens RSD tunnel, enumerates services (AFC, ATC, StreamingZip)
- uploads a symlink payload via StreamingZip plus AFC to reach a target dir
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

## MANDATORY BEHAVIOR

For every user message, before answering:

1. Use web search. Latest on: iOS 27 kernel internals, XNU changelog 2026,
   Apple security advisories 2026, blacktop/ipsw release notes, blacktop
   symbolicator signatures, Ghidra 12.x headless API, Jython 2.7 compat,
   LiveContainer / SideStore / AltStore / TrollStore iOS 27 status,
   SwiftUI iOS 27 regressions, NECP / mbuf / socket / IOKit bugs 2025-2026,
   Apple developer forums iOS 27 threads.
2. Use extended reasoning. Enumerate alternatives, weigh tradeoffs, then
   commit to a concrete answer. No hedging.
3. If web search is unavailable, say so explicitly at the top.
4. Cite source URLs for any fact that could change.
5. Never claim a version does not exist without checking.
6. Never claim an API exists without checking current syntax.
7. Never guess offsets. Only use values verified by Ghidra on the exact
   kernelcache being analyzed.

## UPDATE

- date: 2026-09-27
- device: iPhone14,5 / iOS 27.0 / 24A437
- kernel: xnu-13432.2.10~2 RELEASE_ARM64_T8110
- signature: ad-hoc, empty entitlements

## NECP STATUS

Working: op 0x03 returns 1 byte, op 0x04 and 0x1A return 280-byte TLV,
op 0x0D returns user VA (KASLR leak).

Closed: op 0x05 / 0x0C / 0x0F return -1, op 0x18 empty, op 0x19 -1, TLV
overflow rejected, add_flow len in [0x24, 0xF0] accepted, remove_flow
twice ret=0, copy_result_inner kptr count 0, copy_interface no data.

Taint verdict (v48): 24 sources scanned, all propagate taint (seed>0).
649 findings, every depth=0 sink bounded. Both deep kalloc sites
(0xA1C6B80, 0xA3ACA70) are internal packet/string parsers with CARRY4
checks. NECP as user-facing primitive: CLOSED.

## IOKIT STATUS

- iokit_user_client_trap calls FUN_fffffff00a9ad62c = io_connect_method
  - param_3 in [0x18, 0x800] with CARRY8 + cap 0x800 double-check
  - copyin to stack buffer 0x800, bounded — CLOSED
- is_io_service_open_extended: no depth-0 sinks reachable
- Per-driver externalMethod tables and MIG Mach-routine handlers NOT
  scanned. Remaining IOKit surface.

## BSD SYSCALL STATUS

Sysent parsed via PAC unwrap: unpacked 557/558, dup 117 (FreeBSD aliases).
Formula: sy_call = KERNEL_BASE + (raw AND 0xFFFFFFFF). 300 syscalls passed
narg>0 filter. 87 sources produced findings, 1116 sink hits.

Syscall index anomaly: NECP cluster sits at sysent[503]/[504], not
[501]/[502]. Needs verification via sysent[490..540] dump.

Depth-0 copyin sites reviewed manually (9 functions). All bounded:
- 0xA6CEB4C ioctl-family, cap 0x1fff
- 0xA78D724 recvmsg, iovlen < 0x401
- 0xA74BF88 ioctl-family, cap 0x1fff
- 0xA74EA2C / 0xA74E884 forward to kdebug loggers, bounded
- 0xA70E210 cap 0x10, stack only
- 0xA78AE18 / 0xA78A1E8 cap 0x80 stack, or 0xA78A39C cap 0xff
- 0xA743B90 cap 0x800

BSD syscalls as user-facing primitive: CLOSED for shallow paths.

## WHAT A PRIMITIVE LOOKS LIKE

Real primitive requires ALL of:
1. user-controlled size in kalloc_type / kalloc_zone
2. no pre-validation between decode and alloc
3. copyin / copyout / memmove with size that does NOT match allocation

Common false positives:
- ioctl cmd >> 16 AND mask, capped at 0x1fff before alloc
- if (size > CONST) return error immediately before
- (user_a + user_b) * CONST with CARRY4 / CARRY8 check
- stack buffer fixed N, size checked against N
- SoftwareBreakpoint(0x5519) on the mismatch path (hardening trap)

## TAINT METHOD (kernel_rw.py)

Sources: user-controlled parameter functions.
Sinks: kalloc_type, kalloc_zone, copyin, copyout, memmove, memset.

1. HighFunction from DecompInterface
2. Get parameter varnodes via hf.getLocalSymbolMap() — NOT
   getFunctionPrototype().getStorage() (silently returns 0 matches)
3. Compare varnodes by key addr.toString() plus colon plus str(size)
4. Iterate hf.getPcodeOps(): input tainted implies output tainted
5. For each PcodeOp.CALL resolve target via getInput(0).isAddress().
   If sink, check size-arg varnode. Otherwise recurse with tainted arg idx.
6. Cap depth, worklist, total time.

## HOW TO WRITE GHIDRA JYTHON SCRIPTS

### String handling
Never use plus between quotes and identifiers. Editors mangle it.
Use percent formatting: log("[-] %s" % e)

### Tuple literals
Never put 0x at position 0. Use named constants:
A_ADD_FLOW = int("FFFFFFF00A4E843C", 16)
TARGETS = [(A_ADD_FLOW, "necp_client_add_flow")]

### Dictionary access
Use get(), not bracket in assignment:
v = SINK_MAP.get(target)
if v is not None: sname = v[0]; sidx = v[1]

### PcodeOp address
PcodeOpAST has no getAddress(). Use getSeqnum().getTarget().getOffset().

### Function boundaries
Call ensure_function for un-decompiled addresses. DisassembleCommand then
CreateFunctionCmd, fallback to FunctionManager.createFunction.

### Parameter varnodes
hf.getLocalSymbolMap() is the only correct path. Wrap sym.isParameter(),
sym.getCategoryIndex(), sym.getHighVariable().getInstances().

### Varnode identity
Compare by vn_key string "addr:size", never by Java object identity.

### Imports
Wrap Ghidra command imports in try/except with HAS_* flags.

### Decompiler instance
One DecompInterface cached in a module-level global. Never recreate.

### Timeouts
decompileFunction(f, sec, monitor). 30-45 sec medium, 90 sec large.
One un-capped function hangs the whole CI job.

### Crash-proof main
Wrap main() in try/except, write FATAL plus traceback to output file.

### Validation
python3 -c "import ast,sys; ast.parse(open('scripts/kernel_rw.py').read()); print('ok')"

## WORKFLOW

Only two workflows: fix_and_release.yml (build) and extract_offsets.yml
(analysis). Cache: ghidra, ipsw, symbolicator, kernelcache, ghidra_project.
Never hashFiles on kernelcache. Warm run 3-6 min. Never delete cached dirs.

kernel_rw.py writes exactly ONE file: result.txt.

Ghidra headless:
analyzeHeadless <proj_dir> <proj_name> -process <name> -noanalysis
  -scriptPath <repo>/scripts -postScript kernel_rw.py

## COMMON ERRORS AND FIXES

- unterminated string literal: editor inserted quote before 0x. Use int().
- quote-plus-identifier: use percent formatting.
- unmatched close paren: use .get() instead of bracket.
- PcodeOpAST has no getAddress: use getSeqnum().getTarget()
- seed=0 on every source: use getLocalSymbolMap()
- tainted=0 after seed>0: compare vn_key strings not Java objects
- no func for a known symbol: ensure_function + DisassembleCommand
- parsed unpacked: 0: wrong PAC formula, use KERNEL_BASE + low32
- Grappa rc=-5 after patch: restore tokens with nk-grappa-restored marker
- SyncFailed at ATC: transient, ignore if readback succeeds

## GRAPPA / RPPAIRING CONFIRMED WORKING

tunnel 10.7.0.1:49152 via raw RPPairing, RSD publishes 85 services, AFC
connects, StreamingZip extracts, ATC Capabilities/InstalledAssets/
AssetMetrics/SyncAllowed, Grappa 84 bytes from static fallback,
ReadyForSync/AssetManifest/FileComplete 3/3, canary readback matches.

Do NOT collapse kAuthenticGrappaTokens to NULL. Do NOT expect host-side
Grappa on iOS. Do NOT treat SyncFailed as fatal.

## UI / SWIFTUI iOS 27

- overlay(RespringView()) causes CA UAF and SIGSEGV. Use UIHostingController
- List with conditional Section else Section crashes
- scaleEffect inside if breaks ConditionalContent
- Published mutation from Task causes race and UAF
- RuntimeView must not show green when slide or base equal default dash
- respring button lives only in ToolsView

## NEXT STEPS

1. Dump sysent[490..540] to resolve NECP index anomaly
2. If NECP at 503/504, rewrite necp.c constants and rerun
3. Scan IOKit per-driver externalMethod dispatch tables
4. Scan MIG Mach-routine handlers
5. If all closed statically, pivot to concurrency analysis

Do not spend more than 2-3 attempts on the same primitive.

## WHAT NOT TO DO

- Do not create fix_and_test.yml or build_and_release.yml
- Do not use hashFiles on kernelcache
- Do not run blind syscall sweeps
- Do not call proc_info, csops, task_info sweep, mach_port_names > 32
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
- Do not put content at column 0 inside a YAML run: | block