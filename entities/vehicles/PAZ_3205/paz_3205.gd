extends "res://entities/vehicles/vehicle_base.gd"

const SHADER_MUZZLE_FIRE: Shader = preload("res://entities/vehicles/shaders/muzzle_fire.gdshader")

var target_zombie: Node3D = null
var can_shoot: bool = true
var _turret_scan_timer: float = 0.0
var _turret_gun: Node3D = null
var _muzzle_point: Marker3D = null
var _muzzle_flash_rig: Node3D = null
var _muzzle_flash_mats: Array[ShaderMaterial] = []
var _barrel_linger_smoke: CPUParticles3D = null
var _muzzle_flash_timer: float = 0.0
var _barrel_heat_timer: float = 0.0

func _init() -> void:
	# ==============================================================================
	# ОСНОВНЫЕ НАСТРОЙКИ: ПАЗ-3205 АПОКАЛИПСИС
	# Самые важные параметры для настройки поведения машины вынесены наверх.
	# ==============================================================================

	# --- 1. Привод, разгон и тормоза ---
	drive_type = "RWD"                  ## Тип привода: "RWD" (задний мост), "AWD" (полный), "FWD" (передний)
	engine_force_value = 13400          ## Мощность / тяга мотора (больше = быстрее разгон)
	MAX_SPEED_KMH = 154                 ## Максимальная скорость в стоке (км/ч)
	throttle_response = 1.55            ## Отзывчивость педали газа W (меньше = плавнее набор)
	launch_wheelspin_intensity = 0.75   ## Пробуксовка колёс при старте с места в пол (0..1.5)
	brake_force = 96.0                  ## Сила тормозов
	max_brake_decel_mps2 = 5.8          ## Максимальное замедление при торможении (м/с²)

	# --- 2. Подвеска, крен и наклон кузова ---
	suspension_firmness = 0.76          ## Жёсткость пружин (меньше = мягче на кочках и приземлении)
	compression_damping_ratio = 0.40    ## Мягкость сжатия при ударе/падении (меньше = глубже проседает)
	rebound_damping_ratio = 0.50        ## Скорость отбоя вверх (меньше = мягкий упругий качок)
	anti_roll_stiffness = 1600.0        ## Стабилизатор против крена (меньше = сильнее завал в повороте)
	body_roll_torque_factor = 3.60      ## Сила бокового наклона (крена) кузова в поворотах
	body_pitch_torque_factor = 2.20     ## Сила наклона вперёд/назад (приседание на старте и клевок при тормозе)
	weight_transfer_lat = 0.85          ## Боковой перенос веса на внешние колёса в повороте
	weight_transfer_long = 0.64         ## Продольный перенос веса (назад при газе, вперёд при тормозе)
	front_rest_length_scale = 1.22      ## Ход передней подвески / клиренс спереди
	rear_rest_length_scale = 1.24       ## Ход задней подвески / клиренс сзади
	front_spring_stiffness = 175000.0   ## Баланс жёсткости передних рессор
	rear_spring_stiffness = 185000.0    ## Баланс жёсткости задних рессор
	suspension_travel_speed = 21.0      ## Скорость визуального хода колёс вверх/вниз

	# --- 3. Руль, сцепление и центр тяжести ---
	STEER_SPEED = 1.32                  ## Скорость поворота руля
	STEER_LIMIT = 0.41                  ## Максимальный угол выворота колёс (рад)
	steer_inertia = 3.1                 ## Тяжесть / плавность рулевой рейки
	tire_friction = 3.10                ## Общее сцепление шин с асфальтом
	lateral_stiffness = 11.2            ## Боковая цепкость шин против сноса
	drift_grip_factor = 0.82            ## Сцепление при заносе (меньше = легче уходит в дрифт)
	yaw_stability_assist = 2.7          ## Стабилизация курса ESC (меньше = свободнее виляет корма)
	com_height = 0.48                   ## Высота центра масс (ниже = устойчивее к переворотам)
	com_z_offset = -0.14                ## Смещение центра масс вперёд(-) / назад(+)

	# --- 4. Броня, топливо и таран ---
	health = 2850                       ## Базовая прочность HP
	max_fuel = 190                      ## Объём топливного бака (л)
	fuel_per_100m = 3.7                 ## Расход топлива на 100 метров
	zombie_damage_taken = 2             ## Урон по машине за сбитого зомби
	impact_momentum_keep = 0.94         ## Сохранение скорости при таране препятствий (0..1)

	# --- 5. Прочее (КПП, аэродинамика, габариты, свет, звук) ---
	high_speed_steer_min_ratio = 0.26
	throttle_release_rate = 3.2
	aero_drag_coeff = 1.35
	downforce_multiplier = 34.0
	gear_speed_ratios = [0.20, 0.42, 0.68, 0.98]
	gear_torque_multipliers = [1.46, 1.14, 0.86, 0.64]
	can_deform_body = false
	front_grip_bias = 0.96
	rear_grip_bias = 1.12
	wheelbase_m = 3.37
	steering_scrub_drag = 0.20
	hull_half_extents = Vector2(1.36, 3.32)
	idle_fuel_per_sec = 0.25
	crash_death_speed_mps = 35.0
	engine_sound_id = "paz3205"
	engine_pitch_scale = 0.65
	has_exhaust_backfire = false
	gear_shift_pitch_base = 0.78
	shadow_texture = GlbVehicleHelper.make_shadow_tex("paz3205", 0.56, 0.74)
	headlight_positions = [Vector3(-0.90, 0.94, -3.26), Vector3(0.90, 0.94, -3.26)]
	taillight_positions = [Vector3(-0.92, 1.02, 3.28), Vector3(0.92, 1.02, 3.28)]
	headlight_lens_size = Vector2(0.28, 0.26)
	taillight_lens_size = Vector2(0.24, 0.30)
	headlight_proj_size = Vector2(16.0, 38.0)
	headlight_proj_z_start = -3.28
	taillight_proj_size = Vector2(4.2, 2.6)
	taillight_proj_z_start = 3.24
	shadow_blob_size = Vector2(5.80, 10.60)
	shadow_offset = Vector2(0.0, 0.04)
	engine_hood_offset = Vector3(0.0, 1.25, -2.55)
	car_paint_color = Color(0.533, 0.533, 0.533, 1.0)
	exhaust_offset = Vector3(-0.84, 0.44, 3.25)
	exhaust_offsets = [Vector3(-0.84, 0.44, 3.25)]
	exhaust_style = "diesel"

