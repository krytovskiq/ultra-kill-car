shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D fire_sheet : source_color, filter_linear_mipmap, repeat_disable;
uniform float fps = 24.0;
uniform float intensity = 1.65;
uniform float sway_strength = 0.22;

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
	v_seed = INSTANCE_CUSTOM.x * 13.7 + MODEL_MATRIX[3].x * 0.29 + MODEL_MATRIX[3].z * 0.41;
	v_height = clamp(1.0 - UV.y, 0.0, 1.0);
	float t = TIME * 4.4 + v_seed;
	float h2 = v_height * v_height;
	VERTEX.x += sin(t + v_height * 3.1) * sway_strength * h2;
	VERTEX.z += cos(TIME * 3.7 + v_seed * 1.3 + v_height * 2.5) * sway_strength * 0.72 * h2;
}

void fragment() {
	float t = TIME * fps + abs(v_seed) * 19.3;
	float f0 = floor(t);
	float f1 = f0 + 1.0;
	float blend = fract(t);

	vec4 c0 = texture(fire_sheet, flipbook_uv(UV, f0));
	vec4 c1 = texture(fire_sheet, flipbook_uv(UV, f1));
	vec4 tex = mix(c0, c1, blend);

	float flame = tex.a;
	float edge_x = smoothstep(0.0, 0.12, UV.x) * smoothstep(1.0, 0.88, UV.x);
	float edge_y = smoothstep(0.0, 0.08, UV.y) * smoothstep(1.0, 0.94, UV.y);
	float mask = smoothstep(0.04, 0.22, flame) * edge_x * edge_y;

	vec3 col_outer = vec3(0.88, 0.14, 0.02);
	vec3 col_mid = vec3(1.00, 0.44, 0.06);
	vec3 col_core = vec3(1.00, 0.88, 0.46);
	vec3 fire_col = mix(col_outer, col_mid, smoothstep(0.08, 0.46, flame));
	fire_col = mix(fire_col, col_core, smoothstep(0.55, 0.90, flame));
	fire_col *= mix(1.12, 0.68, v_height * 0.6);

	ALBEDO = fire_col * intensity * mask;
	ALPHA = clamp(flame * mask * 1.25, 0.0, 1.0);
}
