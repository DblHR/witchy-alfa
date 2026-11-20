extends Node
class_name FarmState

signal state_changed

enum PlantStage {
	EMPTY,
	SEED,
	SPROUT,
	FLOWER,
}

const SLOT_COUNT := 8
const DEFAULT_SEED_PRIORITY := ["slimeflower_seed", "witchflower_seed", "meatflower_seed", "vegetableflower_seed", "sweetflower_seed", "fruitflower_seed"]
const PLANT_BY_SEED := {
	"slimeflower_seed": "slimeflower",
	"witchflower_seed": "witchflower",
	"meatflower_seed": "meatflower",
	"vegetableflower_seed": "vegetableflower",
	"sweetflower_seed": "sweetflower",
	"fruitflower_seed": "fruitflower",
}

const HARVEST_BY_PLANT := {
	"slimeflower": "slimeflower",
	"witchflower": "witchflower",
	"meatflower": "meat_fruit",
	"vegetableflower": "vegetable_fruit",
	"sweetflower": "sweet_fruit",
	"fruitflower": "fruit_fruit",
}

## Горшки: сначала BASE_POTS, остальные (до SLOT_COUNT) покупаются у Рикки — счётчик StoryState_
## "farm_pots_bought". Цена следующего горшка — POT_PRICES.
const BASE_POTS := 2
const POTS_BOUGHT_COUNTER := "farm_pots_bought"
const POT_PRICES: Array[int] = [20, 30, 40, 60, 80, 100]

## Сколько горшков доступно (в старых сохранениях — не меньше, чем уже занято).
func unlocked_pots() -> int:
	var n := BASE_POTS + (StoryState_.get_counter(POTS_BOUGHT_COUNTER) if StoryState_ != null else 0)
	for i in range(slots.size() - 1, -1, -1):
		if int(slots[i].get("stage", PlantStage.EMPTY)) != PlantStage.EMPTY:
			n = maxi(n, i + 1)
			break
	return clampi(n, 0, SLOT_COUNT)

func pots_maxed() -> bool:
	return unlocked_pots() >= SLOT_COUNT

func next_pot_price() -> int:
	var bought := unlocked_pots() - BASE_POTS
	return POT_PRICES[clampi(bought, 0, POT_PRICES.size() - 1)]

func buy_pot() -> void:
	if StoryState_ != null and not pots_maxed():
		StoryState_.add_counter(POTS_BOUGHT_COUNTER, unlocked_pots() - BASE_POTS + 1 - StoryState_.get_counter(POTS_BOUGHT_COUNTER))
		state_changed.emit()

