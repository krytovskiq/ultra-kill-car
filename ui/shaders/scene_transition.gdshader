shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec = 0.0;
uniform vec4 fog_color_dark : source_color = vec4(0.04, 0.042, 0.046, 1.0);
uniform vec4 fog_color_mid : source_color = vec4(0.145, 0.138, 0.13, 1.0);
uniform vec4 ember_color : source_color = vec4(0.88, 0.36, 0.14, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
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
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise2d(p);
		p = p * 2.07 + vec2(13.4, 7.1);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 wind = vec2(time_sec * 0.24, time_sec * 0.06);
	float smoke_lo = fbm(uv * vec2(3.2, 2.2) + wind);
	float smoke_hi = fbm(uv * vec2(7.5, 5.2) - wind * 1.45);
	float fog_pattern = mix(smoke_lo, smoke_hi, 0.42);

	vec2 centered = uv - vec2(0.5);
	float dist = length(centered * vec2(1.18, 0.92));
	float vignette = smoothstep(0.18, 0.95, dist);

	// Soft smoky threshold from screen edges inward, guaranteeing 0 at progress=0 and 1 at progress=1
	float threshold = mix(-0.18, 1.18, progress);
	float edge_mask = smoothstep(threshold - 0.32, threshold + 0.06, 1.0 - (vignette * 0.52 + fog_pattern * 0.48));
	float veil = clamp(max(smoothstep(0.0, 0.85, progress) * 0.65, edge_mask), 0.0, 1.0);
	veil = mix(veil, 1.0, smoothstep(0.84, 1.0, progress));
	veil *= smoothstep(0.0, 0.06, progress);

	vec3 col = mix(fog_color_dark.rgb, fog_color_mid.rgb, smoke_lo * (1.0 - vignette * 0.6));
	float ember_noise = smoothstep(0.82, 0.97, fbm(uv * vec2(11.0, 7.0) + vec2(time_sec * 0.52, -time_sec * 0.31)));
	float mid_transition = sin(progress * 3.14159265);
	col += ember_color.rgb * (ember_noise * 0.22 * mid_transition);

	// Fine atmospheric film grain
	float grain = (hash21(uv * 512.0 + vec2(time_sec * 19.0)) - 0.5) * 0.025;
	col = clamp(col + vec3(grain), vec3(0.0), vec3(1.0));

	COLOR = vec4(col, veil);
}
