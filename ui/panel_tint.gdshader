shader_type canvas_item;
// Перекрасить подложку кнопки (buttonPanel.png) в цвет tint, сохранив светотень картинки:
// светлее места картинки — светлее цвет. amount — насколько перекрасить (0 — как есть).
// Используется: кнопка текущей комнаты в мини-меню (HubMenu — ярко-розовая).
uniform vec4 tint : source_color = vec4(0.94, 0.27, 0.55, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float base_light = 0.36;   // средняя яркость исходной подложки
uniform float alpha_mult = 1.5;    // подложка полупрозрачная — перекрашенная плотнее

void fragment() {
	vec4 c = COLOR;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 t = clamp(tint.rgb * (0.65 + 0.35 * l / base_light), 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, t, amount), mix(c.a, min(1.0, c.a * alpha_mult), amount));
}
