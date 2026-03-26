extends VehicleBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2

@export var STEER_SPEED = 1.5
@export var STEER_LIMIT = 0.6
var steer_target := 0.0
@export var engine_force_value = 40

func _ready() -> void:
	add_to_group("player")
	collision_layer = CAR_LAYER
	collision_mask = GROUND_LAYER


func _physics_process(delta: float) -> void:
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

	if Input.is_action_pressed("ui_select"):
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
	# Если врезались в кого-то, у кого есть функция die
	if body.has_method("die"):
		# Передаем вектор скорости машины, чтобы зомби отлетел по направлению движения
		body.die(linear_velocity)
