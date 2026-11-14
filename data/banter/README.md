# Реплики отряда: data/banter/

Все `.json` в этой папке читаются вместе (имя файла ни на что не влияет — разложено по героям для удобства).
В каждом файле может быть:

- `"battle"` — фразы-пузыри в бою;
- `"camp"` — разговоры между комнатами;
- `"settings"` — частота и паузы (лежит в `settings.json`).

Правки подхватываются при следующем запуске игры. Осторожно с запятыми: после последнего элемента списка запятой быть не должно (если файл сломан — Godot напишет предупреждение `BanterDB: не получилось прочитать ...`).

---

## Фразы в бою: `"battle"`

```json
{"id": "aki_kill_01", "speaker": "aki", "trigger": "kill_enemy", "text": ["Ой. Перелечила.", "Упс~"]}
```

| Поле | Что делает |
|---|---|
| `id` | уникальное имя фразы (любое, без повторов) |
| `speaker` | кто говорит: `witch`, `warrior`, `aki`, `luisa`, `fufu`. Говорит, только если жива и на поле |
| `trigger` | когда звучит (таблица ниже) |
| `text` | строка или список вариантов — берётся случайный |
| `about` | чьё это событие должно быть для говорящего (см. ниже). Обычно не нужно — у триггера есть значение по умолчанию |
| `chance` | редкость фразы, 0..1 (по умолчанию 1 — всегда среди кандидатов) |
| `priority` | чем выше, тем главнее: если подходит фраза с priority 10, обычные (0) не звучат |
| `weight` | вес среди фраз одного priority (по умолчанию 1) |
| `once_per_battle` | один раз за бой |
| `once` | один раз за всю игру (запоминается в сохранении) |
| `cooldown` | пауза в секундах, прежде чем эта фраза сможет прозвучать снова |
| `conditions` | условия (ниже) |
| `reply` | ответ других героев: `[{"speaker": "witch", "text": "..."}]` — звучит через ~2.4 сек, если говорящий жив |
| `enemy` | `true` — говорит враг (`speaker` — id врага: `fufu`, `aki_enemy`, `luisa_enemy`, `shlep`, `bubble`, `blob`, `acid`) |
| `disabled` | `true` — фраза выключена |

В тексте можно писать `{actor}`, `{target}`, `{enemy}` — подставится имя участника события: «Держись, {target}!»

### Триггеры

| trigger | когда | about по умолчанию |
|---|---|---|
| `battle_start` | начало боя | any |
| `turn_start` | начало каждого хода игрока (со 2-го) | any |
| `card_played` | разыграна карта (`card`, `card_kind`, `card_cost` в условиях) | actor — хозяйка карты |
| `ult` | ульта | actor |
| `kill_enemy` | враг убит (`enemy`) | actor — чья карта добила |
| `last_enemy` | остался последний враг | any |
| `status_applied` | наложен статус (`status`, `target_side`) | actor — кто наложил |
| `heal` | героиню вылечили | actor — кто лечил |
| `shield` | героине дали щит | actor |
| `ally_low_hp` | героиня опустилась ниже 30% HP | target — сама раненая |
| `big_hit` | героиня получила за раз ≥25% HP | target |
| `ally_down` | героиня пала | other — кто-то из остальных |
| `enemy_low_hp` | враг опустился ниже 25% HP | any |
| `capture` | приманка поймала героиню | any |
| `victory` | комната зачищена | any |

**about**: `actor` — говорит тот, кто действовал (разыграл карту, наложил статус, вылечил);
`target` — тот, с кем это случилось (кого вылечили, кого очаровали, кто ранен);
`other` — кто-то третий (не actor и не target); `any` — кто угодно.

Пример: Ведьмочку очаровали — говорит она сама:
```json
{"id": "witch_charmed", "speaker": "witch", "trigger": "status_applied", "about": "target",
 "conditions": {"status": "charm"}, "text": "Голова кружится..."}
```

Id статусов: `burn` горение, `weak` слабость, `vuln` уязвимость, `stun` оглушение, `charm` очарование,
`nazhim` нажим, `sticky_slime` липкая слизь, `wrap_slime` обволакивающая слизь, `empower` усиление,
`exposed` подставлена, `heat_body` жар тела, `swallowed` проглочена Фуфу.

Id карт — имена файлов в `resources/cards/` (`aki_kiss`, `witch_spark`, `lure`, `filler_strike` ...).

### Как часто вообще говорят

`settings.json` → `"triggers"`: у каждого триггера `chance` — шанс, что на событие вообще кто-то ответит,
`cooldown` — пауза триггера, `important: true` — игнорирует общую паузу. `global_cooldown` — пауза между любыми фразами.
Хотите болтливее — поднимите `chance`, тише — опустите.

---

## Между комнатами: `"camp"`

```json
{"id": "witch_warrior", "lines": [["warrior", "Не стой так близко."], ["witch", "Это ты стоишь близко!"]]}
```

- Разговор играет, только если **все**, кто говорит в `lines`, живы и в отряде.
- `when`: `"choice"` (по умолчанию) — на выборе комнаты; `"loot"` — в окне добычи сразу после боя; `"any"` — в обоих.
- Текст реплики тоже может быть списком вариантов: `["aki", ["Вариант 1", "Вариант 2"]]`.
- `chance`, `priority`, `weight`, `once`, `conditions` — как у боевых фраз. Один и тот же разговор два раза подряд не играет.

---

## Условия: `"conditions"`

Все перечисленные должны выполняться. Где написано «или список» — можно `"enemy": ["shlep", "blob"]` (любой из).

**В бою (что происходит сейчас):**
- `room`: `"battle"` / `"elite"` / `"boss"` / `"quest"` — тип комнаты
- `room_min`, `room_max` — номер комнаты (с 1)
- `turn_min`, `turn_max` — номер хода
- `card`, `card_kind` (`attack` / `support` / `ult`), `card_cost_min`, `card_cost_max`
- `status`, `target_side` (`ally` — на героине / `enemy` — на враге)
- `enemy` — враг события (убит, ранен, получил статус); `enemy_in_room` — такой враг есть в комнате
- `actor`, `target` — конкретные участники события (или список)
- `party_has` — все эти живы в отряде; `party_has_any` — хотя бы одна; `not_party_has` — никого из них

**Между комнатами:** `after_room` — какую комнату только что прошли; `offered` — среди предложенных есть
`shop` / `nurse` / `chest` / `statue` / `battle` / `elite`; `hero_low_hp: true` — у кого-то меньше 40% HP;
`hero_dead: true` — кто-то пал; а также `party_has`, `party_has_any`, `not_party_has`, `room_min`, `room_max`.

**Сюжет (как в диалогах):** `has_unit`, `has_any_unit`, `not_has_unit`, `trust` (`{"fufu": 5}`), `flag`, `not_flag`,
`quest_active`, `quest_completed`, `quest_not_started`, `party_level_min`, `rooms_cleared_min`, `has_item`, `not_has_item`,
`counter_min`, `main_hero`, `seen_dialogue` / `not_seen_dialogue` (например `"seen_dialogue": "nurse_first_meeting"` —
после встречи с Ноктрис).

Пример — Фуфу вспоминает Ноктрис, если доверие 3+, и только один раз:
```json
{"id": "fufu_about_nurse", "once": true, "priority": 5,
 "conditions": {"seen_dialogue": "nurse_first_meeting", "trust": {"fufu": 3}},
 "lines": [["fufu", "Эта медсестра так на тебя смотрела~"], ["warrior", "Не начинай."]]}
```
