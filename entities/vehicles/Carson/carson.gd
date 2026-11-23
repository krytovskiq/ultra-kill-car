extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ CARSON GRAND SICILIAN — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	STEER_SPEED = 1.65
	STEER_LIMIT = 0.36
	steer_inertia = 5.6
	high_speed_steer_min_ratio = 0.22

	throttle_response = 4.6
	throttle_release_rate = 5.4
	engine_force_value = 8200
	MAX_SPEED_KMH = 186
	brake_force = 98.0
	max_brake_decel_mps2 = 8.2
	aero_drag_coeff = 0.50
	gear_speed_ratios = [0.18, 0.36, 0.56, 0.78, 1.02]
	gear_torque_multipliers = [1.74, 1.40, 1.12, 0.88, 0.64]

	suspension_firmness = 1.06
	compression_damping_ratio = 0.48
	rebound_damping_ratio = 0.64
	anti_roll_stiffness = 8800.0
	front_spring_stiffness = 66000.0
	rear_spring_stiffness = 64000.0
	front_rest_length_scale = 1.02
	rear_rest_length_scale = 1.06
	front_grip_bias = 0.98
	rear_grip_bias = 1.04
	suspension_travel_speed = 19.0
	weight_transfer_long = 0.24
	weight_transfer_lat = 0.24
	com_height = 0.36
	com_z_offset = -0.14
	wheelbase_m = 3.26
	steering_scrub_drag = 0.14
	impact_momentum_keep = 0.80
	body_roll_torque_factor = 0.58
	body_pitch_torque_factor = 0.56
	lateral_stiffness = 12.2
	tire_friction = 2.38
	drift_grip_factor = 0.74
	yaw_stability_assist = 2.1
	hull_half_extents = Vector2(0.98, 2.46)

	engine_sound_id = "carson"
	engine_pitch_scale = 1.00
	has_exhaust_backfire = true
	gear_shift_pitch_base = 0.96
	shadow_texture = GlbVehicleHelper.make_shadow_tex("carson", 0.50, 0.70)
	headlight_positions = [Vector3(-0.58, 0.72, -2.18), Vector3(0.58, 0.72, -2.18)]
	taillight_positions = [Vector3(-0.55, 0.67, 2.34), Vector3(0.55, 0.67, 2.34)]
	headlight_lens_size = Vector2(0.24, 0.24)
	taillight_lens_size = Vector2(0.22, 0.22)
	headlight_proj_size = Vector2(13.5, 34.0)
	headlight_proj_z_start = -2.20
	taillight_proj_size = Vector2(3.6, 2.2)
	taillight_proj_z_start = 2.32
	shadow_blob_size = Vector2(4.40, 8.80)
	shadow_offset = Vector2(0.0, 0.04)

	health = 1650
	engine_hood_offset = Vector3(0.0, 0.96, -1.55)
	car_paint_color = Color(0.26, 0.26, 0.28)
	zombie_damage_taken = 4
	crash_death_speed_mps = 26.0
	max_fuel = 130
	fuel_per_100m = 3.3
	idle_fuel_per_sec = 0.23
	exhaust_offset = Vector3(-0.45, 0.25, 2.48)
	exhaust_offsets = [Vector3(-0.45, 0.25, 2.48), Vector3(0.45, 0.25, 2.48)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 2180.0
	_assemble_carson_visuals()
	super()

func _assemble_carson_visuals() -> void:
	if get_node_or_null("CarsonModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/Carson/carson_model.glb")
	if model_root == null:
		return
	model_root.name = "CarsonModelRoot"
	model_root.position = Vector3(0.0, 0.05, -0.09)
	model_root.rotation.y = PI * 0.5
	add_child(model_root)
	var wheel_map: Dictionary = {
		"E4_38_E5_39_001_5": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"E4_38_E5_39_002_7": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"E4_38_E5_39_003_9": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"34_A8_1C_93_69": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
