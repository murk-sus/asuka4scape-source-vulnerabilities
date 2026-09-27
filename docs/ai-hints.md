# natsuk1 AI RESEARCH BRIEF

Read this file before answering anything about this repo.

## PROJECT IDENTITY

natsuk1: on-device iOS kernel research toolkit plus AirTraffic
exploit.

- target: iPhone14,5 (iPhone 13, A15) / iOS 27.0 / build 24A437
- kernel: xnu-13432.2.10~2 / RELEASE_ARM64_T8110 / arm64e
- signing: ad-hoc, empty entitlements, works on LiveContainer and
  SideStore
- author: murk-sus, license MIT

Stack: SwiftUI app plus C probes plus Objective-C GrappaHelper.
CI: fix_and_release.yml (build) plus extract_offsets.yml (analysis).

## MANDATORY BEHAVIOR

For every user message, before answering:

1. Use web search. Latest on iOS 27 kernel internals, XNU changelog
   2026, Apple security advisories 2026, blacktop/ipsw release
   notes, blacktop symbolicator signatures, Ghidra 12.x headless
   API, Jython 2.7 compatibility, LiveContainer / SideStore /
   AltStore / TrollStore iOS 27 status, SwiftUI iOS 27 regressions,
   NECP / mbuf / socket / IOKit bugs 2025-2026, Apple developer
   forums iOS 27 threads.
2. Use extended reasoning. Enumerate alternatives, weigh tradeoffs,
   then commit. No hedging.
3. If web search unavailable, say so explicitly at the top.
4. Cite source URLs for any fact that could change.
5. Never claim a version does not exist without checking.
6. Never claim an API exists without checking current syntax.
7. Never guess offsets. Only use values from this file or verified
   by Ghidra on the exact kernelcache.

## VERIFIED OFFSETS

Only verified values for iPhone14,5 / iOS 27.0 / 24A437 /
xnu-13432.2.10~2.

Kernel base and slide:
- KERNEL_BASE   = 0xFFFFFFF007004000
- KERNEL_SLIDE  = 0x3D00000
- SYSENT_BASE   = 0xFFFFFFF007C192D0
- SYSENT_STRIDE = 24
- SYSENT_COUNT  = 558

Sysent layout: sy_call at +0x00 (u64 ptrauth-signed), sy_arg at
+0x08, flags at +0x10 (u32), sy_narg at +0x14 (u16).

PAC unwrap: sy_call_unwrapped = KERNEL_BASE + (raw AND 0xFFFFFFFF)

Verified anchors:
- sysent[92]   = fcntl
- sysent[94]   = nosys
- sysent[462]  = necp_match_policy
- sysent[501]  = necp_open             0xFFFFFFF00A4E411C
- sysent[502]  = necp_client_action    0xFFFFFFF00A4E5C28
- sysent[503]  = work_interval_ctl
- sysent[504]  = getentropy async
- sysent[505]  = __nexus_open
- sysent[512]  = __channel_open
- sysent[524]  = necp_session_open     0xFFFFFFF00A4B4C3C
- sysent[525]  = necp_session_action   0xFFFFFFF00A4BD438
- sysent[546]  = ulock_wait2

Sinks:
- kalloc_type  0xFFFFFFF00A200988
- kalloc_zone  0xFFFFFFF00A20141C
- copyin       0xFFFFFFF00A368EC0
- copyout      0xFFFFFFF00A369A3C
- memmove      0xFFFFFFF00AA40D30
- memset       0xFFFFFFF00AA40EE0
- kfree_type   0xFFFFFFF00A201000
- ref_dec      0xFFFFFFF00A4E3278

