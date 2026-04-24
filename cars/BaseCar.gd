extends VehicleBody3D

var total_distance: float = 0.0
var start_z_position: float = 0.0
@export_group("Driving")
@export var STEER_SPEED: float = 0.25 # Увеличил скорость возврата руля
@export var STEER_LIMIT: float = 0.5 # Чуть уменьшил общий лимит
@export var engine_force_value: float = 18
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
@export var max_fuel: int = 10000
@export var fuel_consumption: float = 0.0 # Расход в секунду
var current_fuel: float = 0.0
var current_hp: float = 0.0
var destroyed: bool = false

func _ready() -> void:
	start_z_position = global_position.z
	linear_velocity = -global_transform.basis.z * (20.0 / 3.6)
	add_to_group("player")
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
	var target_max_speed = MAX_SPEED_KMH
	var auto_roll_speed = 40
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
			engine_force = - (engine_force_value * 0.5)
			brake = 0.0
		else:
			engine_force = 0.0
	# 2. ТОРМОЗ (Клавиша S)
	var min_speed_kmh = 25
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
		$look/Camera3D.h_offset = randf_range(-shake, shake)
		$look/Camera3D.v_offset = randf_range(-shake, shake)

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
	

func shake_camera(amount: float):
	# amount должен быть около 0.5 - 1.0 для заметного эффекта
	var camera = $look/Camera3D # Уточняем путь согласно твоему дереву узлов
	if camera:
		var tween = create_tween()
		for i in range(5):
			# Используем случайные направления пошире
			var rand_offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
			tween.tween_property(camera, "h_offset", rand_offset.x, 0.02)
			tween.tween_property(camera, "v_offset", rand_offset.y, 0.02)
		
		# Возвращаем в исходную позицию
		tween.tween_property(camera, "h_offset", 0.0, 0.05)
		tween.tween_property(camera, "v_offset", 0.0, 0.05)
		
func _on_kill_zone_body_entered(body: Node3D) -> void:
	# 1. Проверяем, что это зомби
	if not (body.is_in_group("zombie") and body.has_method("die")):
		return

	# 2. Получаем скорость (так как скрипт на машине, берем напрямую)
	var speed_mps = linear_velocity.length()
	var speed_kmh = speed_mps * 3.6 # Стандартный перевод в км/ч (или оставь * 2)

	# 3. ЛОГИКА УДАРА (Выбираем только ОДНО действие)
	if speed_kmh >= 40:
		# СМЕРТЬ (Высокая скорость)
		body.die(linear_velocity, speed_mps)
		
		# Эффекты для смерти
		var shake_power = remap(speed_kmh, 40, 150, 0.3, 1.0)
		shake_camera(shake_power)
		
		Engine.time_scale = 0.2
		await get_tree().create_timer(0.04, true, false, true).timeout
		Engine.time_scale = 1.0
		
		# Кровь только при смерти
		spawn_blood(body.global_position, linear_velocity * 0.5)
		
	elif speed_kmh >= 10:
		# ПАДЕНИЕ (Средняя скорость)
		if body.has_method("knockdown"):
			body.knockdown(linear_velocity)
	else:
		# ТОЛЧОК (Очень низкая скорость)
		print("Просто задели: ", speed_kmh, " км/ч")
