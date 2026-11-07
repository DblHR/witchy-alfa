extends Node
class_name DungeonRun

signal changed

const GROUND_SHOP_SLOT_COUNT := 6
const EVENT_SHOP_SLOT_COUNT := 4
const LAMIA_SHOP_CHANCE := 0.35
const FIND_WARRIOR_QUEST_ROOM_CHANCE := 0.35

var rooms: Array[RoomParams] = []
var room_index: int = 0
const PARTY_SIZE := 3
var party_ids: Array[String] = ["witch", "", ""]
var leader_id: String = "witch"
var party_level: int = 1
var party_slot_count: int = PARTY_SIZE
var party_state: Array = []
var rng := RandomNumberGenerator.new()
var pending_choices: Array[RoomParams] = []
var pending_next_index: int = -1

# session meta
var gold: int = 0
var xp: int = 0
## Эстус (карточный бой): в начале каждого боя в колоду кладётся estus_stacks карт эстуса,
## каждая лечит estus_power процентов макс. HP. Обе величины — прокачка, не сбрасываются.
const ESTUS_BASE_STACKS := 2
const ESTUS_BASE_POWER := CardBalance.ESTUS_BASE_PERCENT
var estus_stacks: int = ESTUS_BASE_STACKS
var estus_power: int = ESTUS_BASE_POWER

var custom_potion_charges: int = 0
var selected_potion_id: String = "heal_potion"
## Карточный забег: два слота зелий, выбираются перед забегом (id зелий: heal_potion и т.п.).
## Каждый слот — одно зелье на забег; выпитое списывается из инвентаря.
const POTION_SLOTS := 2
var selected_potion_ids: Array[String] = ["", ""]
## Брать ли в забег приманку (одна на забег; тратится, когда разыграна).
const LURE_ITEM := "gift"
var take_lure := false
## Открытые рецепты еды (зелья известны сразу — AlchemyDB.STARTER_RECIPES).
var known_recipes: Array[String] = []
var selected_artifact_id: String = ""
var selected_food_id: String = ""
var owned_artifacts: Array[String] = ["mace_staff_common", "dango_staff_common"]
var unlocked_potion_ids: Array[String] = ["heal_potion", "energy_potion", "battle_potion"]
var white_statue_rooms: int = 0
var black_statue_rooms: int = 0
var relics: Array[String] = []
var rooms_cleared: int = 0
var battles_started: int = 0
var guardian_cookie_used: bool = false
var ground_shop_item_ids: Array[String] = []

func _ready() -> void:
	if Inventory_ != null and not Inventory_.changed.is_connected(_on_inventory_changed):
		Inventory_.changed.connect(_on_inventory_changed)
	sync_legacy_owned_artifacts_to_inventory()
	_validate_loadout()
	refresh_selected_potion_charges()

func _on_inventory_changed() -> void:
	sync_legacy_owned_artifacts_to_inventory()
	_validate_loadout()
	refresh_selected_potion_charges()
	emit_changed()

func is_current_room_battle() -> bool:
	var r := get_current_room()
	return r != null and (r.room_type == RoomParams.RoomType.BATTLE or r.room_type == RoomParams.RoomType.BOSS)

func start_new_run(run_seed: int = -1) -> void:
	sync_legacy_owned_artifacts_to_inventory()
	_validate_loadout()
	if run_seed == -1:
		rng.randomize()
	else:
		rng.seed = run_seed

	rooms.clear()
	room_index = 0
	var room_count := rng.randi_range(8, 10)
	for i in range(room_count):
		rooms.append(_generate_room(i, room_count))
	party_state.clear()
	_reset_session_meta()
	emit_changed()

