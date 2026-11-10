extends Control

@onready var start_run: TextureButton = %StartRunButton
@onready var farm: TextureButton = %FarmButton
@onready var alchemy: TextureButton = %AlchemyButton
@onready var shop: TextureButton = %ShopButton
@onready var inv: TextureButton = %InventoryButton

func _ready() -> void:
	get_tree().paused = false

	start_run.pressed.connect(_on_start_run)
	farm.pressed.connect(func(): SceneRouter_.go_to_farm())
	alchemy.pressed.connect(func(): SceneRouter_.go_to_alchemy())
	shop.pressed.connect(func(): SceneRouter_.go_to_shop())
	inv.pressed.connect(func(): SceneRouter_.go_to_inventory())
	_start_wanderers()
	_refresh_badges()
	if StoryState_ != null and StoryState_.has_signal("changed") and not StoryState_.changed.is_connected(_refresh_badges):
		StoryState_.changed.connect(_refresh_badges)
	call_deferred("_play_pending_story_dialogue")

## «!» на кнопке лавки, когда Рикка может выдать квест.
func _refresh_badges() -> void:
	if not is_inside_tree():
		return
	NotifyBadge.attach(shop, StoryDialogueDB_ != null and StoryDialogueDB_.npc_has_quest_offer("rabbit_shop"))

## Ведьмочка бродит по дому. Границы — левый край её картинки (координаты 1920×1080),
## чтобы не заходить под кнопки инвентаря и портала.
const WITCH_MIN_X := 90.0
const WITCH_MAX_X := 1150.0

func _start_wanderers() -> void:
	var witch := get_node_or_null("TextureRect") as TextureRect
	if witch == null:
		return
	var w := HubWanderer.new()
	w.name = "WitchWanderer"
	w.setup(witch, WITCH_MIN_X, WITCH_MAX_X)
	add_child(w)

func _on_start_run() -> void:
	# Тут логично начинать новый забег (seed, сброс золота и т.д.)
	# Но если Вы хотите сохранить "старт run" строго в Setup — можно перенести туда.
	SceneRouter_.go_to_setup()

func _play_pending_story_dialogue() -> void:
	if StoryState_ == null or not StoryState_.has_flag("pending_find_warrior_after_battle"):
		return
	StoryState_.set_flag("pending_find_warrior_after_battle", false)
	if StoryDialogueDB_ == null:
		return
	var d := StoryDialogueDB_.get_dialogue("find_warrior_after_battle")
	if d.is_empty():
		return
	var lines := StoryDialogueDB_.resolve_lines(d)
	if lines.is_empty():
		StoryDialogueDB_.apply_effects(d.get("on_finish", {}))
		return
	DialogueManager_.show_sequence(lines, Callable(self, "_on_pending_story_dialogue_finished").bind(d))

func _on_pending_story_dialogue_finished(dialogue: Dictionary) -> void:
	if StoryState_ != null:
		StoryState_.mark_dialogue_seen(String(dialogue.get("id", "")))
	if StoryDialogueDB_ != null:
		StoryDialogueDB_.apply_effects(dialogue.get("on_finish", {}))
