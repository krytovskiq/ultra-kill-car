shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D smoke_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float fps = 14.0;
uniform float opacity = 0.72;
uniform float sway_strength = 0.52;

varying float v_seed;
varying float v_height;

vec2 flipbook_uv(vec2 uv, float frame_idx) {
	float f = mod(floor(frame_idx), 64.0);
	float col = mod(f, 8.0);
	float row = floor(f / 8.0);
	vec2 tile = vec2(0.125, 0.125);
	vec2 clamped = mix(vec2(0.016), vec2(0.984), clamp(uv, 0.0, 1.0));
	return (vec2(col, row) + clamped) * tile;
}

void vertex() {
	v_seed = INSTANCE_CUSTOM.x * 11.3 + MODEL_MATRIX[3].x * 0.19 + MODEL_MATRIX[3].z * 0.27;
	v_height = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.45 + v_seed + v_height * 2.1) * sway_strength * v_height;
	VERTEX.z += cos(TIME * 1.15 + v_seed * 1.7 + v_height * 1.8) * sway_strength * 0.65 * v_height;
}

void fragment() {
	float t = TIME * fps + abs(v_seed) * 17.0;
	float f0 = floor(t);
	float f1 = f0 + 1.0;
	float blend = fract(t);

	vec2 uv_rise = vec2(UV.x, clamp(UV.y + sin(TIME * 0.55 + v_seed) * 0.025, 0.0, 1.0));
	vec4 c0 = texture(smoke_sheet, flipbook_uv(uv_rise, f0));
	vec4 c1 = texture(smoke_sheet, flipbook_uv(uv_rise, f1));
	vec4 tex = mix(c0, c1, blend);

	float edge_x = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float edge_y = smoothstep(0.02, 0.28, UV.y) * smoothstep(1.0, 0.88, UV.y);

	float alpha_raw = smoothstep(0.06, 0.34, tex.a);
	vec3 soot = mix(vec3(0.04, 0.04, 0.05), vec3(0.16, 0.15, 0.15), clamp(tex.r * tex.a, 0.0, 1.0));
	float ember_glow = pow(smoothstep(0.58, 1.0, UV.y), 1.8) * 0.55 * alpha_raw;
	vec3 col = soot + vec3(0.95, 0.34, 0.08) * ember_glow;

	ALBEDO = col;
	ALPHA = clamp(alpha_raw * tex.a * edge_x * edge_y * opacity, 0.0, 0.88);
}
