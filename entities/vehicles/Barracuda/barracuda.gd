extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: PLYMOUTH BARRACUDA '70
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 6200           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 236                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.6             ## Отзывчивость педали газа W (как на GMC 2500)
	launch_wheelspin_intensity = 5.80   ## Пробуксовка колёс при старте с места в пол
	brake_force = 104.0                 ## Сила тормозов
	max_brake_decel_mps2 = 9.4          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.84          ## Жёсткость пружин (живая упругая подвеска маслкара)
	compression_damping_ratio = 0.22    ## Мягкость сжатия при ударе/падении (глубокий мягкий ход)
	rebound_damping_ratio = 0.45        ## Скорость отбоя вверх (приятный упругий качок)
	anti_roll_stiffness = 1950.0        ## Стабилизатор против крена (живой крен кузова)
	body_roll_torque_factor = 1.58      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.22     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.88          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.84         ## Продольный перенос веса
	front_rest_length_scale = 1.18      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.22       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 68000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 56000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 19.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.22                  ## Скорость поворота руля
	STEER_LIMIT = 0.38                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.8                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.45                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 12.4            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.74            ## Сцепление при заносе
	yaw_stability_assist = 2.4          ## Стабилизация курса ESC
	com_height = 0.35                   ## Высота центра масс
	com_z_offset = -0.08                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1550                       ## Базовая прочность HP
	max_fuel = 132                      ## Объём топливного бака (л)
	fuel_per_100m = 3.3                 ## Расход топлива на 100 метров
	zombie_damage_taken = 5             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.66         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.21
	throttle_release_rate = 6.2
	aero_drag_coeff = 0.41
	gear_speed_ratios = [0.19, 0.38, 0.58, 0.80, 1.04]
	gear_torque_multipliers = [1.58, 1.28, 1.02, 0.82, 0.64]
	front_grip_bias = 1.02
	rear_grip_bias = 1.06
	wheelbase_m = 2.74
	steering_scrub_drag = 0.11
	hull_half_extents = Vector2(0.98, 2.36)
	vehicle_body_scale = 0.92
	idle_fuel_per_sec = 0.24
	crash_death_speed_mps = 26.0
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
	engine_hood_offset = Vector3(0.0, 0.86, -1.65)
	car_paint_color = Color(0.66, 0.24, 0.08)
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
	var vs: float = vehicle_body_scale
	model_root.position = Vector3(0.0, 0.02, 0.0) * vs
	model_root.scale = Vector3.ONE * vs
	_visuals_prescaled = true
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
