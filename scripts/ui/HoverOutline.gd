extends RefCounted
class_name HoverOutline
## Тонкая обводка по контуру картинки при наведении (NPC в лавках, цветок Рикки) — вместо подсветки.
##
##   HoverOutline.set_on(sprite, true)   ## плавно показать / спрятать

const COLOR := Color(1.0, 0.93, 0.98, 1.0)
const WIDTH_PX := 3.0      ## толщина на экране, пикселей
const FADE := 0.10

const SHADER := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 line_color : source_color = vec4(1.0);
uniform float width_tex = 3.0;   // толщина в пикселях текстуры
varying vec4 v_mod;
void vertex() {
	v_mod = COLOR;   // modulate / self_modulate (прятание на время диалога, смена Рикки)
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (amount > 0.001) {
		vec2 px = TEXTURE_PIXEL_SIZE * width_tex;
		float a = 0.0;
		for (int i = 0; i < 12; i++) {
			float ang = float(i) * 0.5236;
			vec2 d = vec2(cos(ang), sin(ang));
			a = max(a, texture(TEXTURE, UV + d * px).a);
			a = max(a, texture(TEXTURE, UV + d * px * 0.5).a);
		}
		float rim = clamp(a - c.a, 0.0, 1.0) * amount;
		c = vec4(mix(c.rgb, line_color.rgb, rim * (1.0 - c.a)), max(c.a, rim * line_color.a));
	}
	COLOR = c * v_mod;
}
"""

static var _shader: Shader

static func _material(ci: CanvasItem) -> ShaderMaterial:
	var m := ci.material as ShaderMaterial
	if m != null and m.shader == _shader and _shader != null:
		return m
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	m = ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("line_color", COLOR)
	m.set_shader_parameter("amount", 0.0)   ## без явного значения твин не видит параметр
	ci.material = m
	return m

static func set_on(ci: CanvasItem, on: bool) -> void:
	if ci == null or not is_instance_valid(ci):
		return
	var m := _material(ci)
	# Толщина в пикселях текстуры, чтобы на экране было WIDTH_PX (картинки вписаны с уменьшением).
	var tr := ci as TextureRect
	if tr != null and tr.texture != null:
		var ts := tr.texture.get_size()
		var k := minf(tr.size.x / ts.x, tr.size.y / ts.y)
		m.set_shader_parameter("width_tex", WIDTH_PX / maxf(k, 0.01))
	var old = ci.get_meta("hover_outline_tween") if ci.has_meta("hover_outline_tween") else null
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var tw := ci.create_tween()
	ci.set_meta("hover_outline_tween", tw)
	tw.tween_property(m, "shader_parameter/amount", 1.0 if on else 0.0, FADE)
