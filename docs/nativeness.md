# Nativeness

What actually works on iOS 27 / 24A437:

- Airlift (AirTraffic / Grappa) — works via static token fallback.
- NECP — closed. All ops bounded at depth-0. Removed from repo.
- IOKit — not probed beyond shallow externalMethod dispatch.
- BSD syscalls — 557/558 unpacked, all shallow paths bounded.

What does not work:

- Kernel R/W primitive. None found.
- Grappa on iOS without static token.
