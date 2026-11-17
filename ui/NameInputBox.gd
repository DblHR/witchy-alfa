extends Control
class_name NameInputBox
## Окно «придумай имя» по центру экрана (в стиле ItemNotice): заголовок, поле ввода, кнопка «Готово».
## Пустое поле — берётся подсказка (default). Имя сохраняется в StoryState_ (set_custom_name).
##
## В диалогах показывается само: поле реплики "ask_name" — см. QUEST_DIALOGUE_README.md.
## Из кода:
##   NameInputBox.ask(parent, "rikka_flower", "Как назовём цветок?", "Игорь", func(name): ...)

signal closed(chosen: String)

const SCREEN := Vector2(1920, 1080)
const PANEL_MIN := Vector2(620, 0)
const MAX_LEN := 20
const FADE := 0.18

static var _shader: Shader

var key := ""
var default_name := ""
var _edit: LineEdit
var _ok: Button
var _closing := false

static func ask(parent: Node, p_key: String, title: String, p_default: String = "", on_closed: Callable = Callable()) -> NameInputBox:
	var n := NameInputBox.new()
	n.key = p_key
	n.default_name = p_default
	n._build(title)
	if on_closed.is_valid():
		n.closed.connect(on_closed, CONNECT_ONE_SHOT)
	parent.add_child(n)
	return n

func _build(title: String) -> void:
	name = "NameInputBox"
	position = Vector2.ZERO
	size = SCREEN
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = ItemNotice.BLUR_SHADER
	var blur := ColorRect.new()
	blur.position = Vector2(-2000, -1000)
	blur.size = SCREEN + Vector2(4000, 2000)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	blur.material = mat
	add_child(blur)

	var center := CenterContainer.new()
	center.size = SCREEN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.14, 0.94)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.72, 0.92, 0.9)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 30
	sb.content_margin_bottom = 30
	sb.shadow_color = Color(1.0, 0.45, 0.85, 0.35)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 32)
	head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.94))
	box.add_child(head)

	_edit = LineEdit.new()
	_edit.max_length = MAX_LEN
	_edit.placeholder_text = default_name
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.custom_minimum_size = Vector2(PANEL_MIN.x - 96, 64)
	_edit.add_theme_font_size_override("font_size", 34)
	_edit.add_theme_color_override("font_color", Color(1, 1, 1))
	_edit.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.35))
	_edit.add_theme_color_override("caret_color", Color(1.0, 0.8, 0.94))
	var eb := StyleBoxFlat.new()
	eb.bg_color = Color(0.20, 0.10, 0.26, 1.0)
	eb.set_corner_radius_all(14)
	eb.set_border_width_all(2)
	eb.border_color = Color(1.0, 0.72, 0.92, 0.6)
	eb.content_margin_left = 16
	eb.content_margin_right = 16
	_edit.add_theme_stylebox_override("normal", eb)
	_edit.add_theme_stylebox_override("focus", eb)
	_edit.text_submitted.connect(func(_t: String) -> void: _confirm())
	box.add_child(_edit)

	var hint := Label.new()
	hint.text = "Пустое поле — «%s»" % default_name if default_name != "" else "Впишите имя"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.55)
	box.add_child(hint)

	var row := CenterContainer.new()
	box.add_child(row)
	_ok = Button.new()
	_ok.text = "Готово"
	_ok.custom_minimum_size = Vector2(240, 60)
	ShopUi.style_button(_ok, 28)
	_ok.pressed.connect(_confirm)
	row.add_child(_ok)
	modulate.a = 0.0

func _ready() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 1.0, FADE)
	_edit.grab_focus.call_deferred()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()   ## клики мимо окна не проходят в диалог под ним

## Выбранное имя (пустое поле — подсказка).
func chosen_name() -> String:
	var t := _edit.text.strip_edges()
	return t if t != "" else default_name

func set_text(t: String) -> void:
	_edit.text = t

func _confirm() -> void:
	if _closing:
		return
	_closing = true
	var chosen := chosen_name()
	if StoryState_ != null and key != "":
		StoryState_.set_custom_name(key, chosen)
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(func() -> void:
		closed.emit(chosen)
		queue_free())
