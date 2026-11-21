extends RefCounted
class_name ButtonGlow
## Подсветка кнопок-картинок (TextureButton): при наведении вокруг кнопки проявляется светящийся
## контур её формы, сама кнопка чуть светлеет; при нажатии — слегка «вдавливается».
## Вешается сама на все TextureButton игры (PauseManagerLayer следит за новыми узлами).
## Не нужна подсветка — button.set_meta("no_glow", true) до добавления в сцену.
## Кнопка в покое не белая (например, потускневшая недоступная) — button.set_meta("rest_tint", цвет):
## подсветка вернёт к нему, а не к белому.

const GLOW_COLOR := Color(1.0, 0.55, 0.88)     ## мягкое свечение вокруг
const GLOW_SCALE := 1.16                        ## насколько свечение шире кнопки
const RIM_COLOR := Color(1.0, 0.93, 0.98)      ## тонкий светлый контур по краю
const RIM_SCALE := 1.05
const HOVER_TINT := Color(1.25, 1.2, 1.25)     ## осветление кнопки под курсором
const PRESS_TINT := Color(0.85, 0.8, 0.85)
const FADE := 0.14
const NODE_NAME := "HoverGlow"

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(1.0, 0.62, 0.9, 1.0);
uniform float strength = 1.0;
void fragment() {
	// Силуэт кнопки одним цветом, края размыты — получается мягкий светящийся контур.
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * 3.0;
	for (int i = 0; i < 8; i++) {
		float ang = float(i) * 0.7854;
		a += texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a;
	}
	a /= 9.0;
	COLOR = vec4(glow_color.rgb, clamp(a * strength, 0.0, 1.0) * COLOR.a);
}
"""

static var _shader: Shader

static func attach(button: TextureButton) -> void:
	if button == null or not is_instance_valid(button) or button.has_meta("no_glow"):
		return
	if button.texture_normal == null or button.get_node_or_null(NODE_NAME) != null:
		return
	# В прокручиваемых списках контур обрезался бы краями списка — там не вешаем.
	var p := button.get_parent()
	while p != null:
		if p is ScrollContainer:
			return
		p = p.get_parent()
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	# Два слоя позади кнопки: широкое мягкое свечение и тонкий светлый контур.
	var glow := Control.new()
	glow.name = NODE_NAME
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.show_behind_parent = true
	glow.modulate.a = 0.0
	button.add_child(glow)
	for layer in [[GLOW_COLOR, GLOW_SCALE, 1.5], [RIM_COLOR, RIM_SCALE, 3.0]]:
		var t := TextureRect.new()
		t.texture = button.texture_normal
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = int(button.stretch_mode) as TextureRect.StretchMode
		t.flip_h = button.flip_h
		t.flip_v = button.flip_v
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_meta("glow_scale", float(layer[1]))
		var mat := ShaderMaterial.new()
		mat.shader = _shader
		mat.set_shader_parameter("glow_color", layer[0])
		mat.set_shader_parameter("strength", float(layer[2]))
		t.material = mat
		glow.add_child(t)
	_fit(button, glow)
	button.resized.connect(func() -> void: _fit(button, glow))
	button.mouse_entered.connect(func() -> void: _hover(button, glow, true))
	button.mouse_exited.connect(func() -> void: _hover(button, glow, false))
	button.button_down.connect(func() -> void:
		if not button.disabled:
			button.self_modulate = PRESS_TINT
	)
	button.button_up.connect(func() -> void:
		button.self_modulate = HOVER_TINT if button.is_hovered() and not button.disabled else rest_tint(button)
	)

static func rest_tint(button: TextureButton) -> Color:
	return button.get_meta("rest_tint") if button.has_meta("rest_tint") else Color.WHITE

static func _fit(button: TextureButton, glow: Control) -> void:
	glow.position = Vector2.ZERO
	glow.size = button.size
	for t in glow.get_children():
		var c := t as Control
		c.position = Vector2.ZERO
		c.size = button.size
		c.pivot_offset = button.size * 0.5
		c.scale = Vector2.ONE * float(c.get_meta("glow_scale", 1.0))

static func _hover(button: TextureButton, glow: Control, on: bool) -> void:
	if not is_instance_valid(button) or not is_instance_valid(glow):
		return
	on = on and not button.disabled
	for t in glow.get_children():
		(t as TextureRect).texture = button.texture_normal
	var tw := glow.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(glow, "modulate:a", 1.0 if on else 0.0, FADE)
	button.self_modulate = HOVER_TINT if on else rest_tint(button)
