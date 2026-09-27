# natsuk1

iOS 27 kernel research toolkit.

Target: iPhone14,5 / iOS 27.0 / build 24A437 / xnu-13432.2.10~2.

## Layout

- `natsuk1/App` — SwiftUI entry point
- `natsuk1/Exploit/Core` — kernel primitives (nk_api, nk_offsets)
- `natsuk1/Exploit/NECP` — NECP probes (closed)
- `natsuk1/Exploit/Airlift` — AirTraffic/Grappa helper
- `natsuk1/Helpers` — Swift utilities
- `natsuk1/Views` — UI
- `natsuk1/Offsets` — per-device offsets JSON
- `natsuk1/Resources` — Info.plist, entitlements, assets
- `natsuk1/Support` — bridging header
- `external/AirliftFFI.xcframework` — prebuilt C FFI stub
- `docs/` — project documentation

## For AI researchers

Read `docs/ai-hints.md` and `docs/ai-think.md` before answering anything.
