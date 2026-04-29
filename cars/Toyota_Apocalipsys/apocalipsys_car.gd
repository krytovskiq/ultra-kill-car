extends VehicleBody3D

var total_distance: float = 0.0
var start_z_position: float = 0.0
var lights_tween: Tween

@export_group("Driving")
@export var STEER_SPEED: float = 1.6
@export var STEER_LIMIT: float = 0.6
@export var engine_force_value: float = 2000.0
@export var brake_force: float = 50.0
@export var handbrake_force: float = 50.0
@export var MAX_SPEED_KMH: int = 130

@export_group("Health")
@export var health: int = 100
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision")
@export var zombie_hit_min_speed_mps: float = 0.8
@export var zombie_hit_max_speed_mps: float = 24.0
@export var zombie_damage_at_min_speed: float = 20.0
@export var zombie_damage_at_max_speed: float = 150.0
@export var zombie_impulse_at_min_speed: float = 30.0 
@export var zombie_impulse_at_max_speed: float = 80.0 
@export var zombie_upward_impulse: float = 15.0 
@export var wall_damage_min_speed_mps: float = 5.0

@export_group("Fuel")
@export var max_fuel: int = 100
@export var fuel_consumption: float = 4.5
var current_fuel: float = 0.0
var current_hp: int = 0
var destroyed: bool = false

@export_group("Enemy Damage")
@export var damage_per_second: int = 10
var damage_timer: float = 0.0

func _ready() -> void:
	# ИСПРАВЛЕННАЯ ПРОВЕРКА И ПОДКЛЮЧЕНИЕ
	var kill_zone = get_node_or_null("Area3D")
	if kill_zone:
		kill_zone.connect("body_entered", _on_kill_zone_body_entered)
	else:
		push_error("ОШИБКА: Узел Area3D не найден! Создай его внутри машины.")

	start_z_position = global_position.z
	linear_velocity = -global_transform.basis.z * (20.0 / 3.6)
	add_to_group("player")
	
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = health
	current_fuel = max_fuel
	center_of_mass = Vector3(0, -0.1, 0)
	if has_node("Hud/HpBar"):
		$Hud/HpBar.max_value = health
		$Hud/HpBar.value = current_hp
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.max_value = max_fuel
		$Hud/FuelBar.value = current_fuel

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	total_distance = abs(global_position.z - start_z_position)
	if has_node("Hud/Metr"):
		$Hud/Metr.text = str(round(total_distance)) + " M"
		
	var speed_mps: float = linear_velocity.length()
	var speed_kmh: int = speed_mps * 3.6
	
	if has_node("Hud/speed"):
		$Hud/speed.text = str(round(speed_kmh)) + "  KM/H"
	
	
	var target_max_speed = MAX_SPEED_KMH
	var auto_roll_speed = 0
	
	if Input.is_key_pressed(KEY_W):
		engine_force = -engine_force_value if speed_kmh < target_max_speed else 0.0
		brake = 0.0
	else:
		engine_force = -(engine_force_value * 0.5) if speed_kmh < auto_roll_speed else 0.0

	var min_speed_kmh = 25
	if Input.is_key_pressed(KEY_S):
		if speed_kmh > min_speed_kmh:
			brake = brake_force
			engine_force = 0.0
		else:
			brake = 0.0
			engine_force = -(engine_force_value * 0.2)
	elif not Input.is_key_pressed(KEY_W) and speed_kmh < min_speed_kmh:
		brake = 0.0
		engine_force = -(engine_force_value * 0.3)
	else:
		if not Input.is_key_pressed(KEY_SPACE):
			brake = 0.0

	var steer_input = Input.get_axis("D", "A") 
	var speed_factor = clamp(1.0 - (speed_kmh / MAX_SPEED_KMH), 0.3, 1.0)
	var steer_target = steer_input * STEER_LIMIT * speed_factor
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)

	traction(speed_mps)
	
	$Light_Right.light_energy = lerp($Light_Right.light_energy, 2.0 if Input.is_key_pressed(KEY_S) else 0.1, 0.2)
	$Light_Left.light_energy = lerp($Light_Left.light_energy, 2.0 if Input.is_key_pressed(KEY_S) else 0.1, 0.2)

	
	if not destroyed and speed_mps > 0.1:
		current_fuel -= fuel_consumption * delta
	
	if current_fuel <= 0:
		current_fuel = 0
		engine_force = 0
	
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.value = current_fuel
	var kill_zone = get_node_or_null("Area3D")
	if kill_zone:
		var bodies = kill_zone.get_overlapping_bodies()
		var has_zombie = false
		
		for body in bodies:
			# Проверяем, что это зомби и он ЖИВОЙ
			if body.is_in_group("zombie") and body.get("state") != 3: # 3 — это ZombieState.DEAD
				has_zombie = true
				break 

		if has_zombie:
			damage_timer += delta
			if damage_timer >= 1.0: # Если прошла секунда
				take_damage(damage_per_second)
				damage_timer = 0.0
		else:
			damage_timer = 0.0


