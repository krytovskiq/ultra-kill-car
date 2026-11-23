shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform bool has_albedo_tex = false;
uniform bool has_normal_tex = false;
uniform bool has_rough_tex = false;
uniform bool use_triplanar = false;
uniform bool world_triplanar = false;

uniform vec3 uv_scale = vec3(1.0, 1.0, 1.0);
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float normal_strength = 1.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.05;
uniform vec4 base_emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float base_emission_energy = 0.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 68.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_local_pos;
varying vec3 v_local_nrm;

void vertex() {
	v_local_pos = VERTEX;
	v_local_nrm = NORMAL;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float eval_headlight(vec3 bulb_pos, vec3 dir_nrm, vec3 frag_pos, vec3 frag_nrm) {
	vec3 delta = frag_pos - bulb_pos;
	float dist = length(delta);
	if (dist > hl_range || dist < 0.05) {
		return 0.0;
	}
	vec3 ray = delta / dist;
	float cos_ang = dot(ray, dir_nrm);
	float core_cone = smoothstep(0.73, 0.95, cos_ang);
	float flood_cone = smoothstep(0.42, 0.84, cos_ang) * (1.0 - smoothstep(4.0, 26.0, dist)) * 0.72;
	float cone = max(core_cone, flood_cone);
	if (cone <= 0.001) {
		return 0.0;
	}
	float range_fade = 1.0 - smoothstep(hl_range * 0.42, hl_range, dist);
	float atten = 1.0 / (1.0 + dist * dist * 0.0032);
	float wrap_ndotl = clamp(abs(dot(frag_nrm, -ray)) * 0.68 + 0.36, 0.22, 1.0);
	return cone * range_fade * atten * wrap_ndotl;
}

void fragment() {
	vec2 sample_uv = UV * uv_scale.xy;
	if (use_triplanar) {
		vec3 p = world_triplanar ? v_world_pos : v_local_pos;
		vec3 an = abs(world_triplanar ? v_world_nrm : v_local_nrm);
		if (an.x > an.y && an.x > an.z) {
			sample_uv = p.zy * uv_scale.zy;
		} else if (an.z > an.y) {
			sample_uv = p.xy * uv_scale.xy;
		} else {
			sample_uv = p.xz * uv_scale.xz;
		}
	}

	vec4 alb = albedo_tint;
	if (has_albedo_tex) {
		vec4 t = texture(albedo_tex, sample_uv);
		if (t.a < 0.18) {
			discard;
		}
		alb *= t;
	}
	ALBEDO = alb.rgb;

	if (has_normal_tex) {
		NORMAL_MAP = texture(normal_tex, sample_uv).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}

	float rgh = roughness_val;
	if (has_rough_tex) {
		rgh *= texture(rough_tex, sample_uv).r;
	}
	ROUGHNESS = clamp(rgh, 0.12, 0.99);
	METALLIC = metallic_val;

	vec3 emission_out = base_emission.rgb * base_emission_energy;
	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		vec3 nrm = normalize(v_world_nrm);
		float b_l = eval_headlight(hl_left_pos, dir_nrm, v_world_pos, nrm);
		float b_r = eval_headlight(hl_right_pos, dir_nrm, v_world_pos, nrm);
		float beam = clamp((b_l + b_r) * hl_intensity, 0.0, 2.2);
		emission_out += (alb.rgb * 1.75 + vec3(0.06, 0.055, 0.045)) * hl_color.rgb * beam;
	}
	EMISSION = emission_out;
}
