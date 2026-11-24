shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec = 0.0;
uniform vec4 fog_color_dark : source_color = vec4(0.025, 0.028, 0.035, 1.0);
uniform vec4 fog_color_mid : source_color = vec4(0.11, 0.10, 0.10, 1.0);
uniform vec4 ember_color : source_color = vec4(0.94, 0.38, 0.12, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 41.3);
	return fract(p.x * p.y);
}

float noise2d(vec2 p) {
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
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise2d(p);
		p = p * 2.04 + vec2(11.3, 6.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	vec2 flow = vec2(time_sec * 0.16, -time_sec * 0.05);
	float mist = fbm(uv * vec2(3.6, 2.4) + flow);

	// Horizontal shutter + vignette iris dissolve (crisp, sleek, non-pixelated)
	vec2 c = uv - vec2(0.5);
	float rad = length(c * vec2(0.86, 1.25));
	float shutter = max(abs(c.y) * 1.45, rad * 0.92) * 0.72 + (1.0 - mist) * 0.22;

	float thresh = mix(1.08, -0.24, progress);
	float veil = smoothstep(thresh - 0.18, thresh + 0.10, shutter);
	veil = max(veil, smoothstep(0.76, 1.0, progress));
	veil *= smoothstep(0.0, 0.04, progress);

	// Subtle amber-crimson edge rim along the active wipe boundary
	float edge_band = smoothstep(0.14, 0.0, abs(shutter - thresh)) * sin(progress * 3.14159265);
	vec3 base_col = mix(fog_color_dark.rgb, fog_color_mid.rgb, mist * 0.45 * (1.0 - rad * 0.55));
	vec3 col = base_col + ember_color.rgb * (edge_band * 0.24);

	// Subtle horizontal tactical scanlines + fine film grain
	float scan = sin(uv.y * 520.0) * 0.008;
	float grain = (hash21(uv * 480.0 + vec2(time_sec * 17.0)) - 0.5) * 0.018;
	col = clamp(col + vec3(scan + grain), vec3(0.0), vec3(1.0));

	COLOR = vec4(col, clamp(veil, 0.0, 1.0));
}
