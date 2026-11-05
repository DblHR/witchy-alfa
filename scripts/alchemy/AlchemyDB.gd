extends Node
class_name AlchemyDB

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
}

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
			if not out.has(String(item_id)):
				out.append(String(item_id))
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
	if Inventory_ == null:
		return false
	for item_id in get_ingredients(recipe_id).keys():
		var need := int(get_ingredients(recipe_id)[item_id])
		if not Inventory_.has_item(String(item_id), need):
			return false
	return true

static func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id) or Inventory_ == null:
		return false
	var ingredients := get_ingredients(recipe_id)
	for item_id in ingredients.keys():
		Inventory_.remove_item(String(item_id), int(ingredients[item_id]))
	Inventory_.add_item(get_result_item_id(recipe_id), 1)
	return true

static func get_recipe_summary(recipe_id: String) -> String:
	var parts: Array[String] = []
	for item_id in get_ingredients(recipe_id).keys():
		parts.append("%d × %s" % [int(get_ingredients(recipe_id)[item_id]), RunItems.get_item_name(String(item_id))])
	parts.sort()
	return ", ".join(parts)
