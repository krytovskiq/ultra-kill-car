shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness_val : hint_range(0.0, 1.0) = 0.85;
uniform float metallic_val : hint_range(0.0, 1.0) = 0.02;
uniform float grime_seed = 0.0;
uniform vec4 blood_tint : source_color = vec4(0.32, 0.05, 0.04, 1.0);
uniform float blood_amount : hint_range(0.0, 1.0) = 0.25;
uniform float alpha_cut : hint_range(0.0, 1.0) = 0.0;

uniform vec4 base_emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float base_emission_energy = 0.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 62.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;

void vertex() {
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
	// Wide near-bumper spill plus focused long-range core beam
	float core_cone = smoothstep(0.68, 0.94, cos_ang);
	float flood_cone = smoothstep(0.38, 0.82, cos_ang) * (1.0 - smoothstep(3.0, 28.0, dist)) * 0.72;
	float cone = max(core_cone, flood_cone);
	if (cone <= 0.001) {
		return 0.0;
	}
	float range_fade = 1.0 - smoothstep(hl_range * 0.42, hl_range, dist);
	float atten = 1.0 / (1.0 + dist * dist * 0.0038);
	float wrap_ndotl = clamp(dot(frag_nrm, -ray) * 0.62 + 0.38, 0.24, 1.0);
	return cone * range_fade * atten * wrap_ndotl;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV) * albedo_tint;
	if (alpha_cut > 0.01 && tex.a < alpha_cut) {
		discard;
	}
	float spatter = sin(UV.x * 23.0 + grime_seed) * cos(UV.y * 19.0 - grime_seed * 1.3);
	float stain_mask = smoothstep(0.35, 0.82, spatter) * blood_amount;
	vec3 stained_rgb = mix(tex.rgb, tex.rgb * blood_tint.rgb * 1.4, stain_mask);
	ALBEDO = stained_rgb;
	ROUGHNESS = mix(roughness_val, 0.42, stain_mask * 0.6);
	METALLIC = metallic_val;

	vec3 emission_out = base_emission.rgb * base_emission_energy;
	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		vec3 nrm = normalize(v_world_nrm);
		float b_l = eval_headlight(hl_left_pos, dir_nrm, v_world_pos, nrm);
		float b_r = eval_headlight(hl_right_pos, dir_nrm, v_world_pos, nrm);
		float beam = clamp((b_l + b_r) * hl_intensity, 0.0, 2.2);
		emission_out += (stained_rgb * 1.9 + vec3(0.08, 0.075, 0.06)) * hl_color.rgb * beam;
	}
	EMISSION = emission_out;
}
