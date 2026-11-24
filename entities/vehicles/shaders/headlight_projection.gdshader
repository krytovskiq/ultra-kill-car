shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back;

uniform sampler2D cookie_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 light_tint : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.15;
uniform float steer_shift : hint_range(-1.0, 1.0) = 0.0;
uniform float pitch_stretch : hint_range(0.70, 1.35) = 1.0;
uniform bool flip_v = true;

void fragment() {
	float base_v = flip_v ? (1.0 - UV.y) : UV.y;
	float long_v = clamp(base_v / clamp(pitch_stretch, 0.72, 1.32), 0.0, 1.0);
	float shifted_u = UV.x - steer_shift * long_v * 0.16;
	vec2 proj_uv = vec2(clamp(shifted_u, 0.0, 1.0), long_v);

	vec4 cookie = texture(cookie_tex, proj_uv);
	// Smoothly fade quad edges horizontally so the light cone has soft, natural boundaries
	float u_fade = smoothstep(0.0, 0.16, shifted_u) * smoothstep(1.0, 0.84, shifted_u);
	// Smoothly taper physical quad UV bounds so neither near nor far edges ever clip sharply
	float quad_fade = smoothstep(0.0, 0.07, base_v) * smoothstep(1.0, 0.46, base_v);
	float long_falloff = pow(clamp(1.0 - base_v, 0.0, 1.0), 1.35);
	float mask = cookie.a * u_fade * quad_fade * (0.45 + 0.55 * long_falloff);

	float final_alpha = clamp(mask * intensity, 0.0, 1.0);
	ALBEDO = cookie.rgb * light_tint.rgb * (intensity * 1.12) * u_fade * quad_fade;
	ALPHA = final_alpha;
}
