extends Camera3D


@export var target_distance := 6.5
@export var target_height := 1.5
@export var look_ahead := 1.6
@export var speed := 6.5
var follow_this: Node3D
var last_lookat: Vector3 = Vector3.ZERO

func _ready() -> void:
	follow_this = get_parent() as Node3D
	if follow_this == null:
		return

	global_position = _get_target_position()
	last_lookat = _get_look_target()

func _physics_process(delta: float) -> void:
	if follow_this == null:
		return

	var weight: float = minf(1.0, delta * speed)
	global_position = global_position.lerp(_get_target_position(), weight)
	last_lookat = last_lookat.lerp(_get_look_target(), weight)
	look_at(last_lookat, Vector3.UP)

func _get_target_position() -> Vector3:
	return follow_this.global_transform.origin + follow_this.global_transform.basis.z * target_distance + Vector3.UP * target_height

func _get_look_target() -> Vector3:
	return follow_this.global_transform.origin - follow_this.global_transform.basis.z * look_ahead + Vector3.UP
