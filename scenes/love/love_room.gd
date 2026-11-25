extends Control
## Экран отношений с персонажем (открывается из сердечка в доме: LoveMenu → SceneRouter_.go_to_love).
## Сцена своя на каждого персонажа: scenes/love/<id>_love.tscn (сейчас fufu_love.tscn) —
## во весь экран карточка интеракций из assets/characters/<id>/interactive/, кнопка «Назад».
## Интерактив добавлять прямо в сцену персонажа.

@export var unit_id := ""
## Кнопка SexButton (если есть в сцене): меню сексуальных взаимодействий (InteractionMenu).
## Пока сцены не сделаны — от персонажа вылетает сердечко (из точки HeartFrom)
## и пузырь со случайной фразой отсюда (низ пузыря — точка BubbleAt).
@export var sex_lines: PackedStringArray = PackedStringArray(["И это всё?", "Уже закончили?", "Так быстро?"])
@export var heart_texture: Texture2D = preload("res://assets/ui/buttons/loveButton.png")
@export var heart_size := 72.0

@onready var back_button: TextureButton = %BackButton
@onready var sex_button: TextureButton = get_node_or_null("%SexButton") as TextureButton
@onready var heart_from: Node2D = get_node_or_null("HeartFrom") as Node2D
@onready var bubble_at: Node2D = get_node_or_null("BubbleAt") as Node2D

var _bubbles: BattleSpeechLayer
var _last_line := -1

func _ready() -> void:
	get_tree().paused = false
	back_button.pressed.connect(func() -> void: SceneRouter_.go_to_hub())
	if sex_button != null:
		sex_button.pressed.connect(_on_sex)
		_bubbles = BattleSpeechLayer.new()
		_bubbles.name = "LoveBubbles"
		_bubbles.bubble_offset = Vector2.ZERO
		_bubbles.bubble_min_width = NpcBubbles.BUBBLE_MIN_WIDTH
		_bubbles.bubble_max_width = NpcBubbles.BUBBLE_MAX_WIDTH
		_bubbles.bubble_font_px = NpcBubbles.BUBBLE_FONT_PX
		_bubbles.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bubbles)

## Нажали «SEX»: меню сексуальных взаимодействий (Interactions, kind "lewd"): открыты с 5 уровня
## доверия, каждое раз в день, дают доверие.
func _on_sex() -> void:
	var at := sex_button.get_global_rect().get_center() + Vector2(sex_button.size.x * 0.5 + 230.0, 0.0)
	var menu := InteractionMenu.open(self, unit_id, Interactions.KIND_LEWD, at)
	menu.chosen.connect(_on_lewd_chosen)

func _on_lewd_chosen(action_id: String) -> void:
	var gained := Interactions.perform(unit_id, action_id)
	if gained < 0:
		return
	play_lewd_scene(action_id)
	if gained > 0:   ## 0 — сегодня за это уже давали доверие
		var at := heart_from.position if heart_from != null else size * 0.5
		InteractionMenu.float_text(self, at + Vector2(0, -40), "+%d ♥ доверие" % gained)

## Сама сцена (поцелуй, тити, …). ПОКА ЗАГЛУШКА: сердечко и фраза в пузыре.
## Сюда подключать настоящие интерактивные сцены (action_id — id из data/interactions/interactions.json).
func play_lewd_scene(_action_id: String) -> void:
	_heart_and_line()

## Сердечко от персонажа и одна из фраз (не та же, что в прошлый раз).
func _heart_and_line() -> void:
	_fly_heart()
	if _bubbles == null or bubble_at == null or sex_lines.is_empty():
		return
	var i := randi() % sex_lines.size()
	if sex_lines.size() > 1 and i == _last_line:
		i = (i + 1 + randi() % (sex_lines.size() - 1)) % sex_lines.size()
	_last_line = i
	_bubbles.clear_lines()
	_bubbles.show_line_for_actor(bubble_at, sex_lines[i])

func _fly_heart() -> void:
	if heart_from == null or heart_texture == null:
		return
	var h := TextureRect.new()
	h.texture = heart_texture
	h.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	h.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.size = Vector2(heart_size, heart_size)
	h.pivot_offset = h.size * 0.5
	h.position = heart_from.position - h.size * 0.5
	h.scale = Vector2(0.3, 0.3)
	add_child(h)
	if _bubbles != null:
		move_child(_bubbles, -1)
	var drift := randf_range(-40.0, 40.0)
	var tw := h.create_tween().set_parallel(true)
	tw.tween_property(h, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "position:y", h.position.y - 230.0, 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(h, "position:x", h.position.x + drift, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "rotation", deg_to_rad(randf_range(-15.0, 15.0)), 1.3)
	tw.tween_property(h, "modulate:a", 0.0, 0.5).set_delay(0.8)
	tw.chain().tween_callback(h.queue_free)

func _unhandled_input(event: InputEvent) -> void:
	# Esc здесь — тоже «Назад» (пауза не нужна).
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		SceneRouter_.go_to_hub()