func _ready() -> void:
	mass = 6800.0
	_assemble_paz_visuals()
	super()
	_setup_turret_vfx()

func _assemble_paz_visuals() -> void:
	if get_node_or_null("PAZModelRoot") != null:
		return
	var model_root := GlbVehicleHelper.load_glb_instance("res://entities/vehicles/PAZ_3205/paz_3205_model.glb")
	if model_root == null:
		return
	model_root.name = "PAZModelRoot"
	model_root.position = Vector3(-0.01, 0.161, 0.24)
	model_root.rotation.y = PI * 0.5
	model_root.scale = Vector3.ONE * 0.095
	add_child(model_root)
	var wheel_map: Dictionary = {
		"Wheel_FL": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"Wheel_FR": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"Wheel_RL": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"Wheel_RR": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		GlbVehicleHelper.mount_wheel_node(self, model_root, w_name, wheel_map[w_name] as RaycastWheel, true)
	_turret_gun = model_root.find_child("Turret_Gun", true, false) as Node3D

func _setup_turret_vfx() -> void:
	if not is_instance_valid(_turret_gun):
		return
	_muzzle_point = Marker3D.new()
	_muzzle_point.name = "MuzzlePoint"
	# Barrel points along +X in Turret_Gun local space
	_muzzle_point.position = Vector3(10.2, 2.5, 0.0)
	_turret_gun.add_child(_muzzle_point)

	_muzzle_flash_rig = Node3D.new()
	_muzzle_flash_rig.name = "MuzzleFlashRig"
	_muzzle_flash_rig.visible = false
	_muzzle_point.add_child(_muzzle_flash_rig)

	var strip_mesh := QuadMesh.new()
	strip_mesh.size = Vector2(9.0, 18.0)
	for i in range(3):
		var mat := ShaderMaterial.new()
		mat.shader = SHADER_MUZZLE_FIRE
		mat.render_priority = 3
		mat.set_shader_parameter("flash_strength", 0.0)
		_muzzle_flash_mats.append(mat)

		var mi := MeshInstance3D.new()
		mi.name = "FlamePlane_%d" % i
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.mesh = strip_mesh
		mi.material_override = mat
		var roll_ang := deg_to_rad(float(i) * 60.0)
		mi.transform = Transform3D(Basis(Vector3.RIGHT, roll_ang) * Basis(Vector3.FORWARD, -PI * 0.5), Vector3(8.5, 0.0, 0.0))
		_muzzle_flash_rig.add_child(mi)

	var mouth_mesh := QuadMesh.new()
	mouth_mesh.size = Vector2(10.5, 10.5)
	var mouth_mat := ShaderMaterial.new()
	mouth_mat.shader = SHADER_MUZZLE_FIRE
	mouth_mat.render_priority = 4
	mouth_mat.set_shader_parameter("flash_strength", 0.0)
	_muzzle_flash_mats.append(mouth_mat)

	var mouth_mi := MeshInstance3D.new()
	mouth_mi.name = "MouthHalo"
	mouth_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mouth_mi.mesh = mouth_mesh
	mouth_mi.material_override = mouth_mat
	mouth_mi.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.6, 0.0, 0.0))
	_muzzle_flash_rig.add_child(mouth_mi)

	if not is_preview:
		_barrel_linger_smoke = CarVFX.create_barrel_linger_smoke(_muzzle_point, Vector3.ZERO)

func set_preview_mode(enabled: bool, showcase_mode: bool = false) -> void:
	super(enabled, showcase_mode)
	if enabled:
		if is_instance_valid(_muzzle_flash_rig):
			_muzzle_flash_rig.visible = false
		if is_instance_valid(_barrel_linger_smoke):
			_barrel_linger_smoke.emitting = false
			_barrel_linger_smoke.visible = false

