extends "res://entities/vehicles/vehicle_base.gd"

const DOGE_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_doge2.png")

var _taillight_mat: StandardMaterial3D = null

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ МАСЛКАРА DODGE (DOGE2) — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	# --- Руль и управление ---
	STEER_SPEED = 1.72                  ## Скорость поворота руля
	STEER_LIMIT = 0.36                  ## Макс. угол поворота колёс
	steer_inertia = 6.0                 ## Инерция руля
	high_speed_steer_min_ratio = 0.20   ## Сужение выворота на макс. скорости

	# --- Двигатель, разгон и максималка ---
	throttle_response = 4.8             ## Реакция мотора на газ
	throttle_release_rate = 5.8
	engine_force_value = 7800           ## Мощность мотора (разгон)
	MAX_SPEED_KMH = 205                 ## Макс. скорость в стоке (км/ч, качается в гараже)
	brake_force = 96.0                  ## Сила тормозов
	max_brake_decel_mps2 = 8.4          ## Тормозное замедление (м/с²)
	aero_drag_coeff = 0.48
	gear_speed_ratios = [0.16, 0.31, 0.48, 0.66, 0.85, 1.04]  ## 6 передач маслкара
	gear_torque_multipliers = [1.72, 1.42, 1.14, 0.92, 0.72, 0.56]

	# --- Подвеска, колёса и устойчивость ---
	suspension_firmness = 1.08          ## Общая жёсткость пружин (выше = спортивнее)
	compression_damping_ratio = 0.46    ## Демпфирование сжатия амортизатора при ударе
	rebound_damping_ratio = 0.62        ## Демпфирование отбоя (гасит раскачку)
	anti_roll_stiffness = 8400.0        ## Стабилизатор против боковых кренов
	front_spring_stiffness = 65000.0    ## Жёсткость передних пружин (Н/м)
	rear_spring_stiffness = 61000.0     ## Жёсткость задних пружин (Н/м)
	front_rest_length_scale = 0.96      ## Ход передней подвески (клиренс спереди)
	rear_rest_length_scale = 1.02       ## Ход задней подвески (клиренс сзади)
	front_grip_bias = 1.00              ## Баланс сцепления передней оси
	rear_grip_bias = 1.01               ## Баланс сцепления задней оси
	suspension_travel_speed = 21.0      ## Скорость визуального хода колёс
	weight_transfer_long = 0.25         ## Перенос веса вперёд/назад при тормозе/газе
	weight_transfer_lat = 0.25          ## Перенос веса на внешнюю сторону в повороте
	com_height = 0.31                   ## Высота центра масс (ниже = устойчивее)
	com_z_offset = -0.14                ## Смещение центра масс вперёд (к V8 мотору)
	wheelbase_m = 3.02                  ## Колёсная база (м)
	steering_scrub_drag = 0.13          ## Сопротивление шин при вывороте руля
	impact_momentum_keep = 0.72         ## Сохранение хода при таране препятствий
	body_roll_torque_factor = 0.62      ## Крен кузова в поворотах
	body_pitch_torque_factor = 0.60     ## Клевок при торможении и приседание при старте
	lateral_stiffness = 12.6            ## Боковая жёсткость покрышек
	tire_friction = 2.38                ## Сцепление шин с асфальтом
	drift_grip_factor = 0.70            ## Лёгкий контролируемый занос задней оси
	yaw_stability_assist = 1.85         ## Помощь удержания курса (ESC)
	hull_half_extents = Vector2(1.14, 2.68) ## Габариты половины кузова (ширина, длина)

	# --- Звук и свет ---
	engine_sound_id = "doge2"
	engine_pitch_scale = 1.00
	has_exhaust_backfire = true
	gear_shift_pitch_base = 0.95
	shadow_texture = DOGE_SHADOW_TEX
	headlight_positions = [Vector3(-0.65, 0.67, -2.42), Vector3(0.65, 0.67, -2.42)]
	taillight_positions = [Vector3(-0.65, 0.91, 2.69), Vector3(0.65, 0.91, 2.69)]
	headlight_lens_size = Vector2(0.30, 0.24)
	taillight_lens_size = Vector2(0.48, 0.20)
	headlight_proj_size = Vector2(14.5, 34.0)
	headlight_proj_z_start = -2.48
	taillight_proj_size = Vector2(3.9, 2.3)
	taillight_proj_z_start = 2.66
	shadow_blob_size = Vector2(5.10, 9.48)
	shadow_offset = Vector2(0.0, 0.06)

	# --- Прочность и топливо ---
	health = 1100                       ## Базовая прочность HP (качается в гараже)
	engine_hood_offset = Vector3(0.0, 0.88, -1.85)
	car_paint_color = Color(0.18, 0.16, 0.15)
	zombie_damage_taken = 6             ## Урон за сбитого зомби
	crash_death_speed_mps = 24.0
	max_fuel = 110                      ## Базовый объём бака в литрах
	fuel_per_100m = 3.4
	idle_fuel_per_sec = 0.22
	exhaust_offset = Vector3(-0.56, 0.28, 2.74)
	exhaust_offsets = [Vector3(-0.56, 0.28, 2.74), Vector3(0.56, 0.28, 2.74)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 1980.0                       ## Масса автомобиля (кг)
	super()

	var body_mesh := get_node_or_null("Sketchfab_model/root/Object_83") as MeshInstance3D
	if body_mesh and body_mesh.mesh and body_mesh.mesh.get_surface_count() > 13:
		var base_mat := body_mesh.mesh.surface_get_material(13) as StandardMaterial3D
		if base_mat:
			_taillight_mat = base_mat.duplicate() as StandardMaterial3D
			body_mesh.set_surface_override_material(13, _taillight_mat)

func set_preview_mode(enabled: bool, showcase_mode: bool = false) -> void:
	super(enabled, showcase_mode)

func _process_vehicle_extras(delta: float) -> void:
	var braking: bool = Input.is_action_pressed("S")
	var target_emission: float = 5.0 if braking else 2.6
	var lerp_t: float = clampf(delta * 14.0, 0.0, 1.0)
	if _taillight_mat:
		_taillight_mat.emission_energy_multiplier = lerpf(_taillight_mat.emission_energy_multiplier, target_emission, lerp_t)

func _destroy_car(death_reason: String = "МАШИНА УНИЧТОЖЕНА") -> void:
	if _taillight_mat:
		_taillight_mat.emission_energy_multiplier = 0.0
	super(death_reason)