NECP op-handlers:
- necp_open                 0xFFFFFFF00A4E411C
- necp_client_action        0xFFFFFFF00A4E5C28
- necp_add_client           0xFFFFFFF00A4E60DC
- necp_claim                0xFFFFFFF00A4E7158
- necp_remove_client        0xFFFFFFF00A4E76F4
- necp_copy_result          0xFFFFFFF00A4E7BE8
- necp_copy_list            0xFFFFFFF00A4E80FC
- necp_add_flow             0xFFFFFFF00A4E843C
- necp_remove_flow          0xFFFFFFF00A4E93C4
- necp_request_nexus        0xFFFFFFF00A4E9904
- necp_agent_action         0xFFFFFFF00A4EA0B4
- necp_copy_agent           0xFFFFFFF00A4EA778
- necp_copy_parameters      0xFFFFFFF00A4EA8A0
- necp_copy_agent_alt       0xFFFFFFF00A4EAB50
- necp_copy_interface       0xFFFFFFF00A4EAC7C
- necp_get_iface_addr       0xFFFFFFF00A4EB2B4
- necp_sysctl_arena         0xFFFFFFF00A4EB704
- necp_copy_route_stats     0xFFFFFFF00A4EBA0C
- necp_update_cache         0xFFFFFFF00A4EBD58
- necp_copy_update          0xFFFFFFF00A4EC264
- necp_sign                 0xFFFFFFF00A4EC5D8
- necp_validate             0xFFFFFFF00A4EC9EC
- necp_get_signed_id        0xFFFFFFF00A4ECC4C
- necp_set_signed_id        0xFFFFFFF00A4ECE88
- necp_get_flow_stats       0xFFFFFFF00A4ED170

NECP internal:
- necp_handler_core         0xFFFFFFF00A501454
- necp_tlv_packer           0xFFFFFFF00A4C3558
- necp_copy_state           0xFFFFFFF00A4ED8BC
- necp_session_lookup       0xFFFFFFF00A4ED864
- necp_raw_lookup           0xFFFFFFF00A4DB8D4
- necp_release_session      0xFFFFFFF00A4E5284
- necp_ref_dec              0xFFFFFFF00A4E3278
- necp_match_policy         0xFFFFFFF00A4F75D8
- necp_session_open         0xFFFFFFF00A4B4C3C
- necp_session_action       0xFFFFFFF00A4BD438

IOKit:
- iokit_user_client_trap     0xFFFFFFF00A98C2E8
- is_io_service_open_extended 0xFFFFFFF00A988758
- io_connect_method          0xFFFFFFF00A9AD62C

New syscalls 27.0:
- nexus   0xA802220 .. 0xA803FE8
- channel 0xA7DACEC .. 0xA7DCF00
- ulock   0xA754778, 0xA755798, 0xA7547C0


- iokit_user_client_trap calls io_connect_method
- param_3 in [0x18, 0x800] with CARRY8 plus cap 0x800
- copyin to stack buffer 0x800, bounded
- is_io_service_open_extended no depth-0 sinks
- per-driver externalMethod dispatch tables scanner found only 4
  candidates, all bounded
- MIG Mach-routine handlers NOT scanned


- nexus 505..511
- channel 512..516
- ulock 517..518 plus 546
- all closed at depth >= 6

## WHAT A PRIMITIVE LOOKS LIKE

Real primitive requires ALL of:
1. user-controlled size in kalloc_type / kalloc_zone
2. no pre-validation between decode and alloc
3. copyin / copyout / memmove with size not matching allocation

Common false positives:
- ioctl cmd >> 16 AND mask, capped before alloc
- if (size > CONST) return error immediately before
- (user_a + user_b) * CONST with CARRY4 / CARRY8 check
- stack buffer fixed N, size checked against N, copyin(N)
- unsigned-range-check idiom (x - MIN < MAX - MIN). SAFE.
  Occurs everywhere in NECP. Never flag as INT_OVERFLOW.
- SoftwareBreakpoint(0x5519) on mismatch is hardening trap


- Never use plus between quotes and identifiers. Use percent format.
- Never put 0x at position 0 of a tuple. Use int("HEX", 16).
- Use .get() not bracket in assignment.
- PcodeOpAST has no getAddress(). Use getSeqnum().getTarget().
- Call ensure_function for un-decompiled addresses.
- Parameter varnodes: hf.getLocalSymbolMap() only.
- Varnode identity: compare vn_key strings.
- Wrap Ghidra imports in try/except with HAS flags.
- One DecompInterface cached in module global.
- decompileFunction has timeout: 30-45 sec medium, 90 large.
- Wrap main in try/except, write FATAL to output file.
- Validate: python3 -c "import ast,sys; ast.parse(open(path).read())"

