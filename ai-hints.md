# ai-hints.md — рабочие заметки для будущих сессий

Проект: `natsuk1` — iOS 27.0 kernel research toolkit (arm64e, iPhone14,5/14,7).
Читать первым делом при любой задаче по этому репо.

---

## 0. TL;DR — где мы сейчас

- NECP-путь через `necp_client_copy_result` **не подтверждён**. Function
  address неизвестен. `0xA4EC264` = `necp_client_copy_update`,
  `0xA4EAC7C` = `necp_client_copy_interface`.
- `necp_client_flow` живёт в **kalloc_type zone** (не kalloc.1024).
  Userspace spray (OOL, mach_msg, socket, cmsg) не может туда попасть.
- Реальные поля flow struct из дизасма `copy_interface` / `remove_flow`:
  - `+0x20` (ldr_x, assigned_results pointer)
  - `+0x88` (ldr_x, parent)
  - `+0xCC`, `+0xD4`, `+0xD8`, `+0x100` (разные флаги/типы)
- Валидных оффсетов из 63: **20 kptr** (kernel globals + 17 zones).
- 4 реально сломаны: `off_g_allproc`, `off_g_kernel_task`,
  `off_g_kernel_map`, `off_g_zone_map`, `off_mach_trap_table`.
- Нужен новый примитив (TLV overflow / mbuf / IOKit) для kread.

---

## 1. Структура репо

```
natsuk1/
├── Exploit/          C-примитивы
│   ├── necp.c        основной примитив (NECP)
│   ├── nk_api.c      логгер + nk_full_exploit
│   ├── nk_api.h
│   ├── nk_offsets.h  хардкод оффсетов
│   └── GrappaHelper.[hm]  AirTraffic pairing token
├── Helpers/          Swift
│   ├── AirliftBridge.swift   pairing + exploit run
│   ├── PairingController.swift  RPPairing host
│   ├── NetworkStatus.swift   интерфейсы, LocalDevVPN check
│   ├── CrashLog.swift        persistent log
│   ├── KeepAlive.swift       audio + location
│   ├── MobileGestalt.swift   MG API
│   ├── DeviceName.swift
│   ├── OffsetsStore.swift    JSON offsets
│   ├── LocalNetworkAuthorization.swift
│   └── Respring.swift        WebKit crash respring
├── Views/            SwiftUI
│   ├── OverviewView.swift    Exploit + Runtime + Logs + Log Actions
│   ├── RuntimeView.swift     Slide/Base/Status
│   ├── AirliftView.swift     Pairing UI
│   ├── SettingsView.swift
│   ├── ToolsView.swift
│   ├── ContentView.swift     TabBar
│   ├── AboutView, DeviceInfoView, MobileGestaltView,
│   ├── OffsetsView, PathAccessView, CrashLogView
├── Offsets/          JSON база
│   ├── index.json
│   └── iPhone14,5_iOS27.0_24A437.json
├── Resources/
│   ├── Info.plist
│   ├── natsuk1.entitlements
│   └── Assets.xcassets
├── natsuk1.swift     @main + AppState + RootView + cCallback
└── bridging.h
```

**Workflows:**
- `.github/workflows/fix_and_test.yml` — name **"1 · Fix and Test"**
  (обязательно, иначе второй не сработает)
- `.github/workflows/build_and_release.yml` — слушает `workflow_run`,
  пересобирает и релизит

---

## 2. GitHub Actions — правила

### 2.1 Не ломать YAML

- Heredoc только через `cat > /tmp/x <<'EOF'`, **никогда не `'''...'''`**
  с многострочным Python — строки склеиваются при копипасте.
- Python-скрипт писать в файл `/tmp/patch.py`, потом `python3 /tmp/patch.py`.
- `grep -q "----- attempt"` — `grep` видит `--attempt` как флаг, использовать
  `grep -q -e "pattern"` или `grep -q -- "pattern"`.
- `#define FOO    0x68` — не искать через `replace("FOO 0x68")`, использовать
  `startswith("#define FOO")` и переписывать строку целиком.
- Все строки heredoc выровнены одинаково (обычно 10 пробелов от начала YAML).
- `for s, e, n, exec in blocks()` — `exec` зарезервирован в Jython 2.7,
  использовать `is_exec`.

### 2.2 Идемпотентность патчей

```python
import sys
F = "natsuk1/Exploit/necp.c"
with open(F) as fh: s = fh.read()
if "my-marker-v1" in s: sys.exit(0)
orig = s
s = s.replace("old", "new")
if "my-marker-v1" not in s: sys.exit(1)
if s == orig: sys.exit(1)
with open(F, "w") as fh: fh.write(s)
```