func _process_vehicle_extras(delta: float) -> void:
	_turret_scan_timer -= delta
	if _turret_scan_timer <= 0.0 or not is_instance_valid(target_zombie) or not target_zombie.visible or target_zombie.get("state") == 3:
		_turret_scan_timer = 0.12
		_find_zombie_target()

	if is_instance_valid(_turret_gun):
		if is_instance_valid(target_zombie):
			var gun_parent := _turret_gun.get_parent() as Node3D
			if gun_parent:
				var local_target := gun_parent.to_local(target_zombie.global_position)
				var target_angle_y := atan2(-local_target.z, local_target.x)
				var limit_radians := deg_to_rad(75.0)
				target_angle_y = clampf(target_angle_y, -limit_radians, limit_radians)
				_turret_gun.rotation.y = move_toward(_turret_gun.rotation.y, target_angle_y, STEER_SPEED * 2.8 * delta)
		else:
			_turret_gun.rotation.y = move_toward(_turret_gun.rotation.y, 0.0, STEER_SPEED * 1.5 * delta)

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(_muzzle_flash_timer - delta, 0.0)
		var strength := clampf(_muzzle_flash_timer / 0.11, 0.0, 1.0)
		for m in _muzzle_flash_mats:
			m.set_shader_parameter("flash_strength", sqrt(strength))
		if _muzzle_flash_timer <= 0.001 and is_instance_valid(_muzzle_flash_rig):
			_muzzle_flash_rig.visible = false

	if _barrel_heat_timer > 0.0:
		_barrel_heat_timer = maxf(_barrel_heat_timer - delta, 0.0)
	if is_instance_valid(_barrel_linger_smoke):
		_barrel_linger_smoke.emitting = (_barrel_heat_timer > 0.0 and not destroyed and not is_preview)

	if (Input.is_action_pressed("space") or Input.is_key_pressed(KEY_SPACE)) and can_shoot:
		_shoot_zombie()

func _find_zombie_target() -> void:
	var closest: Node3D = null
	var min_dist_sq := 75.0 * 75.0
	var forward_dir := -global_transform.basis.z
	forward_dir.y = 0.0
	if forward_dir.length_squared() > 0.0001:
		forward_dir = forward_dir.normalized()

	for z in ZombiePool.active_zombies:
		if not is_instance_valid(z) or not z.visible or z.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if z.get("state") == 3:
			continue
		var to_z := z.global_position - global_position
		if to_z.dot(forward_dir) < -4.0:
			continue
		var dist_sq := to_z.length_squared()
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			closest = z
	target_zombie = closest

func _shoot_zombie() -> void:
	if destroyed or is_preview:
		return
	can_shoot = false
	_muzzle_flash_timer = 0.11
	_barrel_heat_timer = 1.6

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "btr_gunshot", -3.0, randf_range(1.18, 1.34))

	if is_instance_valid(_muzzle_flash_rig):
		_muzzle_flash_rig.visible = true
		_muzzle_flash_rig.rotation.x = randf_range(0.0, TAU)
		var phase := randf_range(0.0, 50.0)
		for m in _muzzle_flash_mats:
			m.set_shader_parameter("seed_phase", phase)
			m.set_shader_parameter("flash_strength", 1.0)

	var muzzle_pos := _muzzle_point.global_position if is_instance_valid(_muzzle_point) else (global_position + Vector3(0.0, 3.2, 0.0))
	var shot_dir: Vector3 = -global_transform.basis.z
	if is_instance_valid(_turret_gun):
		shot_dir = _turret_gun.global_transform.basis.x
	shot_dir = shot_dir.normalized()
	CarVFX.spawn_muzzle_blast(muzzle_pos, shot_dir, linear_velocity)
	shake_camera(0.18)

	if is_instance_valid(target_zombie) and target_zombie.visible and target_zombie.get("state") != 3:
		var hit_pos := target_zombie.global_position + Vector3(0.0, 1.0, 0.0)
		var push_dir := (hit_pos - muzzle_pos).normalized()
		if target_zombie.has_method("die"):
			target_zombie.call("die", push_dir * 20.0 + Vector3.UP * 5.0, 22.0)
			_on_zombie_killed()
		CarVFX.spawn_impact(hit_pos, "blood")
		target_zombie = null

	var cooldown: float = lerpf(0.13, 0.075, clampf(float(_chassis_upgrade_lvl) / 10.0, 0.0, 1.0))
	await get_tree().create_timer(cooldown).timeout
	if is_instance_valid(self):
		can_shoot = true

func _destroy_car(death_reason: String = "МАШИНА УНИЧТОЖЕНА") -> void:
	if is_instance_valid(_muzzle_flash_rig):
		_muzzle_flash_rig.visible = false
	if is_instance_valid(_barrel_linger_smoke):
		_barrel_linger_smoke.emitting = false
	super(death_reason)
