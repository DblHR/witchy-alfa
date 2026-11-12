extends Node
class_name HubWanderer
## Оживляет персонажа на сцене дома: бродит влево-вправо, иногда стоит, разворачивается,
## подпрыгивает. Управляет любым Control с картинкой (TextureRect): двигает его position
## и переключает flip_h. Чтобы добавить ещё героиню — создать ещё один HubWanderer.
##
##   var w := HubWanderer.new()
##   w.setup(texture_rect, min_x, max_x)
##   add_child(w)

## Скорость ходьбы, px/с (в координатах 1920×1080).
const WALK_SPEED_MIN := 90.0
const WALK_SPEED_MAX := 150.0
## Сколько стоять между действиями, с.
const IDLE_MIN := 1.2
const IDLE_MAX := 3.5
## Шаг: лёгкое подпрыгивание при ходьбе.
const STEP_BOB := 7.0
const STEP_PERIOD := 0.32
## Прыжок.
const HOP_HEIGHT := 46.0
const HOP_TIME := 0.42
## Дыхание в покое (растяжение по вертикали).
const BREATH_SCALE := 0.012
const BREATH_PERIOD := 2.4
## Вероятности действий после паузы (остальное — пойти).
const CHANCE_HOP := 0.18
const CHANCE_TURN := 0.22
const CHANCE_DOUBLE_HOP := 0.35
## flip_h = true — смотрит вправо (как картинка стоит в сцене).
const FLIP_MEANS_RIGHT := true

var _body: TextureRect
var _min_x := 0.0
var _max_x := 0.0
var _base_y := 0.0
var _tween: Tween
var _bob: Tween
var _breath: Tween
var _alive := true
## Дыхание — растяжение в вершинном шейдере: не привязано к целым пикселям (scale у Control
## округляется до пикселя, отсюда были рывки).
var _breath_mat: ShaderMaterial
## glow — подсветка при наведении (у тех, с кем можно поговорить): светлее + золотой контур.
const BREATH_SHADER := """
shader_type canvas_item;
uniform float stretch = 0.0;
uniform float pivot_y = 0.0;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float glow_px = 9.0;
varying vec4 v_mod;
void vertex() {
	v_mod = COLOR;
	VERTEX.y = pivot_y + (VERTEX.y - pivot_y) * (1.0 + stretch);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (glow > 0.001) {
		float a = 0.0;
		vec2 px = TEXTURE_PIXEL_SIZE * glow_px;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5235988;
			vec2 d = vec2(cos(ang), sin(ang));
			a = max(a, texture(TEXTURE, UV + d * px).a);
			a = max(a, texture(TEXTURE, UV + d * px * 0.5).a);
		}
		float rim = clamp(a - c.a, 0.0, 1.0) * glow;
		vec3 lit = c.rgb * (1.0 + 0.10 * glow) + glow_color.rgb * 0.05 * glow;
		c = vec4(mix(lit, glow_color.rgb, rim * (1.0 - c.a)), max(c.a, rim * glow_color.a));
	}
	COLOR = c * v_mod;
}
"""
static var _breath_shader: Shader

func setup(body: TextureRect, min_x: float, max_x: float) -> void:
	_body = body
	_min_x = min_x
	_max_x = max_x
	_base_y = body.position.y
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.pivot_offset = Vector2(body.size.x * 0.5, body.size.y)   # качается и тянется от ног
	# Плавное масштабирование картинки (без «лесенки» при сжатии).
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _breath_shader == null:
		_breath_shader = Shader.new()
		_breath_shader.code = BREATH_SHADER
	_breath_mat = ShaderMaterial.new()
	_breath_mat.shader = _breath_shader
	_breath_mat.set_shader_parameter("pivot_y", body.size.y)
	if body.material == null:
		body.material = _breath_mat

func _ready() -> void:
	if _body == null:
		return
	_start_breath()
	_next_action(randf_range(0.3, 1.0))

func _exit_tree() -> void:
	_alive = false

# --- Для разговоров в доме: подсветка, попадание курсором, «замереть» -------------

var _glow_tween: Tween
var _glow := 0.0
static var _images: Dictionary = {}   ## текстура -> Image (для проверки прозрачности)

func set_glow(on: bool) -> void:
	if _breath_mat == null:
		return
	if _glow_tween != null:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(func(v: float) -> void:
		_glow = v
		_breath_mat.set_shader_parameter("glow", v), _glow, 1.0 if on else 0.0, 0.16)