- Маркер обязателен.
- После замен проверять `s.count(pattern) == 1` — если дублируется, падать.

### 2.3 Verify

```bash
set +e
FAIL=0
chk() {
  if eval "$2" >/dev/null 2>&1; then echo "  OK   $1"; else echo "  FAIL $1"; FAIL=1; fi
}
chk "marker"    "grep -q -e 'marker-v1' file.c"
chk "no junk"   "! test -f junk.txt"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
clang -fsyntax-only -isysroot "$SDK" -arch arm64 -x c \
  -I"$(pwd)/natsuk1/Exploit" -Wall -Wno-everything file.c || FAIL=1
if [ "$FAIL" -ne 0 ]; then exit 1; fi
```

### 2.4 IPA + Release notes

```bash
ldid -Snatsuk1/Resources/natsuk1.entitlements "$APP_PATH/natsuk1"
mkdir -p Payload; cp -R "$APP_PATH" Payload/
COPYFILE_DISABLE=1 zip -qry natsuk1.ipa Payload; rm -rf Payload

REPO="${{ github.repository }}"
IPA_URL="https://github.com/${REPO}/releases/download/development/natsuk1.ipa"
gh release create development natsuk1.ipa \
  --target "${GITHUB_SHA}" --title "Development" \
  --prerelease --latest=false \
  --notes "IPA: ${IPA_URL}
AltStore: altstore://install?url=${IPA_URL}
Scarlet:  scarlet://install?url=${IPA_URL}
ESign:    esign://install?url=${IPA_URL}"
```

`--prerelease --latest=false` обязательно для `releases/download/development/`.

### 2.5 Финальный commit

```bash
git config user.name  "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add -A
if git diff --cached --quiet; then echo "no changes"; exit 0; fi
git commit -m "desc [skip ci]"
git push
```

---

## 3. SwiftUI / Xcode

### 3.1 Combine

`Timer.publish(...).autoconnect()` требует `import Combine`. Без него
`Publishers.Autoconnect<...>` не находится.

Если проблемы — заменить на `Task.sleep` в `.task` или
`DispatchQueue.global(qos: .utility).async` + `onReceive`.

### 3.2 nonisolated(unsafe)

Swift 6 warning про `nonisolated(unsafe) static let shared = X()` если X уже
`Sendable` — игнорировать, это не error.

### 3.3 Дубликаты структур

`OverviewView.swift` содержит `StatusDot` и `LogTerminal`. Если объявить их
ещё в другом файле — duplicate symbol. Проверять `grep -r "struct X"`.

### 3.4 Иконки (текущий стиль)

Иконки **только у заголовков секций** (`Label("X", systemImage:)`),
у рядовых кнопок — без иконок.

| Секция                         | Иконка                 |
|--------------------------------|------------------------|
| Overview → Exploit             | `cpu`                  |
| Overview → Runtime             | `waveform.path.ecg`    |
| Overview → Logs                | `terminal`             |
| Overview → Log Actions         | `document.on.document` |
| Airlift → Network              | `network`              |
| Airlift → Pairing              | `link.circle`          |
| Airlift → Exploit              | `cpu`                  |
| Airlift → Log                  | `terminal`             |
| Airlift → Log Actions          | `document.on.document` |
| Tools → Exploit                | `memorychip`           |
| Tools → Device                 | `gearshape.2`          |
| Tools → Diagnostics            | `chart.xyaxis.line`    |
| TabBar → Overview              | `square.grid.2x2`      |
| TabBar → Tools                 | `hammer`               |
| TabBar → Settings              | `gearshape.fill`       |
| Settings → App                 | `exclamationmark.circle` |
| Settings → Background Keep-Alive | `moon.stars`         |
| Settings → Options             | `slider.horizontal.3`  |

### 3.5 Порядок в OverviewView

1. `Exploit` header → Run Exploit, Cancel Exploit (без иконок)
2. `RuntimeView()` — Slide, Base, Status
3. `Logs` → LogTerminal
4. `Log Actions` → Copy All (меняет текст на "Copied!" 1.5 сек), Clear

### 3.6 Respring

`RespringView` использует WebKit GPU-spam, чтобы уронить SpringBoard.
Кнопка Respring шлёт `NotificationCenter.default.post(name:
"natsuk1.respring")`. `.onReceive` в RootView ставит `state.show_respring = true`.

**Не вызывать** `al_device_respring` — перезагружает телефон целиком.

### 3.7 LocalDevVPN

Пользователь юзает LocalDevVPN:
- device IP `10.7.0.1`
- tunnel IP `10.7.1.1`

