class_name StatueShrine
extends Node2D
## Статуя в ивент-комнате: стоит справа на месте врагов, подсвечивается при наведении,
## по клику испускает `clicked` (дальше — реплика статуи и окно дара).

signal clicked

const SCALE := 0.31
const HOVER_TIME := 0.16
## Зов «нажми на меня», пока статую не нажали: светящийся круг под ней и лучи света вверх.
const CALL_COLOR_WHITE := Color(1.0, 0.95, 0.75)
const CALL_COLOR_BLACK := Color(0.85, 0.6, 1.0)
const CIRCLE_RADIUS := Vector2(150, 34)   ## полуоси круга у подножия, px
const RAYS_AMOUNT := 28
## Исчезновение после комнаты, сек.
const VANISH_TIME := 1.1

const GLOW_SHADER := "shader_type canvas_item;
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.86, 0.45, 1.0);
uniform float radius_px = 11.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float a = 0.0;
	vec2 px = TEXTURE_PIXEL_SIZE * radius_px;
	for (int i = 0; i < 12; i++) {
		float ang = float(i) * 0.5235988;
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
		a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px * 0.5).a);
	}
	float rim = clamp(a - c.a, 0.0, 1.0) * glow;
	vec3 lit = c.rgb * (1.0 + 0.10 * glow) + glow_color.rgb * 0.05 * glow;
	vec4 col = vec4(lit, c.a);
	col = mix(col, vec4(glow_color.rgb, 1.0), rim * (1.0 - c.a));
	col.a = max(c.a, rim * glow_color.a);
	COLOR = col;
}
"

static var _shader: Shader

var interactive := true
var _sprite: Sprite2D
var _mat: ShaderMaterial
var _image: Image
var _hovered := false
var _glow_tween: Tween
var _call: Node2D            ## круг и лучи
var _rays: CPUParticles2D
var _call_color := CALL_COLOR_WHITE
var _t := 0.0

## k — масштаб картинки (статуя — SCALE; сундук в комнате-сундуке — крупнее).
func setup(texture: Texture2D, black: bool = false, k: float = SCALE) -> void:
	_call_color = CALL_COLOR_BLACK if black else CALL_COLOR_WHITE
	_build_call()
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	GalleryData.mark_seen_texture(texture)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.scale = Vector2(k, k)
	if texture != null:
		_sprite.offset = Vector2(0, -texture.get_height() * 0.5)   ## ноги статуи — в точке узла
		_image = texture.get_image()
		if _image != null and _image.is_compressed():
			_image.decompress()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("glow", 0.0)
	_sprite.material = _mat
	add_child(_sprite)
	add_child(_rays)
	# Появление: как враги перед боем — из прозрачности, чуть снизу.
	modulate.a = 0.0
	_sprite.position = Vector2(0, 24)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.45)
	tw.tween_property(_sprite, "position", Vector2.ZERO, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func set_interactive(on: bool) -> void:
	interactive = on
	if not on:
		_set_hovered(false)
		_stop_call()

## Круг под ногами (рисуется в _draw узла _call) и лучи — частицы-полоски, летящие вверх.
func _build_call() -> void:
	_call = Node2D.new()
	_call.name = "Call"
	_call.draw.connect(_draw_call.bind(_call))
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_call.material = add
	add_child(_call)
	_rays = CPUParticles2D.new()
	_rays.amount = RAYS_AMOUNT
	_rays.lifetime = 2.4
	_rays.preprocess = 2.4
	_rays.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rays.emission_rect_extents = Vector2(CIRCLE_RADIUS.x * 0.85, CIRCLE_RADIUS.y * 0.4)
	_rays.direction = Vector2.UP
	_rays.spread = 4.0
	_rays.gravity = Vector2.ZERO
	_rays.initial_velocity_min = 110.0
	_rays.initial_velocity_max = 210.0
	_rays.scale_amount_min = 0.6
	_rays.scale_amount_max = 1.3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(_call_color, 0.0))
	ramp.add_point(0.25, Color(_call_color, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(_call_color, 0.0))
	_rays.color_ramp = ramp
	var streak := Gradient.new()
	streak.set_color(0, Color(1, 1, 1, 0.0))
	streak.add_point(0.5, Color(1, 1, 1, 1.0))
	streak.set_color(streak.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = streak
	tex.width = 14
	tex.height = 130
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	_rays.texture = tex
	_rays.material = add
	_rays.position = Vector2(0, -10)
	_rays.z_index = 1   ## лучи поверх статуи (добавляются к узлу после спрайта, см. setup)

## node — свой узел круга (после клика _call уже null, а старый круг ещё тает и рисуется).
func _draw_call(node: Node2D) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, CIRCLE_RADIUS.y / CIRCLE_RADIUS.x))
	for i in range(6):
		var k := 1.0 - float(i) / 6.0
		node.draw_circle(Vector2.ZERO, CIRCLE_RADIUS.x * (0.45 + 0.55 * k), Color(_call_color, (0.05 + 0.07 * pulse) * (1.0 - k * 0.6)))
	node.draw_arc(Vector2.ZERO, CIRCLE_RADIUS.x, 0.0, TAU, 64, Color(_call_color, 0.55 + 0.35 * pulse), 4.0, true)
	node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _stop_call() -> void:
	if _call == null or not is_instance_valid(_call):
		return
	_rays.emitting = false
	var tw := _call.create_tween()
	tw.tween_property(_call, "modulate:a", 0.0, 0.6)
	tw.tween_callback(_call.queue_free)
	var rays := _rays
	get_tree().create_timer(_rays.lifetime).timeout.connect(func() -> void:
		if is_instance_valid(rays):
			rays.queue_free()
	)
	_call = null

