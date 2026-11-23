shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_tex : hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 tint_color : source_color = vec4(0.92, 0.92, 0.94, 1.0);
uniform float uv_tile_u = 1.0;
uniform float uv_tile_v = 1.0;
uniform float normal_strength = 1.15;
uniform float roughness_mult = 0.90;
uniform float tire_track_strength : hint_range(0.0, 1.0) = 0.32;
uniform float road_half_width = 17.0;
uniform float puddle_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ice_amount : hint_range(0.0, 1.0) = 0.0;
uniform float overgrown_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 68.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying float v_lat_signed;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.12);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_lat_signed = (COLOR.b < 0.5) ? ((COLOR.r * 2.0 - 1.0) * 25.0) : v_world_pos.x;
}

float eval_headlight(vec3 bulb_pos, vec3 dir_nrm, vec3 frag_pos, vec3 frag_nrm) {
	vec3 delta = frag_pos - bulb_pos;
	float dist = length(delta);
	if (dist > hl_range || dist < 0.05) {
		return 0.0;
	}
	vec3 ray = delta / dist;
	float cos_ang = dot(ray, dir_nrm);
	float core_cone = smoothstep(0.74, 0.95, cos_ang);
	float flood_cone = smoothstep(0.45, 0.85, cos_ang) * (1.0 - smoothstep(3.0, 24.0, dist)) * 0.65;
	float cone = max(core_cone, flood_cone);
	if (cone <= 0.001) {
		return 0.0;
	}
	float range_fade = 1.0 - smoothstep(hl_range * 0.42, hl_range, dist);
	float atten = 1.0 / (1.0 + dist * dist * 0.0035);
	return cone * range_fade * atten;
}