`NetworkStatus.loopbackVPNUp()` проверяет `10.7.0.`, `10.7.1.`, `10.7.2.`,
`10.7.3.` или `10.7.` — на любом интерфейсе.

### 3.8 xcodebuild

2-4 минуты на `macos-26` — норма.

---

## 4. Ghidra headless

### 4.1 Jython 2.7 ограничения

- `for c in b"abc"` возвращает **str**, не int. Для байта: `ord(c)`.
- `bytearray(size)` не работает с Java byte[]. Использовать
  `from jarray import zeros; arr = zeros(n, 'b')`.
- `except: pass` — плохо, лучше `except Exception as e: print(str(e))`.
- `sorted(set(...))` с mixed типами падает.
- `int(x, 0)` не всегда парсит `0xABC`. Для HEX: `int(x, 16)`.

### 4.2 Auto-analysis отсутствует

Если kernel.raw не был pre-analyzed (`analyzeAll(currentProgram)`),
Ghidra не создаёт имена функций — только `FUN_xxx`. Символьный
`find_func_by_name("proc_pid")` не сработает.

Workaround: глобальный скан `__text` по паттернам.

### 4.3 Быстрое чтение памяти

**Не читать по одному `getInt` в цикле** — 57 MB текста × 32 target'а
= часы. Читать целыми блоками:
```python
ga = sa(start)
jbuf = zeros(size, 'b')
currentProgram.getMemory().getBytes(ga, jbuf)
buf = bytearray(size)
for i in range(size):
    v = int(jbuf[i])
    if v < 0: v += 256
    buf[i] = v
```
Дальше работать с `bytearray` в чистом Jython.

### 4.4 ADRP+ADD xref resolver

Авто-анализа нет, xrefs тоже нет. Искать вручную:
```python
# ADRP
if (b0 & 0x9F000000) == 0x90000000:
    rd = b0 & 0x1F
    immlo = (b0 >> 29) & 3
    immhi = (b0 >> 5) & 0x7FFFF
    imm = (immhi << 2) | immlo
    if imm & 0x100000: imm -= 0x200000
    page = (addr & ~0xFFF) + (imm << 12)
    # ADD imm64
    if (b1 & 0xFF800000) == 0x91000000:
        rn = (b1 >> 5) & 0x1F
        rd2 = b1 & 0x1F
        imm12 = (b1 >> 10) & 0xFFF
        if rn == rd and rd2 == rd:
            resolved = (page + imm12) & 0xFFFFFFFFFFFFFFFF
```
Один проход по всему тексту, collect map `{resolved_addr: [pcs]}`.
Затем просто lookup по target'ам.

### 4.5 ARM64 mem-op decoder

```python
def extract_mem(raw):
    if (raw & 0xFFC00000) == 0xF9400000: return ("ldr_x", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 8)
    if (raw & 0xFFC00000) == 0xB9400000: return ("ldr_w", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 4)
    if (raw & 0xFFC00000) == 0xF9000000: return ("str_x", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 8)
    if (raw & 0xFFC00000) == 0xB9000000: return ("str_w", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 4)
    if (raw & 0xFFE00000) == 0x39400000: return ("ldrb", (raw >> 5) & 0x1F, (raw >> 10) & 0xFFF)
    if (raw & 0xFFE00000) == 0x39000000: return ("strb", (raw >> 5) & 0x1F, (raw >> 10) & 0xFFF)
    if (raw & 0xFFE00000) == 0x79400000: return ("ldrh", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 2)
    if (raw & 0xFFE00000) == 0x79000000: return ("strh", (raw >> 5) & 0x1F, ((raw >> 10) & 0xFFF) * 2)
    if (raw & 0xFFC00000) == 0xF8400000:  # ldur x
        i = (raw >> 12) & 0x1FF
        if i & 0x100: i -= 0x200
        return ("ldur_x", (raw >> 5) & 0x1F, i)
    if (raw & 0xFFC00000) == 0xB8400000:  # ldur w
        i = (raw >> 12) & 0x1FF
        if i & 0x100: i -= 0x200
        return ("ldur_w", (raw >> 5) & 0x1F, i)
    return None
```

### 4.6 Accessor functions

Функции-аксессоры (`proc_pid()`, `kauth_cred_getuid()`, `proc_task()`)
выглядят как:
```
ldr X0, [X0, #imm]
ret
```
Кодировка:
- `ldr x` = `0xF9400000 | (imm/8) << 10 | ...`
- `ldr w` = `0xB9400000 | (imm/4) << 10 | ...`
- `ret` = `0xD65F03C0`

