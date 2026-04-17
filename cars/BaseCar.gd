extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4

@export_group("Driving")
@export var STEER_SPEED: float = 3.0 # Увеличил скорость возврата руля
@export var STEER_LIMIT: float = 0.25 # Чуть уменьшил общий лимит
@export var engine_force_value: float = 1800
@export var brake_force: float = 50.0
@export var handbrake_force: float = 200.0
@export var MAX_SPEED_KMH: float = 240 # ЛИМИТ СКОРОСТИ (измени по вкусу)

@export_group("Health")
@export var max_hp: float = 260.0
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision")
@export var zombie_hit_min_speed_mps: float = 0.8
@export var zombie_hit_max_speed_mps: float = 24.0
@export var zombie_damage_at_min_speed: float = 20.0
@export var zombie_damage_at_max_speed: float = 150.0
@export var zombie_impulse_at_min_speed: float = 30.0 
@export var zombie_impulse_at_max_speed: float = 80.0 
@export var zombie_upward_impulse: float = 15.0 
@export var wall_damage_min_speed_mps: float = 20.0

var current_hp: float = 0.0
var destroyed: bool = false

func _ready() -> void:
	linear_velocity = -global_transform.basis.z * (20.0 / 3.6)
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER | ZOMBIE_LAYER
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = max_hp
	
	# МАКСИМАЛЬНО НИЗКИЙ ЦЕНТР МАСС (чтобы не переворачивалась)
	center_of_mass = Vector3(0, -0.3, 0)

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	var speed_mps: float = linear_velocity.length()
	var speed_kmh = speed_mps * 3.6
	
	if $Hud/speed:
		$Hud/speed.text = str(round(speed_kmh)) + "  KM/H"

	if speed_kmh < 5.0 and engine_force != 0:
		# Дополнительная логика: например, если скорость 0 больше 2 секунд — проигрыш
		pass
	rotation.y = lerp_angle(rotation.y, 0, delta * 3.0)
		# Определяем целевую скорость
	var target_max_speed = MAX_SPEED_KMH # Твой обычный предел (например, 100)
	var auto_roll_speed = 20 # Скорость "ползущего" режима (15 км/ч)

	# 1. ЛОГИКА ГАЗА
	if Input.is_key_pressed(KEY_W):
		# Если жмем W — разгоняемся до максимума
		if speed_kmh < target_max_speed:
			engine_force = -engine_force_value
		else:
			engine_force = 0.0
		brake = 0.0
	else:
		if speed_kmh < auto_roll_speed:
			engine_force = - (engine_force_value * 0.5) # Даем 20% тяги для "ползания"
			brake = 0.0
		else:
			engine_force = 0.0

	# 2. ТОРМОЗ (Клавиша S)
	if Input.is_key_pressed(KEY_S):
		brake = brake_force
		engine_force = 0.0 # При торможении газ отключается полностью
	elif not Input.is_key_pressed(KEY_W) and speed_kmh < 1.0:
		# Чтобы машина не катилась бесконечно, когда почти остановилась
		brake = 2.0 

	# 2. РУЧНИК
	if Input.is_key_pressed(KEY_SPACE):
		brake = handbrake_force
		engine_force = 0.0
	elif not Input.is_key_pressed(KEY_W) and not Input.is_key_pressed(KEY_S):
		brake = 2.0 if speed_mps < 1.0 else 0.0
	
	# 3. УМНАЯ РУЛЕЖКА (Лимит на скорости)
	var steer_input = Input.get_axis("D", "A")
	# На высокой скорости руль поворачивается ОЧЕНЬ мало (в 5 раз меньше)
	var speed_factor = clamp(1.0 - (speed_kmh / (MAX_SPEED_KMH * 1.2)), 0.15, 1.0) 
	var steer_target = steer_input * (STEER_LIMIT * speed_factor)
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

	update_friction(Input.is_key_pressed(KEY_SPACE))
	traction(speed_mps)
	$Light_Right.visible = Input.is_key_pressed(KEY_S)
	$Light_Left.visible = Input.is_key_pressed(KEY_S)
