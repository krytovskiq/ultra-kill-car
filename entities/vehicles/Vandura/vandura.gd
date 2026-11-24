extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: GMC VANDURA
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 6900           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 148                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 2.8             ## Отзывчивость педали газа W (меньше = плавнее набор)
	launch_wheelspin_intensity = 0.90   ## Пробуксовка колёс при старте с места в пол (0..1.5)
	brake_force = 96.0                  ## Сила тормозов
	max_brake_decel_mps2 = 7.4          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.94          ## Жёсткость пружин (меньше = мягче на кочках и приземлении)
	compression_damping_ratio = 0.46    ## Мягкость сжатия при ударе/падении (меньше = глубже проседает)
	rebound_damping_ratio = 0.65        ## Скорость отбоя вверх (меньше = мягкий упругий качок)
	anti_roll_stiffness = 9200.0        ## Стабилизатор против крена (меньше = сильнее завал в повороте)
	body_roll_torque_factor = 0.68      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 0.68     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.26          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.28         ## Продольный перенос веса (назад при газе, вперёд при тормозе)
	front_rest_length_scale = 1.14      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.18       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 76000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 68000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 24.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.46                  ## Скорость поворота руля
	STEER_LIMIT = 0.36                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.8                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.34                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 11.8            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.78            ## Сцепление при заносе (меньше = легче уходит в дрифт)
	yaw_stability_assist = 2.5          ## Стабилизация курса ESC (меньше = свободнее виляет корма)
	com_height = 0.42                   ## Высота центра масс (ниже = устойчивее к переворотам)
	com_z_offset = -0.14                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1450                       ## Базовая прочность HP
	max_fuel = 155                      ## Объём топливного бака (л)
	fuel_per_100m = 3.4                 ## Расход топлива на 100 метров
	zombie_damage_taken = 5             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.82         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.24
	throttle_release_rate = 4.6
	aero_drag_coeff = 0.62
	gear_speed_ratios = [0.18, 0.36, 0.56, 0.78, 1.02]
	gear_torque_multipliers = [1.50, 1.22, 0.96, 0.76, 0.58]
	front_grip_bias = 0.96
	rear_grip_bias = 1.06
	wheelbase_m = 3.18
	steering_scrub_drag = 0.16
	hull_half_extents = Vector2(1.12, 2.58)
	idle_fuel_per_sec = 0.23
	crash_death_speed_mps = 26.0
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
	engine_hood_offset = Vector3(0.0, 1.08, -1.90)
	car_paint_color = Color(0.15, 0.16, 0.18)
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