func reset_to_defaults() -> void:
	rooms.clear()
	room_index = 0
	party_ids = ["witch", "", ""]
	leader_id = "witch"
	party_level = 1
	party_slot_count = PARTY_SIZE
	party_state.clear()
	pending_choices.clear()
	pending_next_index = -1

	gold = 0
	xp = 0
	estus_stacks = ESTUS_BASE_STACKS
	estus_power = ESTUS_BASE_POWER
	custom_potion_charges = 0
	selected_potion_id = "heal_potion"
	selected_potion_ids = ["", ""]
	known_recipes.clear()
	take_lure = false
	_artifacts_migrated = false
	selected_artifact_id = ""
	selected_food_id = ""
	owned_artifacts = ["mace_staff_common", "dango_staff_common"]
	unlocked_potion_ids = ["heal_potion", "energy_potion", "battle_potion"]
	white_statue_rooms = 0
	black_statue_rooms = 0
	relics.clear()
	rooms_cleared = 0
	battles_started = 0
	guardian_cookie_used = false
	ground_shop_item_ids.clear()

	rng.randomize()
	sync_legacy_owned_artifacts_to_inventory()
	refresh_ground_shop(true)
	emit_changed()

## Начало карточного забега: в relics кладётся выбранный посох и съедается одна выбранная еда
## (её эффект действует весь забег), сбрасывается «Стейк». Зовёт CardBattle при запуске.
func begin_card_run() -> void:
	_validate_loadout()
	_reset_session_meta()
	emit_changed()

func _reset_session_meta() -> void:
	refresh_selected_potion_charges()
	white_statue_rooms = 0
	black_statue_rooms = 0
	relics.clear()
	guardian_cookie_used = false
	if selected_artifact_id != "" and Inventory_ != null and Inventory_.has_item(selected_artifact_id):
		add_item(selected_artifact_id)
	if selected_food_id != "" and Inventory_ != null and Inventory_.remove_item(selected_food_id, 1):
		add_item(selected_food_id)
	rooms_cleared = 0
	battles_started = 0

func _validate_loadout() -> void:
	var available_potions := get_available_potion_ids()
	if available_potions.is_empty():
		selected_potion_id = ""
	elif not available_potions.has(selected_potion_id):
		selected_potion_id = available_potions[0]
	_validate_potion_slots()
	if take_lure and (Inventory_ == null or not Inventory_.has_item(LURE_ITEM)):
		take_lure = false

	if selected_artifact_id != "" and (Inventory_ == null or not Inventory_.has_item(selected_artifact_id)):
		selected_artifact_id = ""

	var available_foods := get_available_food_ids()
	if available_foods.is_empty():
		selected_food_id = ""
	elif selected_food_id != "" and not available_foods.has(selected_food_id):
		selected_food_id = available_foods[0]

## Слоты зелий: в слоте только зелье, которое есть в инвентаре (два одинаковых — если их ≥2).
func _validate_potion_slots() -> void:
	while selected_potion_ids.size() < POTION_SLOTS:
		selected_potion_ids.append("")
	var used: Dictionary = {}
	for i in range(POTION_SLOTS):
		var pid := selected_potion_ids[i]
		if pid == "":
			continue
		var item_id := RunItems.get_potion_item_id(pid)
		var have := Inventory_.get_item_count(item_id) if Inventory_ != null and item_id != "" else 0
		if int(used.get(pid, 0)) >= have:
			selected_potion_ids[i] = ""
			continue
		used[pid] = int(used.get(pid, 0)) + 1

func set_potion_slot(slot: int, potion_id: String) -> void:
	if slot < 0 or slot >= POTION_SLOTS:
		return
	selected_potion_ids[slot] = potion_id
	_validate_potion_slots()
	emit_changed()

## Выпить зелье из слота: списать предмет из инвентаря. Возвращает id зелья («» — не вышло).
func drink_potion(potion_id: String) -> bool:
	var item_id := RunItems.get_potion_item_id(potion_id)
	if item_id == "" or Inventory_ == null or not Inventory_.remove_item(item_id, 1):
		return false
	emit_changed()
	return true

func refresh_selected_potion_charges() -> void:
	var item_id := RunItems.get_potion_item_id(selected_potion_id)
	if item_id != "" and Inventory_ != null:
		custom_potion_charges = Inventory_.get_item_count(item_id)
	else:
		custom_potion_charges = RunItems.get_potion_charges(selected_potion_id)

