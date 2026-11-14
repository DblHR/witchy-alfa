extends Node
class_name AssetCatalog

# Central place for texture paths used from code.
# Replace these strings with your actual imported asset paths.

const UI_TEXTURE_PATHS := {
	"farm_bg": "res://assets/backgrounds/rooms/farmBG.png",
	"event_bg_default": "",   ## пусто — фон этажа слоями (FloorBackdrop)
	"event_bg_shop": "res://assets/backgrounds/rooms/eventroomShopBG.png",
	"event_bg_nurse": "res://assets/backgrounds/rooms/nurseBG.png",
	"event_bg_chest": "",   ## пусто — фон этажа слоями (FloorBackdrop)
	"event_bg_statue_white": "",   ## пусто — фон этажа слоями (FloorBackdrop)
	"event_bg_statue_black": "",   ## пусто — фон этажа слоями (FloorBackdrop)
	"event_bg_quest": "",   ## пусто — фон этажа слоями (FloorBackdrop)
	"farm_btn_home": "res://assets/ui/buttons/homeButton.png",
	"farm_btn_shop": "res://assets/ui/buttons/shopButton.png",
	"farm_btn_alchemy": "res://assets/ui/buttons/alchemyButton.png",
}

const FARM_TEXTURE_PATHS := {
	"sprout": "res://assets/farm/plants/sprout.png",
	"slimeflower": "res://assets/farm/plants/slime_flower.png",
	"slimeflower_seed": "res://assets/farm/seeds/slime_seedbag.png",
	"witchflower": "res://assets/farm/plants/witchflower.png",
	"witchflower_seed": "res://assets/farm/seeds/witchflower_seedbag.png",
	"meatflower": "res://assets/farm/plants/meat_flower.png",
	"meatflower_seed": "res://assets/farm/seeds/meatflower_seedbag.png",
	"vegetableflower": "res://assets/farm/plants/vegetable_flower.png",
	"vegetableflower_seed": "res://assets/farm/seeds/vegetableflower_seedbag.png",
	"sweetflower": "res://assets/farm/plants/sweet_flower.png",
	"sweetflower_seed": "res://assets/farm/seeds/sweetflower_seedbag.png",
	"fruitflower": "res://assets/farm/plants/fruit_flower.png",
	"fruitflower_seed": "res://assets/farm/seeds/fruitflower_seedbag.png",
}

const FARM_POT_TEXTURES := {
	0: "res://assets/farm/pots/pot1.png",
	1: "res://assets/farm/pots/pot2.png",
	2: "res://assets/farm/pots/pot3.png",
	3: "res://assets/farm/pots/pot4.png",
	4: "res://assets/farm/pots/pot5.png",
	5: "res://assets/farm/pots/pot6.png",
	6: "res://assets/farm/pots/pot7.png",
	7: "res://assets/farm/pots/pot8.png",
}

const EVENT_NPC_TEXTURES := {
	"shop": "res://assets/npc/sessilia/sessilia.png",
	"rabbit_shop": "res://assets/npc/rikka/rikka.png",
	"nurse": "res://assets/npc/noctris/noctris.png",
	"lamia": "res://assets/npc/sessilia/sessilia.png",
	"chest": "res://assets/npc/chest/chest.png",
	"opened_chest": "res://assets/npc/chest/chest_open.png",
	"statue_white": "res://assets/npc/statues/statue_white.png",
	"statue_black": "res://assets/npc/statues/statue_black.png",
}

const EVENT_CHOICE_TEXTURES := {
	"nurse_heal": "res://assets/npc/noctris/noctris_heal.png",
	"nurse_revive": "res://assets/npc/noctris/noctris_revival.png",
	"nurse_potion": "res://assets/npc/noctris/noctris_potion.png",
}

var _texture_cache: Dictionary = {}

func get_ui_texture(key: String) -> Texture2D:
	return _load_texture(String(UI_TEXTURE_PATHS.get(key, "")))

func get_farm_texture(key: String) -> Texture2D:
	return _load_texture(String(FARM_TEXTURE_PATHS.get(key, "")))

func get_farm_pot_texture(slot_index: int) -> Texture2D:
	return _load_texture(String(FARM_POT_TEXTURES.get(slot_index, "")))

func get_event_npc_texture(key: String) -> Texture2D:
	var tex := _load_texture(String(EVENT_NPC_TEXTURES.get(key, "")))
	if tex != null:
		return tex
	match key:
		"lamia":
			return _build_placeholder_texture("lamia", Color(0.68, 0.50, 0.86, 1.0))
		"rabbit_shop", "shop":
			return _build_placeholder_texture("rabbit_shop", Color(0.92, 0.62, 0.74, 1.0))
		"nurse":
			return _build_placeholder_texture("nurse", Color(0.62, 0.80, 0.95, 1.0))
	return null

func get_event_choice_texture(key: String) -> Texture2D:
	return _load_texture(String(EVENT_CHOICE_TEXTURES.get(key, "")))

func get_event_background(event_type: int, statue_variant: int = 0) -> Texture2D:
	var key := "event_bg_default"
	match event_type:
		RoomParams.EventType.SHOP:
			key = "event_bg_shop"
		RoomParams.EventType.NURSE:
			key = "event_bg_nurse"
		RoomParams.EventType.CHEST:
			key = "event_bg_chest"
		RoomParams.EventType.STATUE:
			key = "event_bg_statue_white" if statue_variant == RoomParams.StatueVariant.WHITE else "event_bg_statue_black"
		RoomParams.EventType.QUEST:
			key = "event_bg_quest"
	return get_ui_texture(key)

func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _texture_cache.has(path):
		return _texture_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AssetCatalog: missing texture path -> %s" % path)
		return null
	var tex := load(path) as Texture2D
	_texture_cache[path] = tex
	return tex

func _build_placeholder_texture(cache_key: String, color: Color) -> Texture2D:
	var key := "placeholder://" + cache_key
	if _texture_cache.has(key):
		return _texture_cache[key]
	var image := Image.create(320, 480, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	# Две заливки прямоугольников вместо 150 000 вызовов set_pixel.
	image.fill_rect(Rect2i(19, 19, 283, 443), Color(0.12, 0.10, 0.14, 1.0))
	image.fill_rect(Rect2i(25, 25, 271, 431), color)
	var tex := ImageTexture.create_from_image(image)
	_texture_cache[key] = tex
	return tex
