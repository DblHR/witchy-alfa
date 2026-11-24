extends Node
class_name UnitRoster

signal changed

const STARTING_UNIT_IDS: Array[String] = ["witch"]
## Тест: ведьма больше не обязательное «ядро» (CORE_LOCK=true вернёт старое поведение).
const CORE_LOCK := false

var unlocked_unit_ids: Array[String] = []
var discovered_boss_ids: Array[String] = []
## Копии пойманных героинь (повторная поимка приманкой): каждая копия даёт дубль случайной карты.
var copies: Dictionary = {}
## Дубли карт: id героини -> [id карт, у которых есть дубль]. Дубль — отдельная карта (ключ id#2):
## её можно взять в колоду вместе с оригиналом и улучшать отдельно.
var card_dupes: Dictionary = {}
## Улучшенные карты: id героини -> [ключи карт] (ключ = id карты, у дубля — id#2).
var card_upgrades: Dictionary = {}

func get_copies(unit_id: String) -> int:
	return int(copies.get(unit_id, 0))

## Новая копия героини. Возвращает id карты, получившей дубль ("" — у всех карт дубль уже есть).
func add_copy(unit_id: String) -> String:
	copies[unit_id] = get_copies(unit_id) + 1
	var got := ""
	var data: CharacterData = CharDB.get_by_id(unit_id) if CharDB != null else null
	if data != null:
		var have: Array = card_dupes.get(unit_id, [])
		var pool: Array[String] = []
		for d in CardLibrary.owned_defs(data):
			if not have.has(d.id):
				pool.append(d.id)
		if not pool.is_empty():
			got = pool[randi() % pool.size()]
			have.append(got)
			card_dupes[unit_id] = have
	changed.emit()
	return got

func has_dupe(unit_id: String, card_id: String) -> bool:
	return (card_dupes.get(unit_id, []) as Array).has(card_id)

## --- Улучшение карт: очко каждые CardBalance.UPGRADE_EVERY_LEVELS уровней отряда, у каждой героини свои ---
func upgrade_points_total() -> int:
	return CardBalance.upgrade_points_for_level(int(DungRun.party_level) if DungRun != null else 1)

func upgrade_points_left(unit_id: String) -> int:
	return maxi(0, upgrade_points_total() - (card_upgrades.get(unit_id, []) as Array).size())

func is_card_upgraded(unit_id: String, card_key: String) -> bool:
	return (card_upgrades.get(unit_id, []) as Array).has(card_key)

## --- Значки «!» про очки улучшения ---
## Инвентарь и вкладка «Персонажи»: значок, пока игрок не заглянул туда после получения новых очков
## (запоминаем, сколько очков всего было при последнем заходе — StoryState counters).
## Сами героини и кнопка «Все карты»: значок, пока у героини есть непотраченные очки.
const UPGRADE_SEEN_INVENTORY := "upgrade_seen_inventory"
const UPGRADE_SEEN_CHARACTERS := "upgrade_seen_characters"

func any_upgrade_points() -> bool:
	for id in unlocked_unit_ids:
		if upgrade_points_left(String(id)) > 0:
			return true
	return false

## Есть непросмотренные новые очки для места where (UPGRADE_SEEN_INVENTORY / _CHARACTERS).
func upgrade_news(where: String) -> bool:
	if StoryState_ == null or not any_upgrade_points():
		return false
	return upgrade_points_total() > StoryState_.get_counter(where)

## Игрок заглянул (в инвентарь / во вкладку персонажей): новые очки увидены.
func mark_upgrade_seen(where: String) -> void:
	if StoryState_ == null:
		return
	var total := upgrade_points_total()
	var seen := StoryState_.get_counter(where)
	if total > seen:
		StoryState_.add_counter(where, total - seen)

func upgrade_card(unit_id: String, card_key: String) -> bool:
	if upgrade_points_left(unit_id) <= 0 or is_card_upgraded(unit_id, card_key):
		return false
	var list: Array = card_upgrades.get(unit_id, [])
	list.append(card_key)
	card_upgrades[unit_id] = list
	changed.emit()
	return true

## Побеждён ли босс хотя бы раз (тогда же он выдаётся в отряд).
func boss_defeated(unit_id: String) -> bool:
	return discovered_boss_ids.has(unit_id)

## --- Отношения / доверие (у всех героинь, включая ведьмочку и воина) ---
## Доверие копится очками: +100 за каждый забег с героиней в отряде (CardBalance.TRUST_PER_RUN).
## Уровень отношений (0..10) считается из очков: 100-200-200-200-300-300-300-400-400-400
## (CardBalance.TRUST_STEPS, 28 забегов до 10).
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
	copies.clear()
	card_dupes.clear()
	card_upgrades.clear()
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
		"copies": copies.duplicate(),
		"trust_points": trust_points.duplicate(),
		"trust_scale": CardBalance.TRUST_SCALE,
		"deck_selection": deck_selection.duplicate(true),
		"card_dupes": card_dupes.duplicate(true),
		"card_upgrades": card_upgrades.duplicate(true),
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
	copies.clear()
	var cp: Dictionary = data.get("copies", {})
	for k in cp.keys():
		copies[String(k)] = int(cp[k])
	trust_points.clear()
	var pts: Dictionary = data.get("trust_points", {})
	# Сохранения до 0.60.92 считали доверие по 1 очку за забег — переводим в новые очки.
	var scale := CardBalance.TRUST_SCALE if not data.has("trust_scale") else 1
	for k in pts.keys():
		trust_points[String(k)] = maxi(0, int(pts[k]) * scale)
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
	card_dupes.clear()
	card_upgrades.clear()
	for pair in [["card_dupes", card_dupes], ["card_upgrades", card_upgrades]]:
		var src: Dictionary = data.get(String(pair[0]), {})
		for k in src.keys():
			var list: Array = []
			for v in src[k]:
				list.append(String(v))
			(pair[1] as Dictionary)[String(k)] = list
	# Старое сохранение: копии были, а дублей карт ещё не существовало — выдаём по дублю за копию.
	if not data.has("card_dupes"):
		for k in copies.keys():
			var n := int(copies[k])
			copies[k] = 0
			for _i in range(n):
				add_copy(String(k))
	unlocked_unit_ids.sort()
	changed.emit()
