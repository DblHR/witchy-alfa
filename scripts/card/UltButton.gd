extends Control
class_name UltButton
## Круглая кнопка ульты героя: портрет в круге, вокруг — кольцо заряда.
## Когда заряд полный, кольцо золотое и пульсирует. Клик шлёт сигнал pressed,
## а решает, можно ли сейчас жать, CardBattle.

signal pressed(button: UltButton)

const BUTTON_SIZE := 96.0
const RING_WIDTH := 8.0
const PORTRAIT_INSET := 12.0
const READY_COLOR := Color(1.0, 0.88, 0.35, 1.0)

## Один шейдер на все кнопки: круглая маска + кадрирование по лицу.
## center — центр лица в UV исходной картинки, side — сторона окна в долях ВЫСОТЫ картинки.
const CIRCLE_SHADER_CODE := """
shader_type canvas_item;
uniform float aspect = 1.0;            // ширина / высота текстуры
uniform vec2 center = vec2(0.5, 0.3);
uniform float side = 0.35;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 half_window = vec2(side / aspect, side) * 0.5;
	vec2 c = clamp(center, half_window, vec2(1.0) - half_window);
	vec2 tuv = c + (UV - vec2(0.5)) * vec2(side / aspect, side);
	vec4 col = texture(TEXTURE, tuv);
	float d = length(UV - vec2(0.5));
	col.a *= 1.0 - smoothstep(0.485, 0.5, d);
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g) * 0.55, gray);
	COLOR = col;
}
"""

## Где лицо на портретах из Setup (card_portrait): x, y — центр лица, z — размер окна
## (доля высоты картинки; меньше значение = крупнее лицо). Для нового героя добавьте строку.
const FACE_FOCUS := {
	"witch": Vector3(0.46, 0.27, 0.30),
	"warrior": Vector3(0.51, 0.16, 0.32),
	"aki": Vector3(0.60, 0.27, 0.32),
	"fufu": Vector3(0.445, 0.19, 0.30),
	"luisa": Vector3(0.51, 0.24, 0.30),
}
const FACE_DEFAULT := Vector3(0.5, 0.25, 0.40)

static var _circle_shader: Shader

var unit: Unit
var ult: CardInstance
var charge: int = 0
var max_charge: int = 1
var alive: bool = true

var _portrait: TextureRect
var _material: ShaderMaterial
var _count_label: Label
var _has_portrait := false
var _time := 0.0

func setup(p_unit: Unit, p_ult: CardInstance, tex: Texture2D) -> void:
	unit = p_unit
	ult = p_ult
	max_charge = maxi(1, p_ult.cost)
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_has_portrait = tex != null
	_portrait = TextureRect.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.position = Vector2(PORTRAIT_INSET, PORTRAIT_INSET)
	_portrait.size = Vector2(BUTTON_SIZE - PORTRAIT_INSET * 2.0, BUTTON_SIZE - PORTRAIT_INSET * 2.0)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.texture = tex
	_portrait.visible = _has_portrait
	if _has_portrait:
		if _circle_shader == null:
			_circle_shader = Shader.new()
			_circle_shader.code = CIRCLE_SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = _circle_shader
		_material.set_shader_parameter("aspect", float(tex.get_width()) / maxf(1.0, float(tex.get_height())))
		var face: Vector3 = FACE_FOCUS.get(p_ult.owner_id, FACE_DEFAULT)
		_material.set_shader_parameter("center", Vector2(face.x, face.y))
		_material.set_shader_parameter("side", face.z)
		_portrait.material = _material
	add_child(_portrait)

	_count_label = Label.new()
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.position = Vector2(0, BUTTON_SIZE - 38.0)
	_count_label.size = Vector2(BUTTON_SIZE, 26)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_count_label.add_theme_constant_override("outline_size", 6)
	add_child(_count_label)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	set_state(0, true)

func is_ready() -> bool:
	return alive and charge >= max_charge

func set_state(p_charge: int, p_alive: bool) -> void:
	charge = clampi(p_charge, 0, max_charge)
	alive = p_alive
	_count_label.text = "%d/%d" % [charge, max_charge]
	if _material != null:
		_material.set_shader_parameter("gray", 0.0 if alive else 1.0)
	modulate = Color.WHITE if alive else Color(0.7, 0.7, 0.7, 0.8)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_ready() else Control.CURSOR_ARROW
	tooltip_text = "%s — %s\nЗаряд: %d/%d\n%s" % [ult.owner_name, ult.title, charge, max_charge, ult.plain_description()]
	set_process(is_ready())
	queue_redraw()

func _on_hover(inside: bool) -> void:
	scale = Vector2(1.07, 1.07) if (inside and is_ready()) else Vector2.ONE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		pressed.emit(self)

func _draw() -> void:
	var center := size * 0.5
	var radius := BUTTON_SIZE * 0.5 - RING_WIDTH * 0.5 - 1.0
	var ready := is_ready()
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)

	if ready:
		draw_circle(center, radius + 5.0, Color(READY_COLOR.r, READY_COLOR.g, READY_COLOR.b, 0.10 + 0.20 * pulse))
	draw_circle(center, radius, Color(0.08, 0.05, 0.12, 0.88))
	if not _has_portrait:
		draw_circle(center, radius - 10.0, ult.color)

	draw_arc(center, radius, 0.0, TAU, 64, Color(0.12, 0.09, 0.20, 0.95), RING_WIDTH, true)
	var ratio := clampf(float(charge) / float(max_charge), 0.0, 1.0)
	if ratio > 0.0:
		var col := ult.color.lightened(0.35)
		if ready:
			col = READY_COLOR.lerp(Color.WHITE, pulse * 0.4)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, col, RING_WIDTH, true)
	# Риски между делениями заряда.
	if max_charge > 1:
		for i in range(max_charge):
			var a := -PI * 0.5 + TAU * float(i) / float(max_charge)
			var dir := Vector2(cos(a), sin(a))
			draw_line(center + dir * (radius - RING_WIDTH * 0.5), center + dir * (radius + RING_WIDTH * 0.5), Color(0.05, 0.03, 0.08, 0.9), 2.0)