## WORKFLOW

Two workflows only: fix_and_release.yml and extract_offsets.yml.
Cache keys: ghidra, ipsw, symbolicator, kernelcache,
ghidra_project, symbols. Warm run 3-6 min. Never hashFiles on
kernelcache. Never delete cached dirs in cleanup.

kernel_rw.py writes exactly ONE file: result.txt, max 100 KB.
No offsets.json, no primitives.json, no dump.txt.

Ghidra headless: analyzeHeadless <proj_dir> <proj_name> -process
<name> -noanalysis -scriptPath <repo>/scripts -postScript
kernel_rw.py


- unterminated string literal: editor inserted quote before 0x.
  Use int("HEX", 16).
- quote-plus-identifier: use percent formatting.
- unmatched close paren: use .get() not bracket.
- PcodeOpAST has no getAddress: use getSeqnum().getTarget().
- seed=0 on every source: use getLocalSymbolMap().
- tainted=0 after seed>0: compare vn_key strings.
- no func: ensure_function plus DisassembleCommand.
- parsed unpacked 0: wrong PAC formula.
- Grappa rc=-5 after patch: restore tokens with marker.
- SyncFailed at ATC: transient, ignore if readback succeeds.


- overlay(RespringView()) causes CA UAF and SIGSEGV.
- List with conditional Section else Section crashes.
- scaleEffect inside if breaks ConditionalContent.
- Published mutation from Task causes race and UAF.
- RuntimeView must not show green when slide/base equal dash.
- respring button lives only in ToolsView.


- Do not change SYS_NECP_OPEN/ACTION in necp.c (they are correct).
- Do not create fix_and_test.yml or build_and_release.yml.
- Do not use hashFiles on kernelcache.
- Do not run blind syscall sweeps.
- Do not call proc_info, csops, task_info sweep, mach_port_names.
- Do not use non-empty entitlements.
- Do not mutate Published from Task.
- Do not put RespringView in the SwiftUI tree.
- Do not commit natsuk1.xcodeproj.
- Do not trust offsets without Ghidra verification.
- Do not answer without web search first.
- Do not delete ghidra / ghidra_project / kernelcache / symbolicator.
- Do not collapse the Grappa token array to NULL.
- Do not use plus between string literals and identifiers in Jython.
- Do not use bracket access on dict or list in assignment.
- Do not put 0x literals at position 0 of a tuple.
- Do not put content at column 0 inside a YAML run pipe block.
- Do not flag unsigned-range-check as INT_OVERFLOW.

## FIX AND RELEASE WORKFLOW

Single workflow `.github/workflows/fix_and_release.yml`.

Rules learned the hard way:

- Never put Python or heredoc over 30 lines inside a run block.
- Use short perl one-liners for multi-line edits.
- Every mutation must be idempotent.
- Commit only if git diff is non-empty, and use skip ci.
- Release notes carry exactly one https link (direct IPA).

Fixes applied automatically by the workflow:

- NetworkStatus: drop netmask field and argument.
- AirliftView: if let pin = airlift.pairPIN must stay intact.
- DeviceInfoView: use DeviceName.machineID().
- DeviceName.full(), OffsetsStore.activeVersion removed as dead.
- NECP removed entirely (closed).

## NECP REMOVAL AND SWIFT OPTIONAL BINDING

- NECP is fully closed on iOS 27, removed from repo entirely.
- Do not restore nk_necp_run or nk_necp_cancel in nk_api.
- All Swift call sites of nk_necp_cancel must be deleted, not renamed.
- Keep if let pin = airlift.pairPIN intact, Text uses pin.
- Never rewrite it to if airlift.pairPIN != nil.

## CODE AND WORKFLOW STYLE

