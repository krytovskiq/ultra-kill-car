extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ PLYMOUTH BARRACUDA '70 — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	STEER_SPEED = 2.15
	STEER_LIMIT = 0.39
	steer_inertia = 7.4
	high_speed_steer_min_ratio = 0.21

	throttle_response = 6.2
	throttle_release_rate = 6.8
	engine_force_value = 8450
	MAX_SPEED_KMH = 236
	brake_force = 105.0
	max_brake_decel_mps2 = 9.8
	aero_drag_coeff = 0.41
	gear_speed_ratios = [0.19, 0.38, 0.58, 0.80, 1.04]
	gear_torque_multipliers = [1.80, 1.45, 1.14, 0.89, 0.67]

	suspension_firmness = 1.22
	compression_damping_ratio = 0.50
	rebound_damping_ratio = 0.68
	anti_roll_stiffness = 9400.0
	front_spring_stiffness = 62000.0
	rear_spring_stiffness = 60000.0
	front_rest_length_scale = 0.92
	rear_rest_length_scale = 0.96
	front_grip_bias = 1.04
	rear_grip_bias = 1.06
	suspension_travel_speed = 23.0
	weight_transfer_long = 0.21
	weight_transfer_lat = 0.22
	com_height = 0.29
	com_z_offset = -0.06
	wheelbase_m = 2.74
	steering_scrub_drag = 0.11
	impact_momentum_keep = 0.66
	body_roll_torque_factor = 0.46
	body_pitch_torque_factor = 0.44
	lateral_stiffness = 13.4
	tire_friction = 2.50
	drift_grip_factor = 0.77
	yaw_stability_assist = 2.3
	hull_half_extents = Vector2(0.98, 2.36)

	engine_sound_id = "barracuda"
	engine_pitch_scale = 1.00
	has_exhaust_backfire = true
	gear_shift_pitch_base = 1.04
	shadow_texture = GlbVehicleHelper.make_shadow_tex("barracuda", 0.50, 0.68)
	headlight_positions = [Vector3(-0.68, 0.58, -2.28), Vector3(0.68, 0.58, -2.28)]
	taillight_positions = [Vector3(-0.62, 0.78, 2.28), Vector3(0.62, 0.78, 2.28)]
	headlight_lens_size = Vector2(0.28, 0.24)
	taillight_lens_size = Vector2(0.42, 0.18)
	headlight_proj_size = Vector2(13.5, 36.0)
	headlight_proj_z_start = -2.30
	taillight_proj_size = Vector2(3.6, 2.2)
	taillight_proj_z_start = 2.26
	shadow_blob_size = Vector2(4.40, 8.40)
	shadow_offset = Vector2(0.0, 0.04)

	health = 1550
	engine_hood_offset = Vector3(0.0, 0.86, -1.65)
	car_paint_color = Color(0.66, 0.24, 0.08)
	zombie_damage_taken = 5
	crash_death_speed_mps = 26.0
	max_fuel = 132
	fuel_per_100m = 3.3
	idle_fuel_per_sec = 0.24
	exhaust_offset = Vector3(-0.50, 0.25, 2.32)
	exhaust_offsets = [Vector3(-0.50, 0.25, 2.32), Vector3(0.50, 0.25, 2.32)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 1660.0
	_assemble_barracuda_visuals()
	super()

func _assemble_barracuda_visuals() -> void:
	if get_node_or_null("BarracudaModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/Barracuda/barracuda_model.glb")
	if model_root == null:
		return
	model_root.name = "BarracudaModelRoot"
	model_root.position = Vector3(0.0, 0.02, 0.0)
	add_child(model_root)
	GlbVehicleHelper.apply_material_overrides(model_root, {
		"exterior.011": {
			"albedo_color": Color(0.66, 0.24, 0.08),
			"metallic": 0.34,
			"roughness": 0.42,
			"clearcoat": 0.14,
			"detail_albedo": TEX_RUST_DIFF,
			"detail_normal": TEX_RUST_NOR,
		}
	})
	var wheel_map: Dictionary = {
		"wheelFL_pivot": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"wheelFR_pivot": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"wheelBL_pivot": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"wheelBR_pivot": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
