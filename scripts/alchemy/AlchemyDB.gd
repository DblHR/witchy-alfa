extends Node
class_name AlchemyDB
## Рецепты алхимии. Зелья известны сразу, еду нужно сначала открыть: рецепт выпадает из сундука
## или покупается у Рикки (предмет «Рецепт: …» изучается при получении). Открытые — DungRun.known_recipes.

## Рецепты, известные с самого начала.
const STARTER_RECIPES: Array[String] = ["slime_potion_recipe", "energy_tonic_recipe", "rage_phial_recipe", "staff_upgrade_common", "staff_upgrade_rare"]

## Улучшение посохов: любые STAFF_UPGRADE_COUNT посоха одной редкости + кварц -> случайный посох
## следующей редкости. Рецепт -> редкость, которая сдаётся. В рецепте вместо предмета — группа «staff_rN».
const STAFF_UPGRADES := {"staff_upgrade_common": 0, "staff_upgrade_rare": 1}
const STAFF_UPGRADE_COUNT := 3
const STAFF_UPGRADE_QUARTZ := 10
const RARITY_NAMES := ["обычный", "редкий", "легендарный"]

const RECIPES := {
	"slime_potion_recipe": {
		"name": "Зелье слаймов",
		"result_item_id": "slime_potion",
		"ingredients": {"slime_goop": 4, "slimeflower": 2, "quartz": 1},
	},
	"energy_tonic_recipe": {
		"name": "Тоник энергии",
		"result_item_id": "energy_tonic",
		"ingredients": {"witchflower": 2, "quartz": 3},
	},
	"rage_phial_recipe": {
		"name": "Фиал ярости",
		"result_item_id": "rage_phial",
		"ingredients": {"witchflower": 3, "quartz": 2},
	},
	"kebab_recipe": {
		"name": "Шашлык",
		"result_item_id": "kebab",
		"ingredients": {"meat_fruit": 1, "vegetable_fruit": 1},
	},
	"steak_recipe": {
		"name": "Стейк",
		"result_item_id": "steak",
		"ingredients": {"meat_fruit": 2},
	},
	"jelly_recipe": {
		"name": "Желе",
		"result_item_id": "jelly",
		"ingredients": {"slime_goop": 3, "sweet_fruit": 1},
	},
	"apple_pie_recipe": {
		"name": "Яблоко в карамели",
		"result_item_id": "apple_pie",
		"ingredients": {"sweet_fruit": 1, "fruit_fruit": 1},
	},
	"staff_upgrade_common": {
		"name": "Посох → редкий",
		"result_item_id": "mace_staff_rare",
		"ingredients": {"staff_r0": 3, "quartz": 10},
	},
	"staff_upgrade_rare": {
		"name": "Посох → легендарный",
		"result_item_id": "mace_staff_legendary",
		"ingredients": {"staff_r1": 3, "quartz": 10},
	},
}

# --- Группы ингредиентов (улучшение посохов) ---------------------------------

static func is_group(key: String) -> bool:
	return key.begins_with("staff_r")

## Посох, который годится на улучшение (этажные легендарные вроде посоха слизней — нет).
static func is_upgradable_staff(item_id: String, rarity: int) -> bool:
	return RunItems.is_artifact(item_id) and RunItems.get_item_rarity(item_id) == rarity and RunItems.get_staff_type(item_id) != "slime"

## Ключ ингредиента для рецепта: посох нужной редкости в рецепте улучшения -> «staff_rN», иначе сам id.
static func ingredient_key(recipe_id: String, item_id: String) -> String:
	if STAFF_UPGRADES.has(recipe_id) and is_upgradable_staff(item_id, int(STAFF_UPGRADES[recipe_id])):
		return "staff_r%d" % int(STAFF_UPGRADES[recipe_id])
	return item_id

static func _group_items(key: String) -> Array[String]:
	var out: Array[String] = []
	var rarity := int(key.trim_prefix("staff_r"))
	for id in RunItems.artifact_ids():
		if is_upgradable_staff(id, rarity):
			out.append(id)
	return out

## Сколько есть в инвентаре (для группы — сумма всех подходящих посохов).
static func count_have(key: String) -> int:
	if Inventory_ == null:
		return 0
	if not is_group(key):
		return Inventory_.get_item_count(key)
	var n := 0
	for id in _group_items(key):
		n += Inventory_.get_item_count(id)
	return n

static func ingredient_name(key: String) -> String:
	if is_group(key):
		return "Любой %s посох" % RARITY_NAMES[clampi(int(key.trim_prefix("staff_r")), 0, 2)]
	return RunItems.get_item_name(key)

static func ingredient_icon(key: String) -> Texture2D:
	if Inventory_ == null:
		return null
	if is_group(key):
		var items := _group_items(key)
		return Inventory_.get_item_icon(items[0]) if not items.is_empty() else null
	return Inventory_.get_item_icon(key)

