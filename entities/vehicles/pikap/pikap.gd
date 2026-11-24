extends "res://entities/vehicles/vehicle_base.gd"

const PIKAP_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_pikap.png")

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: ПИКАП (PIKAP)
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 5400           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 125                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.3             ## Отзывчивость педали газа W (как на GMC 2500)
	launch_wheelspin_intensity = 4.85   ## Пробуксовка колёс при старте с места в пол
	brake_force = 95.0                  ## Сила тормозов
	max_brake_decel_mps2 = 7.5          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.81          ## Жёсткость пружин (мягкая, дышащая подвеска как на GMC 2500)
	compression_damping_ratio = 0.21    ## Мягкость сжатия при ударе/падении (глубокий мягкий ход)
	rebound_damping_ratio = 0.44        ## Скорость отбоя вверх (приятный упругий качок)
	anti_roll_stiffness = 1550.0        ## Стабилизатор против крена (живой крен кузова)
	body_roll_torque_factor = 1.62      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.18     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.88          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.82         ## Продольный перенос веса (назад при газе, вперёд при тормозе)
	front_rest_length_scale = 1.24      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.28       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 58000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 52000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 18.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.15                  ## Скорость поворота руля
	STEER_LIMIT = 0.37                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 4.7                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.38                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 11.8            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.77            ## Сцепление при заносе
	yaw_stability_assist = 2.5          ## Стабилизация курса ESC
	com_height = 0.46                   ## Высота центра масс
	com_z_offset = -0.16                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 600                        ## Базовая прочность HP
	max_fuel = 85                       ## Объём топливного бака (л)
	fuel_per_100m = 3.5                 ## Расход топлива на 100 метров
	zombie_damage_taken = 8             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.74         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.22
	throttle_release_rate = 4.6
	aero_drag_coeff = 0.56
	gear_speed_ratios = [0.22, 0.46, 0.74, 0.98]
	gear_torque_multipliers = [1.36, 1.04, 0.76, 0.56]
	front_grip_bias = 0.95
	rear_grip_bias = 1.06
	wheelbase_m = 3.15
	steering_scrub_drag = 0.15
	hull_half_extents = Vector2(1.04, 2.38)
	vehicle_body_scale = 0.95
	idle_fuel_per_sec = 0.22
	crash_death_speed_mps = 20.0
	engine_sound_id = "pikap"
	engine_pitch_scale = 0.98
	has_exhaust_backfire = true
	gear_shift_pitch_base = 0.90
	shadow_texture = PIKAP_SHADOW_TEX
	headlight_positions = [Vector3(-0.76, 0.96, -2.12), Vector3(0.76, 0.96, -2.12)]
	taillight_positions = [Vector3(-0.86, 0.66, 2.20), Vector3(0.86, 0.66, 2.20)]
	headlight_lens_size = Vector2(0.30, 0.30)
	taillight_lens_size = Vector2(0.20, 0.28)
	headlight_proj_size = Vector2(13.0, 30.0)
	headlight_proj_z_start = -2.13
	taillight_proj_size = Vector2(3.6, 2.1)
	taillight_proj_z_start = 2.16
	shadow_blob_size = Vector2(4.80, 8.54)
	shadow_offset = Vector2(-0.01, 0.01)
	engine_hood_offset = Vector3(0.0, 1.02, -1.68)
	car_paint_color = Color(0.26, 0.38, 0.45)
	exhaust_offset = Vector3(-0.62, 0.34, 2.32)
	exhaust_offsets = [Vector3(-0.62, 0.34, 2.32)]
	exhaust_style = "gasoline"

func _ready() -> void:
	mass = 2150.0                       ## Масса автомобиля (кг)
	super()
