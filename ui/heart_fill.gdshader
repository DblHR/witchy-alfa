shader_type canvas_item;
// Сердечко, заполненное на долю fill (0 — пустое, 1 — полное).
// direction: 0 — снизу вверх, 1 — справа налево, 2 — слева направо.
// Незаполненная часть — серая, осветлённая на lift (как пустые сердечки в инвентаре).
// uv_* — где в текстуре начинается и кончается само сердечко (картинка может быть кусочком
// атласа); edge — мягкость границы.
uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform int direction = 1;
uniform float lift : hint_range(0.0, 1.0) = 0.6;
uniform float uv_top = 0.0;
uniform float uv_bottom = 1.0;
uniform float uv_left = 0.0;
uniform float uv_right = 1.0;
uniform float edge = 0.02;

void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = mix(vec3(g) * 0.8, vec3(1.0), lift);
	// t — насколько далеко от места, откуда начинается заливка: 1 — там, где она начинается.
	float t;
	if (direction == 0) {
		t = (UV.y - uv_top) / max(uv_bottom - uv_top, 0.0001);
	} else if (direction == 1) {
		t = (UV.x - uv_left) / max(uv_right - uv_left, 0.0001);
	} else {
		t = 1.0 - (UV.x - uv_left) / max(uv_right - uv_left, 0.0001);
	}
	float filled = smoothstep(1.0 - fill - edge, 1.0 - fill + edge, t);
	if (fill <= 0.0) { filled = 0.0; }
	if (fill >= 1.0) { filled = 1.0; }
	COLOR = vec4(mix(grey, c.rgb, filled), c.a);
}
