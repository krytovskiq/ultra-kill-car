extends "res://entities/vehicles/vehicle_base.gd"

const BTR_SHADOW_TEX: Texture2D = preload("res://entities/vehicles/textures/shadow_btr.png")
const SHADER_MUZZLE_FIRE: Shader = preload("res://entities/vehicles/shaders/muzzle_fire.gdshader")

@export var handbrake_force: float = 90.0

@onready var base_gun: Node3D = get_node_or_null("Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun")
@onready var _gun_tracer: Node3D = get_node_or_null("Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun/Gun_Effect")

var target_zombie: Node3D = null
var can_shoot: bool = true
var _turret_scan_timer: float = 0.0

var _gun_mesh: Node3D = null
var _gun_base_z: float = -2.6554387
var _muzzle_point: Marker3D = null
var _muzzle_flash_rig: Node3D = null
var _muzzle_flash_mats: Array[ShaderMaterial] = []
var _barrel_linger_smoke: CPUParticles3D = null
var _muzzle_flash_timer: float = 0.0
var _barrel_heat_timer: float = 0.0

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ БРОНЕВИКА (BTR) — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	# --- Руль и вес управления ---
	STEER_SPEED = 0.82                  ## Скорость поворота руля (ниже = тяжелее крутить)
	STEER_LIMIT = 0.28                  ## Максимальный угол поворота колёс (рад)
	steer_inertia = 2.6                 ## Инерция рулевой рейки (тяжесть руля)
	high_speed_steer_min_ratio = 0.28   ## Доля угла поворота на макс. скорости

	# --- Двигатель, разгон и максималка (реалистичный тяжёлый дизельный разгон) ---
	throttle_response = 1.15            ## Скорость набора газа (меньше = тяжелее разгон)
	throttle_release_rate = 2.9         ## Спад тяги при отпускании W
	engine_force_value = 14800          ## Сила дизеля (уменьшите для ещё более медленного старта)
	MAX_SPEED_KMH = 104                 ## Макс. скорость в стоке (км/ч, качается в гараже)
	brake_force = 92.0                  ## Сила тормоза
	max_brake_decel_mps2 = 4.9          ## Тормозное замедление (м/с², тяжёлый тормозной путь)
	aero_drag_coeff = 1.75              ## Сопротивление воздуха крупного бронекорпуса

	# --- Передачи КПП (пороги % скорости и множители тяги) ---
	gear_speed_ratios = [0.22, 0.46, 0.74, 1.02]
	gear_torque_multipliers = [1.45, 1.14, 0.86, 0.64]

	# --- Подвеска, колёса и устойчивость ---
	suspension_firmness = 1.32          ## Общая жёсткость торсионной подвески
	compression_damping_ratio = 0.68    ## Гашение удара при пробое и прыжках с моста
	rebound_damping_ratio = 0.82        ## Гашение отбоя без подпрыгивания 9-тонного корпуса
	can_deform_body = false             ## Тяжёлый бронированный корпус БТР не деформируется при столкновениях
	anti_roll_stiffness = 46000.0       ## Мощный стабилизатор против кренов 9-тонного корпуса
	front_spring_stiffness = 225000.0   ## Жёсткость передних пружин (Н/м)
	rear_spring_stiffness = 235000.0    ## Жёсткость задних пружин (Н/м)
	front_rest_length_scale = 1.18      ## Ход / клиренс передней подвески
	rear_rest_length_scale = 1.18       ## Ход / клиренс задней подвески
	front_grip_bias = 0.90              ## Баланс сцепления передней оси
	rear_grip_bias = 1.15               ## Баланс сцепления ведущей задней оси
	suspension_travel_speed = 14.0      ## Скорость визуального хода тяжёлых колёс
	weight_transfer_long = 0.18         ## Перенос веса вперёд/назад при разгоне и тормозе
	weight_transfer_lat = 0.20          ## Перенос веса в стороны при маневре
	com_height = 0.44                   ## Высота центра масс
	com_z_offset = -0.18                ## Смещение центра масс вперёд
	wheelbase_m = 3.45                  ## Колёсная база (м)
	steering_scrub_drag = 0.24          ## Потери скорости тяжёлых колёс в повороте
	impact_momentum_keep = 0.96         ## Броневик почти не замедляется при сбитии преград
	body_roll_torque_factor = 0.42      ## Сила крена корпуса в повороте
	body_pitch_torque_factor = 0.46     ## Сила клевка при тормозе
	lateral_stiffness = 10.6            ## Боковая жёсткость крупных шин
	tire_friction = 2.40                ## Сцепление тяжёлых покрышек
	drift_grip_factor = 0.84            ## Сцепление при срыве в занос
	yaw_stability_assist = 2.7          ## Курсовая устойчивость (ESC)
	hull_half_extents = Vector2(1.38, 2.95) ## Габариты половины бронекорпуса (ширина, длина)

	# --- Звук и свет ---
	engine_sound_id = "btr"
	engine_pitch_scale = 0.95
	has_exhaust_backfire = false
	gear_shift_pitch_base = 0.76
	shadow_texture = BTR_SHADOW_TEX
	headlight_positions = [Vector3(-0.73, 0.90, -2.64), Vector3(1.04, 1.04, -2.57)]
	taillight_positions = [Vector3(-0.54, 0.88, 2.50), Vector3(0.54, 0.88, 2.50)]
	headlight_lens_size = Vector2(0.25, 0.25)
	taillight_lens_size = Vector2(0.22, 0.22)
	headlight_proj_size = Vector2(16.0, 38.0)
	headlight_proj_z_start = -2.65
	taillight_proj_size = Vector2(4.2, 2.5)
	taillight_proj_z_start = 2.46
	shadow_blob_size = Vector2(5.88, 10.16)
	shadow_offset = Vector2(-0.06, -0.09)

	# --- Броня, урон и топливный бак ---
	health = 3500                       ## Базовая прочность HP (качается в гараже)
	engine_hood_offset = Vector3(0.0, 1.15, -1.55)
	car_paint_color = Color(0.28, 0.31, 0.27)
	max_fuel = 200                      ## Базовый объём бака в литрах (качается в гараже)
	fuel_per_100m = 3.8                 ## Расход на 100 м
	idle_fuel_per_sec = 0.26            ## Холостой расход (л/сек)
	zombie_damage_taken = 2             ## Урон по броне за зомби
	crash_death_speed_mps = 38.0        ## Смертельная скорость лобового удара (м/с)
	downforce_multiplier = 42.0
	exhaust_offset = Vector3(-0.92, 0.96, 2.68)
	exhaust_offsets = [Vector3(-0.92, 0.96, 2.68), Vector3(0.92, 0.96, 2.68)]
	exhaust_style = "diesel"