func consume_selected_potion_charge() -> bool:
	if custom_potion_charges <= 0:
		return false
	var item_id := RunItems.get_potion_item_id(selected_potion_id)
	if item_id != "":
		if Inventory_ == null or not Inventory_.remove_item(item_id, 1):
			refresh_selected_potion_charges()
			return false
	custom_potion_charges = max(custom_potion_charges - 1, 0)
	emit_changed()
	return true

func refund_selected_potion_charge() -> void:
	var item_id := RunItems.get_potion_item_id(selected_potion_id)
	if item_id != "" and Inventory_ != null:
		Inventory_.add_item(item_id, 1)
	refresh_selected_potion_charges()
	emit_changed()

func ensure_ground_shop_stock() -> void:
	if ground_shop_item_ids.is_empty():
		refresh_ground_shop(true)

## Лавка Рикки (дом): кварц и семена всегда, остальное — случайно из еды, обычных посохов,
## неоткрытых рецептов и ингредиентов для еды. Обновляется после каждого забега.
const RIKKA_SEEDS: Array[String] = ["slimeflower_seed", "witchflower_seed", "meatflower_seed", "vegetableflower_seed", "sweetflower_seed", "fruitflower_seed"]
const RIKKA_FOOD_INGREDIENTS: Array[String] = ["meat_fruit", "vegetable_fruit", "sweet_fruit", "fruit_fruit"]

func refresh_ground_shop(force_emit: bool = false) -> void:
	sync_legacy_owned_artifacts_to_inventory()
	ground_shop_item_ids.clear()
	ground_shop_item_ids.append("quartz")
	ground_shop_item_ids.append(RIKKA_SEEDS[rng.randi_range(0, RIKKA_SEEDS.size() - 1)])
	ground_shop_item_ids.append(LURE_ITEM)
	var pools: Array = [RunItems.food_ids(), _common_staffs_not_owned(), AlchemyDB.unknown_recipe_items(), RIKKA_FOOD_INGREDIENTS]
	var guard := 0
	while ground_shop_item_ids.size() < GROUND_SHOP_SLOT_COUNT and guard < 50:
		guard += 1
		var pool: Array = pools[rng.randi_range(0, pools.size() - 1)]
		if pool.is_empty():
			continue
		var id := String(pool[rng.randi_range(0, pool.size() - 1)])
		if ground_shop_item_ids.has(id):
			continue
		ground_shop_item_ids.append(id)
	while ground_shop_item_ids.size() < GROUND_SHOP_SLOT_COUNT:
		ground_shop_item_ids.append("")
	if force_emit:
		emit_changed()

## Обычные посохи (посохи складываются в стопки, поэтому уже имеющиеся тоже продаются).
func _common_staffs_not_owned() -> Array[String]:
	var out: Array[String] = []
	for id in RunItems.artifact_ids():
		if RunItems.get_item_rarity(id) == 0:
			out.append(id)
	return out

## Лавка Сессилии (ламия, ивент в забеге): 4 слота, дороже Рикки, но наборами или редкостью.
## Возвращает [{id, count, price}]. Посох — обычный или (LAMIA_RARE_CHANCE) редкий.
const LAMIA_PRICE_MULT := 1.3
const LAMIA_RARE_CHANCE := 0.2
const LAMIA_FLOOR_LOOT: Array[String] = ["slime_goop"]

