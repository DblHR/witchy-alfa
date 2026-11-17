# Quest/dialogue MVP notes

## NPC placement

- Rabbit shopkeeper (`rabbit_shop`) belongs only to the hub shop scene (`scenes/Shop.gd`).
- Lamia (`lamia`) belongs only to dungeon `EventType.SHOP` rooms.
- Portraits are resolved through `AssetCatalog_`:
  - `rabbit_shop` -> `res://assets/pics/NPCs/bunny.png`
  - `lamia` -> `res://assets/pics/NPCs/shopkeeper.png`

## Dialogue files

Dialogues live in `res://data/dialogues/` and are loaded by `StoryDialogueDB_`.

Important current files:

- `data/dialogues/npc/lamia.json`
- `data/dialogues/npc/rabbit_shop.json`
- `data/dialogues/events/statues_and_chests.json`
- `data/dialogues/npc/nurse.json`
- `data/dialogues/quests/warrior_quest.json` — data placeholder for later; the room itself is disabled in MVP.

`EventPresentationDB.gd` no longer stores old text. It is an empty fallback for compatibility.

### Главный герой в диалогах: id `hero`

Игрок выбирает главного героя (Ведьмочка / Воин) после получения воина, потом — в «Настройках» меню паузы (ESC). Чтобы реплика шла от выбранного героя, вместо `witch` пишите `hero`:

```json
{"speaker": "hero", "emotion": "shy", "text": "Привет, Фуфу!", "characters": [{"id": "fufu"}, {"id": "hero"}]}
```

- `hero` подставляется и в `speaker`, и в `characters` — имя, портрет и эмоции берутся у настоящего персонажа (`witch` или `warrior`).
- `{hero}` в `text`, `speaker_name` и тексте кнопок `choices` заменяется на имя героя: `"text": "Ой, {hero}, это ты!"`.
- `{hero_id}` в пути `cg` заменяется на id героя: `"cg": "res://assets/characters/fufu/love/fufu_hug_{hero_id}.png"` → `fufu_hug_witch.png` / `fufu_hug_warrior.png` (нужны обе картинки).
- Условие `"conditions": {"main_hero": "warrior"}` — диалог только для выбранного воина (или `"witch"`).
- Пока воина нет в отряде, `hero` — всегда ведьмочка. Где герой должен быть именно ведьмочкой или оба сразу — пишите `witch`/`warrior` как раньше.

## Lamia headphones quest

Current flow:

1. Enter a dungeon shop room.
2. The shop is always Lamia.
3. `lamia_headphones_start` has a 45% chance to appear while the quest is not started.
4. After the start dialogue, `StoryState_.start_quest("lamia_headphones")` runs.
5. Chests can drop `warm_headphones` only while `lamia_headphones` is active and the player does not already have the item.
6. Return to Lamia with `warm_headphones`.
7. `lamia_headphones_finish` removes the item and completes the quest.

## Rabbit warrior quest placeholder

Current flow:

1. Enter the hub shop.
2. Rabbit dialogue plays through `scenes/Shop.gd`.
3. If party level is at least 3 and `find_warrior` was not started, `rabbit_shop_warrior_hint` starts the quest.
4. The warrior quest-room is intentionally disabled for MVP in `DungeonRun._try_make_quest_room()`.

## Debug panel

Press `F9`.

Useful buttons:

- Force dungeon Lamia shop
- Force chest room
- Start/Give/Complete/Reset Lamia headphones quest
- Start/Reset Find Warrior quest
- Set party level to 3
- Reload JSON dialogues


### Типы диалогов и когда они играют

- `event` / `flag` — вступление ивент-комнаты и лавки Рикки: сначала `event` (по priority), если нет — `flag` (по weight).
- `hub_talk` — клик по героине дома. Выше priority — главнее; `once` — один раз.
- `after_use` — у NPC ивент-комнаты после услуги (у Ноктрис — после закрытия картинки лечения/микстуры).
- `on_leave` — у NPC ивент-комнаты по кнопке «Идти дальше», перед выходом.
- `boss_victory` — сразу после победы над боссом, до экрана победы (например `fufu_claim`). Играется один доступный, с наибольшим priority.
- `after_run` — дома сразу после конца забега (победа или поражение). Играется один доступный, с наибольшим priority. NPC указывать не обязательно.

### Новые условия
- `"has_any_unit": ["aki", "luisa", "fufu"]` — в отряде есть хотя бы одна из них.
- `"trust": {"fufu": 3}` — уровень доверия героини не ниже 3 (как в галерее).

### Затемнение
- `"fade_from_black": true` в реплике — экран начинается чёрным и плавно просветляется (удобно вместе с `cg`).

### Значок «!»
- На кнопке лавки Рикки и над героиней дома значок появляется сам, если есть ещё не виденный диалог с `"once": true`, условия которого уже выполнены (у Рикки — тип `event`, у героинь дома — `hub_talk`). Диалоги с `"chance"` значок не зажигают.

### Уведомление «Получено: ...» в диалоге
- `"give_item": "gift"` в реплике (+ `"give_amount": 2`, если нужно несколько): после этой реплики предмет выдаётся, а по центру экрана появляется окно «Получено: <название>» с картинкой предмета. Фон размыт, клик закрывает окно, диалог идёт дальше. Id предметов — как в инвентаре (RunItems).
- `"notice": {"title": "Новое поручение", "text": "Найти тёплые наушники", "icon": "res://assets/...png"}` — такое же окно со своим текстом и картинкой (icon можно не указывать). Ничего не выдаёт — для квестов и прочих сообщений.
- Если игрок жмёт «Пропустить», предметы всё равно выдаются, окна показываются подряд.
- Предмет, выданный через `give_item`, не нужно дублировать в `on_finish` → `add_item`.

### Значок «!» — уточнение
- Значок зажигают только диалоги, которые что-то дают: есть `on_finish` (предмет, квест, флаг) или реплика с `give_item` / `notice`. Сцены героинь дома (`hub_talk` + `once`) — всегда.
- Можно задать вручную: `"notify": true` или `"notify": false` у диалога.

### Дежурные фразы NPC в ивент-комнатах (пузыри)
- У Сессилии, Ноктрис и Рикки (лавка дома) дежурная фраза при входе показывается пузырём рядом с NPC, а не окном диалога. Клик по NPC — ещё одна случайная дежурная фраза. Место пузыря — `NpcBubbles.BUBBLE_POS` (scripts/ui/NpcBubbles.gd).
- Пока открыто окно диалога (VN), картинки NPC на фоне (и гуляющие по дому героини) прячутся — на экране только портреты из диалога (scripts/ui/VnSpriteHider.gd).
- Дежурная = диалог типа `event` / `flag` без `"once": true`, без `on_finish`, без выбора / `give_item` / `notice` / `cg`, и все реплики — самого NPC.
- Новый тип `"bark"` — фразы только для пузырей (по клику), в окно VN никогда не попадают. Пример: `{"id": "lamia_bark_01", "type": "bark", "npc": "lamia", "lines": [{"speaker": "lamia", "text": "Хвост не трогать! ...Ну ладно, чуть-чуть."}]}`
- Всё важное (первая встреча, квесты, разовые сцены) по-прежнему показывается окном VN.

### Имя от игрока (ask_name)
- Поле реплики `"ask_name": {"key": "rikka_flower", "title": "Как назовём цветок?", "default": "Игорь"}` — после этой реплики появляется окно ввода имени; пустое поле — `default`. Имя сохраняется в `StoryState_.custom_names[key]`.
- В тексте любой реплики `{name:rikka_flower}` заменяется на это имя (пока имени нет — «цветочек»).
