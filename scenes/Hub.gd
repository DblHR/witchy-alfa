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
	call_deferred("_play_pending_story_dialogue")

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
