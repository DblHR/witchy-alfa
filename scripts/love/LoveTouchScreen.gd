class_name LoveTouchScreen
extends CanvasLayer
## Экран прикосновений: клик по чибику героини в доме (если у неё есть такой экран — пока Фуфу).
## Вместо VN-меню взаимодействий — фон и героиня крупно; окно диалога появляется только как реакция
## (обнимашки, подарок, отказ).
##
##  • Фон больше экрана и чуть плавает от курсора (DRIFT_BG), героиня — меньше (DRIFT_BODY);
##    героиня «дышит» (BREATH_*), в обычной позе иногда моргает (touch.json -> blink).
##  • Кнопки слева: действия (как в VN: закрытые — «(с N ур.)», доверие раз в день), подарки, «Уйти».
##    Обнимашки — сценка в окне диалога (реплики и картинка из interactions.json), потом экран как был;
##    остальные — поза на пару секунд (touch.json -> buttons).
##  • Касания мышью по зонам на картинке (touch.json -> touches, зоны — сцена <id>_touch.tscn):
##    над зоной, которой можно коснуться, курсор — рука. Сколько рук — кругляшки справа внизу.
##    Поза держится, пока не сменить число рук или не кликнуть мимо зон. Щёки двумя руками:
##    зажать и потянуть в сторону — pull_pose, отпустить или вернуть курсор — снова pose.
##  • Кнопка-глаз — спрятать / показать кнопки.
##  • Влюблённое настроение (Mood.LOVE) — снизу вверх по экрану летят сердечки (hearts_*).
##  • ВРЕМЕННО (отладка): клик по смайлику настроения — на пару секунд «72 / 100».
## Сцена героини: scenes/love/<id>_touch.tscn (Background, Body, Body/Zones/<зона>: Polygon2D).
## Настройки: assets/characters/<id>/love/touch.json.

signal closed

const SCENE := "res://scenes/love/LoveTouch.tscn"
const CHAR_SCENE := "res://scenes/love/%s_touch.tscn"
const TOUCH_FILE := "res://assets/characters/%s/love/touch.json"
const STANDARD := "standart"
const WINK := "wink"

## Насколько плавают от курсора (пиксели, курсор у края экрана): фон — больше, героиня — меньше.
const DRIFT_BG := Vector2(90, 45)
const DRIFT_BODY := Vector2(26, 12)
const DRIFT_SMOOTH := 3.0
## Дыхание: период (с) и насколько растягивается по высоте / сжимается по ширине.
const BREATH_PERIOD := 3.4
const BREATH_Y := 0.009
const BREATH_X := 0.004
## Руки (кругляшки): яркость включённой / выключенной.
const HAND_ON := 1.0
const HAND_OFF := 0.3
## Отладка: сколько секунд видно число настроения после клика по смайлику.
const MOOD_DEBUG_TIME := 2.5

## Сердечки при влюблённом настроении: раз в hearts_every (от..до) с,
## летят hearts_rise (от..до) с снизу через весь экран, размер hearts_size (от..до) пикселей.
@export var hearts_every := Vector2(0.55, 1.0)
@export var hearts_rise := Vector2(4.5, 6.5)
@export var hearts_size := Vector2(34, 70)
@export var hearts_spread := 520.0   ## насколько от центра Фуфу по горизонтали
@export var hearts_alpha := 0.8

@onready var world: Node2D = $World
@onready var ui: Control = $UI
@onready var hide_button: TextureButton = %HideButton
@onready var actions_box: VBoxContainer = %Actions
@onready var action_template: Button = %ActionTemplate
@onready var mood_icon: TextureRect = %MoodIcon
@onready var hands_box: Control = %Hands
@onready var hand_left: Button = %HandLeft
@onready var hand_right: Button = %HandRight
@onready var fade: ColorRect = $Fade
@onready var hearts_layer: Node2D = $Hearts
@onready var mood_debug: Label = %MoodDebug

var char_id := ""
var hands := 1
var pose := STANDARD

var _cfg: Dictionary = {}
var _char: Node2D
var _bg: Sprite2D
var _body: Sprite2D
var _zones: Node2D
var _bg_home := Vector2.ZERO
var _body_home := Vector2.ZERO
var _time := 0.0
var _blink_left := 3.0
var _blink_on := 0.0
var _pose_left := 0.0      ## поза от кнопки: сколько ещё держать
var _touch: Dictionary = {} ## касание, от которого сейчас поза
var _pressing := false
var _press_pos := Vector2.ZERO
var _hearts_left := 0.0
var _ui_hidden := false
var _closing := false
var _tex_cache: Dictionary = {}

