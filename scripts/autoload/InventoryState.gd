extends Node
class_name InventoryState

signal changed

const ICON_PATHS := {
	"slime_potion": "res://assets/pics/icons/items/potions/slime_potion.png",
	"energy_tonic": "res://assets/pics/icons/items/potions/energy_tonic.png",
	"rage_phial": "res://assets/pics/icons/items/potions/rage_phial.png",
	"kebab": "res://assets/pics/icons/items/food/kebab.png",
	"steak": "res://assets/pics/icons/items/food/steak.png",
	"jelly": "res://assets/pics/icons/items/food/jelly.png",
	"apple_pie": "res://assets/pics/icons/items/food/applepies.png",
	"slimeflower_seed": "res://assets/pics/farm/slime_seedbag.png",
	"witchflower_seed": "res://assets/pics/farm/witchflower_seedbag.png",
	"meatflower_seed": "res://assets/pics/farm/meatflower_seedbag.png",
	"vegetableflower_seed": "res://assets/pics/farm/vegetableflower_seedbag.png",
	"sweetflower_seed": "res://assets/pics/farm/sweetflower_seedbag.png",
	"fruitflower_seed": "res://assets/pics/farm/fruitflower_seedbag.png",
	"slimeflower": "res://assets/pics/farm/slime_flower.png",
	"witchflower": "res://assets/pics/farm/witchflower.png",
	"meatflower": "res://assets/pics/farm/meat_flower.png",
	"vegetableflower": "res://assets/pics/farm/vegetable_flower.png",
	"sweetflower": "res://assets/pics/farm/sweet_flower.png",
	"fruitflower": "res://assets/pics/farm/fruit_flower.png",
	"slime_goop": "res://assets/pics/icons/items/loot/slime_goop.png",
	"quartz": "res://assets/pics/icons/items/alchemy_ingridients/quartz.png",
	"meat_fruit": "res://assets/pics/icons/items/alchemy_ingridients/meat.png",
	"vegetable_fruit": "res://assets/pics/icons/items/alchemy_ingridients/vegetable.png",
	"sweet_fruit": "res://assets/pics/icons/items/alchemy_ingridients/sweet.png",
	"fruit_fruit": "res://assets/pics/icons/items/alchemy_ingridients/fruit.png",
	"stick_staff": "res://assets/pics/icons/items/staffs/stick_staff.png",
	"mace_staff": "res://assets/pics/icons/items/staffs/mace_staff.png",
	"heart_staff": "res://assets/pics/icons/items/staffs/heart_staff.png",
	"dango_staff": "res://assets/pics/icons/items/staffs/dango_staff.png",
	"slime_staff": "res://assets/pics/icons/items/staffs/slime_staff.png",
	"staff_rarity_0": "res://assets/pics/icons/items/staffs/0rare.png",
	"staff_rarity_1": "res://assets/pics/icons/items/staffs/1rare.png",
	"staff_rarity_2": "res://assets/pics/icons/items/staffs/2rare.png",
}

var items: Dictionary = {}
var _icon_cache: Dictionary = {}

func _ready() -> void:
	items = {}

func add_item(item_id: String, amount: int = 1) -> bool:
	item_id = RunItems.normalize_item_id(item_id)
	if item_id == "" or amount <= 0:
		return false
	# Рецепт не лежит в инвентаре — он сразу изучается.
	if RunItems.is_recipe_item(item_id):
		AlchemyDB.learn(RunItems.get_recipe_id(item_id))
		changed.emit()
		return true
	if RunItems.is_unique_item(item_id):
		if has_item(item_id):
			return false
		items[item_id] = 1
		changed.emit()
		return true
	items[item_id] = get_item_count(item_id) + amount
	changed.emit()
	return true

func remove_item(item_id: String, amount: int = 1) -> bool:
	item_id = RunItems.normalize_item_id(item_id)
	if item_id == "" or amount <= 0:
		return false
	var current := get_item_count(item_id)
	if current < amount:
		return false
	current -= amount
	if current <= 0:
		items.erase(item_id)
	else:
		items[item_id] = current
	changed.emit()
	return true

func has_item(item_id: String, amount: int = 1) -> bool:
	return get_item_count(item_id) >= max(amount, 1)

func get_item_count(item_id: String) -> int:
	return int(items.get(RunItems.normalize_item_id(item_id), 0))

func get_items() -> Dictionary:
	return items.duplicate(true)

