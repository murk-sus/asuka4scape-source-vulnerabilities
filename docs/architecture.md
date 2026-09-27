# Architecture

natsuk1 — iOS kernel research toolkit.

## Layout

- `natsuk1/App` — SwiftUI entry point (`natsuk1App`, `RootView`).
- `natsuk1/Exploit/Core` — kernel primitives: `nk_api.c/h`, `nk_offsets.h`.
- `natsuk1/Exploit/NECP` — `necp.c`, syscall-level probes. Status: closed.
- `natsuk1/Exploit/Airlift` — `GrappaHelper.m`, AirTraffic / Grappa bridge.
- `natsuk1/Helpers` — Swift utilities (KeepAlive, CrashLog, OffsetsStore, …).
- `natsuk1/Views` — SwiftUI screens.
- `natsuk1/Offsets` — per-device offsets JSON.
- `natsuk1/Resources` — Info.plist, entitlements, asset catalog.
- `natsuk1/Support` — bridging header.
- `external/AirliftFFI.xcframework` — prebuilt C FFI stub.
- `docs/` — project documentation (including AI guides).

## Build

- XcodeGen (`project.yml`) → `natsuk1.xcodeproj` → `xcodebuild`.
- Ad-hoc signing via `ldid`, empty entitlements.
- CI: `.github/workflows/fix_and_release.yml`.

## Status

- NECP: closed at depth-0 sinks on this build. Kept as probe.