## Есть ли у героини экран прикосновений.
static func supports(id: String) -> bool:
	return ResourceLoader.exists(CHAR_SCENE % id) and FileAccess.file_exists(TOUCH_FILE % id)

## Открыть поверх host (дом). Закрылся — сигнал closed.
static func open(host: Node, id: String) -> LoveTouchScreen:
	var s := (load(SCENE) as PackedScene).instantiate() as LoveTouchScreen
	s.char_id = id
	host.add_child(s)
	return s

func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(TOUCH_FILE % char_id))
	_cfg = parsed if parsed is Dictionary else {}
	_char = (load(CHAR_SCENE % char_id) as PackedScene).instantiate() as Node2D
	world.add_child(_char)
	_bg = _char.get_node_or_null("Background") as Sprite2D
	_body = _char.get_node("Body") as Sprite2D
	_zones = _body.get_node_or_null("Zones") as Node2D
	if _zones != null:
		_zones.visible = false   ## зоны видны только в редакторе
	_bg_home = _bg.position if _bg != null else Vector2.ZERO
	_body_home = _body.position
	action_template.visible = false
	ui.gui_input.connect(_on_ui_input)
	hide_button.pressed.connect(_toggle_ui)
	hand_left.pressed.connect(_toggle_hands)
	hand_right.pressed.connect(_toggle_hands)
	mood_icon.gui_input.connect(_on_mood_input)
	mood_debug.visible = false
	_blink_left = _blink_interval()
	_set_pose(STANDARD)
	_refresh_hands()
	_refresh_ui()
	fade.modulate.a = 1.0
	fade.visible = true
	create_tween().tween_property(fade, "modulate:a", 0.0, 0.3)

func close() -> void:
	if _closing:
		return
	_closing = true
	CursorFx_.set_touch_cursor(false)
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, 0.25)
	t.tween_callback(func() -> void:
		closed.emit()
		queue_free())

func _exit_tree() -> void:
	CursorFx_.set_touch_cursor(false)

# --- Кнопки ------------------------------------------------------------------------

func _refresh_ui() -> void:
	for c in actions_box.get_children():
		if c != action_template:
			actions_box.remove_child(c)   ## сразу из списка: новые кнопки — с теми же именами
			c.queue_free()
	var entries: Array = Interactions.choice_entries(char_id) + Gifts.choice_entries(char_id)
	entries.append({"text": "Уйти", "leave": true})
	for e in entries:
		var b := action_template.duplicate() as Button
		b.visible = true
		b.name = "Action_" + String(e.get("interaction", e.get("gift", "leave")))
		HeartText.button(b, String(e.get("text", "")))
		b.disabled = bool(e.get("disabled", false))
		var entry: Dictionary = e
		b.pressed.connect(func() -> void: _on_action(entry))
		actions_box.add_child(b)
	var tex: Texture2D = Mood.icon(char_id) if Mood.has_mood(char_id) else null
	mood_icon.texture = tex
	mood_icon.visible = tex != null and not _ui_hidden

func _on_action(e: Dictionary) -> void:
	if _busy():
		return
	if bool(e.get("leave", false)):
		close()
		return
	if e.has("gift"):
		_give(String(e["gift"]))
		return
	var id := String(e.get("interaction", ""))
	if not _try(id):
		return
	var b: Dictionary = (_cfg.get("buttons", {}) as Dictionary).get(id, {})
	if b.is_empty():
		_play_scene(id)   ## обнимашки — сценка в окне диалога
		return
	_touch = {}
	_set_pose(String(b.get("pose", STANDARD)))
	_pose_left = float(b.get("hold", 2.0))

## Подарок: из сумки, доверие и настроение, реплики благодарности.
func _give(item_id: String) -> void:
	var gained := Gifts.give(char_id, item_id)
	if gained < 0:
		return
	if gained > 0:
		_toast("+%d ♥ доверие" % gained)
	_refresh_ui.call_deferred()
	_say(Gifts.lines(char_id, item_id))

## Можно ли действие: закрыто — нет; первый раз за день — может отказаться (настроение).
## Получилось — доверие (раз в день) и надпись.
func _try(action_id: String) -> bool:
	if not Interactions.can_do(char_id, action_id):
		return false
	if Interactions.state(char_id, action_id) == Interactions.State.OK and Mood.refuses(char_id):
		_reset_pose()
		_say(Mood.refuse_lines(char_id))
		return false
	var gained := Interactions.perform(char_id, action_id)
	if gained < 0:
		return false
	if gained > 0:
		_toast("+%d ♥ доверие" % gained)
		_refresh_ui.call_deferred()   ## кнопку как раз нажали — пересобрать после
	return true

