extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: CARSON GRAND SICILIAN
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 6800           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 186                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.4             ## Отзывчивость педали газа W (как на GMC 2500)
	launch_wheelspin_intensity = 5.20   ## Пробуксовка колёс при старте с места в пол
	brake_force = 98.0                  ## Сила тормозов
	max_brake_decel_mps2 = 8.2          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.82          ## Жёсткость пружин (мягкий американский диван на колёсах)
	compression_damping_ratio = 0.21    ## Мягкость сжатия при ударе/падении (глубокий мягкий ход)
	rebound_damping_ratio = 0.44        ## Скорость отбоя вверх (приятный упругий качок)
	anti_roll_stiffness = 1680.0        ## Стабилизатор против крена (живой вальяжный крен)
	body_roll_torque_factor = 1.70      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.25     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.88          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.82         ## Продольный перенос веса
	front_rest_length_scale = 1.20      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.22       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 68000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 58000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 18.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.15                  ## Скорость поворота руля
	STEER_LIMIT = 0.36                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.8                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.38                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 11.8            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.75            ## Сцепление при заносе
	yaw_stability_assist = 2.4          ## Стабилизация курса ESC
	com_height = 0.38                   ## Высота центра масс
	com_z_offset = -0.12                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1650                       ## Базовая прочность HP
	max_fuel = 130                      ## Объём топливного бака (л)
	fuel_per_100m = 3.3                 ## Расход топлива на 100 метров
	zombie_damage_taken = 4             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.80         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.22
	throttle_release_rate = 5.2
	aero_drag_coeff = 0.50
	gear_speed_ratios = [0.18, 0.36, 0.56, 0.78, 1.02]
	gear_torque_multipliers = [1.56, 1.26, 1.00, 0.80, 0.60]
	front_grip_bias = 0.99
	rear_grip_bias = 1.05
	wheelbase_m = 3.26
	steering_scrub_drag = 0.14
	hull_half_extents = Vector2(0.98, 2.46)
	vehicle_body_scale = 0.92
	idle_fuel_per_sec = 0.23
	crash_death_speed_mps = 26.0
	engine_sound_id = "carson"
	engine_pitch_scale = 0.50
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
	engine_hood_offset = Vector3(0.0, 0.96, -1.55)
	car_paint_color = Color(0.26, 0.26, 0.28)
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
	var vs: float = vehicle_body_scale
	model_root.position = Vector3(0.0, 0.05, -0.09) * vs
	model_root.rotation.y = PI * 0.5
	model_root.scale = Vector3.ONE * vs
	_visuals_prescaled = true
	add_child(model_root)
	var wheel_map: Dictionary = {
		"E4_38_E5_39_001_5": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"E4_38_E5_39_002_7": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"E4_38_E5_39_003_9": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"34_A8_1C_93_69": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