## Комната пройдена: статуя медленно растворяется — светлеет, чуть поднимается и тает.
func vanish() -> void:
	set_interactive(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 0.0, VANISH_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "position:y", position.y - 40.0, VANISH_TIME).set_trans(Tween.TRANS_SINE)
	if _mat != null:
		tw.tween_method(_set_glow, 0.0, 1.0, VANISH_TIME * 0.5)
	tw.chain().tween_callback(queue_free)

func _exit_tree() -> void:
	if _hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(delta: float) -> void:
	_t += delta
	if _call != null and is_instance_valid(_call):
		_call.queue_redraw()
	_set_hovered(interactive and _blocking_overlay() == false and _is_over(get_global_mouse_position()))

func _input(event: InputEvent) -> void:
	if not interactive or _blocking_overlay():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_over(get_global_mouse_position()):
			get_viewport().set_input_as_handled()
			set_interactive(false)
			clicked.emit()

## Попадание по непрозрачному пикселю статуи (а не по прямоугольнику картинки).
func _is_over(global_point: Vector2) -> bool:
	if _sprite == null or _sprite.texture == null:
		return false
	var lp := _sprite.to_local(global_point)
	var r := _sprite.get_rect()
	if not r.has_point(lp):
		return false
	if _image == null:
		return true
	var ip := Vector2i(lp - r.position)
	ip.x = clampi(ip.x, 0, _image.get_width() - 1)
	ip.y = clampi(ip.y, 0, _image.get_height() - 1)
	return _image.get_pixelv(ip).a > 0.2

func _blocking_overlay() -> bool:
	if DialogueManager_ == null:
		return false
	var o = DialogueManager_._overlay
	return o != null and is_instance_valid(o) and o.visible

func _set_hovered(on: bool) -> void:
	if on == _hovered:
		return
	_hovered = on
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if on else Input.CURSOR_ARROW)
	if _glow_tween != null:
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(_set_glow, float(_mat.get_shader_parameter("glow")), 1.0 if on else 0.0, HOVER_TIME)

func _set_glow(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("glow", v)
