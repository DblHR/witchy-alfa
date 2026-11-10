extends Control
class_name UltButton
## Круглая кнопка ульты героя: портрет в круге, вокруг — золотое кольцо заряда.
## Заряд заполняется плавно. Когда он полный: вспышка и расходящееся кольцо, потом под кругом
## клубится золотой туман (шейдер на шуме) и изредка поднимаются искры. После ульты туман гаснет.
## Клик шлёт сигнал pressed, а решает, можно ли сейчас жать, CardBattle.

signal pressed(button: UltButton)

const BUTTON_SIZE := 96.0
const RING_WIDTH := 8.0
const PORTRAIT_INSET := 12.0
const READY_COLOR := Color(1.0, 0.88, 0.35, 1.0)
## Цвет заряда (до полного): золото потемнее.
const CHARGE_COLOR := Color(0.95, 0.72, 0.22, 1.0)
## Скорость заполнения кольца (доля круга в секунду).
const FILL_SPEED := 0.9
## Туман под кругом: сторона квадрата и время появления/угасания.
const FOG_SIZE := 210.0
const FOG_FADE_IN := 0.8
const FOG_FADE_OUT := 0.7
## Вспышка при полном заряде: длительность и насколько расходится кольцо.
const BURST_TIME := 0.7
const BURST_RING_GROW := 46.0

