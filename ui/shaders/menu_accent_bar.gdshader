shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.76, 0.22, 0.09, 1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0, 0.62, 0.24, 1.0);

void fragment() {
	float edge_fade = smoothstep(0.0, 0.06, UV.x) * smoothstep(1.0, 0.78, UV.x);
	float sweep = pow(max(0.0, sin(UV.x * 5.0 - TIME * 1.4)), 4.0);
	float pulse = 0.78 + 0.22 * sin(TIME * 2.2 + UV.x * 3.0);
	vec3 col = mix(base_color.rgb, shimmer_color.rgb, sweep * 0.7);
	COLOR = vec4(col * (1.05 + sweep * 0.35), edge_fade * pulse);
}
