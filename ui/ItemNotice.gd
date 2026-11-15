extends Control
class_name ItemNotice
## Уведомление по центру экрана: «Получено: <предмет>» с картинкой (или любое своё: заголовок,
## текст, картинка). Всё под ним размывается и затемняется; клик / пробел / Enter — закрыть.
##
## В диалогах показывается само: поле реплики "give_item" (предмет выдаётся в этот момент)
## или "notice" (просто сообщение) — см. QUEST_DIALOGUE_README.md.
## Из кода:
##   ItemNotice.show_item(parent, "gift", 1, func(): ...)            # предмет из RunItems
##   ItemNotice.show_notice(parent, "Новое поручение", "Найти наушники", icon, func(): ...)

signal closed

const SCREEN := Vector2(1920, 1080)
const PANEL_MIN := Vector2(560, 0)
const ICON_SIZE := Vector2(190, 190)
const FADE := 0.18
## Сколько секунд после появления клики не закрывают окно (чтобы не проскочить случайно).
const CLICK_GUARD := 0.35

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float blur_px = 10.0;
uniform vec4 tint : source_color = vec4(0.05, 0.02, 0.09, 0.45);
void fragment() {
	// Размытие выборками по кругу (работает в любом рендерере), сверху — затемнение.
	vec2 px = SCREEN_PIXEL_SIZE * blur_px;
	vec3 col = texture(screen_texture, SCREEN_UV).rgb;
	float total = 1.0;
	for (int ring = 1; ring <= 3; ring++) {
		float rr = float(ring) / 3.0;
		for (int i = 0; i < 8; i++) {
			float a = float(i) * 0.7854 + rr * 0.6;
			col += texture(screen_texture, SCREEN_UV + vec2(cos(a), sin(a)) * px * rr).rgb;
			total += 1.0;
		}
	}
	col /= total;
	COLOR = vec4(mix(col, tint.rgb, tint.a), COLOR.a);
}
"""

static var _shader: Shader

var _age := 0.0
var _closing := false

## «Получено: <название предмета>» с его иконкой. Сам предмет НЕ выдаёт — только показывает.
static func show_item(parent: Node, item_id: String, amount: int = 1, on_closed: Callable = Callable()) -> ItemNotice:
	var item_name := RunItems.get_item_name(item_id)
	if amount > 1:
		item_name += " ×%d" % amount
	var icon: Texture2D = Inventory_.get_item_icon(item_id) if Inventory_ != null else null
	return show_notice(parent, "Получено:", item_name, icon, on_closed)

static func show_notice(parent: Node, title: String, text: String, icon: Texture2D = null, on_closed: Callable = Callable()) -> ItemNotice:
	var n := ItemNotice.new()
	n._build(title, text, icon)
	if on_closed.is_valid():
		n.closed.connect(on_closed, CONNECT_ONE_SHOT)
	parent.add_child(n)
	return n

func _build(title: String, text: String, icon: Texture2D) -> void:
	name = "ItemNotice"
	position = Vector2.ZERO
	size = SCREEN
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BLUR_SHADER
	var blur := ColorRect.new()
	blur.position = Vector2(-2000, -1000)
	blur.size = SCREEN + Vector2(4000, 2000)
	blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	blur.material = mat
	add_child(blur)

	var center := CenterContainer.new()
	center.position = Vector2.ZERO
	center.size = SCREEN
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = PANEL_MIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.05, 0.14, 0.94)
	sb.set_corner_radius_all(26)
	sb.set_border_width_all(3)
	sb.border_color = Color(1.0, 0.72, 0.92, 0.9)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 30
	sb.content_margin_bottom = 26
	sb.shadow_color = Color(1.0, 0.45, 0.85, 0.35)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	var head := Label.new()
	head.text = title
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 30)
	head.add_theme_color_override("font_color", Color(1.0, 0.8, 0.94))
	box.add_child(head)
	if icon != null:
		var pic := TextureRect.new()
		pic.texture = icon
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = ICON_SIZE
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(pic)
	if text != "":
		var body := Label.new()
		body.text = text
		body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(PANEL_MIN.x - 96, 0)
		body.add_theme_font_size_override("font_size", 36)
		box.add_child(body)
	var hint := Label.new()
	hint.text = "Нажмите, чтобы продолжить"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(1, 1, 1, 0.55)
	box.add_child(hint)

	modulate.a = 0.0

func _ready() -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 1.0, FADE)

func _process(delta: float) -> void:
	_age += delta

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		if event.button_index == MOUSE_BUTTON_LEFT:
			close()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		close()

func close() -> void:
	if _closing or _age < CLICK_GUARD:
		return
	_closing = true
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(self, "modulate:a", 0.0, FADE)
	tw.tween_callback(func() -> void:
		closed.emit()
		queue_free()
	)
