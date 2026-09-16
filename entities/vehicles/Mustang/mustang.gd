extends VehicleBody3D

var total_distance: float = 0.0
var start_z_position: float = 0.0

@export_group("Driving")
@export var STEER_SPEED: float = 2.5
@export var STEER_LIMIT: float = 0.35
@export var engine_force_value: int = 7500
@export var brake_force: float = 90.0
@export var MAX_SPEED_KMH: int = 220

@export_group("Health")
@export var health: int = 10000
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision")
@export var wall_damage_min_speed_mps: float = 5.0
@export var crash_death_speed_mps: float = 20.0

@export_group("Fuel")
@export var max_fuel: int = 100
@export var fuel_consumption: float = 1.0

@export var DeadParticles: PackedScene

var current_fuel: float = 0.0
var current_hp: int = 0
var destroyed: bool = false
var death_shader = preload("res://entities/vehicles/Death_shader.gdshader")
@export_group("Enemy Damage")
@export var damage_per_second: int = 10
var damage_timer: float = 0.0

var _tire_smokes: Array[CPUParticles3D] = []
var _exhaust: CPUParticles3D = null

func _ready() -> void:
	mass = 1500.0
	var kill_zone = get_node_or_null("Area3D")
	if kill_zone:
		kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	else:
		push_error("Main: Узел Area3D не найден внутри машины!")

	start_z_position = global_position.z
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

	# --- VFX Setup ---
	_exhaust = CarVFX.create_exhaust(self, Vector3(-0.4, 0.15, 1.4))
	for wheel in get_children():
		if wheel is VehicleWheel3D and not wheel.use_as_steering:
			var smoke = CarVFX.create_tire_smoke(wheel, Vector3(0, -wheel.wheel_radius, 0))
			_tire_smokes.append(smoke)

func _physics_process(delta: float) -> void:
	if destroyed: return
	
	total_distance = absf(global_position.z - start_z_position)
	if has_node("Hud/Metr"):
		var _m = get_node_or_null("Hud/Metr")
		if is_instance_valid(_m): _m.text = str(round(total_distance)) + " M"
		
	var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)
	var speed_mps: float = horizontal_vel.length()
	var speed_kmh: int = int(speed_mps * 1.8)
	
	if has_node("Hud/speed"):
		var _s = get_node_or_null("Hud/speed")
		if is_instance_valid(_s): _s.text = str(speed_kmh) + "  KM/H"
	
	# Управление двигателем (W)
	if Input.is_action_pressed("W"):
		engine_force = -engine_force_value if speed_kmh < MAX_SPEED_KMH else 0.0
		brake = 0.0
	else:
		engine_force = 0.0
		
	# Тормоз и задний ход (S)
	var min_speed_kmh: int = 25
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
		var _p = get_node_or_null("Hud/Pause")
		if is_instance_valid(_p): _p.visible = get_tree().paused

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
		brake = brake_force * 3.0
	
	if has_node("Hud/FuelBar"):
		$Hud/FuelBar.value = current_fuel


	# --- Tire Smoke ---
	var is_drifting = absf(steering) > 0.15 and speed_kmh > 30
	var is_braking = Input.is_action_pressed("S") and speed_kmh > 40
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.emitting = is_drifting or is_braking

	_handle_zombie_overlapping_damage(delta)

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

func _handle_zombie_overlapping_damage(_delta: float) -> void:
	pass

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if destroyed: return
	var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)
	var speed_mps := horizontal_vel.length()
	var speed_kmh := speed_mps * 3.6 
	if body.is_in_group("dead_wall"):
		if speed_mps >= crash_death_speed_mps:
			take_damage(current_hp) 
			shake_camera(clampf(speed_mps / 10.0, 1.0, 4.0))
			CarVFX.spawn_impact(global_position, "dust")
			return
			
	if body.is_in_group("zombie"):
		CarVFX.spawn_impact(body.global_position + Vector3.UP, "blood")
		take_damage(10) 
		if speed_kmh >= 40.0:
			if body.has_method("die"):
				body.die(linear_velocity, speed_mps)
			shake_camera(clampf(speed_mps / 50.0, 0.05, 0.3))
		elif speed_kmh >= 10.0:
			if body.has_method("knockdown"):
				body.knockdown(linear_velocity)
		return 

	if body != self and not body.is_in_group("player") and body.is_in_group("object_hit"):
		if speed_mps > wall_damage_min_speed_mps:
			var damage_to_car := int(speed_mps * collision_damage_multiplier)
			take_damage(damage_to_car)
			shake_camera(clampf(float(damage_to_car) * 0.1, 0.2, 1.5))
			CarVFX.spawn_impact(body.global_position + Vector3.UP * 0.5, "sparks")
			if body.has_method("take_damage"):
				body.take_damage(speed_mps * 2.0) 
				
	else:
		# Любое другое столкновение — искры
		if speed_mps > 3.0:
			CarVFX.spawn_impact(body.global_position + Vector3.UP * 0.3, "sparks")

func _destroy_car() -> void:
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
	
	await get_tree().create_timer(0.4).timeout
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://ui/menu.tscn")
	
func shake_camera(amount: float) -> void:
	var camera = get_node_or_null("look/Camera3D")
	if not camera: return
	if camera.has_method("add_shake"):
		camera.add_shake(amount)
