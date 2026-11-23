shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;

uniform sampler2D shadow_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.80;

void fragment() {
	vec4 tex = texture(shadow_tex, UV);
	float edge_fade = smoothstep(0.0, 0.05, UV.x) * smoothstep(1.0, 0.95, UV.x)
		* smoothstep(0.0, 0.05, UV.y) * smoothstep(1.0, 0.95, UV.y);
	ALBEDO = vec3(0.02, 0.024, 0.032);
	ALPHA = clamp(tex.a * shadow_strength * edge_fade, 0.0, 0.92);
}
