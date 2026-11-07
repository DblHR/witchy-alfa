extends RefCounted
class_name RunItems

const SELL_PRICE_RATIO := 0.70

const ITEM_ALIASES := {
	"control_fang": "heart_staff_rare",
	"frost_seed": "slime_staff_legendary",
	"farm_seed": "slimeflower_seed",
	"farm_flower": "slimeflower",
	"healing_brew": "slime_potion",
	"energy_tonic": "energy_tonic",
	"rage_phial": "rage_phial",
	"sharp_blade": "mace_staff_common",
	"estus_ring": "dango_staff_common",
	"executioner_fang": "heart_staff_rare",
	"third_room_blessing": "dango_staff_rare",
	"frost_gauntlet": "slime_staff_legendary",
	"green_broth": "kebab",
	"guardian_cookie": "steak",
	"assassin_pin": "stick_staff_rare",
	"golden_idol": "stick_staff_common",
	"mana_clock": "dango_staff_legendary",
	"ambush_powder": "heart_staff_common",
	"healing_potion_tier1": "slime_potion",
	"energy_potion_tier1": "energy_tonic",
	"damage_potion_tier1": "rage_phial",
	"seed_3": "meatflower_seed",
	"seed_4": "vegetableflower_seed",
	"seed_5": "sweetflower_seed",
	"seed_6": "fruitflower_seed",
}