func get_sorted_item_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_id in items.keys():
		var normalized := RunItems.normalize_item_id(String(item_id))
		out.append({
			"id": normalized,
			"name": get_item_name(normalized),
			"desc": RunItems.get_item_desc(normalized),
			"kind": RunItems.get_item_kind(normalized),
			"count": int(items[item_id]),
			"icon": get_item_icon(normalized),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var kind_a := String(a.get("kind", ""))
		var kind_b := String(b.get("kind", ""))
		if kind_a == kind_b:
			return String(a.get("name", "")) < String(b.get("name", ""))
		return kind_a < kind_b
	)
	return out

func get_item_name(item_id: String) -> String:
	return RunItems.get_item_name(item_id)

func get_item_icon(item_id: String) -> Texture2D:
	item_id = RunItems.normalize_item_id(item_id)
	if _icon_cache.has(item_id):
		return _icon_cache[item_id]
	var texture: Texture2D = null
	if RunItems.is_artifact(item_id):
		texture = _build_staff_icon(item_id)
	if RunItems.is_recipe_item(item_id):
		texture = get_item_icon(AlchemyDB.get_result_item_id(RunItems.get_recipe_id(item_id)))
	if texture == null:
		var path := String(ICON_PATHS.get(item_id, ""))
		if path != "" and ResourceLoader.exists(path):
			texture = load(path) as Texture2D
	if texture == null:
		texture = _build_fallback_icon(item_id)
	_icon_cache[item_id] = texture
	return texture

func _build_staff_icon(item_id: String) -> Texture2D:
	var staff_type := RunItems.get_staff_type(item_id)
	var rarity = clamp(RunItems.get_item_rarity(item_id), 0, 2)
	var base_path := String(ICON_PATHS.get("%s_staff" % staff_type, ""))
	var frame_path := String(ICON_PATHS.get("staff_rarity_%d" % rarity, ""))
	if base_path == "" or frame_path == "":
		return null
	if not ResourceLoader.exists(base_path) or not ResourceLoader.exists(frame_path):
		return null
	var base_tex := load(base_path) as Texture2D
	var frame_tex := load(frame_path) as Texture2D
	if base_tex == null or frame_tex == null:
		return null
	var base_img := base_tex.get_image()
	var frame_img := frame_tex.get_image()
	if base_img == null or frame_img == null:
		return null
	var size := Vector2i(max(base_img.get_width(), frame_img.get_width()), max(base_img.get_height(), frame_img.get_height()))
	var canvas := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var frame_pos := Vector2i(int((size.x - frame_img.get_width()) / 2.0), int((size.y - frame_img.get_height()) / 2.0))
	canvas.blend_rect(frame_img, Rect2i(Vector2i.ZERO, frame_img.get_size()), frame_pos)
	var base_pos := Vector2i(int((size.x - base_img.get_width()) / 2.0), int((size.y - base_img.get_height()) / 2.0))
	canvas.blend_rect(base_img, Rect2i(Vector2i.ZERO, base_img.get_size()), base_pos)
	return ImageTexture.create_from_image(canvas)

func _build_fallback_icon(item_id: String) -> Texture2D:
	var color := Color(0.45, 0.45, 0.50, 1.0)
	match RunItems.get_item_kind(item_id):
		"artifact":
			color = Color(0.87, 0.69, 0.22, 1.0)
		"potion":
			color = Color(0.59, 0.44, 0.85, 1.0)
		"food":
			color = Color(0.39, 0.69, 0.36, 1.0)
		"seed":
			color = Color(0.43, 0.78, 0.92, 1.0)
		"ingredient":
			color = Color(0.75, 0.55, 0.85, 1.0)
		"quest":
			color = Color(0.95, 0.58, 0.82, 1.0)
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	image.fill(color)
	for x in range(96):
		image.set_pixel(x, 0, Color.BLACK)
		image.set_pixel(x, 95, Color.BLACK)
	for y in range(96):
		image.set_pixel(0, y, Color.BLACK)
		image.set_pixel(95, y, Color.BLACK)
	return ImageTexture.create_from_image(image)

func clear() -> void:
	items.clear()
	changed.emit()

func serialize_state() -> Dictionary:
	return {
		"items": items.duplicate(true),
	}

func apply_state(data: Dictionary) -> void:
	items.clear()
	var saved_items = data.get("items", {})
	if saved_items is Dictionary:
		items = RunItems.normalize_item_counts(saved_items)
	_icon_cache.clear()
	changed.emit()