Один проход по `__text`, ищем `b0 = ldr X0,[X0,#imm]` + `b1 = ret`.
Получаем все offset'ы структур.

### 4.7 Декомпиляция

```python
from ghidra.app.decompiler import DecompInterface
from ghidra.util.task import ConsoleTaskMonitor
d = DecompInterface()
d.openProgram(currentProgram)
r = d.decompileFunction(f, 120, ConsoleTaskMonitor())
c = r.getDecompiledFunction().getC()
```

---

## 5. iOS kernel research контекст

### 5.1 KASLR

`KBASE = 0xFFFFFFF007004000`, slide обычно `0x3D00000` для iPhone 14
iOS 27. Runtime = KBASE + slide.

### 5.2 Zoned allocators

iOS 16+ — **kalloc_type** с отдельной зоной на каждый type. Видно в дизасме:
`FUN_xxx(kalloc_type_var_ptr, size, flags, ...)`.

Маркер в `__cstring`: `site.struct FOO` — KASAN.

Если структура в kalloc_type — generic spray бесполезен. Только
`kalloc_type`-специфичные spray.

### 5.3 NECP syscalls

- `501 = necp_open`
- `502 = necp_action` (op = 2-й аргумент)

Opcodes:
- `0x01` ADD_CLIENT
- `0x02` REMOVE_CLIENT
- `0x04` COPY_RESULT
- `0x11` ADD_FLOW
- `0x12` REMOVE_FLOW

### 5.4 Подтверждённые факты

- `remove_flow` не проверяет UUID повторно → double-free возможен (`rm1=0 rm2=0`).
- `add_flow` после free **реинициализирует** flow — fake не сохраняется.
- `necp_client_flow` в kalloc_type zone.
- `copy_interface` читает `[flow + 0x20]` как kptr и `memcpy(..., 0x18)`.
- `remove_flow` читает `[flow + 0x20]` (assigned_results) и `[flow + 0x88]`.
- `copy_update` работает с client->update_list через `param_1+0x28`.

### 5.5 Адреса NECP (iOS 27.0 / 24A437 + slide 0x3D00000)

```
necp_open                    0xFFFFFFF00A4E411C
necp_client_add_flow         0xFFFFFFF00A4E843C
necp_client_remove_flow      0xFFFFFFF00A4E93C4
necp_client_copy_interface   0xFFFFFFF00A4EAC7C
necp_client_copy_update      0xFFFFFFF00A4EC264
```

`necp_client_action` = `FUN_fffffff00a4e5c28` — общий dispatcher.

### 5.6 Строки для идентификации

```
0x70D2B70  "necp_client_copy assigned results copyout error"
0x70D2B2B  "necp_client_copy assigned results tlv_header copyout error"
0x70D2AC4  "necp_client_copy result copyout error"
0x70D2AF4  "necp_client_copy group members copyout error"
0x70D2A90  "necp_client_copy parameters copyout error"
```

`copy_result` ссылается минимум на 3 из них. Использовать ADRP+ADD
resolver для нахождения функции.

### 5.7 ifnet array

Из декомпиляции `copy_interface`:
```
DAT_fffffff00ad75720  — array base
DAT_fffffff00ad75718  — size
DAT_fffffff00ad75728  — count/stride
```

`copy_interface` берёт `interface_index` из userspace и читает
`*(ifnet_array_base + (index-1)*stride)` → указатель на ifnet.

### 5.8 kalloc_type_var для flow

```
DAT_fffffff007c62e68  — kalloc_type descriptor для necp_client_flow
```

Дамп `add_flow` показывает `FUN_fffffff00a200988(&DAT_fffffff007c62e68, size, 4, 0)`.

---

## 6. Оффсеты — статус валидации

### 6.1 KPTR_OK (20 из 63)

**Globals:**
- `off_g_kernproc` → `0xFFFFFFF00ADEE310`
- `off_g_task_list` → `0xFFFFFFF00AD78AC0`
- `off_sysent_base` → `0xFFFFFFF0070A7FD7`

**Zones (17):**
- `off_zone_data_kalloc` → `0xFFFFFFF0070463BD`
- `off_zone_early_kalloc` → `0xFFFFFFF0070463B0`
- `off_zone_kalloc_type_var` → `0xFFFFFFF0070463DC`
- `off_zone_site_struct_*` (все 14)

### 6.2 Сломаны (нужно искать)

- `off_g_allproc = 0xBBB048` → `0x1` (counter, не head)
- `off_g_kernel_task = 0x009C70` → `0xDECAFBAD` (sentinel)
- `off_g_kernel_map = 0xBBA228` → ascii `_S_OPTDET_`
- `off_g_zone_map = 0x3D66800` → `0x0`
- `off_mach_trap_table = 0xBE8018` → `0x0`