- No comments in code or workflows.
- Keep Cleanup idempotent with sed and perl.
- Never rewrite if let pin = airlift.pairPIN.
- Remove nk_necp_cancel lines with sed, do not rename.

## CURRENT STATUS

Build iPhone14,5 / iOS 27.0 / 24A437.

- No kernel R/W primitive found on this build.
- NECP closed at depth-0 sinks, code removed from repo.
- Airlift works via static Grappa token fallback.
- Offsets shipped with verified false, do not trust.
- IOKit not probed beyond shallow externalMethod dispatch.
- BSD syscalls 557 of 558 unpacked, shallow paths bounded.

## AIRLIFTVIEW KEEP

- Keep if let pin = airlift.pairPIN, Text reads pin.
- Do not rewrite to if airlift.pairPIN != nil.

## CI IDEMPOTENCE

- Every cleanup mutation must be idempotent.
- Commit only if git diff --cached is non-empty.
- Use skip ci in every commit message from CI.
- Cache key must change when project.yml changes.
- rm -rf natsuk1.xcodeproj before xcodegen generate.

## CARRIERLAB

CarrierLab UI wraps AirLift file writes to /var/mobile/Library/Carrier Bundles.

- check: read-only, safe.
- install: requires clean session, no rollback.
- reload: only after install, re-triggers IPCC read.
- finish: marks session done.
- TODO: al_read_file, al_remove_path, al_make_symlink in AirliftFFI.

## USER WORKFLOW RULES

- Never use sed/perl to modify project.yml. Rewrite fully via cat heredoc.
- Never mutate @Published from background thread. Use DispatchQueue.main.async or @MainActor.
- Do not touch AirliftBridge.swift or PairingController.swift without explicit request.
- Do not add "type INSTALL" style confirmations.
- AirLift probe must distinguish: no VPN / no pairing / too-small pairing / FFI error.
- Read hints before every workflow change. Remove dead steps each run.
- No comments in code or workflows.

## USER RULES 2026-09

- All code, strings and comments in English only.
- Match existing style: @unchecked Sendable, DispatchQueue.main.async, no @MainActor, no Task { @MainActor }.
- Never mutate @Published from background. Always DispatchQueue.main.async in setters.
- Do not touch AirliftBridge.swift or PairingController.swift without explicit request.
- No "type INSTALL" style confirmations. Buttons act immediately.
- CarrierLab probe must distinguish: no VPN / no pairing / too-small pairing / FFI error.
- Read this file before every workflow change. Remove dead steps on every run.
- project.yml is written in full via cat heredoc, never sed/perl patched.

## PAIRING FILE

- Pairing file lives in Documents/natsuk1_pairing.plist or nested in Documents/Data/Application/*/Documents/.
- Never validate by specific keys. Some AirLift versions use different key names.
- Validation: file exists, size > 200, parses as plist, is a dictionary, has at least 1 key.
- findPairingFile() checks direct path, PairingController path, any plist in Documents, then nested Data/Application/*/Documents.

## PAIRING FILE FORMAT

AirLift pairing plist has exactly these keys:

- public_key (data, 32 bytes)
- private_key (data, 32 bytes)
- identifier (string, UUID)
- alt_irk (data, 16 bytes)

Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/etc.
Location: Documents/natsuk1_pairing.plist OR nested Data/Application/<UUID>/Documents/.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".
- One file per run step. Many small steps beat one huge step.
- No nested heredocs. No shell quote escapes inside printf. No printf with embedded single quotes.

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.
- AirliftBridge.runPairing, runExploit, respring, CarrierLabState all use main.async for every state update.

## PAIRING FILE FORMAT

AirLift pairing plist keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.

## UI STYLE

Match Apple native apps. No neon glow. No .shadow for status.
Use .foregroundStyle(.secondary) for values, .green / .orange / .red for statuses only.
Use .font(.system(.body, design: .monospaced)) for technical values.
Section headers use Label with SF Symbols.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Never use printf with embedded single quotes or backslash escapes in a run block.
- One file per heredoc. Multiple heredocs in one run step are allowed if indent is uniform.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.

