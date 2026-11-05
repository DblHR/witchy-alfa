extends Node
class_name UnitRoster

signal changed

const STARTING_UNIT_IDS: Array[String] = ["witch"]
## Тест: ведьма больше не обязательное «ядро» (CORE_LOCK=true вернёт старое поведение).
const CORE_LOCK := false

var unlocked_unit_ids: Array[String] = []
var discovered_boss_ids: Array[String] = []

## --- Отношения (у всех, кроме главных героев — CharacterData.is_protagonist) ---
const RELATIONSHIP_MAX := 10
## Тест: пока прокачки отношений нет, у всех героинь они сразу на максимуме.
const RELATIONSHIP_TEST_MAX := true
## id героини -> уровень отношений (0..RELATIONSHIP_MAX).
var relationship: Dictionary = {}

## --- Колоды ---
## id героини -> id карт, выбранных в колоду (экран Setup). Нет записи — первые карты по лимиту ранга.
var deck_selection: Dictionary = {}

func get_relationship(unit_id: String) -> int:
	if relationship.has(unit_id):
		return int(relationship[unit_id])
	return RELATIONSHIP_MAX if RELATIONSHIP_TEST_MAX else 0

func set_relationship(unit_id: String, value: int) -> void:
	relationship[unit_id] = clampi(value, 0, RELATIONSHIP_MAX)
	changed.emit()

func has_deck_selection(unit_id: String) -> bool:
	return deck_selection.has(unit_id)

func get_deck_selection(unit_id: String) -> Array[String]:
	var out: Array[String] = []
	for v in deck_selection.get(unit_id, []):
		out.append(String(v))
	return out

func set_deck_selection(unit_id: String, card_ids: Array[String]) -> void:
	deck_selection[unit_id] = card_ids.duplicate()
	changed.emit()

func _ready() -> void:
	reset_to_defaults()

func reset_to_defaults() -> void:
	unlocked_unit_ids = STARTING_UNIT_IDS.duplicate()
	discovered_boss_ids.clear()
	relationship.clear()
	deck_selection.clear()
	changed.emit()

func has_unit(unit_id: String) -> bool:
	return unit_id != "" and unlocked_unit_ids.has(unit_id)

func unlock_unit(unit_id: String) -> bool:
	if unit_id == "" or has_unit(unit_id):
		return false
	unlocked_unit_ids.append(unit_id)
	unlocked_unit_ids.sort()
	changed.emit()
	return true

func remove_unit(unit_id: String) -> bool:
	if unit_id == "" or (CORE_LOCK and unit_id == "witch") or unit_id == "base_slime":
		return false
	if not unlocked_unit_ids.has(unit_id):
		return false
	unlocked_unit_ids.erase(unit_id)
	discovered_boss_ids.erase(unit_id)
	changed.emit()
	return true

func unlock_boss_once(unit_id: String) -> bool:
	if unit_id == "":
		return false
	if discovered_boss_ids.has(unit_id):
		return false
	discovered_boss_ids.append(unit_id)
	return unlock_unit(unit_id)

func get_unlocked_unit_ids() -> Array[String]:
	var out := unlocked_unit_ids.duplicate()
	if CORE_LOCK and not out.has("witch"):
		out.push_front("witch")
	return out

func serialize_state() -> Dictionary:
	return {
		"unlocked_unit_ids": unlocked_unit_ids.duplicate(),
		"discovered_boss_ids": discovered_boss_ids.duplicate(),
		"relationship": relationship.duplicate(),
		"deck_selection": deck_selection.duplicate(true),
	}

func apply_state(data: Dictionary) -> void:
	unlocked_unit_ids.clear()
	for v in data.get("unlocked_unit_ids", STARTING_UNIT_IDS):
		var unit_id := String(v)
		if unit_id != "" and not unlocked_unit_ids.has(unit_id):
			unlocked_unit_ids.append(unit_id)
	if unlocked_unit_ids.is_empty():
		unlocked_unit_ids = STARTING_UNIT_IDS.duplicate()
	if CORE_LOCK and not unlocked_unit_ids.has("witch"):
		unlocked_unit_ids.push_front("witch")
	discovered_boss_ids.clear()
	for v in data.get("discovered_boss_ids", []):
		var boss_id := String(v)
		if boss_id != "" and not discovered_boss_ids.has(boss_id):
			discovered_boss_ids.append(boss_id)
	relationship.clear()
	var rel: Dictionary = data.get("relationship", {})
	for k in rel.keys():
		relationship[String(k)] = int(rel[k])
	deck_selection.clear()
	var decks: Dictionary = data.get("deck_selection", {})
	for k in decks.keys():
		var ids: Array[String] = []
		for v in decks[k]:
			ids.append(String(v))
		deck_selection[String(k)] = ids
	unlocked_unit_ids.sort()
	changed.emit()
