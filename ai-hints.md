# ai-hints.md — рабочие заметки

Проект: `natsuk1` — iOS 27.0 kernel research toolkit.
Kernelcache: iPhone14,5 / 24A437. Читать первым делом.

## 0. TL;DR

- **KASLR leak работает** через NECP `op=0x0D` (`necp_client_sysctl_arena`).
  Возвращает kernel VA sysctl arena, из него slide. См. `nk_offsets.h`.
- **NECP kread — закрыт.** Все copyout в copy_result/copy_result_inner/
  copy_list/copy_interface/copy_update/op=0x0B/op=0x15/op=0x1B читают
  из фиксированных оффсетов kernel-структур. User-controlled
  указателей в источнике copyout нет.
- `necp_client_flow` в `kalloc_type` зоне → generic spray бесполезен.
- `add_flow` **переинициализирует** flow — double-free не помогает
  подсунуть fake.
- Точки роста: TLV-overflow (`necp_get_tlv_at_offset = 0xA4C2034`),
  netagent path, mbuf/socket/IOKit.

## 1. Полный dispatcher NECP

`necp_client_action = 0xFFFFFFF00A4E5C28`, syscall 502.

| op | func | name |
|----|------|------|
| 0x01 | 0xA4E60DC | add_client |
| 0x02 | 0xA4E76F4 | remove_client |
| 0x03 | 0xA4E7BE8 | copy_result |
| 0x04 | 0xA4E7BE8 | copy_result (alt) |
| 0x05 | 0xA4E80FC | copy_list |
| 0x06 | 0xA4E9904 | request_nexus |
| 0x07 | 0xA4EA0B4 | agent_action |
| 0x08 | 0xA4EA778 | copy_agent |
| 0x09 | 0xA4EAC7C | copy_interface |
| 0x0B | 0xA4EBA0C | copy_route_statistics |
| 0x0C | 0xA4EA8A0 | copy_parameters |
| 0x0D | 0xA4EB704 | sysctl_arena (KASLR) |
| 0x0E | 0xA4EBD58 | update_cache |
| 0x0F | 0xA4EC264 | copy_update |
| 0x10 | 0xA4E7BE8 | copy_result (long) |
| 0x11 | 0xA4E843C | add_flow |
| 0x12 | 0xA4E93C4 | remove_flow |
| 0x13 | 0xA4E7158 | claim |
| 0x14 | 0xA4EC5D8 | sign |
| 0x15 | 0xA4EB2B4 | get_interface_address |
| 0x16 | 0xA4EAB50 | copy_agent (alt) |
| 0x17 | 0xA4EC9EC | validate |
| 0x18 | 0xA4ECC4C | get_signed_client_id |
| 0x19 | 0xA4ECE88 | set_signed_client_id |
| 0x1A | 0xA4E7BE8 | copy_result (long2) |
| 0x1B | 0xA4ED170 | get_flow_statistics |

## 2. KASLR leak

`necp_client_sysctl_arena` (op=0x0D):
- Аллоцирует sysctl arena через `FUN_fffffff00a7e1c14`.
- Мапит через `FUN_fffffff00a7e2024`, возвращает kernel VA.
- Сохраняет в `client->field_0x110`.
- Затем `copyout(client->field_0xf8 + field_0x110, user_buf, 8)`.

Результат: 8 байт kernel VA в user буфер. Slide = VA - KBASE.

## 3. Структура flow (kalloc_type)

`add_flow` аллоцирует через `kalloc_type(&DAT_fffffff007c62e68, size, 4, 0)`,
`0x3c < size <= 0xf1`. Меньше — на стеке.

Подтверждённые оффсеты flow:
- `+0x20` assigned_results (ldr_x)
- `+0x28` assigned_results_len
- `+0x38` next (в дереве)
- `+0x48` list_next
- `+0x50` list_prev
- `+0x58` refcount / pcb lock
- `+0x6c` flags
- `+0x74` flags2
- `+0x88` parent
- `+0x90` rules list head
- `+0x4a0` update list head
- `+0x4b0` group_members len
- `+0x4b8` group_members ptr
- `+0x4c0` netagent ptr
- `+0x4c8` iface index (slot 0)
- `+0x4d0` iface index 1
- `+0x538` iface count
- `+0x550` fd_data ptr
- `+0x568` netns_ptr
- `+0x5a0` params len
- `+0x5a8` params ptr (kalloc_type)

## 4. copy_result_inner

`0xFFFFFFF00A4F26F0`, 0x780 байт. Обрабатывает op 3/4/0x10/0x1A.

- op=3: `copyout(flow+0x5a8, user, flow+0x5a0)` — parameters
- op=4/0x10/0x1a: обход дерева flow, для каждого:
  - inline TLV `copyout(flow+0x70, user, flow+0x68)`
  - group members `copyout(*(flow+0x4b8), user+off, flow+0x4b0)`
  - protocol `copyout(&local, user+off, 0x11)` (если флаг 0x20)
  - MAC/interface `copyout(ptr, user+off, len)` (если флаг 0x82)
  - stats `copyout(&local, user+off, 9)` (если флаг 0x100)

Все источники — фиксированные оффсеты от flow. Не kread.

## 5. Что проверено и закрыто

- `add_update_helper` (0xA4DD078) — TLV-писатель, kalloc_type, не user-ptr.
- `group_builder` (0xA4E19B4) — принимает `param_6` (assigned_results
  от netagent), пишет в `plVar15[0x15]`. Источник — kernel-side.
- `assigned_results` (0xA501454) — вызывает handler netagent по
  function ptr из глобального реестра `DAT_fffffff00adade70`.
- `destroy_flow` (0xA4E2E0C) — корректная очистка, без UAF.
- `find_client_uuid` (0xA4DB8D4) — обход списка клиентов, без bugs.
- `per_flow_copy` (0xA4F2E70) — внутрянка copy_result_inner.
- `op=0x0E update_cache` — вызывает `FUN_fffffff00a5af190`/`5af698`
  с kernel netagent ptr. Не user-controllable.
- `op=0x06/07/0E` — требуют netagent entitlements.

## 6. Что делать дальше

1. **`necp_get_tlv_at_offset` @ 0xA4C2034.** Единственное место,
   где может быть uint32-overflow в проверке длины. Если overflow —
   OOB read через copy_result. Приоритет.
2. **`op=0x15 get_interface_address`** — ifnet array, если получится
   перезаписать указатель. Требует примитива write.
3. **Fallback: mbuf/socket/IOKit.** NECP как kread закрыт.

## 7. Правила CI

- Ключи кэша Ghidra — статические с версией.
- Warm: `-process -noanalysis`. Cold: `-import` раз в жизни.
- Jython 2.7: только 4 пробела, никаких табов.
- Verify перед коммитом: JSON valid + `ast.parse` + clang syntax.
- Имя workflow `1 · Fix and Test` не менять.

## 8. Что НЕ делать

- Не искать оффсеты через Ghidra без auto-analysis.
- Не спреить flow-struct обычными OOL/msg/socket.
- Не создавать NEXTHINT.txt / GHIDRA_HINTS.txt.
- Не коммитить natsuk1.xcodeproj (в .gitignore).
- Не вызывать `al_device_respring` — перезагружает телефон целиком.
- Не забывать `import Combine` там где `Timer.publish`.
- Не дублировать `StatusDot` / `LogTerminal`.
- Не читать 57 MB `__text` через getInt в цикле.
- Не использовать `exec` как имя переменной в Jython.
- Не доверять оффсетам без проверки в Ghidra.

## 9. Полезные адреса

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
