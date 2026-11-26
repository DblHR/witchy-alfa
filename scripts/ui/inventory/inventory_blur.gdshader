shader_type canvas_item;
// Фон под инвентарём: размытая картинка того, что под ним (дом, алхимия…), чуть затемнённая.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 10.0;        // насколько размыть (пиксели экрана)
uniform vec4 tint : source_color = vec4(0.12, 0.06, 0.14, 0.35);   // затемнение поверх

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius;
	vec4 sum = vec4(0.0);
	float wsum = 0.0;
	for (int x = -4; x <= 4; x++) {
		for (int y = -4; y <= 4; y++) {
			vec2 o = vec2(float(x), float(y)) / 4.0;
			float w = exp(-dot(o, o) * 2.0);
			sum += texture(screen_tex, SCREEN_UV + o * px) * w;
			wsum += w;
		}
	}
	vec3 c = (sum / wsum).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
