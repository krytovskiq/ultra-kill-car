extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ GMC VANDURA — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	STEER_SPEED = 1.42
	STEER_LIMIT = 0.36
	steer_inertia = 4.5
	high_speed_steer_min_ratio = 0.24

	throttle_response = 3.5
	throttle_release_rate = 4.6
	engine_force_value = 7900
	MAX_SPEED_KMH = 148
	brake_force = 96.0
	max_brake_decel_mps2 = 7.4
	aero_drag_coeff = 0.62
	gear_speed_ratios = [0.18, 0.36, 0.56, 0.78, 1.02]
	gear_torque_multipliers = [1.62, 1.32, 1.04, 0.82, 0.62]

	suspension_firmness = 0.96
	compression_damping_ratio = 0.48
	rebound_damping_ratio = 0.64
	anti_roll_stiffness = 9600.0
	front_spring_stiffness = 74000.0
	rear_spring_stiffness = 72000.0
	front_rest_length_scale = 1.08
	rear_rest_length_scale = 1.12
	front_grip_bias = 0.96
	rear_grip_bias = 1.06
	suspension_travel_speed = 16.5
	weight_transfer_long = 0.26
	weight_transfer_lat = 0.26
	com_height = 0.46
	com_z_offset = -0.14
	wheelbase_m = 3.18
	steering_scrub_drag = 0.16
	impact_momentum_keep = 0.82
	body_roll_torque_factor = 0.70
	body_pitch_torque_factor = 0.62
	lateral_stiffness = 11.8
	tire_friction = 2.34
	drift_grip_factor = 0.78
	yaw_stability_assist = 2.5
	hull_half_extents = Vector2(1.12, 2.58)

	engine_sound_id = "vandura"
	engine_pitch_scale = 0.98
	has_exhaust_backfire = false
	gear_shift_pitch_base = 0.90
	shadow_texture = GlbVehicleHelper.make_shadow_tex("vandura", 0.54, 0.70)
	headlight_positions = [Vector3(-0.72, 0.85, -2.52), Vector3(0.72, 0.85, -2.52)]
	taillight_positions = [Vector3(-0.84, 1.00, 2.51), Vector3(0.84, 1.00, 2.51)]
	headlight_lens_size = Vector2(0.32, 0.26)
	taillight_lens_size = Vector2(0.22, 0.34)
	headlight_proj_size = Vector2(14.0, 33.0)
	headlight_proj_z_start = -2.54
	taillight_proj_size = Vector2(3.8, 2.3)
	taillight_proj_z_start = 2.48
	shadow_blob_size = Vector2(4.90, 9.10)
	shadow_offset = Vector2(0.0, 0.04)

	health = 1450
	engine_hood_offset = Vector3(0.0, 1.08, -1.90)
	car_paint_color = Color(0.15, 0.16, 0.18)
	zombie_damage_taken = 5
	crash_death_speed_mps = 26.0
	max_fuel = 155
	fuel_per_100m = 3.4
	idle_fuel_per_sec = 0.23
	exhaust_offset = Vector3(-0.64, 0.32, 2.54)
	exhaust_offsets = [Vector3(-0.64, 0.32, 2.54), Vector3(0.64, 0.32, 2.54)]
	exhaust_style = "gasoline"

func _ready() -> void:
	mass = 2650.0
	_assemble_vandura_visuals()
	super()

func _assemble_vandura_visuals() -> void:
	if get_node_or_null("VanduraModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/Vandura/vandura_model.glb")
	if model_root == null:
		return
	model_root.name = "VanduraModelRoot"
	model_root.position = Vector3(0.0, 0.0, -0.20)
	add_child(model_root)
	GlbVehicleHelper.apply_material_overrides(model_root, {
		"exterior.012": {
			"albedo_color": Color(0.15, 0.16, 0.18),
			"metallic": 0.28,
			"roughness": 0.48,
			"clearcoat": 0.08,
			"detail_albedo": TEX_RUST_DIFF,
			"detail_normal": TEX_RUST_NOR,
		}
	})
	var wheel_map: Dictionary = {
		"wheelFL": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"wheelFR": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"wheelBL": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"wheelBR": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
