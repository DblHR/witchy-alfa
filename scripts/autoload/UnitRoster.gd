extends Node
class_name UnitRoster

signal changed

const STARTING_UNIT_IDS: Array[String] = ["witch"]
## Тест: ведьма больше не обязательное «ядро» (CORE_LOCK=true вернёт старое поведение).
const CORE_LOCK := false

var unlocked_unit_ids: Array[String] = []
var discovered_boss_ids: Array[String] = []

## --- Отношения / доверие (у всех, кроме главных героев — CharacterData.is_protagonist) ---
## Доверие копится очками: +1 за каждый забег с героиней в отряде (CardBalance.TRUST_PER_RUN).
## Уровень отношений (0..10) считается из очков: 1-2-2-2-3-3-3-4-4-4 (28 забегов до 10).
const RELATIONSHIP_MAX := 10
## id героини -> очки доверия.
var trust_points: Dictionary = {}

## --- Колоды ---
## id героини -> id карт, выбранных в колоду (экран Setup). Нет записи — первые карты по лимиту ранга.
var deck_selection: Dictionary = {}

## Уровень отношений 0..RELATIONSHIP_MAX.
func get_relationship(unit_id: String) -> int:
	return mini(RELATIONSHIP_MAX, CardBalance.trust_level(get_trust(unit_id)))

## Задать уровень отношений (админка): очки ставятся ровно на начало уровня.
func set_relationship(unit_id: String, value: int) -> void:
	trust_points[unit_id] = CardBalance.trust_points_for_level(clampi(value, 0, RELATIONSHIP_MAX))
	changed.emit()

func get_trust(unit_id: String) -> int:
	return int(trust_points.get(unit_id, 0))

func add_trust(unit_id: String, amount: int) -> void:
	if unit_id == "" or amount <= 0:
		return
	var cap := CardBalance.trust_points_for_level(RELATIONSHIP_MAX)
	trust_points[unit_id] = mini(cap, get_trust(unit_id) + amount)
	changed.emit()

## Для досье: {level, points, into_level, need} — сколько очков набрано на текущем уровне и сколько нужно.
func trust_progress(unit_id: String) -> Dictionary:
	var pts := get_trust(unit_id)
	var lvl := get_relationship(unit_id)
	var base := CardBalance.trust_points_for_level(lvl)
	var need := 0 if lvl >= RELATIONSHIP_MAX else CardBalance.TRUST_STEPS[lvl]
	return {"level": lvl, "points": pts, "into_level": pts - base, "need": need}

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
	trust_points.clear()
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
		"trust_points": trust_points.duplicate(),
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
	trust_points.clear()
	var pts: Dictionary = data.get("trust_points", {})
	for k in pts.keys():
		trust_points[String(k)] = maxi(0, int(pts[k]))
	# Старое сохранение: был только уровень отношений — переводим в очки.
	if not data.has("trust_points"):
		var rel: Dictionary = data.get("relationship", {})
		for k in rel.keys():
			trust_points[String(k)] = CardBalance.trust_points_for_level(int(rel[k]))
	deck_selection.clear()
	var decks: Dictionary = data.get("deck_selection", {})
	for k in decks.keys():
		var ids: Array[String] = []
		for v in decks[k]:
			ids.append(String(v))
		deck_selection[String(k)] = ids
	unlocked_unit_ids.sort()
	changed.emit()