func refuel(amount: float):
	current_fuel = clamp(current_fuel + amount, 0, max_fuel)

func traction(speed: float) -> void:
	var downforce = clamp(speed * 50.0, 0, 8000)
	apply_central_force(Vector3.DOWN * downforce)

func hit_stop(duration: float):
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration * 0.1, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: int) -> void:
	if destroyed: return
	current_hp = maxf(current_hp - amount, 0)
	if has_node("Hud/HpBar"):
		$Hud/HpBar.value = current_hp
		print("ХП Машины: ", current_hp)
		if current_hp <= 0: _destroy_car()
		

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if destroyed: return
	
	var speed_mps = linear_velocity.length()
	var speed_kmh = speed_mps * 3.6 

	# 1. СТОЛКНОВЕНИЕ С ЗОМБИ
	if body.is_in_group("zombie"):
		take_damage(10) # Машина получает урон
		if speed_kmh >= 40:
			if body.has_method("die"):
				body.die(linear_velocity, speed_mps)
			shake_camera(0.5)
			hit_stop(0.1)
		elif speed_kmh >= 10:
			if body.has_method("knockdown"):
				body.knockdown(linear_velocity)
		return 

	# 2. СТОЛКНОВЕНИЕ С ОБЪЕКТАМИ (Стены, препятствия)
	if body != self and not body.is_in_group("player") and body.is_in_group("object_hit"):
		if speed_mps > wall_damage_min_speed_mps:
			# Рассчитываем урон: чем выше скорость, тем больше повреждений
			var damage_to_car = speed_mps * collision_damage_multiplier
			take_damage(damage_to_car)
			shake_camera(clamp(damage_to_car * 0.1, 0.2, 1.5))
			
			# Если у объекта есть метод получения урона (например, он должен разрушиться)
			if body.has_method("take_damage"):
				body.take_damage(speed_mps * 2.0) 
			
			print("УДАР ОБ ОБЪЕКТ! Урон машине: ", round(damage_to_car))

func _destroy_car():
	if destroyed: return
	destroyed = true
	print("МАШИНА УНИЧТОЖЕНА!")
	engine_force = 0
	brake = brake_force
	await get_tree().create_timer(3.0).timeout
	get_tree().reload_current_scene()

func shake_camera(amount: float):
	var camera = get_node_or_null("look/Camera3D")
	if camera:
		var tween = create_tween()
		for i in range(5):
			var rand_offset = Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
			tween.tween_property(camera, "h_offset", rand_offset.x, 0.02)
			tween.tween_property(camera, "v_offset", rand_offset.y, 0.02)
		tween.tween_property(camera, "h_offset", 0.0, 0.05)
		tween.tween_property(camera, "v_offset", 0.0, 0.05)