## PAIRING FILE FORMAT

AirLift pairing plist keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.

## UI STYLE

Match Apple native apps. Subtle glow only: .shadow(color: c.opacity(0.35), radius: 2).
Never use radius > 3 or opacity > 0.4.
Use .foregroundStyle(.secondary) for technical values.
Use .green / .orange / .red for statuses only.
Section headers use Label with SF Symbols.

## ERROR FIX LOG

### cannot find 'nk_necp_cancel' in scope
Cause: NECP was removed from nk_api.h and nk_api.c earlier, but a call remained in AirliftBridge.cancelExploit.
Fix: remove the call. cancelExploit only logs "cancel requested" and sets state to .done(ok:false, message:"cancelled").
Never reintroduce nk_necp_cancel, nk_necp_run or any nk_necp_* symbol.

### invalid yaml syntax
Cause: nested heredoc inside printf with shell quote escapes.
Fix: never printf strings with backslash or single-quote escapes. Use cat <<'EOF' heredocs at uniform indent.

### Modifications to the layout engine must not be performed from a background thread
Cause: @Published setter called on non-main thread from Task { } or Task.detached.
Fix: all @Published mutations via DispatchQueue.main.async unconditionally. Private setX helpers.

### extra argument 'netmask' in call
Cause: sed/perl patch removed struct field but not call site.
Fix: rewrite the file in full via cat heredoc, never patch partially.

### cannot find 'CarrierLabView' in scope
Cause: project.yml lacked natsuk1/CarrierLab source path.
Fix: project.yml always written in full via cat heredoc, includes all paths.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Never use printf with embedded single quotes or backslash escapes in a run block.
- One file per heredoc. Multiple heredocs in one run step are allowed if indent is uniform.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.

## PAIRING FILE FORMAT

AirLift pairing plist keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.
FFI might expect .mobiledevicepairing extension. Search all candidates.
Fallback: any .plist / .mobilepairing / .mobilepair file > 100 bytes in Documents.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.

## UI STYLE

Match Apple native apps. Subtle glow everywhere: .shadow(color: c.opacity(0.45), radius: 3).
Every value in every menu must have glow. Every button must have glow.
Use .green / .orange / .red for statuses only.
Section headers use Label with SF Symbols.

## ERROR FIX LOG

### cannot find 'nk_necp_cancel' in scope
Cause: NECP was removed but a call remained in AirliftBridge.cancelExploit.
Fix: remove the call. cancelExploit only logs and sets state to .done(ok:false).

### invalid yaml syntax
Cause: nested heredoc inside printf with shell quote escapes.
Fix: never printf strings with backslash or single-quote escapes. Use cat <<'EOF' heredocs at uniform indent.

### Modifications to the layout engine must not be performed from a background thread
Cause: @Published setter called on non-main thread.
Fix: all @Published mutations via DispatchQueue.main.async unconditionally.

### "failed to parse raw pairing file from bytes"
Cause: FFI expects pairing file with specific extension (.mobiledevicepairing) or specific path.
Fix: search all candidate paths: natsuk1_pairing.plist, ALTPairingFile.mobiledevicepairing, pairingFile.plist, any plist in Documents, nested Data/Application.
Do not reject pairing file for missing specific keys. Only require it parses as plist and is not empty.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Never use printf with embedded single quotes or backslash escapes in a run block.
- One file per heredoc. Multiple heredocs in one run step are allowed if indent is uniform.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.

## PAIRING FILE FORMAT

AirLift pairing plist keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.
FFI might expect .mobiledevicepairing extension. Search all candidates.
Fallback: any .plist / .mobilepairing / .mobilepair file > 100 bytes in Documents.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.
- probe() checks only VPN and pairing file validity. Never call al_exploit_run from probe.
  FFI expects device at 10.7.0.3, LocalDevVPN gives 10.7.0.1. Direct FFI call always times out.
  Actual writes still use al_exploit_run and may fail if the FFI cannot reach the device.

## UI STYLE

