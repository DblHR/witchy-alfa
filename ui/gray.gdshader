shader_type canvas_item;
// Серый вариант картинки: amount 0 — как есть, 1 — совсем серая и чуть темнее (кого нет дома).
uniform float amount : hint_range(0.0, 1.0) = 0.0;
// lift — насколько осветлить серое (0 — темнее, 1 — белое): пустые сердечки в инвентаре светло-серые.
uniform float lift : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = COLOR;
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grey = mix(vec3(g) * 0.8, vec3(1.0), lift);
	COLOR = vec4(mix(c.rgb, grey, amount), c.a);
}