func _play_scene(action_id: String) -> void:
	_reset_pose()
	_say(Interactions.scene_lines(char_id, action_id))

## Реплики в окне диалога (без портретов — героиня и так на экране), потом — обычная поза.
func _say(lines: Array) -> void:
	if lines.is_empty():
		return
	var out: Array = []
	for l in lines:
		if l is Dictionary:
			var d := (l as Dictionary).duplicate(true)
			d["no_portraits"] = true
			out.append(d)
	CursorFx_.set_touch_cursor(false)
	DialogueManager_.show_sequence(out, func() -> void:
		_reset_pose()
		_refresh_ui())

func _busy() -> bool:
	return _closing or DialogueManager_.is_showing()

func _toggle_ui() -> void:
	_ui_hidden = not _ui_hidden
	actions_box.visible = not _ui_hidden
	hands_box.visible = not _ui_hidden
	mood_icon.visible = not _ui_hidden and mood_icon.texture != null
	hide_button.modulate.a = 0.5 if _ui_hidden else 1.0

# --- Руки ------------------------------------------------------------------------

func _toggle_hands() -> void:
	set_hands(2 if hands == 1 else 1)

func set_hands(n: int) -> void:
	if n == hands:
		return
	hands = n
	_refresh_hands()
	_reset_pose()

func _refresh_hands() -> void:
	hand_right.modulate.a = HAND_ON
	hand_left.modulate.a = HAND_ON if hands == 2 else HAND_OFF

# --- Касания ------------------------------------------------------------------------

func _on_ui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mpos := (event as InputEventMouseMotion).position
		if _pressing:
			drag_to(mpos)
		_update_cursor(mpos)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if (event as InputEventMouseButton).pressed:
			press_at((event as InputEventMouseButton).position)
		else:
			release()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _busy():
		get_viewport().set_input_as_handled()
		close()

## Нажали мышью в точке экрана: зона — поза касания, мимо зон — обычная поза.
func press_at(pos: Vector2) -> void:
	if _busy():
		return
	var rule := touch_at(pos)
	if rule.is_empty():
		_reset_pose()
		return
	if not _try(String(rule.get("action", ""))):
		return
	_touch = rule
	_pose_left = 0.0
	_pressing = true
	_press_pos = pos
	_set_pose(String(rule.get("pose", STANDARD)))

func release() -> void:
	_pressing = false
	if not _touch.is_empty() and pose == String(_touch.get("pull_pose", "")):
		_set_pose(String(_touch.get("pose", STANDARD)))

## Тянут с зажатой кнопкой: отвели в сторону дальше pull_distance — pull_pose, вернули — pose.
func drag_to(pos: Vector2) -> void:
	if not _pressing or not _touch.has("pull_pose") or _busy():
		return
	var far := absf(pos.x - _press_pos.x) >= float(_cfg.get("pull_distance", 45))
	var want := String(_touch["pull_pose"]) if far else String(_touch.get("pose", STANDARD))
	if pose != want:
		_set_pose(want)

## Какое касание в точке (с учётом числа рук и открытых действий); нет — {}.
func touch_at(pos: Vector2) -> Dictionary:
	if _zones == null:
		return {}
	for r in _cfg.get("touches", []):
		if not (r is Dictionary):
			continue
		var need := int(r.get("hands", 0))
		if need != 0 and need != hands:
			continue
		if not Interactions.can_do(char_id, String(r.get("action", ""))):
			continue
		var z := _zones.get_node_or_null(String(r.get("zone", ""))) as Polygon2D
		if z == null:
			continue
		var local := z.get_global_transform().affine_inverse() * pos
		if Geometry2D.is_point_in_polygon(local, z.polygon):
			return r
	return {}

func _update_cursor(pos: Vector2) -> void:
	CursorFx_.set_touch_cursor(not _busy() and not touch_at(pos).is_empty())

# --- Позы, моргание, дыхание, «плавание» ---------------------------------------------

func _set_pose(p: String) -> void:
	pose = p
	_blink_on = 0.0
	var tex := _pose_tex(p)
	if tex != null:
		_body.texture = tex

func _reset_pose() -> void:
	_touch = {}
	_pressing = false
	_pose_left = 0.0
	if pose != STANDARD:
		_set_pose(STANDARD)

func _pose_tex(p: String) -> Texture2D:
	if _tex_cache.has(p):
		return _tex_cache[p]
	var path := String(_cfg.get("pose_path", "")) % p if String(_cfg.get("pose_path", "")).contains("%s") else ""
	var tex: Texture2D = load(path) as Texture2D if path != "" and ResourceLoader.exists(path) else null
	_tex_cache[p] = tex
	return tex