Match Apple native apps. Subtle glow everywhere: .shadow(color: c.opacity(0.45), radius: 3).
Every value in every menu must have glow. Every button must have glow.
Use .green / .orange / .red for statuses only.
Section headers use Label with SF Symbols.

## ERROR FIX LOG

### cannot find 'nk_necp_cancel' in scope
Cause: NECP was removed but a call remained in AirliftBridge.cancelExploit.
Fix: remove the call. cancelExploit only logs and sets state to .done(ok:false).

### invalid yaml syntax
Cause: nested heredoc inside printf with shell quote escapes.
Fix: never printf strings with backslash or single-quote escapes. Use cat <<'EOF' heredocs at uniform indent.

### Modifications to the layout engine must not be performed from a background thread
Cause: @Published setter called on non-main thread.
Fix: all @Published mutations via DispatchQueue.main.async unconditionally.

### "raw RPPairing timed out after 6s"
Cause: AirliftFFI connects to 10.7.0.3:49152 but LocalDevVPN gives device IP 10.7.0.1.
Fix: probe() no longer calls al_exploit_run. Only checks VPN and pairing file.
The actual write still calls al_exploit_run and will fail if the FFI cannot reach the device.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Never use printf with embedded single quotes or backslash escapes in a run block.
- One file per heredoc. Multiple heredocs in one run step are allowed if indent is uniform.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.

## PAIRING FILE FORMAT

AirLift pairing plistob keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.
FFI might expect .miledevicepairing extension. Search all candidates.
Fallback: any .plist / .mobilepairing / .mobilepair file > 100 bytes in Documents.
AirliftFFI expects classic lockdown format with DeviceCertificate. RPPairing file alone is not enough.
SideInstaller merges both RPPairing and lockdown records into one plist.
Until merged file is generated, install will fail with TunnelFailureRsdUnreachable.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.
- probe() checks only VPN and pairing file validity. Never call al_exploit_run from probe.

## UI STYLE

Match Apple native apps. Subtle glow everywhere: .shadow(color: c.opacity(0.45), radius: 3).
Every value in every menu must have glow. Every button must have glow.
Use .green / .orange / .red for statuses only.
Section headers use Label with SF Symbols.

## ERROR FIX LOG

### cannot find 'nk_necp_cancel' in scope
Cause: NECP was removed but a call remained in AirliftBridge.cancelExploit.
Fix: remove the call. cancelExploit only logs and sets state to .done(ok:false).

### invalid yaml syntax
Cause: nested heredoc inside printf with shell quote escapes.
Fix: never printf strings with backslash or single-quote escapes. Use cat <<'EOF' heredocs at uniform indent.

### Modifications to the layout engine must not be performed from a background thread
Cause: @Published setter called on non-main thread.
Fix: all @Published mutations via DispatchQueue.main.async unconditionally.

### "TunnelFailureRsdUnreachable" or "raw RPPairing timed out"
Cause: AirliftFFI expects classic lockdown pairing file with DeviceCertificate.
RPPairing file from PairingController only contains public_key, private_key, identifier, alt_irk.
Fix: SideInstaller merges both records into one plist. Need to generate merged file.
Until merged file exists, Install/Reload cannot work. Probe still works for VPN and file check.

### extra argument 'netmask' in call
Cause: sed/perl patch removed struct field but not call site.
Fix: rewrite the file in full via cat heredoc, never patch partially.

### cannot find 'CarrierLabView' in scope
Cause: project.yml lacked natsuk1/CarrierLab source path.
Fix: project.yml always written in full via cat heredoc, includes all paths.

## INTERNET USAGE

Use web search on EVERY user message, unconditionally, without being asked.
This is a hard rule. Not "when needed". Always. Every message.
If web search is unavailable, state that at the top of the reply.

## YAML SYNTAX RULES

