shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never;

uniform sampler2D cloud_sheet : source_color, filter_linear_mipmap, repeat_enable;
uniform float scroll_speed = 0.85;
uniform float twist_turns = 3.2;
uniform float fps = 12.0;
uniform float opacity = 0.88;
uniform vec4 top_storm_color : source_color = vec4(0.12, 0.13, 0.16, 1.0);
uniform vec4 mid_cloud_color : source_color = vec4(0.32, 0.33, 0.36, 1.0);
uniform vec4 base_dust_color : source_color = vec4(0.48, 0.40, 0.31, 1.0);
uniform float radial_cap = 0.0;

vec2 flipbook_tile(vec2 tile_uv, float frame_idx) {
	float f = mod(floor(frame_idx), 64.0);
	float col = mod(f, 8.0);
	float row = floor(f / 8.0);
	vec2 wrapped = fract(tile_uv);
	vec2 clamped = mix(vec2(0.025), vec2(0.975), wrapped);
	return (vec2(col, row) + clamped) * vec2(0.125, 0.125);
}

void vertex() {
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	float flute = sin(atan(VERTEX.z, VERTEX.x) * 5.0 + h * 12.0 - TIME * 4.2) * (0.28 + 0.85 * h);
	vec2 radial_dir = length(VERTEX.xz) > 0.01 ? normalize(VERTEX.xz) : vec2(1.0, 0.0);
	VERTEX.xz += radial_dir * flute * (1.0 - radial_cap * 0.65) * smoothstep(0.0, 0.18, h);
}

void fragment() {
	// UV.y = 0 at top of funnel mesh, UV.y = 1 at bottom; for cap UV.y = 0 inner, 1 outer
	float h = clamp(1.0 - UV.y, 0.0, 1.0);
	float swirl_u = UV.x * 2.0 + h * twist_turns - TIME * scroll_speed;
	float rise_v = UV.y * 1.6 + TIME * 0.32;

	float tf = TIME * fps;
	float f0 = floor(tf);
	float f1 = f0 + 1.0;
	float f_blend = fract(tf);
	vec4 tex_a = texture(cloud_sheet, flipbook_tile(vec2(swirl_u, rise_v), f0));
	vec4 tex_b = texture(cloud_sheet, flipbook_tile(vec2(swirl_u, rise_v), f1));
	vec4 cloud = mix(tex_a, tex_b, f_blend);

	float fresnel = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 0.7);
	float funnel_fade = smoothstep(0.0, 0.10, h) * (1.0 - smoothstep(0.88, 1.0, h));
	float cap_mask = smoothstep(0.0, 0.14, UV.y) * (1.0 - smoothstep(0.55, 1.0, UV.y));
	float height_fade = mix(funnel_fade, cap_mask, step(0.5, radial_cap));

	vec3 funnel_grad = mix(base_dust_color.rgb, mid_cloud_color.rgb, smoothstep(0.04, 0.38, h));
	funnel_grad = mix(funnel_grad, top_storm_color.rgb, smoothstep(0.45, 0.92, h));
	vec3 wall_grad = mix(mid_cloud_color.rgb, top_storm_color.rgb, smoothstep(0.0, 0.85, h));
	vec3 storm_grad = mix(funnel_grad, wall_grad, step(0.5, radial_cap));
	vec3 cloud_shade = mix(vec3(0.75), cloud.rgb, cloud.a);
	vec3 final_col = storm_grad * (0.72 + 0.48 * cloud_shade) + vec3(0.05, 0.06, 0.08) * (1.0 - fresnel);

	float cloud_alpha = mix(0.42, 1.0, cloud.a);
	ALPHA = clamp(cloud_alpha * fresnel * height_fade * opacity, 0.0, 0.96);
	ALBEDO = final_col;
}
