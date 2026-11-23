shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec4 beam_color : source_color = vec4(1.0, 0.94, 0.82, 1.0);
uniform float beam_intensity : hint_range(0.0, 2.0) = 0.26;

void fragment() {
	// UV.y = 0 at emitter tip, UV.y = 1 at far open end of cone/beam
	float long_fade = smoothstep(0.0, 0.08, UV.y) * pow(clamp(1.0 - UV.y, 0.0, 1.0), 1.85);
	// Soft Fresnel fade at grazing edges of mesh
	float edge_soft = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.65);
	float dust = 0.92 + 0.08 * sin(UV.y * 18.0 - TIME * 4.5);

	float strength = long_fade * edge_soft * dust * beam_intensity;
	ALBEDO = beam_color.rgb * strength;
	ALPHA = clamp(strength, 0.0, 1.0);
}
