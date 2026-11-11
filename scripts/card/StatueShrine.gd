class_name StatueShrine
extends Node2D
## Статуя в ивент-комнате: стоит справа на месте врагов, подсвечивается при наведении,
## по клику испускает `clicked` (дальше — реплика статуи и окно дара).

signal clicked

const SCALE := 0.31
const HOVER_TIME := 0.16

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

func setup(texture: Texture2D) -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_sprite.scale = Vector2(SCALE, SCALE)
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

func vanish() -> void:
	set_interactive(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _exit_tree() -> void:
	if _hovered:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(_delta: float) -> void:
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
