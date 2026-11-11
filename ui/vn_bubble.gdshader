shader_type canvas_item;
// Окно текста VN (как в ZZZ): размывает то, что под ним, затемняет и скругляет углы.
// Размытие — набором выборок по кругу (работает и в Compatibility, мипмапы экрана не нужны).

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 rect_size = vec2(1200.0, 200.0);   // размер окна в пикселях (для скругления)
uniform float radius = 26.0;                    // скругление углов
uniform float blur_px = 12.0;                   // сила размытия, px экрана
uniform vec4 tint : source_color = vec4(0.035, 0.015, 0.06, 0.82);
uniform vec4 border : source_color = vec4(1.0, 1.0, 1.0, 0.22);
uniform float border_px = 2.0;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * rect_size;
	float d = rounded_box(p, rect_size * 0.5, radius);
	float inside = 1.0 - smoothstep(-1.0, 0.5, d);
	if (inside <= 0.0) {
		discard;
	}
	vec2 px = SCREEN_PIXEL_SIZE * blur_px;
	vec3 col = texture(screen_texture, SCREEN_UV).rgb * 0.16;
	float total = 0.16;
	for (int ring = 1; ring <= 3; ring++) {
		float rr = float(ring) / 3.0;
		float w = 0.12 * (1.2 - rr);
		for (int k = 0; k < 8; k++) {
			float a = (float(k) + 0.5 * float(ring)) * 0.785398;
			col += texture(screen_texture, SCREEN_UV + vec2(cos(a), sin(a)) * px * rr * 1.6).rgb * w;
			total += w;
		}
	}
	col /= total;
	col = mix(col, tint.rgb, tint.a);
	float edge = 1.0 - smoothstep(border_px - 1.0, border_px, -d);
	col = mix(col, border.rgb, edge * border.a);
	COLOR = vec4(col, inside);
}