func roll_lamia_stock(r: RandomNumberGenerator) -> Array:
	var offers: Array = []
	var kinds := ["quartz", "food", "seeds", "potion", "loot", "staff", "lure"]
	for i in range(kinds.size() - 1, 0, -1):
		var j := r.randi_range(0, i)
		var tmp: String = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	for kind in kinds:
		if offers.size() >= EVENT_SHOP_SLOT_COUNT:
			break
		var id := ""
		var count := 1
		match String(kind):
			"quartz":
				id = "quartz"; count = r.randi_range(4, 6)
			"food":
				var foods := RunItems.food_ids()
				id = foods[r.randi_range(0, foods.size() - 1)]; count = r.randi_range(1, 2)
			"seeds":
				id = RIKKA_SEEDS[r.randi_range(0, RIKKA_SEEDS.size() - 1)]; count = 3
			"potion":
				var potions := ["slime_potion", "energy_tonic", "rage_phial"]
				id = potions[r.randi_range(0, potions.size() - 1)]
			"loot":
				id = LAMIA_FLOOR_LOOT[r.randi_range(0, LAMIA_FLOOR_LOOT.size() - 1)]; count = r.randi_range(4, 6)
			"lure":
				id = LURE_ITEM
			"staff":
				var rare := r.randf() < LAMIA_RARE_CHANCE
				var pool: Array[String] = []
				for sid in RunItems.artifact_ids():
					if RunItems.get_item_rarity(sid) == (1 if rare else 0):
						pool.append(sid)
				if pool.is_empty():
					continue
				id = pool[r.randi_range(0, pool.size() - 1)]
		if id == "":
			continue
		offers.append({"id": id, "count": count, "price": roundi(float(RunItems.get_item_price(id) * count) * LAMIA_PRICE_MULT)})
	return offers

func buy_ground_shop_item(slot_idx: int) -> String:
	if slot_idx < 0 or slot_idx >= ground_shop_item_ids.size():
		return ""
	var item_id := ground_shop_item_ids[slot_idx]
	if item_id == "":
		return ""
	var price := RunItems.get_item_price(item_id)
	if not spend_gold(price):
		return ""
	if RunItems.is_unique_item(item_id) and Inventory_ != null and Inventory_.has_item(item_id):
		gain_gold(price)
		return ""
	if Inventory_ == null or not Inventory_.add_item(item_id, 1):
		gain_gold(price)
		return ""
	ground_shop_item_ids[slot_idx] = ""
	emit_changed()
	return item_id

func on_run_finished_refresh_shops() -> void:
	refresh_ground_shop(true)

## Опыт до следующего уровня (CardBalance: ~28 забегов на 10 уровней, как доверие).
func xp_to_next_level(level: int = party_level) -> int:
	return CardBalance.xp_to_next_level(level)

## Добавить опыт. floor_no — этаж, на котором он получен: выше 10 × этаж уровень не растёт,
## лишний опыт сгорает. Возвращает {gained, levels, level, capped}.
func gain_xp(amount: int, floor_no: int = CardBalance.FLOOR_COUNT) -> Dictionary:
	var cap := CardBalance.level_cap(floor_no)
	var levels := 0
	xp += max(amount, 0)
	while party_level < cap and xp >= xp_to_next_level():
		xp -= xp_to_next_level()
		party_level += 1
		levels += 1
	var capped := party_level >= cap
	if capped:
		xp = 0
	emit_changed()
	return {"gained": max(amount, 0), "levels": levels, "level": party_level, "capped": capped}

## Итог забега: опыт, набранный в нём (начисляется только при победе или поражении).
func apply_run_xp(amount: int, floor_no: int) -> Dictionary:
	return gain_xp(amount, floor_no)

func gain_gold(amount: int) -> void:
	gold += max(amount, 0)
	emit_changed()

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	emit_changed()
	return true

func has_item(item_id: String) -> bool:
	return relics.has(RunItems.normalize_item_id(item_id))

func add_item(item_id: String) -> bool:
	var normalized := RunItems.normalize_item_id(item_id)
	if normalized == "" or has_item(normalized):
		return false
	relics.append(normalized)
	emit_changed()
	return true

func add_owned_artifact(item_id: String) -> void:
	item_id = RunItems.normalize_item_id(item_id)
	if item_id == "" or not RunItems.is_artifact(item_id) or Inventory_ == null:
		return
	Inventory_.add_item(item_id, 1)
	sync_legacy_owned_artifacts_to_inventory()
	emit_changed()

## Посохи теперь складываются в стопки и тратятся в алхимии, поэтому старый список owned_artifacts
## переносится в инвентарь только один раз (новая игра / загрузка), дальше он лишь зеркалит инвентарь.
var _artifacts_migrated := false

