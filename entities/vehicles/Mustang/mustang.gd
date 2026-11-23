extends "res://entities/vehicles/vehicle_base.gd"

const MUSTANG_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_mustang.png")

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ СПОРТКАРА MUSTANG — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	# --- Руль и управление ---
	STEER_SPEED = 2.15                  ## Быстрый спортивный отклик руля
	STEER_LIMIT = 0.39                  ## Макс. выворот колёс
	steer_inertia = 7.6
	high_speed_steer_min_ratio = 0.21

	# --- Двигатель, разгон и максималка ---
	throttle_response = 6.2             ## Резкий отклик спортивного мотора
	throttle_release_rate = 6.8
	engine_force_value = 8200           ## Сила двигателя
	MAX_SPEED_KMH = 232                 ## Макс. скорость в стоке (км/ч, качается в гараже)
	brake_force = 104.0                 ## Цепкие дисковые тормоза
	max_brake_decel_mps2 = 9.8
	aero_drag_coeff = 0.42
	gear_speed_ratios = [0.19, 0.38, 0.58, 0.80, 1.04]
	gear_torque_multipliers = [1.78, 1.44, 1.12, 0.88, 0.66]

	# --- Подвеска, колёса и устойчивость ---
	suspension_firmness = 1.24          ## Жёсткая спортивная подвеска
	compression_damping_ratio = 0.50    ## Демпфирование сжатия на кочках и ямах
	rebound_damping_ratio = 0.68        ## Демпфирование отбоя пружин
	anti_roll_stiffness = 9200.0        ## Жёсткий стабилизатор против кренов
	front_spring_stiffness = 62000.0    ## Жёсткость передних пружин (Н/м)
	rear_spring_stiffness = 60000.0     ## Жёсткость задних пружин (Н/м)
	front_rest_length_scale = 0.90      ## Заниженный передний клиренс (множитель хода)
	rear_rest_length_scale = 0.94       ## Задний клиренс (множитель хода)
	front_grip_bias = 1.04              ## Баланс цепкости передних шин
	rear_grip_bias = 1.06               ## Баланс цепкости задних шин
	suspension_travel_speed = 23.0      ## Быстрая отработка визуала колёс
	weight_transfer_long = 0.20         ## Продольный перенос веса (клевки/приседания)
	weight_transfer_lat = 0.21          ## Поперечный перенос веса в поворотах
	com_height = 0.29                   ## Низкий центр масс спорткара
	com_z_offset = -0.06                ## Почти нейтральная развесовка по осям
	wheelbase_m = 2.78                  ## Короткая манёвренная база (м)
	steering_scrub_drag = 0.11          ## Сопротивление шин при повороте
	impact_momentum_keep = 0.64         ## Лёгкий кузов сильнее тормозится о преграды (0..1)
	body_roll_torque_factor = 0.46      ## Минимальный боковой крен
	body_pitch_torque_factor = 0.44     ## Минимальный клевок при торможении
	lateral_stiffness = 13.4            ## Цепкие широкие спортивные шины
	tire_friction = 2.50                ## Высокий коэффициент сцепления с асфальтом
	drift_grip_factor = 0.78            ## Сцепление при скольжении в заносе
	yaw_stability_assist = 2.3          ## Стабилизация курса на высокой скорости
	hull_half_extents = Vector2(0.96, 2.30) ## Габариты половины кузова (ширина, длина)

	# --- Звук и свет ---
	engine_sound_id = "mustang"
	engine_pitch_scale = 1.02
	has_exhaust_backfire = true
	gear_shift_pitch_base = 1.08
	shadow_texture = MUSTANG_SHADOW_TEX
	headlight_positions = [Vector3(-0.75, 0.78, -1.98), Vector3(0.75, 0.78, -1.98)]
	taillight_positions = [Vector3(-0.62, 0.84, 2.34), Vector3(0.62, 0.84, 2.34)]
	headlight_lens_size = Vector2(0.28, 0.28)
	taillight_lens_size = Vector2(0.42, 0.22)
	headlight_proj_size = Vector2(13.5, 36.0)
	headlight_proj_z_start = -2.12
	taillight_proj_size = Vector2(3.6, 2.2)
	taillight_proj_z_start = 2.30
	shadow_blob_size = Vector2(4.40, 8.26)
	shadow_offset = Vector2(-0.02, 0.07)

	# --- Прочность и топливо ---
	health = 1500                       ## Базовая прочность HP (качается в гараже)
	engine_hood_offset = Vector3(0.0, 0.84, -1.65)
	car_paint_color = Color(0.68, 0.64, 0.16)
	zombie_damage_taken = 5
	crash_death_speed_mps = 26.0
	max_fuel = 130                      ## Базовый объём бака (л)
	fuel_per_100m = 3.3
	idle_fuel_per_sec = 0.24
	exhaust_offset = Vector3(-0.52, 0.28, 2.26)
	exhaust_offsets = [Vector3(-0.52, 0.28, 2.26), Vector3(0.52, 0.28, 2.26)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 1640.0                       ## Масса автомобиля (кг)
	super()
