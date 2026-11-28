shader_type canvas_item;
// Фиолетовый мимик (сундук-враг): картинка перекрашивается в tint по яркости, светотень сохраняется.
uniform vec4 tint : source_color = vec4(0.62, 0.32, 0.95, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.75;
uniform float glow = 0.15;   // чуть светится изнутри

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 t = tint.rgb * (0.35 + l * 1.25) + vec3(glow * l);
	COLOR = vec4(mix(c.rgb, clamp(t, 0.0, 1.0), amount), c.a);
}
