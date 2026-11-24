extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: GMC K-2500 4x4
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "AWD"                  ## Тип привода: "AWD" (полный 4x4), "RWD" (задний), "FWD" (передний)
	awd_front_torque_split = 0.42       ## Доля тяги на переднюю ось для полного привода (0.42 = 42% перед / 58% зад)
	engine_force_value = 11200          ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 176                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.4             ## Отзывчивость педали газа W (меньше = плавнее набор)
	launch_wheelspin_intensity = 5.78   ## Пробуксовка колёс при старте с места в пол
	brake_force = 100.0                 ## Сила тормозов
	max_brake_decel_mps2 = 7.6          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.80          ## Жёсткость пружин (меньше = мягче на кочках и приземлении)
	compression_damping_ratio = 0.20    ## Мягкость сжатия при ударе/падении (меньше = глубже проседает)
	rebound_damping_ratio = 0.44        ## Скорость отбоя вверх (меньше = мягкий упругий качок)
	anti_roll_stiffness = 1600.0        ## Стабилизатор против крена (меньше = сильнее завал в повороте)
	body_roll_torque_factor = 1.60      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.20     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.90          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.80         ## Продольный перенос веса (назад при газе, вперёд при тормозе)
	front_rest_length_scale = 1.24      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.28       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 88000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 84000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 17.5      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.12                  ## Скорость поворота руля
	STEER_LIMIT = 0.36                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.6                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.40                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 12.0            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.78            ## Сцепление при заносе (меньше = легче уходит в дрифт)
	yaw_stability_assist = 2.6          ## Стабилизация курса ESC (меньше = свободнее виляет корма)
	com_height = 0.50                   ## Высота центра масс (ниже = устойчивее к переворотам)
	com_z_offset = -0.18                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 2150                       ## Базовая прочность HP
	max_fuel = 165                      ## Объём топливного бака (л)
	fuel_per_100m = 3.5                 ## Расход топлива на 100 метров
	zombie_damage_taken = 3             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.88         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.23
	throttle_release_rate = 4.6
	aero_drag_coeff = 0.58
	downforce_multiplier = 20.0
	gear_speed_ratios = [0.16, 0.32, 0.49, 0.68, 0.86, 1.04]
	gear_torque_multipliers = [1.78, 1.44, 1.14, 0.92, 0.74, 0.58]
	front_grip_bias = 0.96
	rear_grip_bias = 1.10
	wheelbase_m = 3.47
	steering_scrub_drag = 0.18
	hull_half_extents = Vector2(1.24, 2.94)
	idle_fuel_per_sec = 0.24
	crash_death_speed_mps = 29.0
	engine_sound_id = "k2500"
	engine_pitch_scale = 0.56
	has_exhaust_backfire = true
	gear_shift_pitch_base = 0.86
	shadow_texture = GlbVehicleHelper.make_shadow_tex("k2500", 0.54, 0.70)
	headlight_positions = [Vector3(-0.76, 1.02, -2.72), Vector3(0.76, 1.02, -2.72)]
	taillight_positions = [Vector3(-0.90, 1.15, 2.82), Vector3(0.90, 1.15, 2.82)]
	headlight_lens_size = Vector2(0.32, 0.26)
	taillight_lens_size = Vector2(0.22, 0.34)
	headlight_proj_size = Vector2(15.0, 35.0)
	headlight_proj_z_start = -2.74
	taillight_proj_size = Vector2(4.0, 2.4)
	taillight_proj_z_start = 2.80
	shadow_blob_size = Vector2(5.20, 9.80)
	shadow_offset = Vector2(0.0, 0.06)
	engine_hood_offset = Vector3(0.0, 1.24, -2.00)
	car_paint_color = Color(0.455, 0.516, 0.425, 1.0)
	exhaust_offset = Vector3(-0.66, 0.44, 2.86)
	exhaust_offsets = [Vector3(-0.66, 0.44, 2.86), Vector3(0.66, 0.44, 2.86)]
	exhaust_style = "diesel"

func _ready() -> void:
	mass = 3200.0
	_assemble_k2500_visuals()
	super()

func _assemble_k2500_visuals() -> void:
	if get_node_or_null("GMCK2500ModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/GMC_K2500/gmc_k2500_model.glb")
	if model_root == null:
		return
	model_root.name = "GMCK2500ModelRoot"
	model_root.position = Vector3(0.0, 0.0, -0.14)
	add_child(model_root)
	GlbVehicleHelper.apply_material_overrides(model_root, {
		"exterior.010": {
			"albedo_color": Color(0.24, 0.28, 0.22),
			"metallic": 0.22,
			"roughness": 0.62,
			"clearcoat": 0.04,
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
