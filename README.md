<p align="right">
  <img align="right" height="140" src="natsuk1.png?raw=true"/>
</p>

# natsuk1

iOS 27.0 kernel research toolkit.

![platform](https://img.shields.io/badge/platform-iOS%2027.0-blue)
![arch](https://img.shields.io/badge/arch-arm64e-green)
![device](https://img.shields.io/badge/device-iPhone14%2C5-lightgrey)
![license](https://img.shields.io/badge/license-MIT-yellow)

## Overview

Kernel-level research project targeting XNU on arm64e.

- KASLR leak via NECP sysctl arena (op=0x0D)
- Full NECP opcode map (0x01..0x1B)
- NECP UAF primitives with double-free confirmation
- Kernel offset database for iOS 27.0 / 24A437
- Remote pairing host (RPPairing) for sandbox-escape research
- Background keep-alive (silent audio + location)
- Crash-safe logging with recovery across sessions

## Requirements

- iPhone with **iOS 27.0** (build 24A437)
- LocalDevVPN with interface `10.7.0.x`
- Sideload via AltStore / TrollStore / Sideloadly / Xcode

## Install

Download the latest `natsuk1.ipa` from the [development release](../../releases/tag/development) and sideload it.

## Build

```
brew install xcodegen ldid
xcodegen generate
xcodebuild -project natsuk1.xcodeproj -scheme natsuk1 -configuration Release -sdk iphoneos
```

## Structure

```
natsuk1/
├── Exploit/         C primitives (NECP, KASLR leak, offsets)
├── Helpers/         Swift bridges (pairing, MG, keep-alive)
├── Offsets/         Versioned kernel offset DB
├── Resources/       Info.plist, entitlements, assets
└── Views/           SwiftUI interface
```

## Notes

- All offsets are device/build specific. Verify before use.
- NECP kread: verified closed (no user-controlled pointer sinks).
- KASLR leak: NECP op=0x0D returns a kernel VA in user buffer.
- This is a research project, not a general-purpose jailbreak.

## Credits

- [@flong69zxc-max](https://github.com/flong69zxc-max)
- [@murk-sus](https://github.com/murk-sus)
- [@eurogoth](https://t.me/eurogoth)
- [@asuka4scape](https://t.me/asuka4scape_developer)

## License

MIT — see [LICENSE](LICENSE).

<!-- AUTO-RULES-START -->

## 🤖 AUTO-GENERATED RESEARCH RULES

Этот блок обновляется workflow при каждом push.
**Читать первым делом. Не нарушать.**

### Обновлено
- date: 2026-09-26
- device: iPhone14,5 / iOS 27.0 / 24A437
- necp_status: **closed** (исчерпан)

### 1. NECP — статус "ЗАКРЫТ"

Проверено всё:
- `op=0x03/0x04/0x10/0x1A` возвращают **ровно 310 байт** TLV
- `op=0x0D` (sysctl_arena) → user VA, RO, kernel-wide singleton,
  первые 256 байт одинаковые у всех клиентов, `vm_protect(RW_COPY)`
  даёт COW-копию — **ядро наших записей не видит**
- `op=0x05 copy_list` → ret=-1
- `op=0x0C copy_parameters` → ret=-1
- `op=0x0F copy_update` → ret=-1
- `op=0x18/0x19` signed_id → пусто / -1
- TLV overflow (`len=0xffffffff`) → kernel отклоняет
- double-free `remove_flow x2` → ret=0, но `copy_result` = 1 байт
- kptr count во всех dump'ах = 0

**Вывод:** NECP — обычный userspace API. Примитивов нет.

### 2. iOS 27 sandbox — критично

- **`SIGKILL - CODESIGNING` = AMFI убивает ad-hoc приложение на iOS 27**
  при вызове определённых syscall'ов:
  - `proc_info(336)` — flavors 1..20
  - `csops(169)` — ops 0..15
  - `task_info` — flavors 1..40
  - `mach_port_names` — при большом count
- **Не вызывать их из ad-hoc подписанного приложения.**
- **Blind syscall sweep 0..558** убивает через `SIGSYS` на `syscall(78)`.
  Whitelist: `getpid(20)`, `getuid(24)`, `getgid(47)`, `getppid(39)`,
  `geteuid(25)`, `getegid(43)`, `gettid(286)`, `getpgid(202)`.
- `socket()`, `getsockopt()`, `setsockopt()`, `sysctl`, `uname` — **безопасны**.

### 3. Сборка — грабли

- `#include <mach/mach_vm.h>` → **`error: mach_vm.h unsupported`** в iPhoneOS SDK 26.5.
  Объявлять extern вручную:
  ```c
  extern kern_return_t mach_vm_read_overwrite(vm_map_t, mach_vm_address_t,
      mach_vm_size_t, mach_vm_address_t, mach_vm_size_t*);
  extern kern_return_t mach_vm_write(vm_map_t, mach_vm_address_t,
      vm_offset_t, mach_msg_type_number_t);
  extern kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t,
      mach_vm_size_t, boolean_t, vm_prot_t);
  ```
- `TCP_KEEPINIT`, `TCP_FASTOPEN_KEY`, `SO_REUSEPORT_LF`, `SO_NO_CHECK` — **не в SDK**.
  Sweep только по числам.
- `@MainActor` + `nonisolated(unsafe) static let shared = Foo()` → ошибка компиляции.
  Использовать `final class Foo: ObservableObject, @unchecked Sendable`,
  `nonisolated(unsafe) static let shared = Foo()`, `private init()`.

### 4. SwiftUI iOS 27 — что роняет

- `.overlay(RespringView())` — **никогда**. WKWebView спамит GPU → CA UAF → SIGSEGV.
- `List { if cond { Section } else { Section } }` в корне → падает.
- `.scaleEffect()` внутри `if` → `_ConditionalContent` ломается.
- Мутации `@Published` из `Task { }` → race → UAF. Только `Timer`.

### 5. LiveContainer

`SIGKILL - CODESIGNING` = LC ломает подпись embedded .app на iOS 27.
**Ставить IPA напрямую** через Sideloadly / AltStore / TrollStore / ESign.
Не через LiveContainer.

### 6. Оффсеты (iOS 27.0 / 24A437)

```
necp_open                      0xFFFFFFF00A4E411C
necp_client_action             0xFFFFFFF00A4E5C28
necp_client_copy_result        0xFFFFFFF00A4E7BE8
necp_client_copy_result_inner  0xFFFFFFF00A4F26F0
necp_client_add_flow           0xFFFFFFF00A4E843C
necp_client_remove_flow        0xFFFFFFF00A4E93C4
necp_client_copy_interface     0xFFFFFFF00A4EAC7C
necp_client_sysctl_arena       0xFFFFFFF00A4EB704
necp_client_copy_update        0xFFFFFFF00A4EC264
necp_get_tlv_at_offset         0xFFFFFFF00A4C2034
copyin                         0xFFFFFFF00A368EC0
copyout                        0xFFFFFFF00A369A3C
kalloc_type                    0xFFFFFFF00A200988
kfree_type                     0xFFFFFFF00A201000
kalloc_type_necp_flow          0xFFFFFFF007C62E68
```
KBASE = `0xFFFFFFF007004000`, slide = `0x3D00000`.

### 7. Ghidra / CI

- Jython 2.7: только 4 пробела. Валидация через `ast.parse`.
- Warm = `-process -noanalysis` (1-3 мин). Cold = `-import` (24-90 мин).
- Ключи кэша — статические с версией. **Никогда** `hashFiles`.
- Символизация: `ipsw kernel symbolicate --signatures symbolicator/kernel/27.0/kexts`.
- Kernelcache iOS 27 — **уже Mach-O**. Не декомпрессировать.

### 8. YAML

- **Не пихать C/Swift код в heredoc длиннее 30 строк**. Любая строка с неправильным
  отступом ломает весь YAML.
- Все строки heredoc на 10 пробелах от начала файла.
- `set +e` + `FAIL=1`, `grep -q -e "pattern"`.
- Один workflow — `fix_and_release.yml`.

### 9. Что дальше

1. **mbuf / socket** — `sendmsg` + `msg_control`, `setsockopt(IPPROTO_*)`, mbuf UAF.
2. **IOKit** — `IOSurface`, `IOConnectCallMethod`, `IOHIDEvent`.
3. **Ghidra** — `sbappendcontrol`, `m_copydata`, `sock_getsockopt`.

После 2-3 попыток — менять подход.

### 10. Что НЕ делать

- Не создавать `fixPublished_and_test.yml` / `build_and_release.yml`.
- Не пихать C/Swift в heredoc.
- Не использовать `hashFiles('kernelcache/**')`.
- Не делать blind syscall sweep.
- **Не вызывать `proc_info(336)`, `csops(169)`, `task_info` flavor sweep,
  `mach_port_names` из ad-hoc приложения — SIGKILL CODESIGNING.**
- Не мутировать `@` из `Task {}`.
- Не класть `RespringView` в дерево SwiftUI.
- Не вызывать `al_device_respring`.
- Не коммитить `natsuk1.xcodeproj`.
- Не забывать `import Combine`.
- Не доверять оффсетам без Ghidra.

<!-- AUTO-RULES-END -->