func _blink_interval() -> float:
	var ev: Array = (_cfg.get("blink", {}) as Dictionary).get("every", [3.0, 5.0])
	return randf_range(float(ev[0]), float(ev[ev.size() - 1]))

func _process(delta: float) -> void:
	_time += delta
	# Поза от кнопки — на время.
	if _pose_left > 0.0:
		_pose_left -= delta
		if _pose_left <= 0.0:
			_reset_pose()
	# Влюблена — летят сердечки.
	if Mood.state(char_id) == Mood.LOVE:
		_hearts_left -= delta
		if _hearts_left <= 0.0:
			_hearts_left = randf_range(hearts_every.x, hearts_every.y)
			_spawn_heart()
	# Моргание — только в обычной позе.
	if pose == STANDARD:
		if _blink_on > 0.0:
			_blink_on -= delta
			if _blink_on <= 0.0:
				_body.texture = _pose_tex(STANDARD)
		else:
			_blink_left -= delta
			if _blink_left <= 0.0 and _pose_tex(WINK) != null:
				_body.texture = _pose_tex(WINK)
				_blink_on = float((_cfg.get("blink", {}) as Dictionary).get("duration", 0.16))
				_blink_left = _blink_interval()
	# Плавает от курсора: фон сильнее, героиня слабее.
	var vp := get_viewport().get_visible_rect().size
	var m := (get_viewport().get_mouse_position() - vp * 0.5) / (vp * 0.5)
	m = m.clamp(Vector2(-1, -1), Vector2(1, 1))
	var k := clampf(delta * DRIFT_SMOOTH, 0.0, 1.0)
	if _bg != null:
		_bg.position = _bg.position.lerp(_bg_home - m * DRIFT_BG, k)
	_body.position = _body.position.lerp(_body_home - m * DRIFT_BODY, k)
	# Дышит: чуть вытягивается вверх от низа картинки.
	var s := 0.5 + 0.5 * sin(_time * TAU / BREATH_PERIOD)
	_body.scale = Vector2(1.0 - BREATH_X * s, 1.0 + BREATH_Y * s)

# --- Сердечки (влюблённое настроение) ---------------------------------------------

## Одно сердечко: снизу из-за края, по-над Фуфу, вверх через весь экран, чуть покачиваясь.
func _spawn_heart() -> void:
	var tex := HeartText.icon()
	if tex == null:
		return
	var s := Sprite2D.new()
	s.texture = tex
	var px := randf_range(hearts_size.x, hearts_size.y)
	s.scale = Vector2.ONE * px / float(tex.get_width())
	var x := 960.0 + randf_range(-hearts_spread, hearts_spread)
	s.position = Vector2(x, 1080.0 + px)
	s.modulate.a = 0.0
	s.rotation = randf_range(-0.25, 0.25)
	hearts_layer.add_child(s)
	var t := randf_range(hearts_rise.x, hearts_rise.y)
	var sway := randf_range(30.0, 70.0) * (1.0 if randf() < 0.5 else -1.0)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position:y", -px, t)
	tw.tween_method(func(k: float) -> void:
		s.position.x = x + sin(k * TAU * 1.5) * sway, 0.0, 1.0, t)
	tw.tween_property(s, "modulate:a", hearts_alpha, 0.6)
	tw.tween_property(s, "modulate:a", 0.0, 0.8).set_delay(t - 0.8)
	tw.chain().tween_callback(s.queue_free)

# --- Отладка: число настроения по клику на смайлик (ВРЕМЕННО) -------------------------

func _on_mood_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		show_mood_debug()

func show_mood_debug() -> void:
	mood_debug.text = "%d / %d" % [Mood.value(char_id), Mood.MAX_VALUE]
	mood_debug.visible = true
	mood_debug.modulate.a = 1.0
	var tw := mood_debug.create_tween()
	tw.tween_interval(MOOD_DEBUG_TIME)
	tw.tween_property(mood_debug, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func() -> void: mood_debug.visible = false)

# --- Надпись «+N ♥ доверие» ---------------------------------------------------------

func _toast(text: String) -> void:
	var l := HeartText.rich(text, 38)
	l.add_theme_color_override("default_color", Color(1.0, 0.55, 0.8))
	l.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.25))
	l.add_theme_constant_override("outline_size", 8)
	ui.add_child(l)
	l.reset_size()
	l.position = Vector2(960.0 - l.size.x * 0.5, 180.0)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", 110.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(1.1)
	t.chain().tween_callback(l.queue_free)
