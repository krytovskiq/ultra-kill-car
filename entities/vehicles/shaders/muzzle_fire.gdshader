shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform float flash_strength : hint_range(0.0, 1.0) = 0.0;
uniform float seed_phase = 0.0;
uniform vec4 core_color : source_color = vec4(1.0, 0.96, 0.78, 1.0);
uniform vec4 mid_color : source_color = vec4(1.0, 0.55, 0.12, 1.0);
uniform vec4 edge_color : source_color = vec4(0.85, 0.16, 0.02, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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

void fragment() {
	// UV.y = 1.0 near barrel mouth -> 0.0 toward flame tip; UV.x = 0.5 centerline
	float along = clamp(1.0 - UV.y, 0.0, 1.0);
	float radial = abs(UV.x - 0.5) * 2.0;

	// Flame narrows smoothly from mouth toward tip with turbulent jagged tongues
	float n1 = vnoise(vec2(UV.x * 7.5 + seed_phase, along * 5.0 - TIME * 12.0));
	float n2 = vnoise(vec2(UV.x * 16.0 - seed_phase * 0.7, along * 11.0 + seed_phase));
	float turb = mix(n1, n2, 0.45);

	float profile_width = mix(0.95, 0.12, pow(along, 0.75)) * (0.65 + 0.55 * turb);
	float lateral_mask = smoothstep(profile_width, profile_width * 0.15, radial);
	float length_mask = smoothstep(1.0, 0.55, along) * smoothstep(0.0, 0.07, along);
	float radial_halo = smoothstep(1.0, 0.18, length(UV - vec2(0.5)) * 2.0) * (0.75 + 0.25 * turb);

	float mask = clamp(max(lateral_mask * length_mask, radial_halo * 0.65 * (1.0 - along)), 0.0, 1.0);
	float heat = clamp(mask * (1.15 - along * 0.65), 0.0, 1.0);

	vec3 col = mix(edge_color.rgb, mid_color.rgb, smoothstep(0.18, 0.58, heat));
	col = mix(col, core_color.rgb, smoothstep(0.56, 0.92, heat));

	ALBEDO = col * 3.8 * flash_strength;
	ALPHA = mask * flash_strength;
}
