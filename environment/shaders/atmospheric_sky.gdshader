shader_type sky;

uniform vec4 sky_top_color : source_color = vec4(0.32, 0.42, 0.54, 1.0);
uniform vec4 sky_horizon_color : source_color = vec4(0.62, 0.61, 0.58, 1.0);
uniform vec4 ground_horizon_color : source_color = vec4(0.48, 0.46, 0.43, 1.0);
uniform vec4 ground_bottom_color : source_color = vec4(0.22, 0.21, 0.19, 1.0);
uniform vec4 cloud_lit_color : source_color = vec4(0.86, 0.85, 0.82, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.40, 0.44, 0.50, 1.0);
uniform vec4 sun_glow_color : source_color = vec4(1.0, 0.88, 0.72, 1.0);
uniform vec3 sun_direction = vec3(0.38, 0.48, 0.78);
uniform vec3 moon_direction = vec3(-0.18, 0.34, 0.92);
uniform float night_factor : hint_range(0.0, 1.0) = 0.0;
uniform float blood_moon_factor : hint_range(0.0, 1.0) = 0.0;
uniform float acid_factor : hint_range(0.0, 1.0) = 0.0;
uniform float star_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.54;
uniform float cloud_speed : hint_range(0.0, 0.2) = 0.014;
uniform float haze_strength : hint_range(0.0, 1.0) = 0.65;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.52;
	for (int i = 0; i < 4; i++) {
		v += amp * noise2(p);
		p = p * 2.07 + vec2(17.1, 31.7);
		amp *= 0.48;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// Base sky and ground dome gradients
	float sky_t = pow(clamp(max(y, 0.0), 0.0, 1.0), 0.52);
	vec3 sky_col = mix(sky_horizon_color.rgb, sky_top_color.rgb, sky_t);

	float ground_t = pow(clamp(max(-y, 0.0), 0.0, 1.0), 0.45);
	vec3 ground_col = mix(ground_horizon_color.rgb, ground_bottom_color.rgb, ground_t);

	vec3 col = mix(ground_col, sky_col, smoothstep(-0.04, 0.06, y));

	// Soft sun scatter through atmospheric haze (fades at night)
	vec3 s_dir = normalize(sun_direction);
	float sun_dot = max(dot(dir, s_dir), 0.0);
	float sun_halo = pow(sun_dot, 6.0) * 0.30 + pow(sun_dot, 42.0) * 0.35;
	float sun_disc = smoothstep(0.9965, 0.9992, sun_dot) * 0.55;
	float above_horizon = smoothstep(-0.05, 0.15, y);
	col += sun_glow_color.rgb * (sun_halo + sun_disc) * above_horizon * (1.0 - night_factor * 0.85);

	// Night twinkling stars (masked behind thick acid storm & horizon haze)
	if (star_intensity > 0.01 && y > 0.03) {
		vec2 star_uv = dir.xz / max(y + 0.18, 0.12) * 44.0;
		vec2 cell = floor(star_uv);
		vec2 f = fract(star_uv) - 0.5;
		float rnd = hash21(cell);
		if (rnd > 0.945) {
			float twinkle = 0.62 + 0.38 * sin(TIME * (1.8 + rnd * 4.5) + rnd * 62.8);
			float st_pt = smoothstep(0.22, 0.02, length(f)) * twinkle;
			vec3 st_col = mix(vec3(0.84, 0.90, 1.0), vec3(1.0, 0.56, 0.46), blood_moon_factor * 0.75);
			col += st_col * st_pt * star_intensity * smoothstep(0.03, 0.25, y) * (1.0 - acid_factor * 0.75);
		}
	}

	// Night Moon & Crimson Blood Moon during Blood Night anomaly
	float moon_vis = clamp(night_factor + blood_moon_factor, 0.0, 1.0);
	if (moon_vis > 0.02 && y > -0.02) {
		vec3 m_dir = normalize(moon_direction);
		float m_dot = max(dot(dir, m_dir), 0.0);
		float m_thresh = mix(0.9968, 0.9922, blood_moon_factor);
		float m_disc = smoothstep(m_thresh, m_thresh + 0.0018, m_dot);
		float crater = fbm(dir.xy * 18.0 + vec2(3.1, 7.4));
		vec3 m_surface = mix(vec3(0.86, 0.90, 0.96), vec3(0.96, 0.18, 0.14), blood_moon_factor) * (0.76 + crater * 0.36);
		vec3 m_halo_col = mix(vec3(0.45, 0.56, 0.78), vec3(0.88, 0.14, 0.12), blood_moon_factor);
		float m_halo = pow(m_dot, mix(24.0, 7.0, blood_moon_factor)) * mix(0.32, 0.62, blood_moon_factor);
		col += (m_surface * m_disc * 1.15 + m_halo_col * m_halo) * moon_vis * smoothstep(-0.02, 0.12, y);
	}

	// Flowing layered atmospheric clouds
	if (y > 0.005) {
		float plane_dist = 1.0 / (y + 0.14);
		vec2 uv1 = dir.xz * plane_dist * 0.65 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.45);
		vec2 uv2 = dir.xz * plane_dist * 1.25 - vec2(TIME * cloud_speed * 0.6, TIME * cloud_speed * 0.9);

		float n1 = fbm(uv1);
		float n2 = fbm(uv2 + vec2(n1 * 0.45));
		float density = mix(n1, n2, 0.42);

		float threshold = mix(0.68, 0.36, cloud_coverage);
		float cloud_mask = smoothstep(threshold, threshold + 0.24, density);
		// Horizon dissolve so clouds merge seamlessly with depth fog
		float horizon_fade = smoothstep(0.01, 0.22, y);
		cloud_mask *= horizon_fade * 0.88;

		// Soft cloud rim lighting from sun/moon direction
		float sun_cloud = pow(sun_dot, 4.0) * 0.55 + (1.0 - smoothstep(0.4, 0.85, density)) * 0.25;
		vec3 c_col = mix(cloud_shadow_color.rgb, cloud_lit_color.rgb, clamp(0.35 + sun_cloud, 0.0, 1.0));
		c_col += sun_glow_color.rgb * pow(sun_dot, 12.0) * 0.22 * (1.0 - night_factor * 0.7);
		c_col = mix(c_col, vec3(0.42, 0.62, 0.22) * (0.65 + 0.4 * density), acid_factor * 0.45);

		col = mix(col, c_col, cloud_mask);
	}

	// Atmospheric mist band near the horizon
	float mist_band = exp(-abs(y) * 9.5) * haze_strength;
	col = mix(col, sky_horizon_color.rgb, clamp(mist_band, 0.0, 0.72));

	COLOR = col;
}
