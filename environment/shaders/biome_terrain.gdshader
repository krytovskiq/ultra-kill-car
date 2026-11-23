shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_primary : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_primary : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_primary : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D albedo_detail : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_detail : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 tint_primary : source_color = vec4(0.92, 0.86, 0.78, 1.0);
uniform vec4 tint_detail : source_color = vec4(0.84, 0.79, 0.72, 1.0);
uniform float uv_scale_primary = 0.08;
uniform float uv_scale_detail = 0.14;
uniform float normal_strength = 1.25;
uniform float road_half_width = 17.0;
uniform float puddle_amount : hint_range(0.0, 1.0) = 0.18;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 68.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying float v_lat_abs;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.13 + vec2(17.1, 31.7);
		a *= 0.48;
	}
	return v;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_lat_abs = (COLOR.b < 0.5) ? (COLOR.r * 60.0) : abs(v_world_pos.x);
}

void fragment() {
	vec2 uv_p = v_world_pos.xz * uv_scale_primary;
	vec2 uv_d = v_world_pos.xz * uv_scale_detail;

	vec3 alb_p = texture(albedo_primary, uv_p).rgb * tint_primary.rgb;
	vec3 nor_p = texture(normal_primary, uv_p).rgb;
	float rgh_p = texture(rough_primary, uv_p).r;

	vec3 alb_d = texture(albedo_detail, uv_d).rgb * tint_detail.rgb;
	vec3 nor_d = texture(normal_detail, uv_d).rgb;
	float rgh_d = texture(rough_detail, uv_d).r;

	float macro_patch = fbm(v_world_pos.xz * 0.032);
	float slope = 1.0 - smoothstep(0.76, 0.96, abs(v_world_nrm.y));
	float shoulder_edge = 1.0 - smoothstep(road_half_width + 0.5, road_half_width + 7.5, v_lat_abs);
	float blend = clamp(smoothstep(0.38, 0.68, macro_patch) * 0.72 + slope * 0.65 + shoulder_edge * 0.45, 0.0, 1.0);

	// Large-scale color Variation breaks long repeating vistas
	float big_var = mix(0.84, 1.12, fbm(v_world_pos.xz * 0.011));
	vec3 albedo = mix(alb_p, alb_d, blend) * big_var;
	vec3 nrm_map = normalize(mix(nor_p, nor_d, blend));
	float rough = clamp(mix(rgh_p, rgh_d, blend) * 0.94, 0.48, 0.98);

	// Damp depressions / roadside moisture glints
	float snow_spec = 0.35;
	if (snow_amount > 0.01) {
		float flat_snow = smoothstep(0.60, 0.90, abs(v_world_nrm.y));
		float drift = fbm(v_world_pos.xz * vec2(0.055, 0.022));
		float frost_grain = vnoise(v_world_pos.xz * 1.35);
		float snow_mask = clamp(flat_snow * (0.58 + 0.42 * drift) + 0.20, 0.0, 1.0) * snow_amount;
		vec3 snow_lit = vec3(0.76, 0.82, 0.88) * (0.90 + 0.18 * frost_grain);
		vec3 snow_shadow = vec3(0.54, 0.62, 0.72);
		vec3 snow_col = mix(snow_shadow, snow_lit, smoothstep(0.28, 0.72, drift));
		albedo = mix(albedo, snow_col, snow_mask * 0.90);
		rough = mix(rough, 0.46, snow_mask * 0.82);
		snow_spec = mix(0.35, 0.64, snow_mask);
	}

	if (puddle_amount > 0.01) {
		float flat_only = smoothstep(0.92, 0.99, abs(v_world_nrm.y));
		float puddle_n = fbm(v_world_pos.xz * 0.07 + vec2(4.2, 9.1));
		float p_mask = smoothstep(0.74 - puddle_amount * 0.14, 0.84 - puddle_amount * 0.10, puddle_n) * flat_only;
		albedo *= mix(1.0, 0.62, p_mask);
		rough = mix(rough, 0.18, p_mask * 0.85);
		SPECULAR = mix(snow_spec, 0.72, p_mask);
	} else {
		SPECULAR = snow_spec;
	}

	ALBEDO = albedo;
	NORMAL_MAP = nrm_map;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = rough;

	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		vec3 nrm = normalize(v_world_nrm);
		vec3 dl = v_world_pos - hl_left_pos;
		vec3 dr = v_world_pos - hl_right_pos;
		float dist_l = length(dl);
		float dist_r = length(dr);
		float beam = 0.0;
		if (dist_l < hl_range && dist_l > 0.05) {
			vec3 rl = dl / dist_l;
			float cl = max(smoothstep(0.73, 0.95, dot(rl, dir_nrm)), smoothstep(0.42, 0.84, dot(rl, dir_nrm)) * (1.0 - smoothstep(4.0, 25.0, dist_l)) * 0.70);
			beam += cl * (1.0 - smoothstep(hl_range * 0.42, hl_range, dist_l)) / (1.0 + dist_l * dist_l * 0.0035);
		}
		if (dist_r < hl_range && dist_r > 0.05) {
			vec3 rr = dr / dist_r;
			float cr = max(smoothstep(0.73, 0.95, dot(rr, dir_nrm)), smoothstep(0.42, 0.84, dot(rr, dir_nrm)) * (1.0 - smoothstep(4.0, 25.0, dist_r)) * 0.70);
			beam += cr * (1.0 - smoothstep(hl_range * 0.42, hl_range, dist_r)) / (1.0 + dist_r * dist_r * 0.0035);
		}
		EMISSION = albedo * hl_color.rgb * clamp(beam * hl_intensity, 0.0, 1.9) * 1.35;
	}
}