## Что лежит на полке для рецепта: все ингредиенты + посохи нужной редкости, если это улучшение.
static func get_shelf_ids(recipe_id: String) -> Array[String]:
	var out := get_all_ingredient_ids()
	if STAFF_UPGRADES.has(recipe_id):
		for id in _group_items("staff_r%d" % int(STAFF_UPGRADES[recipe_id])):
			out.append(id)
	return out

## Результат варки. Улучшение посохов — случайный посох следующей редкости.
static func roll_result(recipe_id: String, rng: RandomNumberGenerator) -> String:
	if STAFF_UPGRADES.has(recipe_id):
		var pool := _group_items("staff_r%d" % (int(STAFF_UPGRADES[recipe_id]) + 1))
		if not pool.is_empty():
			return pool[rng.randi_range(0, pool.size() - 1)]
	return get_result_item_id(recipe_id)

static func get_recipe_desc(recipe_id: String) -> String:
	if STAFF_UPGRADES.has(recipe_id):
		var r := int(STAFF_UPGRADES[recipe_id])
		return "%d любых посоха (%s) + %d кварца → случайный %s посох." % [STAFF_UPGRADE_COUNT, RARITY_NAMES[r], STAFF_UPGRADE_QUARTZ, RARITY_NAMES[r + 1]]
	return RunItems.get_item_desc(get_result_item_id(recipe_id))

static func get_recipe_ids() -> Array[String]:
	var out: Array[String] = []
	for recipe_id in RECIPES.keys():
		out.append(String(recipe_id))
	out.sort_custom(func(a: String, b: String) -> bool:
		return get_recipe_name(a) < get_recipe_name(b)
	)
	return out

## Все предметы, которые встречаются в рецептах (то, что рисуется на полке ингредиентов).
static func get_all_ingredient_ids() -> Array[String]:
	var out: Array[String] = []
	for recipe_id in RECIPES.keys():
		for item_id in RECIPES[recipe_id]["ingredients"].keys():
			if not out.has(String(item_id)) and not is_group(String(item_id)):
				out.append(String(item_id))
	return out

static func is_known(recipe_id: String) -> bool:
	return STARTER_RECIPES.has(recipe_id) or (DungRun != null and DungRun.known_recipes.has(recipe_id))

static func learn(recipe_id: String) -> void:
	if recipe_id == "" or DungRun == null or is_known(recipe_id) or not RECIPES.has(recipe_id):
		return
	DungRun.known_recipes.append(recipe_id)
	DungRun.emit_changed()

## Предметы-рецепты еды, которые ещё не открыты (для сундука и лавки).
static func unknown_recipe_items() -> Array[String]:
	var out: Array[String] = []
	for item_id in RunItems.all_item_ids():
		if RunItems.is_recipe_item(item_id) and not is_known(RunItems.get_recipe_id(item_id)):
			out.append(item_id)
	return out

static func get_recipe(recipe_id: String) -> Dictionary:
	return RECIPES.get(String(recipe_id), {})

static func get_recipe_name(recipe_id: String) -> String:
	return String(get_recipe(recipe_id).get("name", recipe_id))

static func get_result_item_id(recipe_id: String) -> String:
	return String(get_recipe(recipe_id).get("result_item_id", ""))

static func get_ingredients(recipe_id: String) -> Dictionary:
	return Dictionary(get_recipe(recipe_id).get("ingredients", {})).duplicate(true)

static func can_craft(recipe_id: String) -> bool:
	if Inventory_ == null or not is_known(recipe_id):
		return false
	for item_id in get_ingredients(recipe_id).keys():
		var need := int(get_ingredients(recipe_id)[item_id])
		if count_have(String(item_id)) < need:
			return false
	return true

static func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id) or Inventory_ == null:
		return false
	var ingredients := get_ingredients(recipe_id)
	for item_id in ingredients.keys():
		var key := String(item_id)
		var left := int(ingredients[item_id])
		if is_group(key):
			# Без мини-игры: сначала тратятся самые большие стопки.
			var items := _group_items(key)
			items.sort_custom(func(a: String, b: String) -> bool: return Inventory_.get_item_count(a) > Inventory_.get_item_count(b))
			for id in items:
				var take := mini(left, Inventory_.get_item_count(id))
				if take > 0:
					Inventory_.remove_item(id, take)
					left -= take
		else:
			Inventory_.remove_item(key, left)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Inventory_.add_item(roll_result(recipe_id, rng), 1)
	return true

static func get_recipe_summary(recipe_id: String) -> String:
	var parts: Array[String] = []
	for item_id in get_ingredients(recipe_id).keys():
		parts.append("%d × %s" % [int(get_ingredients(recipe_id)[item_id]), ingredient_name(String(item_id))])
	parts.sort()
	return ", ".join(parts)