const ITEM_DEFS := {
	"warm_headphones": {
		"name": "Тёплые наушники",
		"desc": "Потерянные наушники ламии. Мягкие, тёплые и почему-то пахнут ванилью.",
		"kind": "quest",
		"equippable": false,
		"unique": true,
		"stackable": false,
		"sellable": false,
		"price": 0,
		"rarity": 0,
	},
	"stick_staff_common": {
		"name": "Кривой посох",
		"desc": "Посох-шутка. Каждый удар картой: 5% — двойной урон, 15% — промах.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 18,
		"effect_id": "stick_staff_common",
		"staff_type": "stick",
		"rarity": 0,
	},
	"stick_staff_rare": {
		"name": "Кривой посох+",
		"desc": "Посох-шутка. Каждый удар картой: 10% — двойной урон, 10% — промах.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 26,
		"effect_id": "stick_staff_rare",
		"staff_type": "stick",
		"rarity": 1,
	},
	"stick_staff_legendary": {
		"name": "Кривой посох++",
		"desc": "Легендарный мем. Каждый удар картой: 20% — двойной урон, 5% — тройной, 5% — промах.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 38,
		"effect_id": "stick_staff_legendary",
		"staff_type": "stick",
		"rarity": 2,
	},
	"mace_staff_common": {
		"name": "Звёздный посох",
		"desc": "Весь урон карт отряда +5%.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 20,
		"effect_id": "mace_staff_common",
		"staff_type": "mace",
		"rarity": 0,
	},
	"mace_staff_rare": {
		"name": "Звёздный посох+",
		"desc": "Весь урон карт отряда +10%.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 30,
		"effect_id": "mace_staff_rare",
		"staff_type": "mace",
		"rarity": 1,
	},
	"mace_staff_legendary": {
		"name": "Звёздный посох++",
		"desc": "Весь урон карт отряда +20%.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 42,
		"effect_id": "mace_staff_legendary",
		"staff_type": "mace",
		"rarity": 2,
	},
	"heart_staff_common": {
		"name": "Посох сердца",
		"desc": "В начале каждого боя — Слабость всем врагам на 1 ход.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 21,
		"effect_id": "heart_staff_common",
		"staff_type": "heart",
		"rarity": 0,
	},
	"heart_staff_rare": {
		"name": "Посох сердца+",
		"desc": "В начале каждого боя — Слабость всем врагам на 3 хода.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 32,
		"effect_id": "heart_staff_rare",
		"staff_type": "heart",
		"rarity": 1,
	},
	"heart_staff_legendary": {
		"name": "Посох сердца++",
		"desc": "В начале каждого боя — Слабость всем врагам на 3 хода и очарование случайного врага на 1 ход.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 46,
		"effect_id": "heart_staff_legendary",
		"staff_type": "heart",
		"rarity": 2,
	},
	"dango_staff_common": {
		"name": "Данго-посох",
		"desc": "В начале каждого боя — один случайный бафф из трёх: +1 карта в первый ход, +1 энергия в первый ход, Слабость всем врагам.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 22,
		"effect_id": "dango_staff_common",
		"staff_type": "dango",
		"rarity": 0,
	},
	"dango_staff_rare": {
		"name": "Данго-посох+",
		"desc": "В начале каждого боя — два случайных баффа из трёх: +1 карта, +1 энергия в первый ход, Слабость всем врагам.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 33,
		"effect_id": "dango_staff_rare",
		"staff_type": "dango",
		"rarity": 1,
	},
	"dango_staff_legendary": {
		"name": "Данго-посох++",
		"desc": "В начале каждого боя — все три баффа: +1 карта и +1 энергия в первый ход, Слабость всем врагам.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 48,
		"effect_id": "dango_staff_legendary",
		"staff_type": "dango",
		"rarity": 2,
	},
	"slime_staff_legendary": {
		"name": "Посох слизней",
		"desc": "Этажный легендарный посох. Любая разыгранная карта с шансом 20% накладывает на всех врагов липкую слизь.",
		"kind": "artifact",
		"equippable": true,
		"unique": true,
		"stackable": false,
		"sellable": true,
		"price": 60,
		"effect_id": "slime_staff_legendary",
		"staff_type": "slime",
		"rarity": 2,
	},
	"recipe_kebab": {
		"name": "Рецепт: Шашлык",
		"desc": "Открывает рецепт «Шашлык» для алхимии. Изучается сразу при получении.",
		"kind": "recipe",
		"equippable": false,
		"unique": false,
		"stackable": false,
		"sellable": false,
		"price": 30,
		"recipe_id": "kebab_recipe",
	},
	"recipe_steak": {
		"name": "Рецепт: Стейк",
		"desc": "Открывает рецепт «Стейк» для алхимии. Изучается сразу при получении.",
		"kind": "recipe",
		"equippable": false,
		"unique": false,
		"stackable": false,
		"sellable": false,
		"price": 30,
		"recipe_id": "steak_recipe",
	},
	"recipe_jelly": {
		"name": "Рецепт: Желе",
		"desc": "Открывает рецепт «Желе» для алхимии. Изучается сразу при получении.",
		"kind": "recipe",
		"equippable": false,
		"unique": false,
		"stackable": false,
		"sellable": false,
		"price": 30,
		"recipe_id": "jelly_recipe",
	},
	"recipe_apple_pie": {
		"name": "Рецепт: Яблоко в карамели",
		"desc": "Открывает рецепт «Яблоко в карамели» для алхимии. Изучается сразу при получении.",
		"kind": "recipe",
		"equippable": false,
		"unique": false,
		"stackable": false,
		"sellable": false,
		"price": 30,
		"recipe_id": "apple_pie_recipe",
	},
	"slime_potion": {
		"name": "Зелье слаймов",
		"desc": "Зелье: лечит самую раненую героиню на 40% макс. HP.",
		"kind": "potion",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 20,
		"effect_id": "heal_potion",
	},
	"energy_tonic": {
		"name": "Тоник энергии",
		"desc": "Зелье: +2 энергии в этот ход.",
		"kind": "potion",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 22,
		"effect_id": "energy_potion",
	},
	"rage_phial": {
		"name": "Фиал ярости",
		"desc": "Зелье: до конца хода урон карт +30%.",
		"kind": "potion",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 22,
		"effect_id": "battle_potion",
	},
	"kebab": {
		"name": "Шашлык",
		"desc": "Еда на забег: в начале каждого боя лечит отряд на 5% макс. HP.",
		"kind": "food",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 20,
		"effect_id": "kebab",
	},
	"steak": {
		"name": "Стейк",
		"desc": "Еда на забег: один раз за забег героиня, упавшая ниже 25% HP, сразу лечится на 25%.",
		"kind": "food",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 22,
		"effect_id": "steak",
	},
	"jelly": {
		"name": "Желе",
		"desc": "Еда на забег: в первом ходу каждого боя +1 карта в руку.",
		"kind": "food",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 18,
		"effect_id": "jelly",
	},
	"apple_pie": {
		"name": "Яблоко в карамели",
		"desc": "Еда на забег: первая атака в каждом бою наносит +40% урона.",
		"kind": "food",
		"equippable": true,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 24,
		"effect_id": "apple_pie",
	},
	"slimeflower_seed": {
		"name": "Семена слайм-цветка",
		"desc": "Мешочек липких семян для выращивания слайм-цветка.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"witchflower_seed": {
		"name": "Семена ведьминого цветка",
		"desc": "Новый сорт для алхимии. Росток использует тот же спрайт, что и слайм-цветок.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 7,
		"effect_id": "",
	},
	"slimeflower": {
		"name": "Слайм-цветок",
		"desc": "Желеобразный цветок для варки зелья слаймов.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 10,
		"effect_id": "",
	},
	"witchflower": {
		"name": "Ведьмин цветок",
		"desc": "Алхимический цветок для тоника энергии и фиала ярости.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 12,
		"effect_id": "",
	},
	"meatflower_seed": {
		"name": "Семена мясного цветка",
		"desc": "Мешочек семян для выращивания мясного цветка.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 7,
		"effect_id": "",
	},
	"vegetableflower_seed": {
		"name": "Семена овощного цветка",
		"desc": "Мешочек семян для выращивания овощного цветка.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 7,
		"effect_id": "",
	},
	"sweetflower_seed": {
		"name": "Семена сладкого цветка",
		"desc": "Мешочек семян для выращивания сладкого цветка.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 7,
		"effect_id": "",
	},
	"fruitflower_seed": {
		"name": "Семена фруктового цветка",
		"desc": "Мешочек семян для выращивания фруктового цветка.",
		"kind": "seed",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 7,
		"effect_id": "",
	},
	"meatflower": {
		"name": "Мясной цветок",
		"desc": "Созревший цветок, из которого добывают мясной материал.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"vegetableflower": {
		"name": "Овощной цветок",
		"desc": "Созревший цветок, из которого добывают овощной материал.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"sweetflower": {
		"name": "Сладкий цветок",
		"desc": "Созревший цветок, из которого добывают сладкий материал.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"fruitflower": {
		"name": "Фруктовый цветок",
		"desc": "Созревший цветок, из которого добывают фруктовый материал.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"slime_goop": {
		"name": "Слизь",
		"desc": "Обычная добыча со слаймов. Липкая, но полезная.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 4,
		"effect_id": "",
	},
	"quartz": {
		"name": "Кварц",
		"desc": "Базовый алхимический минерал.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 5,
		"effect_id": "",
	},
	"meat_fruit": {
		"name": "Мясной материал",
		"desc": "Материал из мясного цветка для мясных рецептов.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"vegetable_fruit": {
		"name": "Овощной материал",
		"desc": "Материал из овощного цветка для сытных рецептов.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"sweet_fruit": {
		"name": "Сладкий материал",
		"desc": "Материал из сладкого цветка для десертов и желе.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
	"fruit_fruit": {
		"name": "Фруктовый материал",
		"desc": "Материал из фруктового цветка для яблока в карамели и других десертов.",
		"kind": "ingredient",
		"equippable": false,
		"unique": false,
		"stackable": true,
		"sellable": true,
		"price": 6,
		"effect_id": "",
	},
}

const POTION_DEFS := {
	"heal_potion": {"name": "Зелье слаймов", "desc": "Лечит самую раненую героиню на 40% макс. HP.", "charges": 0},
	"energy_potion": {"name": "Тоник энергии", "desc": "+2 энергии в этот ход.", "charges": 0},
	"battle_potion": {"name": "Фиал ярости", "desc": "До конца хода урон карт +30%.", "charges": 0},
}

const POTION_ITEM_IDS := {
	"heal_potion": "slime_potion",
	"energy_potion": "energy_tonic",
	"battle_potion": "rage_phial",
}

static func normalize_item_id(id: String) -> String:
	var clean := String(id)
	if ITEM_ALIASES.has(clean):
		return String(ITEM_ALIASES[clean])
	return clean

static func normalize_item_array(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for value in ids:
		var id := normalize_item_id(String(value))
		if id != "":
			out.append(id)
	return out

static func normalize_item_counts(items: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in items.keys():
		var id := normalize_item_id(String(key))
		var count := int(items[key])
		if id == "" or count <= 0:
			continue
		out[id] = int(out.get(id, 0)) + count
	return out

static func get_item_def(id: String) -> Dictionary:
	return ITEM_DEFS.get(normalize_item_id(id), {})

static func get_item_name(id: String) -> String:
	var normalized := normalize_item_id(id)
	var d := get_item_def(normalized)
	return String(d.get("name", normalized))

static func get_item_desc(id: String) -> String:
	return String(get_item_def(id).get("desc", ""))

static func get_item_price(id: String) -> int:
	return int(get_item_def(id).get("price", 0))

static func get_item_sell_price(id: String) -> int:
	return int(floor(get_item_price(id) * SELL_PRICE_RATIO))

static func get_item_kind(id: String) -> String:
	return String(get_item_def(id).get("kind", ""))

static func get_item_kind_label(id: String) -> String:
	match get_item_kind(id):
		"artifact":
			return "Посох"
		"food":
			return "Еда"
		"potion":
			return "Зелье"
		"ingredient":
			return "Ингредиент"
		"seed":
			return "Семена"
		"quest":
			return "Квест"
		"recipe":
			return "Рецепт"
		_:
			return "Предмет"

## Рецепт-предмет («recipe_kebab») -> id рецепта алхимии («kebab_recipe»).
static func get_recipe_id(id: String) -> String:
	return String(get_item_def(id).get("recipe_id", ""))

static func is_recipe_item(id: String) -> bool:
	return get_item_kind(id) == "recipe"

static func get_item_rarity(id: String) -> int:
	return int(get_item_def(id).get("rarity", -1))

static func get_item_rarity_label(id: String) -> String:
	match get_item_rarity(id):
		0:
			return "Обычный"
		1:
			return "Редкий"
		2:
			return "Легендарный"
		_:
			return ""

static func get_staff_type(id: String) -> String:
	return String(get_item_def(id).get("staff_type", ""))

static func is_equippable(id: String) -> bool:
	return bool(get_item_def(id).get("equippable", false))

static func is_unique_item(id: String) -> bool:
	return bool(get_item_def(id).get("unique", false))

static func is_stackable(id: String) -> bool:
	return bool(get_item_def(id).get("stackable", true))

static func is_sellable(id: String) -> bool:
	return bool(get_item_def(id).get("sellable", true))

static func get_item_effect_id(id: String) -> String:
	return String(get_item_def(id).get("effect_id", ""))

static func get_inventory_kind(id: String) -> String:
	return get_item_kind(id)

static func is_unique_artifact(id: String) -> bool:
	return is_unique_item(id)

static func is_artifact(id: String) -> bool:
	return get_item_kind(id) == "artifact"

static func all_item_ids() -> Array[String]:
	var out: Array[String] = []
	for k in ITEM_DEFS.keys():
		out.append(String(k))
	out.sort()
	return out

static func artifact_ids() -> Array[String]:
	var out: Array[String] = []
	for id in all_item_ids():
		if is_loadout_artifact(id):
			out.append(id)
	return out

static func food_ids() -> Array[String]:
	var out: Array[String] = []
	for id in all_item_ids():
		if is_loadout_food(id):
			out.append(id)
	return out

static func is_loadout_artifact(id: String) -> bool:
	return get_item_kind(id) == "artifact" and is_equippable(id)

static func is_loadout_food(id: String) -> bool:
	return get_item_kind(id) == "food" and is_equippable(id)

static func is_potion_item(id: String) -> bool:
	return get_item_kind(id) == "potion"

static func is_seed(id: String) -> bool:
	return get_item_kind(id) == "seed"

static func is_ingredient(id: String) -> bool:
	return get_item_kind(id) == "ingredient"

static func is_shop_item(id: String) -> bool:
	var kind := get_item_kind(id)
	return kind in ["artifact", "food", "potion", "seed"] or normalize_item_id(id) == "quartz"

static func random_item_ids(rng: RandomNumberGenerator, count: int, exclude: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for id in all_item_ids():
		if is_shop_item(id):
			pool.append(id)
	for id in exclude:
		pool.erase(normalize_item_id(id))
	var out: Array[String] = []
	while count > 0 and not pool.is_empty():
		var idx := rng.randi_range(0, pool.size() - 1)
		out.append(pool[idx])
		pool.remove_at(idx)
		count -= 1
	return out

static func get_potion_def(id: String) -> Dictionary:
	return POTION_DEFS.get(String(id), {})

static func get_potion_name(id: String) -> String:
	var d := get_potion_def(id)
	return String(d.get("name", id))

static func get_potion_desc(id: String) -> String:
	var d := get_potion_def(id)
	return String(d.get("desc", ""))

static func get_potion_charges(id: String) -> int:
	var d := get_potion_def(id)
	return int(d.get("charges", 0))

static func get_potion_item_id(potion_id: String) -> String:
	return String(POTION_ITEM_IDS.get(String(potion_id), ""))

static func get_potion_id_for_item(item_id: String) -> String:
	var normalized := normalize_item_id(item_id)
	for potion_id in POTION_ITEM_IDS.keys():
		if String(POTION_ITEM_IDS[potion_id]) == normalized:
			return String(potion_id)
	return ""
