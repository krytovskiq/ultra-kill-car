shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.022, 0.058, 0.088, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.148, 0.195, 1.0);
uniform vec4 horizon_reflection_color : source_color = vec4(0.30, 0.34, 0.38, 1.0);
uniform vec4 foam_color : source_color = vec4(0.84, 0.88, 0.90, 1.0);

uniform float wave_height_scale = 1.05;
uniform float wave_speed = 1.0;
uniform float shore_z_half_span = 242.0;

uniform vec3 hl_left_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_right_pos = vec3(0.0, -1000.0, 0.0);
uniform vec3 hl_dir = vec3(0.0, -0.05, -1.0);
uniform float hl_intensity = 0.0;
uniform vec4 hl_color : source_color = vec4(1.0, 0.94, 0.78, 1.0);
uniform float hl_range = 75.0;

varying vec3 v_world_pos;
varying vec3 v_world_nrm;
varying vec3 v_local_pos;
varying float v_crest;

// Evaluates a single Gerstner wave and accumulates displacement + partial derivatives
void add_gerstner_wave(
	vec2 xz,
	float t,
	vec2 dir_raw,
	float steepness,
	float wavelength,
	inout vec3 disp,
	inout vec3 d_dx,
	inout vec3 d_dz,
	inout float crest_acc
) {
	vec2 d = normalize(dir_raw);
	float k = 6.2831853 / max(wavelength, 0.5);
	float c = sqrt(9.8 / k) * wave_speed;
	float a = (steepness / k) * wave_height_scale;
	float f = k * (dot(d, xz) - c * t);
	float s = sin(f);
	float co = cos(f);

	disp.x += d.x * (a * co);
	disp.y += a * s;
	disp.z += d.y * (a * co);

	float wa = k * a;
	d_dx += vec3(-d.x * d.x * wa * s, d.x * wa * co, -d.x * d.y * wa * s);
	d_dz += vec3(-d.x * d.y * wa * s, d.y * wa * co, -d.y * d.y * wa * s);
	crest_acc += s * 0.5 + 0.5;
}

