extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4

@export_group("Driving")
@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.6
@export var engine_force_value: float = 2500.0 # Мощность авто
@export var brake_force: float = 10.0 # Сила плавного тормоза

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
var stop_threshold_speed: float = 2.8 
var friction_force: float = 15.0 

func _ready() -> void:
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER | ZOMBIE_LAYER
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = max_hp
	# Настройка физики прямо из кода для уверенности
	mass = 1800 

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	var speed_mps: float = linear_velocity.length()
	if $Hud/speed:
		$Hud/speed.text = str(round(speed_mps * 3.6)) + "  KM/H"

	# УПРАВЛЕНИЕ: W едет вперед, S назад
	var input_gas = Input.get_axis("W", "S") 
	
	if input_gas != 0:
		engine_force = input_gas * engine_force_value
		brake = 0.0
	else:
		engine_force = 0.0
		# Плавно останавливаем машину на малой скорости
		if speed_mps < stop_threshold_speed and speed_mps > 0.1:
			brake = move_toward(brake, brake_force, delta * 10.0)
		else:
			brake = 0.0
		apply_central_force(-linear_velocity * friction_force)

	# РУЛЕЖКА
	var steer_input = Input.get_axis("D", "A")
	var steer_target = steer_input * STEER_LIMIT
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

	# ТРЕНИЕ (для дрифта на S)
	if Input.is_action_pressed("S") and speed_mps > 5.0:
		if has_node("wheal2"): $wheal2.wheel_friction_slip = 0.8
		if has_node("wheal3"): $wheal3.wheel_friction_slip = 0.8
	else:
		if has_node("wheal2"): $wheal2.wheel_friction_slip = 3.0
		if has_node("wheal3"): $wheal3.wheel_friction_slip = 3.0

	traction(speed_mps)

func traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * speed * 5.0)

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
