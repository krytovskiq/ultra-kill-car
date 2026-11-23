extends "res://entities/vehicles/vehicle_base.gd"

const PIKAP_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_pikap.png")

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ ПИКАПА (PIKAP) — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	# --- Руль и управление ---
	STEER_SPEED = 1.50                  ## Скорость поворота руля
	STEER_LIMIT = 0.37                  ## Максимальный угол поворота колёс
	steer_inertia = 5.0                 ## Инерция / тяжесть рулевой рейки
	high_speed_steer_min_ratio = 0.22   ## Уменьшение выворота на большой скорости

	# --- Мотор, разгон и максималка ---
	throttle_response = 3.0             ## Плавность набора газа при нажатии W
	throttle_release_rate = 4.6         ## Спад оборотов при отпускании газа
	engine_force_value = 5800           ## Сила двигателя (влияет на разгон)
	MAX_SPEED_KMH = 125                 ## Макс. скорость в стоке (км/ч, качается в гараже)
	brake_force = 90.0                  ## Сила торможения
	max_brake_decel_mps2 = 7.4          ## Максимальное замедление (м/с²)
	aero_drag_coeff = 0.56              ## Аэродинамическое сопротивление
	gear_speed_ratios = [0.22, 0.46, 0.74, 0.82]
	gear_torque_multipliers = [1.1, 0.97, 0.40, 0.30]

	# --- Подвеска, колёса и устойчивость ---
	suspension_firmness = 0.90          ## Общая жёсткость пружин (ниже = мягче ход по кочкам)
	compression_damping_ratio = 0.44    ## Гашение удара при сжатии амортизаторов
	rebound_damping_ratio = 0.58        ## Плавность возврата пружин без подпрыгиваний
	anti_roll_stiffness = 7000.0        ## Жёсткость стабилизатора против бокового крена
	front_spring_stiffness = 59000.0    ## Жёсткость передних пружин (Н/м)
	rear_spring_stiffness = 53000.0     ## Жёсткость задних рессор (Н/м)
	front_rest_length_scale = 1.15      ## Множитель длины хода передней подвески (клиренс)
	rear_rest_length_scale = 1.22       ## Множитель длины хода задней подвески
	front_grip_bias = 0.92              ## Доля сцепления передней оси
	rear_grip_bias = 1.08               ## Доля сцепления задней оси
	suspension_travel_speed = 16.5      ## Скорость визуального хода колёс вверх/вниз
	weight_transfer_long = 0.27         ## Перенос веса вперёд/назад при разгоне и тормозе
	weight_transfer_lat = 0.29          ## Перенос веса на внешние колёса в поворотах
	com_height = 0.42                   ## Высота центра масс (ниже = меньше шанс переворота)
	com_z_offset = -0.22                ## Смещение центра масс вперёд (к мотору)
	wheelbase_m = 3.15                  ## Колёсная база (расстояние между осями в метрах)
	steering_scrub_drag = 0.16          ## Потери скорости на вывернутом руле
	impact_momentum_keep = 0.74         ## Сохранение скорости при таране препятствий (0..1)
	body_roll_torque_factor = 0.78      ## Глубина наклона кузова набок в повороте
	body_pitch_torque_factor = 0.68     ## Сила клевка носом при тормозе и подъёма при газе
	lateral_stiffness = 11.4            ## Боковая жёсткость шины против бокового сноса
	tire_friction = 2.24                ## Общий коэффициент сцепления шин с дорогой
	drift_grip_factor = 0.76            ## Сцепление при заносе (ниже = проще уйти в дрифт)
	yaw_stability_assist = 2.4          ## Электронная стабилизация курса (ESC)
	hull_half_extents = Vector2(1.04, 2.38) ## Габариты половины кузова (ширина, длина)

	# --- Звук и свет ---
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

	# --- Прочность и топливо ---
	health = 600                        ## Базовая броня HP (качается в гараже)
	engine_hood_offset = Vector3(0.0, 1.02, -1.68)
	car_paint_color = Color(0.26, 0.38, 0.45)
	zombie_damage_taken = 8             ## Урон по машине за сбитого зомби
	crash_death_speed_mps = 20.0
	max_fuel = 85                       ## Базовый объём топливного бака в литрах
	fuel_per_100m = 3.5                 ## Расход на 100 метров
	idle_fuel_per_sec = 0.22            ## Расход на холостых (л/сек)
	exhaust_offset = Vector3(-0.62, 0.34, 2.32)
	exhaust_offsets = [Vector3(-0.62, 0.34, 2.32)]
	exhaust_style = "gasoline"

func _ready() -> void:
	mass = 2150.0                       ## Масса автомобиля (кг)
	super()