func sync_legacy_owned_artifacts_to_inventory() -> void:
	if Inventory_ == null:
		return
	if not _artifacts_migrated:
		_artifacts_migrated = true
		for item_id in owned_artifacts:
			item_id = RunItems.normalize_item_id(item_id)
			if item_id != "" and RunItems.is_artifact(item_id) and not Inventory_.has_item(item_id):
				Inventory_.add_item(item_id, 1)
	owned_artifacts = _get_inventory_artifact_ids()

func _get_inventory_artifact_ids() -> Array[String]:
	var out: Array[String] = []
	if Inventory_ == null:
		return out
	for item_id in Inventory_.get_items().keys():
		var id := String(item_id)
		if RunItems.is_artifact(id) and Inventory_.get_item_count(id) > 0:
			out.append(id)
	out.sort()
	return out

func get_owned_artifacts() -> Array[String]:
	return get_selectable_artifact_ids()

func get_owned_unique_artifacts() -> Array[String]:
	sync_legacy_owned_artifacts_to_inventory()
	return _get_inventory_artifact_ids()

func get_selectable_artifact_ids() -> Array[String]:
	var out: Array[String] = []
	if Inventory_ == null:
		return out
	for item_id in Inventory_.get_items().keys():
		var id := String(item_id)
		if RunItems.is_loadout_artifact(id) and Inventory_.get_item_count(id) > 0:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return RunItems.get_item_name(a) < RunItems.get_item_name(b)
	)
	return out

func get_available_potion_ids() -> Array[String]:
	var out: Array[String] = []
	if Inventory_ == null:
		return out
	for potion_id in unlocked_potion_ids:
		var item_id := RunItems.get_potion_item_id(String(potion_id))
		if item_id != "" and Inventory_.get_item_count(item_id) > 0:
			out.append(String(potion_id))
	out.sort()
	return out

func get_available_food_ids() -> Array[String]:
	var out: Array[String] = []
	if Inventory_ == null:
		return out
	for item_id in Inventory_.get_items().keys():
		var id := RunItems.normalize_item_id(String(item_id))
		if RunItems.is_loadout_food(id) and Inventory_.get_item_count(id) > 0:
			out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return RunItems.get_item_name(a) < RunItems.get_item_name(b)
	)
	return out

func get_unlocked_potions() -> Array[String]:
	return get_available_potion_ids()

func get_relic_names() -> Array[String]:
	var out: Array[String] = []
	for id in relics:
		out.append(RunItems.get_item_name(id))
	return out

func prepare_next_choices() -> void:
	pending_choices.clear()
	pending_next_index = -1
	var next_i := room_index + 1
	if rooms.is_empty() or next_i >= rooms.size():
		return
	pending_next_index = next_i
	var room_count := rooms.size()
	if next_i == room_count - 1:
		pending_choices.append(_generate_room(next_i, room_count))
		return
	if next_i == room_count - 2:
		pending_choices.append(_generate_room(next_i, room_count))
		return
	var option_count := rng.randi_range(2, 3)
	for _k in range(option_count):
		pending_choices.append(_generate_room(next_i, room_count))

func get_pending_choices() -> Array[RoomParams]:
	return pending_choices

func has_pending_choices() -> bool:
	return pending_next_index != -1 and not pending_choices.is_empty()

func choose_pending_choice(choice_index: int) -> void:
	if not has_pending_choices():
		return
	choice_index = clamp(choice_index, 0, pending_choices.size() - 1)
	rooms[pending_next_index] = pending_choices[choice_index]
	room_index = pending_next_index
	pending_choices.clear()
	pending_next_index = -1
	emit_changed()

func save_party_state(units: Array[Unit]) -> void:
	party_state.clear()
	party_state.resize(4)
	party_state.fill(null)
	for i in range(min(4, units.size())):
		var u := units[i]
		if u == null:
			continue
		party_state[i] = {"hp": u.hp, "energy": u.energy, "dead": u.is_dead}
	emit_changed()

