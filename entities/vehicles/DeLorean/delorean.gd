extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: DELOREAN V6 TURBO
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 5700           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 248                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.6             ## Отзывчивость педали газа W (как на GMC 2500)
	launch_wheelspin_intensity = 4.60   ## Пробуксовка колёс при старте с места в пол
	brake_force = 108.0                 ## Сила тормозов
	max_brake_decel_mps2 = 9.8          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.86          ## Жёсткость пружин (спортивная, но живая и упругая подвеска)
	compression_damping_ratio = 0.24    ## Мягкость сжатия при ударе/падении (мягкое поглощение ударов)
	rebound_damping_ratio = 0.47        ## Скорость отбоя вверх (приятный упругий отклик)
	anti_roll_stiffness = 2200.0        ## Стабилизатор против крена
	body_roll_torque_factor = 1.38      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 1.85     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.85          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.78         ## Продольный перенос веса
	front_rest_length_scale = 1.15      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.18       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 58000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 66000.0     ## Баланс жёсткости задних пружин
	suspension_travel_speed = 20.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.35                  ## Скорость поворота руля
	STEER_LIMIT = 0.38                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 5.0                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.48                ## Спортивное сцепление шин с асфальтом
	lateral_stiffness = 12.8            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.76            ## Сцепление при заносе
	yaw_stability_assist = 2.5          ## Стабилизация курса ESC
	com_height = 0.32                   ## Высота центра масс
	com_z_offset = 0.04                 ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1350                       ## Базовая прочность HP
	max_fuel = 128                      ## Объём топливного бака (л)
	fuel_per_100m = 3.1                 ## Расход топлива на 100 метров
	zombie_damage_taken = 5             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.66         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.21
	throttle_release_rate = 6.4
	aero_drag_coeff = 0.36
	gear_speed_ratios = [0.16, 0.32, 0.50, 0.69, 0.88, 1.06]
	gear_torque_multipliers = [1.56, 1.28, 1.04, 0.84, 0.68, 0.54]
	front_grip_bias = 1.02
	rear_grip_bias = 1.08
	wheelbase_m = 2.44
	steering_scrub_drag = 0.10
	hull_half_extents = Vector2(0.98, 2.12)
	vehicle_body_scale = 0.90
	idle_fuel_per_sec = 0.21
	crash_death_speed_mps = 26.0
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
	engine_hood_offset = Vector3(0.0, 0.80, 1.45)
	car_paint_color = Color(0.62, 0.65, 0.68)
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
	var vs: float = vehicle_body_scale
	model_root.position = Vector3(0.0, 0.01, 0.0) * vs
	model_root.rotation.y = PI * 0.5
	model_root.scale = Vector3.ONE * vs
	_visuals_prescaled = true
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