## Курсор над непрозрачной частью картинки (не над пустым прямоугольником вокруг).
func is_over(global_point: Vector2) -> bool:
	if _body == null or _body.texture == null:
		return false
	var lp := _body.get_global_transform().affine_inverse() * global_point
	var tex_size := _body.texture.get_size()
	var k := minf(_body.size.x / tex_size.x, _body.size.y / tex_size.y)   ## KEEP_ASPECT_CENTERED
	var drawn := tex_size * k
	var p := (lp - (_body.size - drawn) * 0.5) / k
	if p.x < 0.0 or p.y < 0.0 or p.x >= tex_size.x or p.y >= tex_size.y:
		return false
	if _body.flip_h:
		p.x = tex_size.x - 1.0 - p.x
	var img: Image = _images.get(_body.texture, null)
	if img == null:
		img = _body.texture.get_image()
		if img == null:
			return true
		if img.is_compressed():
			img.decompress()
		_images[_body.texture] = img
	return img.get_pixel(int(p.x), int(p.y)).a > 0.25

## Остановиться (на время разговора) и продолжить.
func set_frozen(on: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT

func _next_action(delay: float) -> void:
	_kill(_tween)
	_tween = create_tween()
	_tween.tween_interval(delay)
	_tween.tween_callback(_choose)

func _choose() -> void:
	if not _alive or not is_instance_valid(_body):
		return
	var r := randf()
	if r < CHANCE_HOP:
		_hop(randf() < CHANCE_DOUBLE_HOP)
	elif r < CHANCE_HOP + CHANCE_TURN:
		_face(not _facing_right())
		_next_action(randf_range(IDLE_MIN * 0.6, IDLE_MAX * 0.6))
	else:
		_walk()

func _walk() -> void:
	var from := _body.position.x
	var target := randf_range(_min_x, _max_x)
	# Не топтаться на месте: шаг хотя бы 120 px.
	if absf(target - from) < 120.0:
		target = clampf(from + (120.0 if randf() < 0.5 else -120.0) * 2.0, _min_x, _max_x)
	_face(target > from)
	var t := absf(target - from) / randf_range(WALK_SPEED_MIN, WALK_SPEED_MAX)
	_stop_breath()
	_start_bob()
	_kill(_tween)
	_tween = create_tween()
	_tween.tween_property(_body, "position:x", target, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		_stop_bob()
		_start_breath()
		_next_action(randf_range(IDLE_MIN, IDLE_MAX))
	)

func _hop(double: bool) -> void:
	_stop_breath()
	_kill(_tween)
	_tween = create_tween()
	var hops := 2 if double else 1
	for i in range(hops):
		var h := HOP_HEIGHT * (1.0 if i == 0 else 0.6)
		# Присесть — прыжок — приземлиться.
		_tween.tween_property(_body, "scale", Vector2(1.06, 0.92), 0.08)
		_tween.tween_property(_body, "scale", Vector2(0.96, 1.05), 0.06)
		_tween.parallel().tween_property(_body, "position:y", _base_y - h, HOP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_body, "position:y", _base_y, HOP_TIME * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_tween.parallel().tween_property(_body, "scale", Vector2.ONE, HOP_TIME * 0.5)
		_tween.tween_property(_body, "scale", Vector2(1.05, 0.95), 0.06)
		_tween.tween_property(_body, "scale", Vector2.ONE, 0.1)
	_tween.tween_callback(func() -> void:
		_start_breath()
		_next_action(randf_range(IDLE_MIN, IDLE_MAX))
	)

func _facing_right() -> bool:
	return _body.flip_h == FLIP_MEANS_RIGHT

func _face(right: bool) -> void:
	if _facing_right() == right:
		return
	# Быстрый «разворот»: сжать по горизонтали, отразить, расправить.
	var t := create_tween()
	t.tween_property(_body, "scale:x", 0.1, 0.07)
	t.tween_callback(func() -> void: _body.flip_h = right if FLIP_MEANS_RIGHT else not right)
	t.tween_property(_body, "scale:x", 1.0, 0.07)

func _start_bob() -> void:
	_kill(_bob)
	_bob = create_tween().set_loops()
	_bob.tween_property(_body, "position:y", _base_y - STEP_BOB, STEP_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_bob.tween_property(_body, "position:y", _base_y, STEP_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _stop_bob() -> void:
	_kill(_bob)
	_body.position.y = _base_y

func _set_stretch(v: float) -> void:
	if _breath_mat != null:
		_breath_mat.set_shader_parameter("stretch", v)

func _start_breath() -> void:
	_kill(_breath)
	_breath = create_tween().set_loops()
	_breath.tween_method(_set_stretch, 0.0, BREATH_SCALE, BREATH_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_breath.tween_method(_set_stretch, BREATH_SCALE, 0.0, BREATH_PERIOD * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _stop_breath() -> void:
	_kill(_breath)
	_set_stretch(0.0)

static func _kill(t: Tween) -> void:
	if t != null and t.is_valid():
		t.kill()