## Золотой туман: клубящийся шум (fbm), закрученный вокруг центра, с мягким краем.
const FOG_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 deep : source_color = vec4(0.95, 0.55, 0.10, 1.0);
uniform vec4 light : source_color = vec4(1.0, 0.92, 0.55, 1.0);
uniform float strength = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
	return v;
}
void fragment() {
	vec2 p = UV - vec2(0.5);
	float r = length(p) * 2.0;
	float t = TIME * 0.22;
	float sw = t + r * 1.8;                       // закрутка: дальше от центра — сильнее
	mat2 rot = mat2(vec2(cos(sw), sin(sw)), vec2(-sin(sw), cos(sw)));
	vec2 q = rot * p * 5.0;
	float fog = fbm(q + vec2(t * 0.9, -t * 0.6)) * 0.65 + fbm(q * 1.7 - vec2(t * 0.7)) * 0.35;
	float edge = 1.0 - smoothstep(0.4, 1.0, r);   // мягкий внешний край
	float breathe = 0.85 + 0.15 * sin(TIME * 1.7);
	float a = edge * smoothstep(0.22, 0.72, fog) * 0.9;
	a += (1.0 - smoothstep(0.35, 0.8, r)) * 0.45;  // ровное свечение у самого круга
	a = clamp(a * strength * breathe, 0.0, 0.92);
	COLOR = vec4(mix(deep.rgb, light.rgb, clamp(fog * 1.3 - 0.1, 0.0, 1.0)), a);
}
"""

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
static var _fog_shader: Shader
static var _spark_texture: Texture2D

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
## Показанная доля заряда (догоняет настоящую — кольцо заполняется плавно).
var _shown_ratio := 0.0
var _fog: ColorRect
var _fog_material: ShaderMaterial
var _fog_tween: Tween
var _sparks: CPUParticles2D
var _fx: Control
## Время с начала вспышки полного заряда; < 0 — вспышки нет.
var _burst_t := -1.0
## Заряд стал полным — вспышка, как только кольцо дозаполнится.
var _burst_pending := false

func setup(p_unit: Unit, p_ult: CardInstance, tex: Texture2D) -> void:
	unit = p_unit
	ult = p_ult
	max_charge = maxi(1, p_ult.cost)
	custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	size = custom_minimum_size
	pivot_offset = size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	_build_fog()
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

	# Вспышка и расходящееся кольцо — поверх портрета.
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.size = size
	_fx.draw.connect(_draw_fx)
	add_child(_fx)

	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	set_state(0, true)

func is_ready() -> bool:
	return alive and charge >= max_charge

## Туман и искры под кругом (рисуются позади кнопки — show_behind_parent).
func _build_fog() -> void:
	if _fog_shader == null:
		_fog_shader = Shader.new()
		_fog_shader.code = FOG_SHADER_CODE
	_fog_material = ShaderMaterial.new()
	_fog_material.shader = _fog_shader
	_fog_material.set_shader_parameter("strength", 0.0)
	_fog = ColorRect.new()
	_fog.name = "UltFog"
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fog.show_behind_parent = true
	_fog.size = Vector2(FOG_SIZE, FOG_SIZE)
	_fog.position = Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.5 - _fog.size * 0.5
	_fog.material = _fog_material
	_fog.visible = false
	add_child(_fog)

	if _spark_texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 16
		gt.height = 16
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		_spark_texture = gt
	_sparks = CPUParticles2D.new()
	_sparks.name = "UltSparks"
	_sparks.show_behind_parent = true
	_sparks.position = Vector2(BUTTON_SIZE, BUTTON_SIZE) * 0.5
	_sparks.texture = _spark_texture
	_sparks.emitting = false
	_sparks.amount = 7
	_sparks.lifetime = 1.8
	_sparks.randomness = 0.6
	_sparks.local_coords = false
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	_sparks.emission_sphere_radius = BUTTON_SIZE * 0.42
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 25.0
	_sparks.gravity = Vector2(0, -22)
	_sparks.initial_velocity_min = 10.0
	_sparks.initial_velocity_max = 28.0
	_sparks.scale_amount_min = 0.25
	_sparks.scale_amount_max = 0.55
	var fade := Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
	fade.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	fade.add_point(0.15, Color(1.0, 0.92, 0.6, 1.0))
	fade.add_point(0.7, Color(1.0, 0.75, 0.3, 0.7))
	_sparks.color_ramp = fade
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_sparks.material = add
	add_child(_sparks)

## Туман и искры: появиться (полный заряд) или погаснуть (ульта сыграна / героиня пала).
func _set_glow(on: bool) -> void:
	if _fog_tween != null:
		_fog_tween.kill()
	_sparks.emitting = on
	var start_v := float(_fog_material.get_shader_parameter("strength"))
	if on:
		_fog.visible = true
	_fog_tween = create_tween()
	_fog_tween.tween_method(func(v: float) -> void: _fog_material.set_shader_parameter("strength", v),
		start_v, 1.0 if on else 0.0, FOG_FADE_IN if on else FOG_FADE_OUT)
	if not on:
		_fog_tween.tween_callback(func() -> void: _fog.visible = false)

func set_state(p_charge: int, p_alive: bool) -> void:
	var was_ready := is_ready()
	charge = clampi(p_charge, 0, max_charge)
	alive = p_alive
	_count_label.text = "%d/%d" % [charge, max_charge]
	if _material != null:
		_material.set_shader_parameter("gray", 0.0 if alive else 1.0)
	modulate = Color.WHITE if alive else Color(0.7, 0.7, 0.7, 0.8)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if is_ready() else Control.CURSOR_ARROW
	tooltip_text = "%s — %s\nЗаряд: %d/%d\n%s" % [ult.owner_name, ult.title, charge, max_charge, ult.plain_description()]
	var now_ready := is_ready()
	if now_ready and not was_ready:
		_burst_pending = true
	elif was_ready and not now_ready:
		_burst_pending = false
		_set_glow(false)
	if not alive:
		_shown_ratio = 0.0
	queue_redraw()

func _on_hover(inside: bool) -> void:
	scale = Vector2(1.07, 1.07) if (inside and is_ready()) else Vector2.ONE

func _process(delta: float) -> void:
	_time += delta
	var target := clampf(float(charge) / float(max_charge), 0.0, 1.0)
	_shown_ratio = move_toward(_shown_ratio, target, FILL_SPEED * delta)
	if _burst_pending and _shown_ratio >= target:
		_burst_pending = false
		_burst_t = 0.0
		_set_glow(true)
	if _burst_t >= 0.0:
		_burst_t += delta
		if _burst_t > BURST_TIME:
			_burst_t = -1.0
		_fx.queue_redraw()
	queue_redraw()

## Вспышка полного заряда: круг заливает светом, золотое кольцо расходится и тает.
func _draw_fx() -> void:
	if _burst_t < 0.0:
		return
	var k := clampf(_burst_t / BURST_TIME, 0.0, 1.0)
	var center := size * 0.5
	var radius := BUTTON_SIZE * 0.5 - RING_WIDTH * 0.5 - 1.0
	var flash := 1.0 - clampf(k * 2.5, 0.0, 1.0)
	if flash > 0.0:
		_fx.draw_circle(center, radius, Color(1.0, 0.96, 0.78, 0.75 * flash))
	var ease_k := 1.0 - pow(1.0 - k, 3.0)
	var ring_r := radius + BURST_RING_GROW * ease_k
	_fx.draw_arc(center, ring_r, 0.0, TAU, 72, Color(1.0, 0.86, 0.4, 0.9 * (1.0 - k)), lerpf(7.0, 1.5, k), true)

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
	var ratio := _shown_ratio
	if ratio > 0.001:
		var col := CHARGE_COLOR
		if ready and ratio >= 0.999:
			col = READY_COLOR.lerp(Color.WHITE, pulse * 0.4)
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, col, RING_WIDTH, true)
		# Блик на кончике заполняющейся дуги.
		if ratio < 0.999:
			var tip := -PI * 0.5 + TAU * ratio
			draw_circle(center + Vector2(cos(tip), sin(tip)) * radius, RING_WIDTH * 0.55, Color(1.0, 0.95, 0.75, 0.9))
	# Риски между делениями заряда.
	if max_charge > 1:
		for i in range(max_charge):
			var a := -PI * 0.5 + TAU * float(i) / float(max_charge)
			var dir := Vector2(cos(a), sin(a))
			draw_line(center + dir * (radius - RING_WIDTH * 0.5), center + dir * (radius + RING_WIDTH * 0.5), Color(0.05, 0.03, 0.08, 0.9), 2.0)