func update_friction(handbrake: bool):
	# Увеличил зацеп, чтобы меньше заносило
	var stiffness = 1.0 if handbrake else 6.0 
	if has_node("wheal2"): $wheal2.wheel_friction_slip = stiffness
	if has_node("wheal3"): $wheal3.wheel_friction_slip = stiffness
	if has_node("wheal0"): $wheal0.wheel_friction_slip = 6.0
	if has_node("wheal1"): $wheal1.wheel_friction_slip = 6.0

func traction(speed: float) -> void:
	# Прижимная сила стала сильнее
	var downforce = clamp(speed * 50.0, 0, 8000)
	apply_central_force(Vector3.DOWN * downforce)


func _on_body_entered(body: Node) -> void:
	if destroyed: return
	var impact_speed := linear_velocity.length()
	
	if body.has_method("take_damage") or body.is_in_group("zombie"):
		if impact_speed < zombie_hit_min_speed_mps: return

		var speed_factor = clamp((impact_speed - zombie_hit_min_speed_mps) / (zombie_hit_max_speed_mps - zombie_hit_min_speed_mps), 0, 1)
		var impact_damage = lerp(zombie_damage_at_min_speed, zombie_damage_at_max_speed, speed_factor)
		var impulse_mag = lerp(zombie_impulse_at_min_speed, zombie_impulse_at_max_speed, speed_factor)
		
		var dir = _get_hit_direction(body)
		var final_impulse = dir * impulse_mag
		final_impulse.y = zombie_upward_impulse

		# СПАВНИМ КРОВЬ
		spawn_blood(body.global_position, final_impulse)
		
		# ЭФФЕКТ "ХИТ-СТОП" (замирание времени)
		hit_stop(0.06)
		body.take_damage(impact_damage, final_impulse)

# ФУНКЦИЯ ДЛЯ КРОВИ (создает сочные брызги)
func spawn_blood(pos: Vector3, impulse: Vector3):
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos + Vector3.UP * 0.6
	
	# 1. Настройка материала процесса (физика частиц)
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = impulse.normalized() + Vector3.UP * 0.5
	p_mat.spread = 30.0
	p_mat.initial_velocity_min = 10.0
	p_mat.initial_velocity_max = 18.0
	p_mat.gravity = Vector3(0, -25, 0)
	p_mat.damping_min = 15.0
	p_mat.damping_max = 20.0
	
	# РЕАЛИЗМ: Случайный размер
	p_mat.scale_min = 0.1
	p_mat.scale_max = 0.3
	
	# ИСПРАВЛЕННАЯ СТРОКА (Убрал 's' из флага)
	p_mat.particle_flag_align_y = true 
	
	particles.process_material = p_mat
	particles.amount = 20 # Меньше частиц = больше FPS
	particles.lifetime = 0.4
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	# 2. ВИЗУАЛ (Вытянутые капли)
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.08, 0.3) # Тонкие длинные капли
	
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.4, 0, 0) # Темная кровь
	# Включаем Billboard для оптимизации (частицы всегда лицом к игроку)
	m_mat.billboard_mode = StandardMaterial3D.BILLBOARD_PARTICLES
	m_mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED # ОПТИМИЗАЦИЯ: убираем расчет теней
	
	mesh.material = m_mat 
	particles.draw_pass_1 = mesh
	
	# 3. Запуск и удаление
	particles.emitting = true
	# Удаляем через 0.8 сек, чтобы частицы успели исчезнуть
	get_tree().create_timer(0.8).timeout.connect(particles.queue_free)


func hit_stop(duration: float):
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: float) -> void:
	if destroyed: return
	current_hp = maxf(current_hp - amount, 0.0)
	if current_hp <= 0.0: _destroy_car()

func _get_hit_direction(body: Node) -> Vector3:
	var car_fwd = -global_transform.basis.z 
	return (car_fwd + Vector3.UP * 0.2).normalized()

func _destroy_car():
	destroyed = true
	engine_force = 0
	brake = 10
	get_tree().reload_current_scene()
	