func _ready() -> void:
	mass = 9400.0                       ## Реальная боевая масса (кг) — 9.4 тонны
	super()
	_setup_muzzle_vfx()

func _setup_muzzle_vfx() -> void:
	if not is_instance_valid(base_gun):
		return
	_gun_mesh = base_gun.get_node_or_null("Gun") as Node3D
	if _gun_mesh:
		_gun_base_z = _gun_mesh.position.z

	_muzzle_point = Marker3D.new()
	_muzzle_point.name = "MuzzlePoint"
	_muzzle_point.position = Vector3(0.0, 1.95, -23.6)
	base_gun.add_child(_muzzle_point)

	_setup_muzzle_flash_rig()
	if not is_preview:
		_barrel_linger_smoke = CarVFX.create_barrel_linger_smoke(_muzzle_point, Vector3.ZERO)

func _setup_muzzle_flash_rig() -> void:
	if not is_instance_valid(_muzzle_point):
		return
	_muzzle_flash_rig = Node3D.new()
	_muzzle_flash_rig.name = "MuzzleFlashRig"
	_muzzle_flash_rig.visible = false
	_muzzle_point.add_child(_muzzle_flash_rig)

	# Crossed 3-plane flame tongues along -Z in barrel-tip space (~2.1m long x 1.0m wide in world)
	var strip_mesh := QuadMesh.new()
	strip_mesh.size = Vector2(10.5, 22.0)
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
		# QuadMesh lies in XY with +Y top -> tilt -90 on X so top (+Y -> UV.y=0) extends along -Z
		mi.transform = Transform3D(Basis(Vector3.FORWARD, roll_ang) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0.0, 0.0, -10.5))
		_muzzle_flash_rig.add_child(mi)

	var mouth_mesh := QuadMesh.new()
	mouth_mesh.size = Vector2(12.5, 12.5)
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
	mouth_mi.position = Vector3(0.0, 0.0, -0.8)
	_muzzle_flash_rig.add_child(mouth_mi)

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

	if is_instance_valid(base_gun):
		if is_instance_valid(target_zombie):
			var gun_parent := base_gun.get_parent() as Node3D
			if gun_parent:
				var local_target := gun_parent.to_local(target_zombie.global_position)
				var target_angle_y := atan2(-local_target.x, -local_target.z)
				var limit_radians := deg_to_rad(70.0)
				target_angle_y = clampf(target_angle_y, -limit_radians, limit_radians)
				base_gun.rotation.y = move_toward(base_gun.rotation.y, target_angle_y, STEER_SPEED * 2.5 * delta)
		else:
			base_gun.rotation.y = move_toward(base_gun.rotation.y, 0.0, STEER_SPEED * 1.4 * delta)

	if _muzzle_flash_timer > 0.0:
		_muzzle_flash_timer = maxf(_muzzle_flash_timer - delta, 0.0)
		var strength := clampf(_muzzle_flash_timer / 0.14, 0.0, 1.0)
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
	var min_dist_sq := 80.0 * 80.0
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
		if to_z.dot(forward_dir) < -5.0:
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
	_muzzle_flash_timer = 0.14
	_barrel_heat_timer = 1.9

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "btr_gunshot", -1.0, randf_range(0.76, 0.86))

	if is_instance_valid(_muzzle_flash_rig):
		_muzzle_flash_rig.visible = true
		_muzzle_flash_rig.rotation.z = randf_range(0.0, TAU)
		var phase := randf_range(0.0, 50.0)
		for m in _muzzle_flash_mats:
			m.set_shader_parameter("seed_phase", phase)
			m.set_shader_parameter("flash_strength", 1.0)

	if is_instance_valid(_muzzle_point):
		var muzzle_world := _muzzle_point.global_position
		var muzzle_fwd := (-_muzzle_point.global_transform.basis.z).normalized()
		CarVFX.spawn_muzzle_blast(muzzle_world, muzzle_fwd, linear_velocity)

	if is_instance_valid(_gun_mesh):
		_gun_mesh.position.z = _gun_base_z + 1.85
		var rec_tw := create_tween()
		rec_tw.tween_property(_gun_mesh, "position:z", _gun_base_z, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_gun_tracer):
		_gun_tracer.position = Vector3(0.0, 1.95, -25.0)
		_gun_tracer.visible = true
		var tween := create_tween()
		tween.tween_property(_gun_tracer, "position:z", -140.0, 0.065)
		var wr_tr: WeakRef = weakref(_gun_tracer)
		tween.finished.connect(
			func():
				var tracer_node = wr_tr.get_ref()
				if tracer_node and is_instance_valid(tracer_node):
					tracer_node.visible = false
		)

	shake_camera(0.14)

	var aim_dir := (-global_transform.basis.z)
	aim_dir.y = 0.0
	aim_dir = aim_dir.normalized() if aim_dir.length_squared() > 0.0001 else Vector3.FORWARD
	if is_instance_valid(base_gun):
		var g_fwd := -base_gun.global_transform.basis.z
		g_fwd.y = 0.0
		if g_fwd.length_squared() > 0.0001:
			aim_dir = g_fwd.normalized()

	var hit_pos: Vector3 = global_position + aim_dir * 34.0
	hit_pos.y = 0.0
	if is_instance_valid(target_zombie):
		var t_pos := target_zombie.global_position
		var sum_pos := t_pos
		var cnt := 1
		var near_pack := ZombiePool.get_nearby_zombies(t_pos)
		for nz: Node3D in near_pack:
			if is_instance_valid(nz) and nz.visible and nz.get("state") != 3:
				if (nz.global_position - t_pos).length_squared() <= 64.0:
					sum_pos += nz.global_position
					cnt += 1
		hit_pos = sum_pos / float(cnt)
		hit_pos.y = 0.0

	CarVFX.spawn_he_explosion(hit_pos, 9.5)
	if sm and sm.has_method("play_btr_explosion"):
		sm.call("play_btr_explosion")

	const BTR_BLAST_RADIUS_SQ := 9.5 * 9.5
	const BTR_SHOCK_RADIUS_SQ := 14.0 * 14.0
	var kills: int = 0
	var snapshot: Array[Node3D] = ZombiePool.active_zombies.duplicate()
	for z: Node3D in snapshot:
		if not is_instance_valid(z) or not z.visible or z.process_mode == Node.PROCESS_MODE_DISABLED:
			continue
		if z.get("state") == 3:
			continue
		var delta_v := z.global_position - hit_pos
		delta_v.y = 0.0
		var d2 := delta_v.length_squared()
		if d2 <= BTR_BLAST_RADIUS_SQ:
			var d := sqrt(d2)
			var out_dir := (delta_v / d) if d > 0.15 else aim_dir
			var falloff := 1.0 - clampf(d / 9.5, 0.0, 0.65)
			var impulse := out_dir * (22.0 * falloff)
			if z.has_method("die"):
				z.die(impulse, 28.0 * falloff)
				_on_zombie_killed()
				kills += 1
			else:
				z.queue_free()
		elif d2 <= BTR_SHOCK_RADIUS_SQ:
			var d := maxf(sqrt(d2), 0.1)
			var out_dir := delta_v / d
			if z.has_method("knockdown"):
				z.knockdown(out_dir * 12.5)

	if kills > 0:
		CarVFX.spawn_impact(hit_pos + Vector3.UP, "blood")
	for b_node in get_tree().get_nodes_in_group("explosive_barrel"):
		if not is_instance_valid(b_node) or not (b_node is Node3D):
			continue
		var bd := (b_node as Node3D).global_position - hit_pos
		bd.y = 0.0
		if bd.length_squared() <= 121.0 and b_node.has_method("detonate"):
			b_node.call("detonate", self)
	target_zombie = null

	var reload_sec: float = clampf(0.32 - float(_chassis_upgrade_lvl) * 0.014, 0.18, 0.35)
	await get_tree().create_timer(reload_sec).timeout
	if is_instance_valid(self):
		can_shoot = true

func _destroy_car(death_reason: String = "МАШИНА УНИЧТОЖЕНА") -> void:
	if is_instance_valid(_muzzle_flash_rig):
		_muzzle_flash_rig.visible = false
	if is_instance_valid(_barrel_linger_smoke):
		_barrel_linger_smoke.emitting = false
	super(death_reason)
