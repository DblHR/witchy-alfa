extends Node
class_name SceneRouter

# Явные пути сцен — чтобы не разносить строки по проекту.
const MAIN_MENU := "res://scenes/MainMenu.tscn" 
const HUB := "res://scenes/Hub.tscn"            
const PROLOGUE := "res://scenes/Prologue.tscn"

const SETUP := "res://scenes/Setup.tscn"
const CARD_BATTLE := "res://scenes/card/CardBattle.tscn"

const FARM := "res://scenes/Farm.tscn"
const ALCHEMY := "res://scripts/alchemy/Alchemy.tscn"
const SHOP_SCENE := "res://scenes/Shop.tscn"
const INVENTORY := "res://scenes/Inventory.tscn"

func go_to_setup() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SETUP)

func go_to_card_battle() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(CARD_BATTLE)

# Эти два пока не используем, но заранее фиксируем API.
func go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)

func go_to_hub() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB)
	
func go_to_farm() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(FARM)

func go_to_alchemy() -> void:
	if not AlchemyDB.has_cauldron():
		return   ## котла ещё нет — покупается у Рикки
	get_tree().paused = false
	get_tree().change_scene_to_file(ALCHEMY)

func go_to_shop() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SHOP_SCENE)

## Экран отношений с персонажем: scenes/love/<id>_love.tscn.
const LOVE_DIR := "res://scenes/love/"

static func love_scene(unit_id: String) -> String:
	return LOVE_DIR + unit_id + "_love.tscn"

func go_to_love(unit_id: String) -> void:
	var path := love_scene(unit_id)
	if not ResourceLoader.exists(path):
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(path)

## Сон (scenes/dreams/Dream.tscn): какой — dream_id (Dreams). После сна — обратно в дом.
const DREAM := "res://scenes/dreams/Dream.tscn"
var dream_id := ""

func go_to_dream(id: String) -> void:
	dream_id = id
	get_tree().paused = false
	get_tree().change_scene_to_file(DREAM)

## Инвентарь открывается поверх текущей комнаты (дом, алхимия…): своим слоем INVENTORY_LAYER,
## фон под ним размыт (Inventory.tscn → Blur). Комната под ним живёт дальше, но клики до неё не доходят.
## «Назад» / Esc — слой убирается, сигнал inventory_closed (дом обновляет значки).
## Если открыть некуда (нет текущей сцены) — по-старому отдельной сценой.
signal inventory_closed
const INVENTORY_LAYER := 45
var inventory_return := HUB
var _inventory_layer: CanvasLayer

func go_to_inventory() -> void:
	if is_inventory_open():
		return
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path == INVENTORY:
		get_tree().paused = false
		inventory_return = HUB
		get_tree().change_scene_to_file(INVENTORY)
		return
	var layer := CanvasLayer.new()
	layer.name = "InventoryOverlay"
	layer.layer = INVENTORY_LAYER
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child((load(INVENTORY) as PackedScene).instantiate())
	cur.add_child(layer)
	_inventory_layer = layer

func is_inventory_open() -> bool:
	return is_instance_valid(_inventory_layer) and not _inventory_layer.is_queued_for_deletion()

## «Назад» из инвентаря.
func leave_inventory() -> void:
	if is_inventory_open():
		_inventory_layer.queue_free()
		_inventory_layer = null
		inventory_closed.emit()
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(inventory_return if ResourceLoader.exists(inventory_return) else HUB)

func go_to_prologue() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(PROLOGUE)
