shader_type canvas_item;

uniform vec4 fog_tint : source_color = vec4(0.32, 0.36, 0.37, 1.0);
uniform vec4 ember_color : source_color = vec4(0.96, 0.46, 0.16, 1.0);
uniform float scrim_strength : hint_range(0.0, 1.0) = 0.78;
uniform float fog_strength : hint_range(0.0, 1.0) = 0.42;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.45);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.7, 7.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Multi-layered slow drifting apocalypse fog banks
	float fog_a = fbm(vec2(uv.x * 2.8 - t * 0.035, uv.y * 2.2 - t * 0.014));
	float fog_b = fbm(vec2(uv.x * 5.2 + t * 0.022, uv.y * 3.8 + t * 0.018));
	float fog_band = mix(fog_a, fog_b, 0.45);
	float low_mist = smoothstep(0.32, 1.0, uv.y) * 0.65 + 0.35;
	float fog_alpha = clamp((fog_band - 0.24) * 1.45, 0.0, 1.0) * low_mist * fog_strength;

	// Left dark scrim frames navigation controls while leaving right highway & vehicle clear
	float left_scrim = smoothstep(0.62, 0.05, uv.x) * scrim_strength;
	float top_bottom = smoothstep(0.22, 0.0, uv.y) * 0.30 + smoothstep(0.75, 1.0, uv.y) * 0.42;
	float radial_vig = smoothstep(0.45, 1.15, length((uv - vec2(0.55, 0.5)) * vec2(1.1, 1.35))) * 0.55;
	float dark_alpha = clamp(max(left_scrim, max(top_bottom, radial_vig)), 0.0, 0.88);

	// Subtle floating rust-ash embers rising slowly in wind
	vec2 spark_uv = vec2(uv.x * 24.0 + sin(uv.y * 6.0 + t * 0.7) * 0.35 - t * 0.45, uv.y * 14.0 + t * 0.65);
	vec2 cell = floor(spark_uv);
	vec2 f = fract(spark_uv);
	float h = hash21(cell);
	float spark = 0.0;
	if (h > 0.965) {
		vec2 center = vec2(fract(h * 19.3), fract(h * 43.7));
		float d = length(f - center);
		float twinkle = 0.55 + 0.45 * sin(t * 4.5 + h * 40.0);
		spark = smoothstep(0.08, 0.015, d) * twinkle * 0.70;
	}

	// Subtle film grain
	float grain = (hash21(uv * 800.0 + fract(t * 23.0)) - 0.5) * 0.03;

	vec3 base_dark = vec3(0.03, 0.035, 0.04);
	vec3 col = mix(base_dark, fog_tint.rgb, clamp(fog_alpha / max(dark_alpha + fog_alpha, 0.001), 0.0, 0.82));
	col += ember_color.rgb * spark + grain;

	float out_alpha = clamp(max(dark_alpha, fog_alpha) + spark * 0.55, 0.0, 0.90);
	COLOR = vec4(col, out_alpha);
}