func apply_party_state(units: Array[Unit]) -> void:
	if party_state.is_empty():
		return
	for i in range(min(units.size(), party_state.size())):
		var s = party_state[i]
		if s == null:
			continue
		var u: Unit = units[i]
		if u == null:
			continue
		u.hp = int(s["hp"])
		u.energy = int(s["energy"])
		u.is_dead = bool(s["dead"])

func serialize_state() -> Dictionary:
	return {
		"party_ids": party_ids.duplicate(),
		"leader_id": leader_id,
		"party_level": party_level,
		"party_slot_count": party_slot_count,
		"party_state": party_state.duplicate(true),
		"gold": gold,
		"xp": xp,
		"estus_stacks": estus_stacks,
		"estus_power_pct": estus_power,
		"custom_potion_charges": custom_potion_charges,
		"selected_potion_id": selected_potion_id,
		"selected_potion_ids": selected_potion_ids.duplicate(),
		"known_recipes": known_recipes.duplicate(),
		"take_lure": take_lure,
		"selected_artifact_id": selected_artifact_id,
		"selected_food_id": selected_food_id,
		"owned_artifacts": owned_artifacts.duplicate(),
		"unlocked_potion_ids": unlocked_potion_ids.duplicate(),
		"white_statue_rooms": white_statue_rooms,
		"black_statue_rooms": black_statue_rooms,
		"relics": relics.duplicate(),
		"rooms_cleared": rooms_cleared,
		"battles_started": battles_started,
		"guardian_cookie_used": guardian_cookie_used,
		"ground_shop_item_ids": ground_shop_item_ids.duplicate(),
	}

func apply_state(data: Dictionary) -> void:
	if data.is_empty():
		return

	var loaded_party_ids: Array = data.get("party_ids", party_ids)
	party_ids.clear()
	for v in loaded_party_ids:
		party_ids.append(String(v))

	leader_id = String(data.get("leader_id", leader_id))
	party_level = int(data.get("party_level", party_level))
	party_slot_count = PARTY_SIZE
	while party_ids.size() < PARTY_SIZE:
		party_ids.append("")
	while party_ids.size() > PARTY_SIZE:
		party_ids.pop_back()
	party_state = Array(data.get("party_state", [])).duplicate(true)
	gold = int(data.get("gold", gold))
	xp = int(data.get("xp", xp))
	# Старые сохранения хранили заряды эстуса автобаттлера (estus_charges) — они больше не значат ничего.
	estus_stacks = maxi(0, int(data.get("estus_stacks", estus_stacks)))
	# Старое сохранение хранило лечение числом («estus_power») — теперь это процент, берём новое поле.
	estus_power = maxi(0, int(data.get("estus_power_pct", ESTUS_BASE_POWER)))
	custom_potion_charges = int(data.get("custom_potion_charges", custom_potion_charges))
	selected_potion_id = String(data.get("selected_potion_id", selected_potion_id))
	selected_potion_ids.clear()
	for v in Array(data.get("selected_potion_ids", [selected_potion_id, ""])):
		selected_potion_ids.append(String(v))
	take_lure = bool(data.get("take_lure", false))
	known_recipes.clear()
	for v in Array(data.get("known_recipes", [])):
		known_recipes.append(String(v))
	selected_artifact_id = RunItems.normalize_item_id(String(data.get("selected_artifact_id", selected_artifact_id)))
	selected_food_id = RunItems.normalize_item_id(String(data.get("selected_food_id", selected_food_id)))

	_artifacts_migrated = false
	var loaded_owned_artifacts: Array = data.get("owned_artifacts", owned_artifacts)
	owned_artifacts = RunItems.normalize_item_array(loaded_owned_artifacts)

	var loaded_unlocked_potion_ids: Array = data.get("unlocked_potion_ids", unlocked_potion_ids)
	unlocked_potion_ids.clear()
	for v in loaded_unlocked_potion_ids:
		unlocked_potion_ids.append(String(v))

	white_statue_rooms = int(data.get("white_statue_rooms", white_statue_rooms))
	black_statue_rooms = int(data.get("black_statue_rooms", black_statue_rooms))

	var loaded_relics: Array = data.get("relics", relics)
	relics = RunItems.normalize_item_array(loaded_relics)

	rooms_cleared = int(data.get("rooms_cleared", rooms_cleared))
	battles_started = int(data.get("battles_started", battles_started))
	guardian_cookie_used = bool(data.get("guardian_cookie_used", guardian_cookie_used))
	var loaded_ground_shop: Array = data.get("ground_shop_item_ids", [])
	ground_shop_item_ids.clear()
	for v in loaded_ground_shop:
		ground_shop_item_ids.append(RunItems.normalize_item_id(String(v)))
	sync_legacy_owned_artifacts_to_inventory()
	_validate_loadout()
	ensure_ground_shop_stock()
	refresh_selected_potion_charges()
	emit_changed()

