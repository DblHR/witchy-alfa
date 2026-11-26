shader_type canvas_item;
// Светлый контур по форме вкладки (InventoryTab): width — толщина в пикселях картинки.
uniform vec4 outline_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform float width = 0.0;
varying vec4 v_mod;

void vertex() {
	v_mod = COLOR;   // modulate кнопки (в fragment COLOR уже умножен на текстуру)
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float edge = 0.0;
	if (width > 0.01) {
		for (int i = 0; i < 16; i++) {
			float ang = float(i) * 0.3927;
			vec2 off = vec2(cos(ang), sin(ang)) * TEXTURE_PIXEL_SIZE * width;
			edge = max(edge, texture(TEXTURE, UV + off).a);
		}
	}
	float a = max(tex.a, outline_color.a * edge);
	vec3 rgb = mix(outline_color.rgb, tex.rgb, tex.a);
	COLOR = vec4(rgb, a) * v_mod;
}
