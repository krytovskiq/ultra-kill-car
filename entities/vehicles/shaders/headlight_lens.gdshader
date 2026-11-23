shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled;

uniform vec4 lens_color : source_color = vec4(1.0, 0.94, 0.80, 1.0);
uniform float intensity : hint_range(0.0, 4.0) = 1.35;
uniform float forward_sign = -1.0;
uniform vec2 lens_aspect = vec2(1.0, 1.0);

varying float v_facing;

void vertex() {
	vec3 lamp_dir = normalize((MODEL_MATRIX * vec4(0.0, 0.0, forward_sign, 0.0)).xyz);
	vec3 center_w = MODEL_MATRIX[3].xyz;
	vec3 to_cam = normalize(CAMERA_POSITION_WORLD - center_w);
	v_facing = smoothstep(0.02, 0.50, dot(lamp_dir, to_cam));

	vec2 sc = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz)) * lens_aspect;
	vec3 cam_right = normalize(INV_VIEW_MATRIX[0].xyz);
	vec3 cam_up = normalize(INV_VIEW_MATRIX[1].xyz);
	vec3 cam_fwd = normalize(INV_VIEW_MATRIX[2].xyz);
	// Nudge slightly toward viewer when facing camera so recessed housings never clip half the lens
	vec4 shifted_origin = vec4(center_w + cam_fwd * (0.04 * v_facing), 1.0);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(cam_right * sc.x, 0.0),
		vec4(cam_up * sc.y, 0.0),
		vec4(cam_fwd, 0.0),
		shifted_origin
	);
}

void fragment() {
	float d = length((UV - vec2(0.5)) * 2.0);
	float core = smoothstep(0.42, 0.08, d);
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), 2.5) * 0.60;
	float glow = (core * 0.95 + halo) * v_facing * intensity;
	ALBEDO = lens_color.rgb * glow;
	ALPHA = clamp(glow, 0.0, 1.0);
}
