extends Node2D
class_name DreamScreen
## Экран сна (scenes/dreams/Dream.tscn): фон боевой локации в сонных тонах, сверху — название сна,
## таймер и опыт. Отсчёт countdown секунд (кнопки — подсказкой) → игра duration секунд →
## итог: опыт отряда (Dreams.xp_for, не больше xp_cap) → «Проснуться» — в дом (утро).
## Какой сон — SceneRouter_.dream_id (поставил дом или админка). «Проснуться» сверху — закончить раньше.

@onready var game_root: Node2D = $Game
@onready var title_label: Label = %TitleLabel
@onready var controls_label: Label = %ControlsLabel
@onready var timer_label: Label = %TimerLabel
@onready var xp_label: Label = %XpLabel
@onready var countdown_label: Label = %CountdownLabel
@onready var result_box: Control = %ResultBox
@onready var result_label: Label = %ResultLabel
@onready var wake_button: Button = %WakeButton
@onready var skip_button: Button = %SkipButton
@onready var fade: ColorRect = %Fade

var game: DreamGame
var dream_id := ""
var time_left := 0.0
var _finished := false

func _ready() -> void:
	dream_id = String(SceneRouter_.get("dream_id")) if SceneRouter_ != null else ""
	if dream_id == "" or Dreams.dream(dream_id).is_empty():
		dream_id = "witch"
	var cfg := Dreams.dream(dream_id)
	title_label.text = "Сон: " + String(cfg.get("title", dream_id))
	controls_label.text = String(cfg.get("controls", ""))
	result_box.visible = false
	wake_button.pressed.connect(_wake)
	skip_button.pressed.connect(_finish)
	game = Dreams.make_game(dream_id)
	if game == null:
		_finish()
		return
	game.screen = self
	game_root.add_child(game)
	game.build()
	game.points_changed.connect(_on_points)
	_on_points(0)
	time_left = float(cfg.get("duration", 30))
	_show_time()
	fade.modulate.a = 1.0
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.6)
	_countdown()

func _countdown() -> void:
	var n := int(Dreams.config().get("countdown", 3))
	controls_label.visible = true
	countdown_label.visible = true
	for i in range(n, 0, -1):
		countdown_label.text = str(i)
		countdown_label.pivot_offset = countdown_label.size * 0.5
		countdown_label.scale = Vector2(1.4, 1.4)
		countdown_label.create_tween().tween_property(countdown_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
		await get_tree().create_timer(1.0).timeout
		if _finished:
			return
	countdown_label.text = "Старт!"
	game.running = true
	var tw := countdown_label.create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(countdown_label, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void:
		countdown_label.visible = false
		countdown_label.modulate.a = 1.0)
	controls_label.create_tween().tween_property(controls_label, "modulate:a", 0.35, 1.5).set_delay(2.0)

func _process(delta: float) -> void:
	if game == null or not game.running or _finished:
		return
	time_left -= delta
	_show_time()
	if time_left <= 0.0:
		_finish()

## Отнять / добавить время (Аки попала в Фуфу — минус секунды).
func add_time(sec: float) -> void:
	time_left = maxf(0.0, time_left + sec)
	_show_time()
	if sec < 0.0:
		timer_label.modulate = Color(1, 0.4, 0.4)
		timer_label.create_tween().tween_property(timer_label, "modulate", Color.WHITE, 0.6)

func _show_time() -> void:
	timer_label.text = "%d" % ceili(maxf(0.0, time_left))

func _on_points(p: int) -> void:
	xp_label.text = "Опыт: +%d" % Dreams.xp_for(dream_id, p)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if game != null:
		game.running = false
	skip_button.visible = false
	countdown_label.visible = false
	var xp := Dreams.xp_for(dream_id, game.points if game != null else 0)
	var text := "Сон закончился\n+%d опыта отряда" % xp
	if xp > 0 and DungRun != null:
		var r: Dictionary = DungRun.gain_xp(xp)
		if int(r.get("levels", 0)) > 0:
			text += "\nУровень отряда %d!" % int(r.get("level", 0))
		if SaveManager_ != null:
			SaveManager_.save_game()
	result_label.text = text
	result_box.visible = true
	result_box.modulate.a = 0.0
	result_box.create_tween().tween_property(result_box, "modulate:a", 1.0, 0.4)

func _wake() -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(func() -> void: get_tree().change_scene_to_file(SceneRouter.HUB))
