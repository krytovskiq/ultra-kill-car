extends "res://entities/vehicles/vehicle_base.gd"

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: УАЗ БУХАНКА (UAZ BUHANKA)
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "AWD"                  ## Тип привода: "AWD" (полный 4x4), "RWD" (задний), "FWD" (передний)
	awd_front_torque_split = 0.45       ## Доля тяги на переднюю ось для полного привода (0.45 = 45% перед / 55% зад)
	engine_force_value = 5600           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 118                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 2.5             ## Отзывчивость педали газа W (меньше = плавнее набор)
	launch_wheelspin_intensity = 0.72   ## Пробуксовка колёс при старте с места в пол (0..1.5)
	brake_force = 92.0                  ## Сила тормозов
	max_brake_decel_mps2 = 7.2          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.90          ## Жёсткость пружин (меньше = мягче на кочках и приземлении)
	compression_damping_ratio = 0.44    ## Мягкость сжатия при ударе/падении (меньше = глубже проседает)
	rebound_damping_ratio = 0.64        ## Скорость отбоя вверх (меньше = мягкий упругий качок)
	anti_roll_stiffness = 7400.0        ## Стабилизатор против крена (меньше = сильнее завал в повороте)
	body_roll_torque_factor = 0.74      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 0.72     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.28          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.30         ## Продольный перенос веса (назад при газе, вперёд при тормозе)
	front_rest_length_scale = 1.24      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.28       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 62000.0    ## Баланс жёсткости передних рессор
	rear_spring_stiffness = 58000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 24.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.48                  ## Скорость поворота руля
	STEER_LIMIT = 0.38                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.8                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.30                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 11.2            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.78            ## Сцепление при заносе (меньше = легче уходит в дрифт)
	yaw_stability_assist = 2.4          ## Стабилизация курса ESC (меньше = свободнее виляет корма)
	com_height = 0.42                   ## Высота центра масс (ниже = устойчивее к переворотам)
	com_z_offset = -0.08                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1050                       ## Базовая прочность HP
	max_fuel = 135                      ## Объём топливного бака (л)
	fuel_per_100m = 3.2                 ## Расход топлива на 100 метров
	zombie_damage_taken = 6             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.78         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.25
	throttle_release_rate = 4.4
	aero_drag_coeff = 0.66
	gear_speed_ratios = [0.20, 0.42, 0.68, 0.98]
	gear_torque_multipliers = [1.40, 1.10, 0.82, 0.60]
	front_grip_bias = 0.98
	rear_grip_bias = 1.05
	wheelbase_m = 2.37
	steering_scrub_drag = 0.16
	hull_half_extents = Vector2(1.06, 2.18)
	vehicle_body_scale = 0.93
	idle_fuel_per_sec = 0.21
	crash_death_speed_mps = 23.0
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
	engine_hood_offset = Vector3(0.0, 1.06, -1.68)
	car_paint_color = Color(0.76, 0.62, 0.16)
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
	var vs: float = vehicle_body_scale
	model_root.position = Vector3(0.0, 0.0, 0.198) * vs
	model_root.rotation.y = PI
	model_root.scale = Vector3.ONE * (1.48 * vs)
	_visuals_prescaled = true
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
