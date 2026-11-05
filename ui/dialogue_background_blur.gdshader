shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_strength : hint_range(0.0, 12.0) = 4.8;
uniform vec4 tint_color : source_color = vec4(0.06, 0.04, 0.08, 0.16);

void fragment() {
    vec2 uv = SCREEN_UV;
    vec2 tex_size = vec2(textureSize(screen_texture, 0));
    vec2 px = max(vec2(1.0) / tex_size, vec2(blur_strength) / tex_size);

    vec3 col = vec3(0.0);
    float total = 0.0;

    vec2 offsets[13] = vec2[](
        vec2(0.0, 0.0),
        vec2(1.0, 0.0), vec2(-1.0, 0.0),
        vec2(0.0, 1.0), vec2(0.0, -1.0),
        vec2(0.75, 0.75), vec2(-0.75, 0.75), vec2(0.75, -0.75), vec2(-0.75, -0.75),
        vec2(2.0, 0.0), vec2(-2.0, 0.0),
        vec2(0.0, 2.0), vec2(0.0, -2.0)
    );

    float weights[13] = float[]( 
        0.18,
        0.11, 0.11,
        0.11, 0.11,
        0.07, 0.07, 0.07, 0.07,
        0.05, 0.05,
        0.05, 0.05
    );

    for (int i = 0; i < 13; i++) {
        vec2 sample_uv = clamp(uv + offsets[i] * px, vec2(0.0), vec2(1.0));
        col += textureLod(screen_texture, sample_uv, 1.0).rgb * weights[i];
        total += weights[i];
    }

    col /= max(total, 0.001);
    col = mix(texture(screen_texture, uv).rgb, col, 0.92);
    COLOR = vec4(col + tint_color.rgb * tint_color.a, max(0.12, tint_color.a));
}