func _generate_room(i: int, room_count: int) -> RoomParams:
	var r := RoomParams.new()
	r.index = i
	if i == 0:
		r.room_type = RoomParams.RoomType.BATTLE
		r.enemy_count = 1
		return r
	if i == room_count - 1:
		r.room_type = RoomParams.RoomType.BOSS
		r.is_boss = true
		r.boss_id = "fufu"
		r.enemy_count = 1
		r.hp_bonus = 720
		return r
	if i == room_count - 2:
		r.room_type = RoomParams.RoomType.EVENT
		r.event_type = RoomParams.EventType.SHOP if rng.randf() < 0.5 else RoomParams.EventType.NURSE
		_finalize_event_room(r)
		return r
	if _try_make_quest_room(r):
		return r
	var roll := rng.randf()
	if roll < 0.70:
		r.room_type = RoomParams.RoomType.BATTLE
	else:
		r.room_type = RoomParams.RoomType.EVENT
		var e_roll := rng.randf()
		if e_roll < 0.25:
			r.event_type = RoomParams.EventType.CHEST
		elif e_roll < 0.50:
			r.event_type = RoomParams.EventType.STATUE
		elif e_roll < 0.75:
			r.event_type = RoomParams.EventType.SHOP
		else:
			r.event_type = RoomParams.EventType.NURSE
		_finalize_event_room(r)
		return r
	var depth := i
	r.enemy_count = clamp(1 + int(floor(depth / 3.0)), 1, 4)
	r.hp_bonus = int(round(pow(float(depth), 1.35) * 27.0))
	r.strong_chance = clamp(0.10 + float(depth) * 0.06, 0.0, 0.65)
	r.damage_bonus = 0
	return r

func _try_make_quest_room(room: RoomParams) -> bool:
	if StoryState_ != null and StoryState_.is_quest_active("find_warrior") and not StoryState_.has_flag("find_warrior_room_done"):
		if rng.randf() < FIND_WARRIOR_QUEST_ROOM_CHANCE:
			room.room_type = RoomParams.RoomType.EVENT
			room.event_type = RoomParams.EventType.QUEST
			room.quest_id = "find_warrior"
			return true
	return false

func _pick_shop_npc_id() -> String:
	# Dungeon shops are always run by Lamia. Rabbit belongs only to the hub shop.
	return "lamia"

func _finalize_event_room(room: RoomParams) -> void:
	match room.event_type:
		RoomParams.EventType.STATUE:
			room.statue_variant = RoomParams.StatueVariant.WHITE if rng.randf() < 0.5 else RoomParams.StatueVariant.BLACK
		RoomParams.EventType.SHOP:
			if room.event_npc_id == "":
				room.event_npc_id = _pick_shop_npc_id()
			var exclude := get_owned_unique_artifacts()
			room.shop_item_ids = RunItems.random_item_ids(rng, EVENT_SHOP_SLOT_COUNT, exclude)
			room.shop_refreshed = true
		_:
			pass

func get_current_room() -> RoomParams:
	if rooms.is_empty():
		return null
	if room_index < 0 or room_index >= rooms.size():
		return null
	return rooms[room_index]

func advance_room() -> void:
	room_index += 1
	emit_changed()

func is_finished() -> bool:
	return room_index >= rooms.size()

func emit_changed() -> void:
	changed.emit()
