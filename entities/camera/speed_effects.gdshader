shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float speed_ratio : hint_range(0.0, 1.2) = 0.0;
uniform float boost_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float steer_bias : hint_range(-1.0, 1.0) = 0.0;
uniform float effect_scale : hint_range(0.0, 1.0) = 1.0;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5 + steer_bias * 0.025, 0.52);
	vec2 dir = uv - center;
	float dist = length(dir);

	float active = smoothstep(0.18, 1.0, speed_ratio) * effect_scale;
	float edge_mask = smoothstep(0.24, 0.72, dist);

	vec3 col;
	if (active > 0.005 && edge_mask > 0.005) {
		float blur_amt = active * edge_mask * (0.018 + boost_pulse * 0.010);
		vec2 radial = normalize(dir + vec2(0.0001));

		// Subtle 4-tap peripheral radial motion blur keeping screen center crisp
		vec3 acc = vec3(0.0);
		acc += texture(screen_texture, uv - radial * blur_amt * 0.25).rgb;
		acc += texture(screen_texture, uv - radial * blur_amt * 0.55).rgb;
		acc += texture(screen_texture, uv - radial * blur_amt * 0.85).rgb;
		acc += texture(screen_texture, uv - radial * blur_amt * 1.15).rgb;
		col = acc * 0.25;

		// Subtle edge chromatic dispersion on high speed
		float chroma = active * edge_mask * 0.0028;
		float r_edge = texture(screen_texture, uv + radial * chroma).r;
		float b_edge = texture(screen_texture, uv - radial * chroma).b;
		col.r = mix(col.r, r_edge, 0.55);
		col.b = mix(col.b, b_edge, 0.55);

		// Dynamic peripheral speed lines
		float ang = atan(dir.y, dir.x);
		float sector = floor(ang * 42.0);
		float line_seed = hash12(vec2(sector, 1.73));
		float angular_shape = smoothstep(0.68, 0.96, sin(ang * 42.0 + line_seed * 6.283));
		float streak_phase = fract(dist * 3.8 - TIME * (4.5 + speed_ratio * 11.0) + line_seed * 10.0);
		float streak_body = smoothstep(0.0, 0.18, streak_phase) * smoothstep(0.95, 0.25, streak_phase);
		float streak = angular_shape * streak_body * smoothstep(0.32, 0.72, dist) * active * 0.20;
		col += vec3(0.78, 0.86, 0.96) * streak;
	} else {
		col = texture(screen_texture, uv).rgb;
	}

	// Very soft natural vignette at screen corners without darkening the image
	float vig = smoothstep(0.45, 0.92, dist) * (0.10 + 0.14 * active);
	col *= (1.0 - vig);

	COLOR = vec4(col, 1.0);
}