### 6.3 NECP flow offsets (только эти валидны)

- `+0x20` (assigned_results pointer) — подтверждён в copy_interface и remove_flow
- `+0x88` (parent) — подтверждён в remove_flow

`0x68`, `0x70`, `0x58`, `0x100` из Offsets.json **не подтверждены**.

### 6.4 Числовые struct offsets (из Ghidra accessor scan)

Независимо подтверждены через `ldr X0, [X0, #imm]; ret`:
- `+0x74` (proc_pid)
- `+0x98` (proc_ucred) — есть в `0xFFFFFFF0081EA3F4`
- `+0x4E0` (task_bsd_info) — `0xFFFFFFF00A254C88`
- `+0x320` (task_itk_space)
- и т.д.

Точные matches в тексте — см. `result.txt` секция
`NUMERIC OFFSET -> ACCESSOR MATCH`.

---

## 7. Что делать если kread не работает

1. **Проверить, что функция правильная.** `copy_interface` читает
   `[flow+0x20]` через `memcpy(&local_d0, flow+0x20, 0x18)` — это
   фиксированный offset, не user-controlled read.

2. **Проверить kalloc_type.** Если flow в отдельной зоне — generic spray
   бесполезен.

3. **Double-free не помогает** — `add_flow` реинициализирует flow.

4. **Искать TLV overflow** в `necp_get_tlv_at_offset` — если там
   uint32 overflow в проверке длины, получится OOB read.

5. **Fallback на TLV or mbuf/socket** — если NECP мёртв.

---

## 8. Логирование на устройстве

- `CrashLog.swift` → `Documents/natsuk1-live.log`, marker `[SHUTDOWN]`
  при уходе в background.
- `nslog` зеркалит всё в Console.app.
- `AppState.parseLogLine` извлекает `slide=0x...`, `base=0x...` для UI.
- cCallback зовётся из C (NK log), `parseLogLine(_line)` в Swift.

---

## 9. Что НЕ надо делать

- ❌ Не искать offsets через символы Ghidra без auto-analysis.
- ❌ Не спреить flow-struct обычными OOL/msg/socket.
- ❌ Не создавать NEXTHINT.txt.
- ❌ Не менять `workflow name` — второй workflow сломается.
- ❌ Не использовать `al_device_respring` для respring.
- ❌ Не коммитить `natsuk1.xcodeproj` (в .gitignore).
- ❌ Не забывать `import Combine` где есть `Timer.publish`.
- ❌ Не дублировать `StatusDot` / `LogTerminal`.
- ❌ Не читать 57 MB `__text` через `getInt` в цикле — виснет.
- ❌ Не использовать `exec` как имя переменной в Jython.

---

## 10. Что срочно надо проверить следующим шагом

1. **Запустить `final_recon.py` (fast version) с single-pass ADRP+ADD
   resolver.** Он найдёт функцию по xref на строки `assigned results
   copyout error` и `assigned results tlv_header copyout error`. Это
   и есть `necp_client_copy_result`.

2. **По её декомпиляции** найти:
   - какой offset читается как kptr из flow
   - куда идёт `copyout` (в userspace или нет)
   - есть ли user-controllable offset

3. **Если функция читает `[flow + X]` где X controllable** — построить
   kread через TLV.

4. **Если нет** — искать `necp_get_tlv_at_offset` в symbols и смотреть
   overflow.

Скрипт `final_recon.py` (fast) с однопроходным ADRP+ADD resolver уже
готов — запускать его, ждать 3-5 минут, читать `result.txt` секцию
`CANDIDATE FUNCTIONS` и `TOP CANDIDATE FULL DUMP`.

---

## 11. Полезные команды

```bash
# Собрать IPA локально
brew install xcodegen ldid
xcodegen generate
xcodebuild -project natsuk1.xcodeproj -scheme natsuk1 \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=5.0 build

# Установить на устройство
ios-deploy --bundle build/Build/Products/Release-iphoneos/natsuk1.app
# или через Sideloadly / TrollStore (IPA)

# Смотреть логи
idevicesyslog | grep natsuk1
```

---

## 12. Итоговое правило

1. **Не доверять оффсетам без проверки в Ghidra.**
2. **Не строить kread на структуре в kalloc_type zone** если нет
   типового spray.
3. **Проверять гипотезу через реальный лог на устройстве.**
4. **Если после 2-3 попыток не работает — менять подход, не крутить
   одни и те же оффсеты.**
5. **Все изменения в репо — через GitHub Actions workflow с verify-шагом
   до коммита.**
