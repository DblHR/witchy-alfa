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
	get_tree().paused = false
	get_tree().change_scene_to_file(ALCHEMY)

func go_to_shop() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(SHOP_SCENE)

func go_to_inventory() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(INVENTORY)

func go_to_prologue() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(PROLOGUE)