void fragment() {
	vec2 base_uv = UV * vec2(uv_tile_u, uv_tile_v);
	vec3 tex_alb = texture(albedo_tex, base_uv).rgb * tint_color.rgb;
	vec3 tex_nor = texture(normal_tex, base_uv).rgb;
	float tex_rgh = texture(roughness_tex, base_uv).r * roughness_mult;

	// Macro world-space variation + fine sharp asphalt micro-fissures
	float macro_n = value_noise(v_world_pos.xz * 0.065);
	float fine_n = value_noise(v_world_pos.xz * 0.42);
	float c1 = value_noise(v_world_pos.xz * 1.45 + vec2(fine_n * 0.8, -fine_n * 0.7));
	float c2 = value_noise(v_world_pos.xz * 3.60 - vec2(fine_n * 1.1, macro_n * 1.3));
	float crack_line = smoothstep(0.968, 0.996, 1.0 - abs(c1 - 0.5) * 2.0) * smoothstep(0.35, 0.85, c2);
	float weather = mix(0.85, 1.09, macro_n * 0.7 + fine_n * 0.3);

	// Procedural tire-worn wheel tracks along highway lanes
	float lat_abs = abs(v_lat_signed);
	float lane_dist_a = abs(lat_abs - 3.6);
	float lane_dist_b = abs(lat_abs - 9.2);
	float track_a = exp(-lane_dist_a * lane_dist_a * 0.55);
	float track_b = exp(-lane_dist_b * lane_dist_b * 0.45) * 0.75;
	float wear = clamp(max(track_a, track_b) * (0.7 + 0.3 * macro_n), 0.0, 1.0) * tire_track_strength;

	// Dusty sandy/grit shoulder encroachment near road borders
	float edge_dust = smoothstep(road_half_width - 3.8, road_half_width, lat_abs) * (0.55 + 0.45 * macro_n);
	float puddle_n = value_noise(v_world_pos.xz * 0.085 + vec2(9.4, 3.1));
	float puddle = smoothstep(0.76 - puddle_strength * 0.10, 0.86, puddle_n) * puddle_strength * (1.0 - edge_dust);

	vec3 final_alb = tex_alb * weather * (1.0 - wear * 0.24);
	final_alb = mix(final_alb, final_alb * 0.52, crack_line * 0.42);
	vec3 shoulder_col = mix(vec3(0.32, 0.29, 0.24), vec3(0.74, 0.80, 0.86), ice_amount);
	float snow_lip = smoothstep(road_half_width - mix(3.8, 5.4, ice_amount), road_half_width, lat_abs) * (0.50 + 0.50 * macro_n);
	final_alb = mix(final_alb, shoulder_col, max(edge_dust * 0.52, snow_lip * ice_amount * 0.88));
	final_alb *= mix(1.0, 0.64, puddle);

	float ice_glaze = 0.0;
	if (ice_amount > 0.01) {
		float ice_n = value_noise(v_world_pos.xz * 0.11 + vec2(3.7, -5.2));
		ice_glaze = clamp(smoothstep(0.18, 0.72, ice_n * 0.60 + wear * 0.55 + fine_n * 0.25) * 0.82 + 0.18, 0.0, 1.0) * ice_amount * (1.0 - snow_lip * 0.70);
		vec3 frost_tint = mix(vec3(0.26, 0.34, 0.43), vec3(0.55, 0.65, 0.75), fine_n * 0.5 + wear * 0.5);
		final_alb = mix(final_alb, frost_tint, ice_glaze * 0.62);
		float rime = smoothstep(0.58, 0.90, c1) * ice_amount * (1.0 - wear * 0.65);
		final_alb = mix(final_alb, vec3(0.72, 0.78, 0.85), rime * 0.45);
	}

	float over_moss = 0.0;
	if (overgrown_amount > 0.01) {
		float moss_n = value_noise(v_world_pos.xz * 0.14 + vec2(-2.3, 6.4));
		float tuft_n = value_noise(v_world_pos.xz * 0.68 + vec2(1.9, -4.1));
		float shoulder_creep = smoothstep(road_half_width - 6.8, road_half_width - 0.6, lat_abs) * (0.45 + 0.55 * macro_n);
		float center_strip = exp(-lat_abs * lat_abs * 0.22) * smoothstep(0.45, 0.82, moss_n) * 0.65;
		float crack_moss = crack_line * 1.35 + smoothstep(0.62, 0.88, tuft_n * (1.0 - wear * 0.45)) * 0.55;
		over_moss = clamp(max(max(shoulder_creep, center_strip), crack_moss), 0.0, 1.0) * overgrown_amount;
		vec3 moss_col = mix(vec3(0.16, 0.28, 0.10), vec3(0.28, 0.44, 0.14), tuft_n);
		final_alb = mix(final_alb, moss_col, over_moss * 0.88);
	}

	float final_rgh = clamp(tex_rgh - wear * 0.30 + (fine_n - 0.5) * 0.06 + edge_dust * 0.14, 0.28, 0.98);
	final_rgh = mix(final_rgh, 0.14, puddle * 0.90);
	final_rgh = mix(final_rgh, 0.07, ice_glaze * 0.92);
	final_rgh = mix(final_rgh, 0.76, snow_lip * ice_amount * 0.70);
	final_rgh = mix(final_rgh, 0.92, over_moss * 0.82);

	ALBEDO = final_alb;
	NORMAL_MAP = tex_nor;
	NORMAL_MAP_DEPTH = mix(normal_strength, normal_strength * 0.42, ice_glaze * 0.75);
	ROUGHNESS = final_rgh;
	SPECULAR = mix(mix(mix(0.45, 0.68, wear), 0.85, puddle), 0.96, ice_glaze);

	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		vec3 nrm = normalize(v_world_nrm);
		float b_l = eval_headlight(hl_left_pos, dir_nrm, v_world_pos, nrm);
		float b_r = eval_headlight(hl_right_pos, dir_nrm, v_world_pos, nrm);
		float beam = clamp((b_l + b_r) * hl_intensity, 0.0, 1.8);
		float wet_glint = 1.0 + puddle * 0.85 + ice_glaze * 1.15;
		EMISSION = final_alb * hl_color.rgb * beam * 1.15 * wet_glint;
	}
}