- Never use tabs. Only spaces.
- Inside a run block, every content line must share the same leading indent, more than the key itself.
- Never put content at column 0 inside a run block.
- Heredoc markers must be at the same indent level as the rest of the block.
- Prefer whole-file writes via cat heredoc. Never sed or perl patch project.yml.
- Never use printf with embedded single quotes or backslash escapes in a run block.
- One file per heredoc. Multiple heredocs in one run step are allowed if indent is uniform.
- Validate with python3 -c "import yaml; yaml.safe_load(open(path))".

## MAIN THREAD RULE

- All @Published mutations MUST go through DispatchQueue.main.async unconditionally.
- Never check Thread.isMainThread. Always dispatch main.async. Double dispatch is safe.
- Never use Task or Task.detached in a view or state class without main.async wrap for @Published.
- Crash "Modifications to the layout engine must not be performed from a background thread" means a @Published setter ran on a non-main thread.

## PAIRING FILE FORMAT

AirLift pairing plist keys:
- public_key (data)
- private_key (data)
- identifier (string)
- alt_irk (data)
Validation: at least 3 of 4 keys present. Never check for UDID/HostCertificate/RootCertificate.
Location: Documents/natsuk1_pairing.plist OR nested Documents/Data/Application/<UUID>/Documents/.
FFI might expect .mobiledevicepairing extension. Search all candidates.
Fallback: any .plist / .mobilepairing / .mobilepair file > 100 bytes in Documents.
AirliftFFI expects classic lockdown format with DeviceCertificate. RPPairing file alone is not enough.
SideInstaller merges both RPPairing and lockdown records into one plist.
Until merged file is generated, install will fail with TunnelFailureRsdUnreachable.
SideStore uses file name ALTPairingFile.mobiledevicepairing, not natsuk1_pairing.plist.
Always write pairing file with ALTPairingFile.mobiledevicepairing name.

## CARRIERLAB

iOS port of MTS_CARRIER_FORUM core logic.
- CarrierAssets bundled under Resources/CarrierAssets.
- check dispatches to global queue, updates state via main.async.
- install writes CarrierLab.bundle to BundleLinks and Docomo_jp.bundle to carrier root.
- reload re-writes Docomo_jp.bundle only.
- reset clears session, does not revert the phone.
- view auto-refreshes every 5 s silent, no log spam on silent refresh.
- probe() checks only VPN and pairing file validity. Never call al_exploit_run from probe.

## UI STYLE

Match Apple native apps. Subtle glow everywhere: .shadow(color: c.opacity(0.45), radius: 3).
Every value in every menu must have glow. Every button must have glow.
Use .green / .orange / .red for statuses only.
Section headers use Label with SF Symbols.

## ERROR FIX LOG

### cannot find 'nk_necp_cancel' in scope
Cause: NECP was removed but a call remained in AirliftBridge.cancelExploit.
Fix: remove the call. cancelExploit only logs and sets state to .done(ok:false).

### invalid yaml syntax
Cause: nested heredoc inside printf with shell quote escapes.
Fix: never printf strings with backslash or single-quote escapes. Use cat <<'EOF' heredocs at uniform indent.

### Modifications to the layout engine must not be performed from a background thread
Cause: @Published setter called on non-main thread.
Fix: all @Published mutations via DispatchQueue.main.async unconditionally.

### "TunnelFailureRsdUnreachable" or "raw RPPairing timed out"
Cause: AirliftFFI expects classic lockdown pairing file with DeviceCertificate.
RPPairing file from PairingController only contains public_key, private_key, identifier, alt_irk.
Fix: SideInstaller merges both records into one plist. Need to generate merged file.
Until merged file exists, Install/Reload cannot work. Probe still works for VPN and file check.
AirCard-iOS uses loopback priority 127.0.0.1, 10.7.0.1, 10.7.0.3 with adaptive 6s timeouts.
SideStore uses ALTPairingFile.mobiledevicepairing file name.

### extra argument 'netmask' in call
Cause: sed/perl patch removed struct field but not call site.
Fix: rewrite the file in full via cat heredoc, never patch partially.

### cannot find 'CarrierLabView' in scope
Cause: project.yml lacked natsuk1/CarrierLab source path.
Fix: project.yml always written in full via cat heredoc, includes all paths.