void vertex() {
	v_local_pos = VERTEX;
	vec3 world_base = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME;

	vec3 disp = vec3(0.0);
	vec3 d_dx = vec3(1.0, 0.0, 0.0);
	vec3 d_dz = vec3(0.0, 0.0, 1.0);
	float crest_acc = 0.0;

	// 4 multi-directional Gerstner ocean waves (primary swell along strait + cross waves)
	add_gerstner_wave(world_base.xz, t, vec2(0.92, 0.38), 0.22, 34.0, disp, d_dx, d_dz, crest_acc);
	add_gerstner_wave(world_base.xz, t, vec2(0.76, -0.65), 0.18, 21.0, disp, d_dx, d_dz, crest_acc);
	add_gerstner_wave(world_base.xz, t, vec2(-0.42, 0.91), 0.15, 13.5, disp, d_dx, d_dz, crest_acc);
	add_gerstner_wave(world_base.xz, t, vec2(0.98, -0.18), 0.12, 7.8, disp, d_dx, d_dz, crest_acc);

	// Dampen wave amplitude very close to the north/south rocky banks so shoreline contact is clean
	float shore_prox = clamp((shore_z_half_span - abs(VERTEX.z)) / 24.0, 0.15, 1.0);
	disp *= shore_prox;

	VERTEX += disp;
	vec3 nrm_local = normalize(cross(d_dz, d_dx));
	NORMAL = nrm_local;

	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_nrm = normalize((MODEL_MATRIX * vec4(nrm_local, 0.0)).xyz);
	v_crest = clamp(crest_acc * 0.25, 0.0, 1.0);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm_water(vec2 p) {
	float v = 0.0;
	v += 0.55 * value_noise(p);
	v += 0.30 * value_noise(p * 2.13 + vec2(4.7, -3.1));
	v += 0.15 * value_noise(p * 4.41 - vec2(9.2, 6.4));
	return v;
}

float eval_headlight_water(vec3 bulb_pos, vec3 dir_nrm, vec3 frag_pos, vec3 frag_nrm, vec3 view_world) {
	vec3 delta = frag_pos - bulb_pos;
	float dist = length(delta);
	if (dist > hl_range || dist < 0.1) {
		return 0.0;
	}
	vec3 ray = delta / dist;
	float cos_ang = dot(ray, dir_nrm);
	float cone = smoothstep(0.55, 0.92, cos_ang);
	if (cone <= 0.001) {
		return 0.0;
	}
	float range_fade = 1.0 - smoothstep(hl_range * 0.45, hl_range, dist);
	float atten = 1.0 / (1.0 + dist * dist * 0.0028);
	vec3 h = normalize(-ray + view_world);
	float spec = pow(max(dot(frag_nrm, h), 0.0), 28.0) * 2.6;
	float diff = max(dot(frag_nrm, -ray), 0.0) * 0.45;
	return cone * range_fade * atten * (diff + spec);
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 wp = v_world_pos.xz;

	// Dual scrolling micro-ripple normal perturbation
	vec2 uv1 = wp * 0.24 + vec2(t * 0.65, t * 0.28);
	vec2 uv2 = wp * 0.42 + vec2(-t * 0.48, t * 0.54);
	float n1 = fbm_water(uv1);
	float n2 = fbm_water(uv2);
	float nx = (n1 - 0.5) * 0.28 + (n2 - 0.5) * 0.22;
	float nz = (fbm_water(uv1 + vec2(2.3, 1.7)) - 0.5) * 0.28 + (fbm_water(uv2 - vec2(1.9, 2.8)) - 0.5) * 0.22;

	vec3 world_nrm = normalize(v_world_nrm + vec3(nx, 0.0, nz));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_nrm, 0.0)).xyz);

	vec3 cam_pos = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 view_world = normalize(cam_pos - v_world_pos);
	float ndotv = clamp(dot(world_nrm, view_world), 0.02, 1.0);
	float fresnel = pow(1.0 - ndotv, 3.6);

	// Depth & swell color variation
	float swell_mix = clamp(v_crest * 0.85 + n1 * 0.35 - 0.15, 0.0, 1.0);
	vec3 water_col = mix(deep_color.rgb, shallow_color.rgb, swell_mix);

	// Shoreline foam along the north/south strait banks + around bridge piers
	float bank_dist = max(shore_z_half_span - abs(v_local_pos.z), 0.0);
	float shore_foam_zone = 1.0 - smoothstep(0.0, 18.0, bank_dist);
	float shore_waves = sin(bank_dist * 0.85 - t * 2.8 + n1 * 3.2) * 0.5 + 0.5;
	float shore_foam = shore_foam_zone * smoothstep(0.32, 0.78, shore_waves * shore_foam_zone + n2 * 0.45);

	// Bridge pillar foam wakes around X = +-6.8, Z in {-122, -56, +9, +75, +141}
	float pier_x = abs(abs(v_local_pos.x) - 6.8);
	float pier_z_mod = abs(mod(v_local_pos.z + 155.0, 65.8) - 32.9);
	float pier_dist = length(vec2(pier_x, pier_z_mod));
	float pier_foam = (1.0 - smoothstep(1.8, 7.5, pier_dist)) * smoothstep(0.30, 0.75, n1 * 0.65 + n2 * 0.55);

	// Rolling wave crest whitecaps
	float foam_pattern = n1 * 0.62 + n2 * 0.38;
	float crest_foam = smoothstep(0.60, 0.84, v_crest * 0.78 + foam_pattern * 0.44) * 0.78;
	float total_foam = clamp(max(crest_foam, max(shore_foam, pier_foam)), 0.0, 1.0);

	// Sky/fog Fresnel reflection + subtle atmospheric shimmer
	vec3 base_albedo = mix(water_col, horizon_reflection_color.rgb, fresnel * 0.68);
	base_albedo = mix(base_albedo, foam_color.rgb, total_foam);

	// Atmospheric sky/moonlight glitter trail across wave facets
	vec3 sky_light_dir = normalize(vec3(0.32, 0.64, -0.70));
	vec3 half_sky = normalize(sky_light_dir + view_world);
	float sky_glint = pow(max(dot(world_nrm, half_sky), 0.0), 42.0) * (1.0 - total_foam * 0.75) * 0.48;

	vec3 emission_out = horizon_reflection_color.rgb * (fresnel * 0.22 + sky_glint);
	if (hl_intensity > 0.005) {
		vec3 dir_nrm = normalize(hl_dir);
		float b_l = eval_headlight_water(hl_left_pos, dir_nrm, v_world_pos, world_nrm, view_world);
		float b_r = eval_headlight_water(hl_right_pos, dir_nrm, v_world_pos, world_nrm, view_world);
		float beam = clamp((b_l + b_r) * hl_intensity, 0.0, 2.5);
		emission_out += hl_color.rgb * beam * 0.85;
	}

	ALBEDO = base_albedo;
	ROUGHNESS = mix(0.11, 0.78, total_foam);
	METALLIC = mix(0.24, 0.02, total_foam);
	SPECULAR = 0.72;
	EMISSION = emission_out;
}
