shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_wall : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_wall : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_wall : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform sampler2D albedo_crack : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_crack : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 tint_color : source_color = vec4(0.84, 0.84, 0.86, 1.0);
uniform float world_uv_scale = 0.16;
uniform float normal_strength = 1.25;
uniform float metallic_val = 0.05;
uniform float window_density : hint_range(0.0, 1.0) = 0.78;
uniform float night_window_boost : hint_range(0.0, 1.5) = 0.0;
uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 68.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(v_world_nrm);
	vec2 tri_uv;
	if (an.x > an.y && an.x > an.z) {
		tri_uv = v_world_pos.zy * world_uv_scale;
	} else if (an.z > an.y) {
		tri_uv = v_world_pos.xy * world_uv_scale;
	} else {
		tri_uv = v_world_pos.xz * world_uv_scale;
	}

	vec3 wall_alb = texture(albedo_wall, tri_uv).rgb * tint_color.rgb;
	vec3 wall_nor = texture(normal_wall, tri_uv).rgb;
	float wall_rgh = texture(rough_wall, tri_uv).r;

	vec2 crack_uv = tri_uv * 0.68 + vec2(0.31, 0.77);
	vec3 crack_alb = texture(albedo_crack, crack_uv).rgb * 0.78;
	vec3 crack_nor = texture(normal_crack, crack_uv).rgb;

	float grime_n = vnoise(v_world_pos.xz * 0.11 + vec2(v_world_pos.y * 0.06, 0.0));
	float crack_mask = smoothstep(0.45, 0.72, grime_n);
	float bottom_soot = 1.0 - smoothstep(0.0, 7.5, v_world_pos.y);

	vec3 final_alb = mix(wall_alb, crack_alb, crack_mask * 0.58) * mix(1.0, 0.58, bottom_soot * 0.72);
	final_alb *= mix(1.0, 0.26, burn_amount * (0.55 + 0.45 * grime_n));
	vec3 final_nor = normalize(mix(wall_nor, crack_nor, crack_mask * 0.6));
	float final_rgh = clamp(wall_rgh + crack_mask * 0.12 + burn_amount * 0.22, 0.45, 0.98);
	vec3 emission_out = vec3(0.0);
	if (burn_amount > 0.05 && crack_mask > 0.60 && v_world_pos.y < 14.0) {
		float ember_pulse = 0.65 + 0.35 * sin(TIME * 4.5 + v_world_pos.x * 0.6 + v_world_pos.z * 0.4);
		emission_out += vec3(1.0, 0.28, 0.04) * smoothstep(0.60, 0.74, crack_mask) * burn_amount * ember_pulse * 0.95;
	}

	// Модульный фасад: межэтажные плиты, оконные рамы, тёмные стёкла и редкие горящие окна ночью
	float is_wall = 1.0 - smoothstep(0.55, 0.85, an.y);
	if (is_wall > 0.05 && v_world_pos.y > 3.6 && window_density > 0.05) {
		float h_coord = (an.x > an.z) ? v_world_pos.z : v_world_pos.x;
		vec2 cell_id = floor(vec2(h_coord / 3.0, v_world_pos.y / 3.6));
		vec2 cell_uv = fract(vec2(h_coord / 3.0, v_world_pos.y / 3.6));
		float sill = step(abs(cell_uv.y - 0.12), 0.055) * step(0.16, cell_uv.x) * step(cell_uv.x, 0.84);
		final_alb = mix(final_alb, final_alb * 0.68, sill);
		float win_x = step(0.20, cell_uv.x) * step(cell_uv.x, 0.80);
		float win_y = step(0.20, cell_uv.y) * step(cell_uv.y, 0.78);
		float mullion_v = step(abs(cell_uv.x - 0.50), 0.032);
		float mullion_h = step(abs(cell_uv.y - 0.52), 0.028);
		float in_frame = clamp(max(mullion_v, mullion_h), 0.0, 1.0);
		float win_rand = hash21(cell_id + floor(v_world_pos.xz * 0.03));
		float has_win = step(1.0 - window_density, win_rand) * win_x * win_y * is_wall;
		if (has_win > 0.5) {
			if (in_frame > 0.5) {
				final_alb = vec3(0.11, 0.11, 0.12);
				final_rgh = 0.72;
			} else {
				float broken_dark = mix(0.05, 0.14, hash21(cell_id * 3.1));
				final_alb = vec3(broken_dark, broken_dark * 1.05, broken_dark * 1.15);
				final_rgh = 0.18;
				SPECULAR = 0.85;
				float lit_r = hash21(cell_id + vec2(91.7, 13.3));
				float lit_thresh = mix(0.955, 0.72, clamp(night_window_boost + burn_amount * 0.75, 0.0, 1.0));
				if (lit_r > lit_thresh) {
					vec3 glow_col = (burn_amount > 0.3) ? mix(vec3(1.0, 0.34, 0.05), vec3(1.0, 0.66, 0.18), fract(lit_r * 13.0)) : ((lit_r > 0.985) ? vec3(0.45, 0.88, 0.52) : vec3(1.0, 0.58, 0.20));
					emission_out = glow_col * (0.55 + night_window_boost * 1.35 + burn_amount * 1.45);
				}
			}
		}
	}

	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		vec3 dl = v_world_pos - hl_left_pos;
		vec3 dr = v_world_pos - hl_right_pos;
		float dist_l = length(dl);
		float dist_r = length(dr);
		float beam = 0.0;
		if (dist_l < hl_range && dist_l > 0.05) {
			vec3 rl = dl / dist_l;
			float cl = max(smoothstep(0.72, 0.95, dot(rl, dir_nrm)), smoothstep(0.42, 0.84, dot(rl, dir_nrm)) * (1.0 - smoothstep(4.0, 26.0, dist_l)) * 0.70);
			beam += cl * (1.0 - smoothstep(hl_range * 0.42, hl_range, dist_l)) / (1.0 + dist_l * dist_l * 0.0032);
		}
		if (dist_r < hl_range && dist_r > 0.05) {
			vec3 rr = dr / dist_r;
			float cr = max(smoothstep(0.72, 0.95, dot(rr, dir_nrm)), smoothstep(0.42, 0.84, dot(rr, dir_nrm)) * (1.0 - smoothstep(4.0, 26.0, dist_r)) * 0.70);
			beam += cr * (1.0 - smoothstep(hl_range * 0.42, hl_range, dist_r)) / (1.0 + dist_r * dist_r * 0.0032);
		}
		emission_out += final_alb * hl_color.rgb * clamp(beam * hl_intensity, 0.0, 2.0) * 1.55;
	}

	ALBEDO = final_alb;
	NORMAL_MAP = final_nor;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = final_rgh;
	METALLIC = metallic_val;
	EMISSION = emission_out;
}
