extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ DELOREAN V6 TURBO — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	STEER_SPEED = 2.35
	STEER_LIMIT = 0.40
	steer_inertia = 8.0
	high_speed_steer_min_ratio = 0.21

	throttle_response = 6.8
	throttle_release_rate = 7.2
	engine_force_value = 8900
	MAX_SPEED_KMH = 248
	brake_force = 110.0
	max_brake_decel_mps2 = 10.2
	aero_drag_coeff = 0.36
	gear_speed_ratios = [0.16, 0.32, 0.50, 0.69, 0.88, 1.06]
	gear_torque_multipliers = [1.82, 1.48, 1.18, 0.94, 0.74, 0.56]

	suspension_firmness = 1.28
	compression_damping_ratio = 0.50
	rebound_damping_ratio = 0.68
	anti_roll_stiffness = 9800.0
	front_spring_stiffness = 62000.0
	rear_spring_stiffness = 64000.0
	front_rest_length_scale = 0.88
	rear_rest_length_scale = 0.92
	front_grip_bias = 1.04
	rear_grip_bias = 1.08
	suspension_travel_speed = 24.0
	weight_transfer_long = 0.18
	weight_transfer_lat = 0.20
	com_height = 0.26
	com_z_offset = 0.04
	wheelbase_m = 2.44
	steering_scrub_drag = 0.10
	impact_momentum_keep = 0.66
	body_roll_torque_factor = 0.42
	body_pitch_torque_factor = 0.40
	lateral_stiffness = 13.8
	tire_friction = 2.55
	drift_grip_factor = 0.79
	yaw_stability_assist = 2.4
	hull_half_extents = Vector2(0.98, 2.12)

	engine_sound_id = "delorean"
	engine_pitch_scale = 1.03
	has_exhaust_backfire = true
	gear_shift_pitch_base = 1.12
	shadow_texture = GlbVehicleHelper.make_shadow_tex("delorean", 0.50, 0.68)
	headlight_positions = [Vector3(-0.58, 0.56, -2.02), Vector3(0.58, 0.56, -2.02)]
	taillight_positions = [Vector3(-0.62, 0.77, 2.04), Vector3(0.62, 0.77, 2.04)]
	headlight_lens_size = Vector2(0.32, 0.18)
	taillight_lens_size = Vector2(0.46, 0.18)
	headlight_proj_size = Vector2(14.5, 38.0)
	headlight_proj_z_start = -2.04
	taillight_proj_size = Vector2(3.6, 2.2)
	taillight_proj_z_start = 2.02
	shadow_blob_size = Vector2(4.40, 7.90)
	shadow_offset = Vector2(0.0, 0.02)

	health = 1350
	engine_hood_offset = Vector3(0.0, 0.80, 1.45)
	car_paint_color = Color(0.62, 0.65, 0.68)
	zombie_damage_taken = 5
	crash_death_speed_mps = 26.0
	max_fuel = 128
	fuel_per_100m = 3.1
	idle_fuel_per_sec = 0.21
	exhaust_offset = Vector3(-0.42, 0.24, 2.08)
	exhaust_offsets = [Vector3(-0.42, 0.24, 2.08), Vector3(0.42, 0.24, 2.08)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 1380.0
	_assemble_delorean_visuals()
	super()

func _assemble_delorean_visuals() -> void:
	if get_node_or_null("DeLoreanModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/DeLorean/delorean_model.glb")
	if model_root == null:
		return
	model_root.name = "DeLoreanModelRoot"
	model_root.position = Vector3(0.0, 0.01, 0.0)
	model_root.rotation.y = PI * 0.5
	add_child(model_root)
	GlbVehicleHelper.apply_material_overrides(model_root, {
		"DSV2581_bodymat": {
			"albedo_color": Color(0.62, 0.65, 0.68),
			"metallic": 0.72,
			"roughness": 0.32,
			"clearcoat": 0.10,
		},
		"RB1c_Tire_1k": {
			"metallic": 0.08,
			"roughness": 0.86,
		},
	})
	var wheel_map: Dictionary = {
		"Hazer81Turbo_WheelStock_FL": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"Hazer81Turbo_WheelStock_FR": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"Hazer81Turbo_WheelStock_RL": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"Hazer81Turbo_WheelStock_RR": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