func is_pot_unlocked(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < unlocked_pots()

## Урожай с горшка: 1 всегда, 50% — 2, из них 20% — 3 (P(3)=20%, P(2)=30%, P(1)=50%).
const HARVEST_CHANCE_2 := 0.5
const HARVEST_CHANCE_3 := 0.2
## Шанс, что вместе с урожаем вернётся одно семечко того же растения.
const SEED_BACK_CHANCE := 0.2

var slots: Array[Dictionary] = []

func _ready() -> void:
	_reset_slots()

func _reset_slots() -> void:
	slots.clear()
	for _i in range(SLOT_COUNT):
		slots.append(_make_empty_slot())
	state_changed.emit()

func _make_empty_slot() -> Dictionary:
	return {
		"stage": PlantStage.EMPTY,
		"watered": false,
		"dry_days": 0,
		"seed_item_id": "",
		"plant_item_id": "",
	}

func get_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in slots:
		out.append(slot.duplicate(true))
	return out

func get_slot(slot_index: int) -> Dictionary:
	if not _is_valid_slot(slot_index):
		return _make_empty_slot()
	return slots[slot_index].duplicate(true)

func get_available_seed_ids() -> Array[String]:
	var out: Array[String] = []
	for seed_id in DEFAULT_SEED_PRIORITY:
		if not PLANT_BY_SEED.has(seed_id):
			continue
		if Inventory_ != null and Inventory_.has_item(seed_id):
			out.append(seed_id)
	return out

func get_harvest_item_id(slot_data: Dictionary) -> String:
	var plant_id := String(slot_data.get("plant_item_id", ""))
	return String(HARVEST_BY_PLANT.get(plant_id, plant_id))

func get_seed_texture_key(slot_data: Dictionary) -> String:
	return String(slot_data.get("seed_item_id", "slimeflower_seed"))

func get_plant_texture_key(slot_data: Dictionary) -> String:
	return String(slot_data.get("plant_item_id", "slimeflower"))

func get_stage_label(slot_data: Dictionary) -> String:
	var stage := int(slot_data.get("stage", PlantStage.EMPTY))
	match stage:
		PlantStage.SEED:
			return RunItems.get_item_name(String(slot_data.get("seed_item_id", "")))
		PlantStage.SPROUT, PlantStage.FLOWER:
			var harvest_id := get_harvest_item_id(slot_data)
			if harvest_id != "":
				return RunItems.get_item_name(harvest_id)
	return ""

func choose_seed_for_planting(slot_index: int = -1) -> String:
	var priority := DEFAULT_SEED_PRIORITY.duplicate()
	if slot_index >= 0 and slot_index % 2 == 1:
		priority.reverse()
	for seed_id in priority:
		if Inventory_ != null and Inventory_.has_item(seed_id):
			return seed_id
	return ""

func can_plant_seed(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index) or not is_pot_unlocked(slot_index):
		return false
	var slot := slots[slot_index]
	return int(slot.get("stage", PlantStage.EMPTY)) == PlantStage.EMPTY and choose_seed_for_planting(slot_index) != ""

func can_water_slot(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	var slot := slots[slot_index]
	var stage := int(slot.get("stage", PlantStage.EMPTY))
	return (stage == PlantStage.SEED or stage == PlantStage.SPROUT) and not bool(slot.get("watered", false))

func can_harvest_slot(slot_index: int) -> bool:
	if not _is_valid_slot(slot_index):
		return false
	var slot := slots[slot_index]
	return int(slot.get("stage", PlantStage.EMPTY)) == PlantStage.FLOWER

func can_interact(slot_index: int) -> bool:
	return can_plant_seed(slot_index) or can_water_slot(slot_index) or can_harvest_slot(slot_index)

func plant_seed(slot_index: int, seed_item_id: String = "") -> bool:
	if not _is_valid_slot(slot_index) or not is_pot_unlocked(slot_index):
		return false
	var chosen_seed := RunItems.normalize_item_id(seed_item_id)
	if chosen_seed == "":
		chosen_seed = choose_seed_for_planting(slot_index)
	if chosen_seed == "" or not PLANT_BY_SEED.has(chosen_seed):
		return false
	if int(slots[slot_index].get("stage", PlantStage.EMPTY)) != PlantStage.EMPTY:
		return false
	if not Inventory_.remove_item(chosen_seed, 1):
		return false

	var slot := slots[slot_index]
	slot["stage"] = PlantStage.SEED
	slot["watered"] = false
	slot["dry_days"] = 0
	slot["seed_item_id"] = chosen_seed
	slot["plant_item_id"] = String(PLANT_BY_SEED[chosen_seed])
	state_changed.emit()
	return true

func water(slot_index: int) -> bool:
	return water_slot(slot_index)

func water_slot(slot_index: int) -> bool:
	if not can_water_slot(slot_index):
		return false
	var slot := slots[slot_index]
	slot["watered"] = true
	slot["dry_days"] = 0
	state_changed.emit()
	return true

func reset_to_defaults() -> void:
	_reset_slots()

## Сколько собрать с горшка: {"item": id урожая, "count": 1..3, "seed": id семечка или ""}.
func roll_harvest(slot_data: Dictionary) -> Dictionary:
	var r := randf()
	var count := 3 if r < HARVEST_CHANCE_3 else (2 if r < HARVEST_CHANCE_2 else 1)
	var seed_id := String(slot_data.get("seed_item_id", ""))
	return {
		"item": get_harvest_item_id(slot_data),
		"count": count,
		"seed": seed_id if seed_id != "" and randf() < SEED_BACK_CHANCE else "",
	}

func harvest(slot_index: int) -> bool:
	return harvest_slot(slot_index)

func harvest_slot(slot_index: int) -> bool:
	if not can_harvest_slot(slot_index):
		return false
	slots[slot_index] = _make_empty_slot()
	state_changed.emit()
	return true

func advance_day() -> void:
	var changed := false
	for i in range(slots.size()):
		var slot := slots[i]
		var stage := int(slot.get("stage", PlantStage.EMPTY))
		if stage == PlantStage.EMPTY:
			continue
		var watered := bool(slot.get("watered", false))
		var dry_days := int(slot.get("dry_days", 0))
		if watered:
			dry_days = 0
			match stage:
				PlantStage.SEED:
					slot["stage"] = PlantStage.SPROUT
				PlantStage.SPROUT:
					slot["stage"] = PlantStage.FLOWER
				_:
					pass
		else:
			dry_days += 1
			if dry_days >= 2:
				slots[i] = _make_empty_slot()
				changed = true
				continue
		slot["dry_days"] = dry_days
		slot["watered"] = false
		changed = true
	if changed:
		state_changed.emit()

func serialize_state() -> Dictionary:
	return {
		"slots": get_slots(),
	}

func apply_state(data: Dictionary) -> void:
	var saved_slots = data.get("slots", [])
	if not (saved_slots is Array) or saved_slots.is_empty():
		return
	slots.clear()
	for slot_data in saved_slots:
		if slot_data is Dictionary:
			slots.append({
				"stage": int(slot_data.get("stage", PlantStage.EMPTY)),
				"watered": bool(slot_data.get("watered", false)),
				"dry_days": int(slot_data.get("dry_days", 0)),
				"seed_item_id": RunItems.normalize_item_id(String(slot_data.get("seed_item_id", ""))),
				"plant_item_id": RunItems.normalize_item_id(String(slot_data.get("plant_item_id", ""))),
			})
	while slots.size() < SLOT_COUNT:
		slots.append(_make_empty_slot())
	if slots.size() > SLOT_COUNT:
		slots.resize(SLOT_COUNT)
	state_changed.emit()

func _is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < slots.size()
