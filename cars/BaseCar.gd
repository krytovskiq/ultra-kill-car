extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4
var total_distance: float = 0.0
var start_z_position: float = 0.0
@export_group("Driving")
@export var STEER_SPEED: float = 0.25 # Увеличил скорость возврата руля
@export var STEER_LIMIT: float = 0.5 # Чуть уменьшил общий лимит
@export var engine_force_value: float = 1800
@export var brake_force: float = 50.0
@export var handbrake_force: float = 200.0
@export var MAX_SPEED_KMH: int = 150

@export_group("Health")
@export var max_hp: int = 260
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

@export_group("Fuel")
@export var max_fuel: int = 100
@export var fuel_consumption: float = 2.0 # Расход в секунду
var current_fuel: float = 0.0
var current_hp: float = 0.0
var destroyed: bool = false

func _ready() -> void:
	start_z_position = global_position.z
	linear_velocity = -global_transform.basis.z * (20.0 / 3.6)
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER | ZOMBIE_LAYER
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = max_hp
	current_fuel = max_fuel
	# МАКСИМАЛЬНО НИЗКИЙ ЦЕНТР МАСС (чтобы не переворачивалась)
	center_of_mass = Vector3(0, -0.3, 0)
	if $Hud/FuelBar:
		$Hud/FuelBar.max_value = max_fuel
		$Hud/FuelBar.value = current_fuel
func _physics_process(delta: float) -> void:
	if destroyed: return
	
	total_distance = abs(global_position.z - start_z_position)
	if $Hud/Metr:
		$Hud/Metr.text = str(round(total_distance)) + " M"
		
	var speed_mps: float = linear_velocity.length()
	var speed_kmh: int = speed_mps * 2
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
	var min_speed_kmh = 10
	if Input.is_key_pressed(KEY_S):
		if speed_kmh > min_speed_kmh:
			brake = brake_force
			engine_force = 0.0
		else:
			brake = 0.0
			engine_force = -(engine_force_value * 0.2) # Небольшая тяга для 20 км/ч
	elif not Input.is_key_pressed(KEY_W) and speed_kmh < min_speed_kmh:
		brake = 0.0
		engine_force = -(engine_force_value * 0.3)
	else:
		if not Input.is_key_pressed(KEY_SPACE):
			brake = 0.0
	# 3. УМНАЯ РУЛЕЖКА
	# Получаем ввод: влево (A) даст положительное число, вправо (D) — отрицательное
	var steer_input = Input.get_axis("D", "A") 
	
	# Рассчитываем лимит поворота в зависимости от скорости (чтобы не улететь на 200 км/ч)
	var speed_factor = clamp(1.0 - (speed_kmh / MAX_SPEED_KMH), 0.3, 1.0)
	var steer_target = steer_input * STEER_LIMIT * speed_factor
	
	# Применяем поворот к свойству steering (оно само повернет узлы VehicleWheel3D)
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


	traction(speed_mps)
	$Light_Right.visible = Input.is_key_pressed(KEY_S)
	$Light_Left.visible = Input.is_key_pressed(KEY_S)
	
	# Система топлива
	if not destroyed and speed_mps != 0:
		current_fuel -= fuel_consumption * delta
	if current_fuel <= 0:
		current_fuel = 0
		engine_force = 0
	if $Hud/FuelBar:
		$Hud/FuelBar.value = current_fuel
	if speed_kmh <= 1:
		_destroy_car()
func refuel(amount: float):
	current_fuel = clamp(current_fuel + amount, 0, max_fuel)
	print("Заправлено! Текущее топливо: ", current_fuel)

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

# Функция замирания времени (дает ощущение тяжести удара)
func hit_stop(duration: float):
	Engine.time_scale = 0.1 # Замедляем всё в 10 раз
	await get_tree().create_timer(duration * 0.1, true, false, true).timeout
	Engine.time_scale = 1.0

# Функция спавна крови (используй свои частицы)
func spawn_blood(pos: Vector3, impulse: Vector3):
	# Если у тебя есть сцена частиц крови, создавай её здесь
	# Пример быстрого Camera Shake:
	if has_node("Camera3D"):
		var shake = 0.3
		$Camera3D.h_offset = randf_range(-shake, shake)
		$Camera3D.v_offset = randf_range(-shake, shake)

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
	brake = 0
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
	
