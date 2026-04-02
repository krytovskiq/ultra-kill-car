extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4

@export_group("Driving")
@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target := 0.0
@export var engine_force_value = 40

@export_group("Health")
@export var max_hp: float = 260.0
@export var collision_damage_multiplier: float = 0.35

@export_group("Zombie Collision")
@export var zombie_hit_min_speed_mps: float = 0.8
@export var zombie_hit_max_speed_mps: float = 24.0
@export var zombie_damage_at_min_speed: float = 8.0
@export var zombie_damage_at_max_speed: float = 120.0
@export var zombie_impulse_at_min_speed: float = 5.0
@export var zombie_impulse_at_max_speed: float = 28.0
@export var zombie_upward_impulse: float = 2.2
@export var wall_damage_min_speed_mps: float = 20.0

@export_group("UI")
@export var show_hp_ui: bool = true

var current_hp: float = 0.0
var destroyed: bool = false

@onready var hp_control: Control = $Hud/HPControl
@onready var hp_bar: ProgressBar = $Hud/HPControl/HPBar
@onready var hp_text: Label = $Hud/HPControl/HPText

func _ready() -> void:
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER | ZOMBIE_LAYER
	contact_monitor = true
	max_contacts_reported = 24
	current_hp = max_hp
	_setup_hp_ui()
	_update_hp_ui()


func _physics_process(delta: float) -> void:
	if destroyed:
		engine_force = 0.0
		brake = 2.0
		traction(linear_velocity.length())
		return

	var speed: float = linear_velocity.length()
	traction(speed)
	$Hud/speed.text = str(round(speed * 3.6)) + "  KM/H"

	var fwd_mps: float = transform.basis.x.x
	steer_target = Input.get_action_strength("A") - Input.get_action_strength("D")
	steer_target *= STEER_LIMIT
	if Input.is_action_pressed("S"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		if speed < 20 and speed != 0:
			engine_force = clamp(engine_force_value * 3 / speed, 0, 300)
		else:
			engine_force = engine_force_value
	else:
		engine_force = 0
	if Input.is_action_pressed("W"):
		# Increase engine force at low speeds to make the initial acceleration faster.
		if fwd_mps >= -1:
			if speed < 30 and speed != 0:
				engine_force = -clamp(engine_force_value * 10 / speed, 0, 300)
			else:
				engine_force = -engine_force_value
		else:
			brake = 1
	else:
		brake = 0.0

	if Input.is_action_pressed("S"):
		brake = 3
		$wheal2.wheel_friction_slip = 0.8
		$wheal3.wheel_friction_slip = 0.8
	else:
		$wheal2.wheel_friction_slip = 3
		$wheal3.wheel_friction_slip = 3
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


func traction(speed: float) -> void:
	apply_central_force(Vector3.DOWN * speed)


func _on_body_entered(body: Node) -> void:
	if destroyed:
		return

	var impact_speed := linear_velocity.length()
	if impact_speed < 1.0:
		return

	if body.has_method("die"):
		if impact_speed < zombie_hit_min_speed_mps:
			return

		var speed_factor := inverse_lerp(zombie_hit_min_speed_mps, zombie_hit_max_speed_mps, impact_speed)
		speed_factor = clampf(speed_factor, 0.0, 1.0)
		var impact_damage := lerpf(zombie_damage_at_min_speed, zombie_damage_at_max_speed, speed_factor)
		var impulse_strength := lerpf(zombie_impulse_at_min_speed, zombie_impulse_at_max_speed, speed_factor)
		var impulse := _get_hit_direction(body) * impulse_strength
		impulse.y = maxf(impulse.y, zombie_upward_impulse)

		if body.has_method("take_damage"):
			body.take_damage(impact_damage, impulse)
		return

	if body is StaticBody3D and impact_speed > wall_damage_min_speed_mps:
		var hit_damage := (impact_speed - wall_damage_min_speed_mps) * collision_damage_multiplier
		take_damage(hit_damage)


func take_damage(amount: float) -> void:
	if destroyed:
		return
	if amount <= 0.0:
		return

	current_hp = maxf(current_hp - amount, 0.0)
	_update_hp_ui()
	if current_hp <= 0.0:
		_destroy_car()


func hit(amount: float) -> void:
	take_damage(amount)


func _destroy_car() -> void:
	if destroyed:
		return
	destroyed = true
	engine_force = 0.0
	brake = 3.0
	_spawn_flash(global_position + Vector3.UP * 1.0, Color(1.0, 0.25, 0.1), 2.0)
	_update_hp_ui()


func _setup_hp_ui() -> void:
	if hp_control == null or hp_bar == null or hp_text == null:
		return

	hp_control.visible = show_hp_ui
	hp_bar.min_value = 0.0
	hp_bar.max_value = max_hp


func _update_hp_ui() -> void:
	if hp_control == null or hp_bar == null or hp_text == null:
		return

	hp_control.visible = show_hp_ui
	if not show_hp_ui:
		return

	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_text.text = "HP: %d / %d" % [roundi(current_hp), roundi(max_hp)]


func _spawn_flash(position: Vector3, color: Color, size: float) -> void:
	var pulse := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.45 * size
	pulse.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	pulse.material_override = mat

	pulse.transparency = 0.0
	pulse.global_position = position
	get_tree().current_scene.add_child(pulse)

	var tween := get_tree().create_tween()
	tween.tween_property(pulse, "scale", Vector3.ONE * (3.2 * size), 0.35).from(Vector3.ONE * (0.15 * size))
	tween.parallel().tween_property(pulse, "transparency", 1.0, 0.35)
	tween.finished.connect(Callable(pulse, "queue_free"))


func _get_hit_direction(body: Node) -> Vector3:
	var car_dir := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if car_dir.length() > 0.2:
		car_dir = car_dir.normalized()
	else:
		car_dir = -global_transform.basis.z
		car_dir.y = 0.0
		car_dir = car_dir.normalized()

	var to_target := car_dir
	if body is Node3D:
		var body_node := body as Node3D
		to_target = body_node.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.01:
			to_target = to_target.normalized()
		else:
			to_target = car_dir

	var result := (to_target + car_dir * 0.6).normalized()
	if result == Vector3.ZERO:
		return car_dir
	return result
