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
```markdown
# ai-hints.md — рабочие заметки для будущих сессий

Проект: `natsuk1` — iOS 27.0 kernel research toolkit (arm64e, iPhone14,5).
**Читать первым делом при любой задаче по этому репо.**

---

## 0. TL;DR — что работает

- **Workflow `Extract Offsets`** — рабочий, подтверждён запуском. Warm-run 1–3 минуты,
  cold 24–90 минут (только первый раз после смены версии кэша).
- **Символизация**: `ipsw kernel symbolicate --signatures $SIG_PATH --json $KERNEL`.
  `SIG_PATH` — это НЕ `symbolicator/kernel/27.0`, а `symbolicator/kernel/27.0/kexts`
  (или `symbolicator/kernel/27.0` если `kexts/` нет).
- **Ghidra**: warm = `-process -noanalysis` + `-postScript kernel_rw.py`. Не надо
  переимпортировать kernelcache каждый раз.
- **Kernelcache iOS 27 уже распакован** (`Mach-O 64-bit arm64e`). Декомпрессия
  через `ipsw kernel dec` НЕ нужна и падает на этом файле.

---

## 1. GitHub Actions — правила, которые мы нарушали

### 1.1 Ключи actions/cache должны быть статическими

❌ **НИКОГДА так:**
```yaml
key: ghidra-project-${{ hashFiles('kernelcache/**') }}
```

hashFiles вычисляется ДО распаковки kernelcache → ключ всегда ghidra-project-.
Кэш никогда не совпадает → cold run каждый раз.

✅ ТОЛЬКО так:

```yaml
key: ghidra-project-24A437-v4
```

Статический ключ с версией. При смене kernelcache / обновлении логики — инкремент
-v4 → -v5. Старые ключи не перезаписываются (кэш immutable), новый запуск
делает cold, дальше warm.

1.2 set -euo pipefail + || true для диагностики

-e убивает step на первой же ошибке. Для шагов, где нужно видеть, что упало,
обязательно || true или явный set +e:

```bash
ipsw kernel symbolicate ... 2>&1 | tee /tmp/sym.log || true
```

1.3 Upload artifact — только явные пути

❌ НЕ так:

```yaml
path: |
  result.txt
  artifacts/
  **/*.json
```

Глобы и папки захватят мусор из workspace (ghidra/, kernelcache/,
symbolicator/, ipsw/ — 10+ GB).

✅ ТОЛЬКО так:

```yaml
path: |
  result.txt
  offsets.json
  kernel.log
  symbols.json
```

Ровно 4 файла. Плюс шаг Cleanup workspace в конце с rm -rf для тяжёлых папок.

1.4 Verify caches перед использованием

Всегда печатать hit/miss:

```yaml
- name: Verify caches
  run: |
    echo "ghidra:       ${{ steps.cache-ghidra.outputs.cache-hit }}"
    echo "kernelcache:  ${{ steps.cache-kernelcache.outputs.cache-hit }}"
    echo "symbols:      ${{ steps.cache-symbols.outputs.cache-hit }}"
    echo "project:      ${{ steps.cache-project.outputs.cache-hit }}"
```

Иначе непонятно, warm ты запускаешь или cold.

1.5 Validate Ghidra после установки

```bash
test -x "$GHIDRA_ROOT/support/analyzeHeadless"
test -d "$GHIDRA_ROOT/Ghidra/Extensions/Jython"
```

Если Jython не распакован — Ghidra не выполнит kernel_rw.py и молча завершится.

1.6 Validate scripts перед прогоном

```bash
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" scripts/kernel_rw.py
```

Ловит IndentationError на стороне workflow, а не в Ghidra через 25 минут.

---

2. Символизация — как работает и как НЕ работает

2.1 Структура blacktop/symbolicator

```
symbolicator/
└── kernel/
    ├── 25.0/
    │   └── kexts/
    │       ├── AGXG16P.kext.json
    │       ├── AppleA7IOP.kext.json
    │       └── ... (десятки .json)
    ├── 26.0/kexts/...
    ├── 27.0/kexts/...
    └── 27.2/kexts/...
```

Ключевое: сигнатуры лежат в kernel/<version>/kexts/*.json, а НЕ прямо в
kernel/<version>/.

2.2 Правильная команда

```bash
# НЕ так (мы так делали, не работало):
ipsw kernel sym --signatures symbolicator/kernel/27.0 "$KERNEL"

# НЕ так:
ipsw kernel sym --signatures symbolicator/kernel "$KERNEL"

# ТОЛЬКО так:
ipsw kernel symbolicate --signatures symbolicator/kernel/27.0/kexts --json "$KERNEL"
```

symbolicate — новая команда (алиас sym устарел). Она автоматически:

1. Применяет сигнатуры из --signatures.
2. Дополнительно парсит встроенные таблицы: bsd_syscall_table,
   mach_trap_table, mig_kern_subsystem.
3. Пишет символы в stdout в JSON.

2.3 Встроенные таблицы — что дают

Даже без сигнатур symbolicate извлекает:

· necp_open = syscall 501
· necp_client_action = syscall 502
· все mach traps
· все MIG-подсистемы

Это 100% точные адреса. Если в логе есть строки
Found bsd_syscall_table=... / Found mach_trap_table=... — символика
работает.

2.4 Если symbolicate вернул []

Причины в порядке вероятности:

1. Неверный SIG_PATH (указали корень вместо kexts/).
2. Для iOS 27.0 сигнатур нет в blacktop/symbolicator — используем fallback
   адреса из NECP_FALLBACK.
3. ipsw версии < 3.1.667 — обновить.
4. Kernelcache повреждён / неверный формат.

Fallback адреса подтверждены через switch-таблицу necp_client_action:

```
necp_client_copy_interface    0xFFFFFFF00A4EAC7C
necp_client_copy_update       0xFFFFFFF00A4EC264
necp_client_add_flow          0xFFFFFFF00A4E843C
necp_client_remove_flow       0xFFFFFFF00A4E93C4
```

Это те же адреса, что и в symbolicate выдал бы.

---

3. Ghidra — warm vs cold

3.1 Что такое warm

```bash
analyzeHeadless ghidra_project KernelProject \
  -process "$KERNEL_NAME" -noanalysis \
  -postScript kernel_rw.py -scriptPath scripts/
```

Открывает уже импортированный ghidra_project/KernelProject. Auto-analysis
НЕ делается. Время: 1–3 минуты. В логе нет строки
ANALYZING all memory and code.

3.2 Что такое cold

```bash
analyzeHeadless ghidra_project KernelProject \
  -import "$KERNEL" \
  -processor "AARCH64:LE:64:AppleSilicon" \
  -loader BinaryLoader \
  -loader-baseAddr 0xFFFFFFF007004000 \
  -postScript kernel_rw.py \
  -analysisTimeoutPerFile 12000 \
  -max-cpu 4
```

Импортирует kernelcache, делает auto-analysis. Время: 24–90 минут. В логе есть
строка ANALYZING all memory and code + таблица
AARCH64 ELF PLT Thunks / ASCII Strings / Basic Constant Reference Analyzer / ....

3.3 Как переключать

В одном шаге:

```yaml
if [ "${{ steps.cache-project.outputs.cache-hit }}" = "true" ]; then
  echo "=== warm ==="
  analyzeHeadless ... -process ...
else
  echo "=== cold ==="
  rm -rf ghidra_project && mkdir ghidra_project
  analyzeHeadless ... -import ...
fi
```

Cold нужен один раз после смены версии кэша. Дальше только warm.
Менять версию нужно, если:

· Обновился kernelcache (новый билд iOS).
· Изменилась версия Ghidra.
· Кэш побился (редко).

3.4 Не декомпрессировать Mach-O

kernelcache.release.iPhone14,5 из iOS 27.0 — это уже распакованный Mach-O.
file показывает Mach-O 64-bit arm64e. Попытка ipsw kernel dec на нём:

```
failed parse compressed kernelcache Img4: failed to ASN.1 parse IM4P:
asn1: structure error: length too large
```

Правильная логика:

```bash
FTYPE=$(file "$KERNEL")
if echo "$FTYPE" | grep -q "Mach-O"; then
  echo "already decompressed, skip"
  exit 0
fi
ipsw kernel dec "$KERNEL" -o "$OUTNAME"
```

---

4. kernel_rw.py — Jython 2.7 особенности

4.1 Отступы — только 4 пробела, без табов

Jython 2.7 очень чувствителен к смеси табов и пробелов. Копипаст через
markdown легко ломает отступы. Симптом в логе:

```
File "scripts/kernel_rw.py", line 229
    )
    ^
IndentationError: unindent does not match any outer indentation level
```

Защита: писать файл через cat > file <<'EOF' в терминале, не через
веб-редактор GitHub. Плюс проверка в workflow:

```yaml
- name: Validate scripts
  run: |
    python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" scripts/kernel_rw.py
```

4.2 Что работает, что нет

Работает:

· fh = open(path); data = json.load(fh); fh.close()
· except Exception as e:
· list(dict.items())[:5]
· int(v, 16), int(v, 0) (только с явным префиксом)

Не работает:

· with open(path) as fh: ... (иногда падает)
· голый except: без класса (Jython ругается)
· f-string (нет в 2.7)
· match/case (нет)

4.3 Fallback-адреса NECP

```python
NECP_FALLBACK = {}
NECP_FALLBACK["necp_open"] = 0xFFFFFFF00A4E411C
NECP_FALLBACK["necp_client_add_flow"] = 0xFFFFFFF00A4E843C
NECP_FALLBACK["necp_client_remove_flow"] = 0xFFFFFFF00A4E93C4
NECP_FALLBACK["necp_client_copy_interface"] = 0xFFFFFFF00A4EAC7C
NECP_FALLBACK["necp_client_copy_update"] = 0xFFFFFFF00A4EC264
NECP_FALLBACK["necp_client_action"] = 0xFFFFFFF00A4E5C28
NECP_FALLBACK["necp_client_copy_result"] = 0xFFFFFFF00A4E7BE8
NECP_FALLBACK["necp_client_remove_client"] = 0xFFFFFFF00A4E76F4
NECP_FALLBACK["necp_client_copy_list"] = 0xFFFFFFF00A4E80FC
NECP_FALLBACK["necp_client_copy_result_inner"] = 0xFFFFFFF00A4F26F0
```

copy_result_inner — фактическая функция копирования, вызывается из
copy_result через FUN_fffffff00a4f26f0. Это ключ к kread-примитиву.

4.4 necp_client_copy_result — это case 3/4/0x10/0x1a в dispatcher'е

В декомпиляции necp_client_action:

```c
case 3:
case 4:
case 0x10:
case 0x1a:
  uVar5 = FUN_fffffff00a4e7be8(pcVar7, param_2, param_3);  // copy_result
```

Внутри copy_result — не читает [flow+0x20], а ищет flow по UUID и вызывает
FUN_fffffff00a4f26f0. Смотреть надо её декомпиляцию.

---

5. NECP — что искать в декомпиляции

5.1 Поля flow

Из necp_client_copy_interface:

· [flow+0x20] — assigned_results pointer
· [flow+0x88] — parent
· [flow+0xCC] — флаги (ldrh)
· [flow+0xD4], [flow+0xD8] — счётчики
· [flow+0x100] — флаг
· [flow+0x4A0] — используется в copy_result через puVar7[0x94]

[flow+0x20] подтверждён в remove_flow (ldr_x [x23, #0x20]) и в
copy_interface (ldr_x [x0, #0x20]).

5.2 Что искать в copy_result_inner

· memcpy(..., flow+X, ...) — если X user-controllable, примитив kread.
· *(long *)(flow + X) где X > 0x100 — потенциально user-controlled offset.
· Вызов copyout (это FUN_fffffff00a369a3c) — куда идёт результат.

5.3 Если X фиксирован

Переключаться на necp_get_tlv_at_offset — там может быть uint32 overflow в
проверке длины. Искать в дизасме add wN, wN, #imm рядом с cmp wN, wM.

---

6. Что НЕ надо делать

· ❌ Не ставить hashFiles('kernelcache/**') в ключ кэша. Всегда 0 → cold.
· ❌ Не указывать symbolicator/kernel или symbolicator/kernel/27.0 в
--signatures. Только /27.0/kexts.
· ❌ Не декомпрессировать Mach-O через ipsw kernel dec. Проверять
  file сначала.
· ❌ Не заливать в артефакт workspace целиком. Только 4 файла явно.
· ❌ Не смешивать табы и пробелы в kernel_rw.py. Только 4 пробела.
· ❌ Не забывать || true для команд, где нужен лог ошибки.
· ❌ Не делать cold каждый раз. Warm через -process -noanalysis.
· ❌ Не создавать NEXTHINT.txt / GHIDRA_HINTS.txt. Cleanup в workflow
  их удалит всё равно.
· ❌ Не менять имя workflow Extract Offsets. Кэш ключи статические, но
  имя важно для читаемости.
· ❌ Не коммитить natsuk1.xcodeproj (в .gitignore).
· ❌ Не вызывать al_device_respring — перезагружает телефон целиком.

---

7. Полезные команды

```bash
# Локально собрать
brew install xcodegen ldid
xcodegen generate
xcodebuild -project natsuk1.xcodeproj -scheme natsuk1 \
  -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO SWIFT_VERSION=5.0 build

# Проверить kernel_rw.py на синтаксис
python3 -c "import ast; ast.parse(open('scripts/kernel_rw.py').read())"

# Смотреть результат
cat result.txt | grep -A 3 "copy_result_inner"
jq . offsets.json
jq 'if type == "array" then length else keys | length end' symbols.json
```

---

8. Итоговое правило

1. Ключи кэша — статические с версией. Никаких hashFiles(kernelcache).
2. Warm-run это -process -noanalysis. Cold только первый раз.
3. Символизация — symbolicate + /kexts. Не sym + корень.
4. Артефакт — ровно 4 файла. Явные пути, не глобы.
5. Jython 2.7 — только 4 пробела. Валидировать через ast.parse.
6. Kernelcache iOS 27 — уже Mach-O. Проверять file перед декомпрессией.
7. Если после 2-3 попыток не работает — смотреть в kernel.log и
result.txt, а не менять оффсеты наугад.

```
```
