extends VehicleBody3D

var total_distance: float = 0.0
var start_z_position: float = 0.0

@export_group("Driving")
@export var STEER_SPEED: float = 2.8
@export var STEER_LIMIT: float = 0.40
@export var engine_force_value: int = 5500
@export var brake_force: float = 90.0
@export var MAX_SPEED_KMH: int = 280

@export_group("Health")
@export var health: int = 100
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision")
@export var wall_damage_min_speed_mps: float = 5.0
@export var crash_death_speed_mps: float = 25.0

@export_group("Fuel")
@export var max_fuel: int = 100
@export var fuel_consumption: float = 1.0

@export var DeadParticles: PackedScene

var current_fuel: float = 0.0
var current_hp: int = 0
var destroyed: bool = false
var death_shader = preload("res://cars/Death_shader.gdshader")
@export_group("Enemy Damage")
@export var damage_per_second: int = 10
var damage_timer: float = 0.0
var cleanup_timer: float = 0.0 # Таймер для очистки отставших зомби

func _ready() -> void:
	var kill_zone = get_node_or_null("Area3D")
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	else:
		push_error("Main: Узел Area3D не найден внутри машины!")

	start_z_position = global_position.z
	linear_velocity = -global_transform.basis.z * (20.0 / 3.6)
	add_to_group("player")
	
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = health
	current_fuel = max_fuel
	
	if has_node("Hud/HpBar"):
		$Hud/HpBar.max_value = health
		$Hud/HpBar.value = current_hp
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.max_value = max_fuel
		$Hud/FuelBar.value = current_fuel

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	total_distance = absf(global_position.z - start_z_position)
	if has_node("Hud/Metr"):
		$Hud/Metr.text = str(round(total_distance)) + " M"
		
	var speed_mps: float = linear_velocity.length()
	var speed_kmh: int = floori(speed_mps * 2.6)
	
	if has_node("Hud/speed"):
		$Hud/speed.text = str(speed_kmh) + "  KM/H"
	
	# Управление двигателем (W)
	if Input.is_action_pressed("W"):
		engine_force = -engine_force_value if speed_kmh < MAX_SPEED_KMH else 0.0
		brake = 0.0
	else:
		engine_force = 0.0
		
	# Тормоз и задний ход (S)
	var min_speed_kmh: int = 25
	if Input.is_action_just_pressed("ui_accessibility_drag_and_drop"):
		brake_force > max_fuel
	if Input.is_action_pressed("S"):
		if speed_kmh > min_speed_kmh:
			brake = brake_force
			engine_force = 0.0
		else:
			brake = 0.0
			engine_force = -(engine_force_value * 0.2)
	elif not Input.is_key_pressed(KEY_W) and speed_kmh < min_speed_kmh:
		brake = 0.0
		engine_force = -(engine_force_value * 0.3)
	if Input.is_key_pressed(KEY_ESCAPE) and not destroyed:
		get_tree().paused = !get_tree().paused
		$Hud/Pause.visible = get_tree().paused

	# Плавное динамическое рулевое управление
	var steer_input := Input.get_axis("D", "A") 
	var speed_ratio := clampf(float(speed_kmh) / float(MAX_SPEED_KMH), 0.0, 1.0)
	var dynamic_steer_limit: float = STEER_LIMIT * lerp(1.0, 0.25, speed_ratio)
	var steer_target: float = steer_input * dynamic_steer_limit
	var dynamic_steer_speed: float = STEER_SPEED * lerp(1.0, 0.3, speed_ratio)
	
	# ИСПРАВЛЕНО: Теперь используется dynamic_steer_speed вместо константы
	steering = move_toward(steering, steer_target, dynamic_steer_speed * delta)
	
	_apply_traction(speed_mps)
	
	if speed_mps > 0.1:
		current_fuel = maxf(current_fuel - fuel_consumption * delta, 0.0)
	
	if current_fuel <= 0.0:
		engine_force = 0.0
	
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.value = current_fuel
		
	_handle_zombie_overlapping_damage(delta)
	_cleanup_distant_zombies(delta)

func refuel(amount: float) -> void:
	current_fuel = clampf(current_fuel + amount, 0.0, float(max_fuel))

func _apply_traction(speed: float) -> void:
	var downforce := clampf(speed * 10.0, 0.0, 8000.0)
	apply_central_force(Vector3.DOWN * downforce)

