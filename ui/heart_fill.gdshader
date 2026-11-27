shader_type canvas_item;
// Сердечко, заполненное снизу на долю fill (0 — пустое, 1 — полное).
// Незаполненная часть — серая, осветлённая на lift (как пустые сердечки в инвентаре).
// uv_top / uv_bottom — где по высоте в текстуре начинается и кончается само сердечко
// (картинка может быть кусочком атласа); edge — мягкость границы.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform float lift : hint_range(0.0, 1.0) = 0.6;
uniform float uv_top = 0.0;
uniform float uv_bottom = 1.0;
uniform float edge = 0.02;

void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = mix(vec3(g) * 0.8, vec3(1.0), lift);
	float y = (UV.y - uv_top) / max(uv_bottom - uv_top, 0.0001);   // 0 — верх, 1 — низ
	float filled = smoothstep(1.0 - fill - edge, 1.0 - fill + edge, y);
	if (fill <= 0.0) { filled = 0.0; }
	if (fill >= 1.0) { filled = 1.0; }
	COLOR = vec4(mix(grey, c.rgb, filled), c.a);
}
