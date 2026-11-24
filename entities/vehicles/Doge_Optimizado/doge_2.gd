extends "res://entities/vehicles/vehicle_base.gd"

const DOGE_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_doge2.png")

var _taillight_mat: StandardMaterial3D = null

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: МАСЛКАР DODGE (DOGE2)
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний), "AWD" (полный), "FWD" (передний)
	engine_force_value = 6400           ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 205                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 3.7             ## Отзывчивость педали газа W (как на GMC 2500)
	launch_wheelspin_intensity = 6.20   ## Пробуксовка колёс при старте с места в пол
	brake_force = 96.0                  ## Сила тормозов
	max_brake_decel_mps2 = 8.4          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.85          ## Жёсткость пружин (живая упругая подвеска мощного маслкара)
	compression_damping_ratio = 0.23    ## Мягкость сжатия при ударе/падении (глубокий мягкий ход)
	rebound_damping_ratio = 0.46        ## Скорость отбоя вверх (приятный упругий качок)
	anti_roll_stiffness = 2100.0        ## Стабилизатор против крена (живой крен кузова)
	body_roll_torque_factor = 1.50      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.20     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.88          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.85         ## Продольный перенос веса
	front_rest_length_scale = 1.16      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.20       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 68000.0    ## Баланс жёсткости передних пружин
	rear_spring_stiffness = 58000.0     ## Баланс жёсткости задних рессор
	suspension_travel_speed = 19.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.24                  ## Скорость поворота руля
	STEER_LIMIT = 0.37                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 5.0                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 2.46                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 12.6            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.75            ## Сцепление при заносе
	yaw_stability_assist = 2.4          ## Стабилизация курса ESC
	com_height = 0.36                   ## Высота центра масс
	com_z_offset = -0.12                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 1100                       ## Базовая прочность HP
	max_fuel = 110                      ## Объём топливного бака (л)
	fuel_per_100m = 3.4                 ## Расход топлива на 100 метров
	zombie_damage_taken = 6             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.72         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.21
	throttle_release_rate = 5.4
	aero_drag_coeff = 0.48
	gear_speed_ratios = [0.17, 0.33, 0.50, 0.68, 0.86, 1.04]
	gear_torque_multipliers = [1.56, 1.26, 1.00, 0.80, 0.64, 0.50]
	front_grip_bias = 1.00
	rear_grip_bias = 1.04
	wheelbase_m = 3.02
	steering_scrub_drag = 0.13
	hull_half_extents = Vector2(1.14, 2.68)
	vehicle_body_scale = 0.96
	idle_fuel_per_sec = 0.22
	crash_death_speed_mps = 24.0
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
	engine_hood_offset = Vector3(0.0, 0.88, -1.85)
	car_paint_color = Color(0.18, 0.16, 0.15)
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
