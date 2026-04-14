extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4

@export_group("Driving")
@export var STEER_SPEED: float = 1
@export var STEER_LIMIT: float = 0.5
@export var engine_force_value: float = 1800
@export var brake_force: float = 50.0
@export var handbrake_force: float = 200.0

@export_group("Health")
@export var max_hp: float = 260.0
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision") # ВОТ ЭТОТ БЛОК НУЖНО ВЕРНУТЬ:
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
var stop_threshold_speed: float = 1.0 
var friction_force: float = 5.0 

func _ready() -> void:
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER | ZOMBIE_LAYER
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = max_hp
	
	# СМЕЩАЕМ ЦЕНТР МАСС НИЖЕ (чтобы не переворачивалась и меньше заносило)
	center_of_mass = Vector3(0, -0.5, 0)

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	var speed_mps: float = linear_velocity.length()
	var speed_kmh = speed_mps * 3.6
	
	if $Hud/speed:
		$Hud/speed.text = str(round(speed_kmh)) + "  KM/H"

	# 1. ГАЗ (W)
	if Input.is_key_pressed(KEY_W):
		engine_force = -engine_force_value
		brake = 0.0 # ВАЖНО: обнуляем тормоз при нажатии газа
	else:
		engine_force = 0.0

	# 2. ТОРМОЗ (S) И РУЧНИК (Space)
	if Input.is_key_pressed(KEY_SPACE):
		brake = handbrake_force
		engine_force = 0.0
	elif Input.is_key_pressed(KEY_S):
		brake = brake_force
		engine_force = 0.0
	elif not Input.is_key_pressed(KEY_W):
		# Если ничего не нажато — катимся или медленно тормозим
		if speed_mps < 1.0:
			brake = 2.0 # Легкое удержание на месте
		else:
			brake = 0.0
	
	# Визуал фар стоп-сигналов
	var show_lights = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_SPACE)
	$Light_Left.visible = show_lights
	$Light_Right.visible = show_lights

	# 3. РУЛЕЖКА (Динамическая)
	var steer_input = Input.get_axis("D", "A")
	var speed_factor = clamp(1.0 - (speed_kmh / 180.0), 0.25, 1.0) 
	var steer_target = steer_input * (STEER_LIMIT * speed_factor)
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

	# Обновляем трение колес
	update_friction(Input.is_key_pressed(KEY_SPACE))
	traction(speed_mps)


func update_friction(handbrake: bool):
	# Если нажат ручник — зад заносит, если нет — держим дорогу крепко
	var stiffness = 0.8 if handbrake else 3.5 
	if has_node("wheal2"): $wheal2.wheel_friction_slip = stiffness
	if has_node("wheal3"): $wheal3.wheel_friction_slip = stiffness
	# Передние колеса всегда должны хорошо держать дорогу
	if has_node("wheal0"): $wheal0.wheel_friction_slip = 4.0
	if has_node("wheal1"): $wheal1.wheel_friction_slip = 4.0

func traction(speed: float) -> void:
	# Нажми Tab один раз перед этой строкой:
	var downforce = clamp(speed * 40.0, 0, 5000)
	# И здесь тоже Tab:
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
	
