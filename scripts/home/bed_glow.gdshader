// Свечение кровати («пора спать», Hub._set_bed_hint): тёплый ореол вокруг силуэта и лёгкий отсвет
// на самой кровати. Рисуется поверх кровати со сложением цвета; прозрачность пульсирует из кода.
// Он же — обводка при наведении (Hub._set_bed_outline: узкий spread, sharp = 1, без отсвета).
shader_type canvas_item;
render_mode blend_add;

uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
// Поле вокруг кровати (доля размера узла с каждой стороны) — туда выходит ореол.
uniform vec2 margin = vec2(0.06, 0.12);
// Ширина ореола (доля картинки).
uniform vec2 spread = vec2(0.035, 0.07);
// Сколько отсвета на самой кровати.
uniform float inner_tint = 0.35;
// 0 — мягкий ореол, 1 — чёткая обводка.
uniform float sharp = 0.0;

float sample_a(sampler2D tex, vec2 uv) {
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}

void fragment() {
	vec2 uv = (UV - margin) / (vec2(1.0) - 2.0 * margin);
	float near = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) / 16.0 * 6.2831853;
		vec2 dir = vec2(cos(ang), sin(ang));
		near += sample_a(TEXTURE, uv + dir * spread);
		near += sample_a(TEXTURE, uv + dir * spread * 0.5);
	}
	near /= 32.0;
	float inside = sample_a(TEXTURE, uv);
	float edge = mix(near, smoothstep(0.02, 0.2, near), sharp);
	float glow = edge * (1.0 - inside) + inside * inner_tint;
	COLOR = vec4(glow_color.rgb * glow, 1.0) * vec4(1.0, 1.0, 1.0, COLOR.a);
}
