extends VehicleBody3D

var total_distance: float = 0.0
var start_z_position: float = 0.0
var lights_tween: Tween

@export_group("Driving")
@export var STEER_SPEED: float = 1.5
@export var STEER_LIMIT: float = 0.3
@export var engine_force_value: int = 5000
@export var brake_force: float = 160.0
@export var handbrake_force: float = 90.0
@export var MAX_SPEED_KMH: int = 110

@export_group("Health")
@export var health: int = 100
@export_group("Driving")
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
@export var max_fuel: int = 1000
@export_group("Fuel")
@export var fuel_consumption: float = 1.0
var current_fuel: float = 0.0
var current_hp: int = 0
var destroyed: bool = false

@export_group("Enemy Damage")
@export var damage_per_second: int = 10
var damage_timer: float = 0.0

# --- ПРОСТЫЕ НАСТРОЙКИ ПУШКИ ---
@onready var base_gun: Node3D = $"Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun"
var target_zombie: Node3D = null
var can_shoot: bool = true
# -------------------------------

func _ready() -> void:
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
	center_of_mass = Vector3(0, -0.2, 0)
	if has_node("Hud/HpBar"):
		$Hud/HpBar.max_value = health
		$Hud/HpBar.value = current_hp
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.max_value = max_fuel
		$Hud/FuelBar.value = current_fuel

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	# --- ПРОСТАЯ ЛОГИКА ПУШКИ ---
	_find_zombie_target() 
	if is_instance_valid(target_zombie):
		# 1. Вычисляем позицию зомби относительно БТР
		var local_target_pos = base_gun.to_local(target_zombie.global_position)
		
		# 2. Считаем чистый угол поворота по горизонтали
		var target_angle_y = atan2(local_target_pos.x, local_target_pos.z)
		
		# 3. ОГРАНИЧЕНИЕ: Переводим 70 градусов в радианы и зажимаем угол лимитом
		var limit_radians = deg_to_rad(70.0)
		target_angle_y = clamp(target_angle_y, -limit_radians, limit_radians)
		
		# 4. Плавно поворачиваем пушку в пределах разрешенного угла
		base_gun.rotate_y(target_angle_y * STEER_SPEED * delta)
		
		# Если нажали ПРОБЕЛ и пушка готова — уничтожаем зомби
		if Input.is_key_pressed(KEY_SPACE) and can_shoot:
			_shoot_zombie()
	# -----------------------------

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
			if body.is_in_group("zombie") and body.get("state") != 3: 
				has_zombie = true
				break 

		if has_zombie:
			damage_timer += delta
			if damage_timer >= 1.0: 
				take_damage(damage_per_second)
				damage_timer = 0.0
		else:
			damage_timer = 0.0

# --- ВСЕГО ДВЕ КОРОТКИЕ ФУНКЦИИ ДЛЯ СТРЕЛЬБЫ ---

# Ищем ближайшего живого зомби на всей карте
func _find_zombie_target() -> void:
	var zombies = get_tree().get_nodes_in_group("zombie")
	var closest: Node3D = null
	var min_dist = 40.0 # Дистанция атаки пушки БТР
	
	for z in zombies:
		if is_instance_valid(z) and z.get("state") != 3:
			var dist = global_position.distance_to(z.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = z
	target_zombie = closest

# Логика мгновенного убийства на пробел
# Логика мгновенного убийства на пробел с эффектом шейдера
func _shoot_zombie() -> void:
	can_shoot = false
	print("БТР произвел выстрел скоростным трассером!")
	
	# Находим наш снаряд-эффект
	var tracer = get_node_or_null("Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun/Gun_Effect")
	
	if tracer:
		# 1. Возвращаем снаряд в исходную точку у дула пушки
		tracer.position = Vector3.ZERO 
		tracer.visible = true
		
		# 2. Создаем сверхбыструю анимацию полета (Tween)
		var tween = create_tween()
		
		# За 60 миллисекунд (0.06 сек) двигаем снаряд вперед по локальной оси Z на 60 метров
		# Убедитесь, какая ось у вас смотрит вперед (если X или Y, замените "position:z")
		tween.tween_property(tracer, "position:z", -60.0, 0.06)
		
		# Как только анимация полета завершилась — прячем снаряд обратно
		tween.finished.connect(func(): tracer.visible = false)
	
	# Зомби мгновенно погибает от выстрела
	if target_zombie.has_method("die"):
		target_zombie.die(linear_velocity, 50.0)
	else:
		target_zombie.queue_free()
		
	# Кулдаун между выстрелами игрока (0.3 секунды)
	await get_tree().create_timer(0.3).timeout
	can_shoot = true
# -----------------------------------------------

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

	if body.is_in_group("zombie"):
		take_damage(2)
		if speed_kmh >= 40:
			if body.has_method("die"):
				body.die(linear_velocity, speed_mps)
			shake_camera(0.5)
			hit_stop(0.1)
		elif speed_kmh >= 10:
			if body.has_method("knockdown"):
				body.knockdown(linear_velocity)
		return 

	if body != self and not body.is_in_group("player") and body.is_in_group("object_hit"):
		if speed_mps > wall_damage_min_speed_mps:
			var damage_to_car = speed_mps * collision_damage_multiplier
			take_damage(damage_to_car)
			shake_camera(clamp(damage_to_car * 0.1, 0.2, 1.5))
			
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
			tween.tween_property(camera, "h_offset", rand_offset.x, 0.003)
			tween.tween_property(camera, "v_offset", rand_offset.y, 0.003)
		tween.tween_property(camera, "h_offset", 0.0, 0.003)
		tween.tween_property(camera, "v_offset", 0.0, 0.003)