func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration * 0.1, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: int) -> void:
	if destroyed: return
	current_hp = maxi(current_hp - amount, 0)
	if has_node("Hud/HpBar"):
		$Hud/HpBar.value = current_hp
	if current_hp <= 0: 
		_destroy_car()

func _handle_zombie_overlapping_damage(delta: float) -> void:
	var kill_zone = get_node_or_null("Area3D")
	if not kill_zone: return
	
	var bodies: Array[Node3D] = kill_zone.get_overlapping_bodies()
	var has_active_zombie := false
	
	for body in bodies:
		if body.is_in_group("zombie") and body.get("state") != 3: 
			has_active_zombie = true
			break 

	if has_active_zombie:
		damage_timer += delta
		if damage_timer >= 1.0:
			take_damage(damage_per_second)
			damage_timer = 0.0
	else:
		damage_timer = 0.0

func _cleanup_distant_zombies(delta: float) -> void:
	cleanup_timer += delta
	if cleanup_timer < 1.5: return
	cleanup_timer = 0.0
	
	var all_zombies: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("zombie"):
		if node is Node3D:
			all_zombies.append(node)
			
	for zombie in all_zombies:
		if is_instance_valid(zombie):
			var main_node = get_tree().current_scene
			if main_node and "_forward" in main_node:
				var forward_vector: Vector3 = main_node._forward
				var rel_pos = zombie.global_position - global_position
				var dist_along_forward = rel_pos.dot(forward_vector)
				if dist_along_forward < -40.0 and zombie.get("state") != 3:
					zombie.queue_free()

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if destroyed: return
	var speed_mps := linear_velocity.length()
	var speed_kmh := speed_mps * 3.6 
	if body.is_in_group("dead_wall"):
		if speed_mps >= crash_death_speed_mps:
			take_damage(current_hp) 
			shake_camera(2.0)
			return
			
	if body.is_in_group("zombie"):
		take_damage(10) 
		if speed_kmh >= 40.0:
			if body.has_method("die"):
				body.die(linear_velocity, speed_mps)
			shake_camera(0.5)
			hit_stop(0.1)
		elif speed_kmh >= 10.0:
			if body.has_method("knockdown"):
				body.knockdown(linear_velocity)
		return 

	if body != self and not body.is_in_group("player") and body.is_in_group("object_hit"):
		if speed_mps > wall_damage_min_speed_mps:
			var damage_to_car := int(speed_mps * collision_damage_multiplier)
			take_damage(damage_to_car)
			shake_camera(clampf(float(damage_to_car) * 0.1, 0.2, 1.5))
			if body.has_method("take_damage"):
				body.take_damage(speed_mps * 2.0) 
				
func _destroy_car() -> void:
	if DeadParticles:
		var Dead = DeadParticles.instantiate() as CPUParticles3D
		get_tree().current_scene.add_child(Dead)
		Dead.global_position = global_position
	if DeadParticles:
		var Dead = DeadParticles.instantiate() as CPUParticles3D
		get_tree().current_scene.add_child(Dead)
		Dead.global_position = global_position
		
		Dead.lifetime = 1.0 
		Dead.anim_speed_min = 2.0
		Dead.anim_speed_max = 2.5
		Dead.emitting = true
		Dead.restart()
	apply_central_impulse(Vector3(0, 13000.0, 0))
	if has_node("Hud/ColorRect"):
		var effect_rect = $Hud/ColorRect as ColorRect
		effect_rect.show()
		var mat = effect_rect.material as ShaderMaterial
		var tween_blood = create_tween()
		tween_blood.tween_property(mat, "shader_parameter/effect_strength", 1.0, 0.0)
		var tween_time = create_tween()
		tween_time.tween_property(Engine, "time_scale", 0.1, 0.2).set_trans(Tween.TRANS_SINE)
	
	await get_tree().create_timer(1.0).timeout
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
	
func shake_camera(amount: float) -> void:
	var camera = get_node_or_null("look/Camera3D")
	if not camera: return
	
	var tween := create_tween()
	for i in range(5):
		var rand_offset := Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
		tween.tween_property(camera, "h_offset", rand_offset.x, 0.02)
		tween.tween_property(camera, "v_offset", rand_offset.y, 0.02)
	tween.tween_property(camera, "h_offset", 0.0, 0.05)
	tween.tween_property(camera, "v_offset", 0.0, 0.05)
