extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ УАЗ БУХАНКА (UAZ BUHANKA) — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	STEER_SPEED = 1.45
	STEER_LIMIT = 0.38
	steer_inertia = 4.6
	high_speed_steer_min_ratio = 0.25

	throttle_response = 3.2
	throttle_release_rate = 4.4
	engine_force_value = 6600
	MAX_SPEED_KMH = 118
	brake_force = 92.0
	max_brake_decel_mps2 = 7.2
	aero_drag_coeff = 0.66
	gear_speed_ratios = [0.20, 0.42, 0.68, 0.96]
	gear_torque_multipliers = [1.48, 1.16, 0.86, 0.62]

	suspension_firmness = 0.88
	compression_damping_ratio = 0.46
	rebound_damping_ratio = 0.62
	anti_roll_stiffness = 7800.0
	front_spring_stiffness = 62000.0
	rear_spring_stiffness = 60000.0
	front_rest_length_scale = 1.18
	rear_rest_length_scale = 1.20
	front_grip_bias = 0.98
	rear_grip_bias = 1.04
	suspension_travel_speed = 16.0
	weight_transfer_long = 0.28
	weight_transfer_lat = 0.28
	com_height = 0.44
	com_z_offset = -0.10
	wheelbase_m = 2.37
	steering_scrub_drag = 0.16
	impact_momentum_keep = 0.78
	body_roll_torque_factor = 0.76
	body_pitch_torque_factor = 0.68
	lateral_stiffness = 11.2
	tire_friction = 2.30
	drift_grip_factor = 0.78
	yaw_stability_assist = 2.4
	hull_half_extents = Vector2(1.06, 2.18)

	engine_sound_id = "buhanka"
	engine_pitch_scale = 1.00
	has_exhaust_backfire = false
	gear_shift_pitch_base = 0.94
	shadow_texture = GlbVehicleHelper.make_shadow_tex("buhanka", 0.54, 0.68)
	headlight_positions = [Vector3(-0.68, 1.05, -2.10), Vector3(0.68, 1.05, -2.10)]
	taillight_positions = [Vector3(-0.84, 0.88, 2.16), Vector3(0.84, 0.88, 2.16)]
	headlight_lens_size = Vector2(0.28, 0.28)
	taillight_lens_size = Vector2(0.20, 0.28)
	headlight_proj_size = Vector2(13.5, 31.0)
	headlight_proj_z_start = -2.12
	taillight_proj_size = Vector2(3.6, 2.2)
	taillight_proj_z_start = 2.14
	shadow_blob_size = Vector2(4.70, 8.00)
	shadow_offset = Vector2(0.0, 0.04)

	health = 1050
	engine_hood_offset = Vector3(0.0, 1.06, -1.68)
	car_paint_color = Color(0.76, 0.62, 0.16)
	zombie_damage_taken = 6
	crash_death_speed_mps = 23.0
	max_fuel = 135
	fuel_per_100m = 3.2
	idle_fuel_per_sec = 0.21
	exhaust_offset = Vector3(-0.52, 0.34, 2.18)
	exhaust_offsets = [Vector3(-0.52, 0.34, 2.18)]
	exhaust_style = "gasoline"

func _ready() -> void:
	mass = 2250.0
	_assemble_buhanka_visuals()
	super()

func _assemble_buhanka_visuals() -> void:
	if get_node_or_null("BuhankaModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/Buhanka/buhanka_model.glb")
	if model_root == null:
		return
	model_root.name = "BuhankaModelRoot"
	model_root.position = Vector3(0.0, 0.0, 0.198)
	model_root.rotation.y = PI
	model_root.scale = Vector3.ONE * 1.48
	add_child(model_root)
	GlbVehicleHelper.apply_material_overrides(model_root, {
		"material_11": {"metallic": 0.06, "roughness": 0.88},
	})
	var wheel_map: Dictionary = {
		"FL": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"FR": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"RL": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"RR": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	GlbVehicleHelper.split_buhanka_wheels(self, model_root, wheel_map)
