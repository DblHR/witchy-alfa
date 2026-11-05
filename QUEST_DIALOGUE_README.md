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

