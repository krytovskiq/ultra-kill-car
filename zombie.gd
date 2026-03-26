extends CharacterBody3D

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4
const RAGDOLL_LAYER := 8
const BONE_CAPSULE_BASIS := Basis(Vector3.RIGHT, PI * 0.5)

@export var move_speed := 5.8
@export var acceleration := 14.0
@export var turn_speed := 12.0
@export var stop_distance := 1.25
@export var gravity := 30.0

@export var animation_idle_speed := 1.1
@export var animation_run_speed := 1.85
@export var floor_snap_force := 0.35
@export var visual_height_offset := 0.0
@export var ground_clearance := 0.02

@export var hit_impulse_scale := 1.2
@export var limb_detach_impulse := 1.9
@export var detach_limbs := true
@export var detach_speed_threshold := 12.0
@export var body_radius := 0.32
@export var body_height := 1.05
@export var hitbox_radius := 0.65
@export var hitbox_height := 1.6
@export var ragdoll_linear_damp := 0.45
@export var ragdoll_angular_damp := 2.4

@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _visual_root: Node3D = $Sketchfab_model
@onready var _mesh_instance: MeshInstance3D = $Sketchfab_model/ce6a336ac9b348a6ab14975772090f1b_fbx/Object_2/RootNode/Object_4/Skeleton3D/Object_7
@onready var _skeleton: Skeleton3D = $Sketchfab_model/ce6a336ac9b348a6ab14975772090f1b_fbx/Object_2/RootNode/Object_4/Skeleton3D
@onready var _bone_sim: PhysicalBoneSimulator3D = $Sketchfab_model/ce6a336ac9b348a6ab14975772090f1b_fbx/Object_2/RootNode/Object_4/Skeleton3D/PhysicalBoneSimulator3D

var _target: Node3D
var _ragdoll_active := false
var _body_collision: CollisionShape3D
var _hitbox: Area3D

func _ready() -> void:
	collision_layer = ZOMBIE_LAYER
	collision_mask = GROUND_LAYER
	floor_snap_length = floor_snap_force

	# Чтобы кости сразу не падали, выключаем их симуляцию
	if _bone_sim != null:
		_bone_sim.active = false
		_setup_bone_collision_shapes()
	_configure_ragdoll_collision(false)

	if _animation_player != null and _animation_player.has_animation("anim"):
		_animation_player.play("anim")
		_animation_player.speed_scale = animation_idle_speed

	if _visual_root != null:
		var visual_position := _visual_root.position
		visual_position.y = visual_height_offset
		_visual_root.position = visual_position
		_align_visual_to_floor()

	_ensure_collision()
	_ensure_hitbox()
	_acquire_target()

func _physics_process(delta: float) -> void:
	if _ragdoll_active:
		return

	if _target == null or not is_instance_valid(_target):
		_acquire_target()
		return

	var to_target := _target.global_position - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance > 0.001:
		var dir := flat / distance
		var desired := Vector3.ZERO
		if distance > stop_distance:
			desired = dir * move_speed
		var accel_t: float = minf(1.0, acceleration * delta)
		velocity.x = lerpf(velocity.x, desired.x, accel_t)
		velocity.z = lerpf(velocity.z, desired.z, accel_t)

		var target_yaw: float = atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(1.0, turn_speed * delta))

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	apply_floor_snap()
	move_and_slide()
	_update_animation(delta)

# Вызывай эту функцию, когда хочешь, чтобы он умер
func die(hit_velocity: Vector3 = Vector3.ZERO, hit_origin: Vector3 = Vector3.ZERO) -> void:
	if _ragdoll_active:
		return
	_ragdoll_active = true

	if _animation_player != null:
		_animation_player.stop()

	# Включаем физику костей
	if _bone_sim != null:
		_bone_sim.active = true
	if _skeleton != null:
		_skeleton.physical_bones_start_simulation()
	_configure_ragdoll_collision(true)

	# Чтобы CharacterBody больше не мешал физике костей
	collision_layer = 0
	collision_mask = 0
	if _body_collision != null:
		_body_collision.disabled = true
	if _hitbox != null:
		_hitbox.monitoring = false
		_hitbox.monitorable = false

	var impulse := hit_velocity * hit_impulse_scale
	var hit_speed: float = hit_velocity.length()
	if impulse.length() < 0.1:
		impulse = -global_transform.basis.z * 6.0

	if _bone_sim != null:
		for child in _bone_sim.get_children():
			if child is PhysicalBone3D:
				var bone := child as PhysicalBone3D
				bone.sleeping = false
				if detach_limbs and hit_speed >= detach_speed_threshold and _is_limb(bone.bone_name):
					bone.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
					bone.apply_impulse(_get_detach_impulse(bone, impulse, hit_origin))
				else:
					bone.apply_impulse(impulse)

func _acquire_target() -> void:
	_target = get_tree().get_first_node_in_group("player") as Node3D
	if _target == null and get_tree().current_scene != null:
		_target = get_tree().current_scene.get_node_or_null("car") as Node3D

func _is_limb(bone_name: String) -> bool:
	if _is_minor_bone(bone_name):
		return false

	return bone_name.find("Arm") != -1 or bone_name.find("ForeArm") != -1 or bone_name.find("Hand") != -1 or bone_name.find("UpLeg") != -1 or bone_name.find("Leg") != -1 or bone_name.find("Foot") != -1

func _ensure_collision() -> void:
	if has_node("CollisionShape3D"):
		_body_collision = $CollisionShape3D
	else:
		_body_collision = CollisionShape3D.new()
		_body_collision.name = "CollisionShape3D"
		add_child(_body_collision)

	var shape := CapsuleShape3D.new()
	shape.radius = body_radius
	shape.height = body_height
	_body_collision.shape = shape
	_body_collision.position = Vector3(0, body_height * 0.5 + body_radius, 0)
	_body_collision.disabled = false

func _ensure_hitbox() -> void:
	if has_node("Hitbox"):
		_hitbox = $Hitbox
	else:
		_hitbox = Area3D.new()
		_hitbox.name = "Hitbox"
		add_child(_hitbox)

	_hitbox.collision_layer = 0
	_hitbox.collision_mask = CAR_LAYER
	_hitbox.monitoring = true
	_hitbox.monitorable = false
	if not _hitbox.body_entered.is_connected(_on_hitbox_body_entered):
		_hitbox.body_entered.connect(_on_hitbox_body_entered)

	var shape_node: CollisionShape3D
	if _hitbox.has_node("CollisionShape3D"):
		shape_node = _hitbox.get_node("CollisionShape3D") as CollisionShape3D
	else:
		shape_node = CollisionShape3D.new()
		shape_node.name = "CollisionShape3D"
		_hitbox.add_child(shape_node)

	var area_shape := CapsuleShape3D.new()
	area_shape.radius = hitbox_radius
	area_shape.height = hitbox_height
	shape_node.shape = area_shape
	shape_node.position = Vector3(0, hitbox_height * 0.5 + hitbox_radius, 0)

func _configure_ragdoll_collision(enabled: bool) -> void:
	if _bone_sim == null:
		return

	for child in _bone_sim.get_children():
		if child is PhysicalBone3D:
			var bone := child as PhysicalBone3D
			if enabled:
				_configure_ragdoll_bone(bone)
			else:
				bone.collision_layer = 0
				bone.collision_mask = 0

func _on_hitbox_body_entered(body: Node3D) -> void:
	if _ragdoll_active:
		return
	if body == null or not body.is_in_group("player"):
		return

	var hit_velocity := Vector3.ZERO
	if body is VehicleBody3D:
		hit_velocity = (body as VehicleBody3D).linear_velocity
	die(hit_velocity, body.global_position)

func _update_animation(delta: float) -> void:
	if _animation_player == null:
		return

	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var normalized_speed := clampf(horizontal_speed / maxf(move_speed, 0.01), 0.0, 1.0)
	var target_speed := lerpf(animation_idle_speed, animation_run_speed, normalized_speed)
	_animation_player.speed_scale = lerpf(_animation_player.speed_scale, target_speed, minf(1.0, delta * 8.0))

func _configure_ragdoll_bone(bone: PhysicalBone3D) -> void:
	var shape_node := _get_bone_shape_node(bone)
	if _should_disable_bone_collision(bone.bone_name):
		bone.collision_layer = 0
		bone.collision_mask = 0
		if shape_node != null:
			shape_node.disabled = true
	else:
		bone.collision_layer = RAGDOLL_LAYER
		bone.collision_mask = GROUND_LAYER
		if shape_node != null:
			shape_node.disabled = false

	bone.mass = _get_bone_mass(bone.bone_name)
	bone.linear_damp = ragdoll_linear_damp
	bone.angular_damp = ragdoll_angular_damp

func _get_bone_mass(bone_name: String) -> float:
	if bone_name.find("Hips") != -1 or bone_name.find("Spine") != -1:
		return 0.32
	if bone_name.find("Head") != -1 or bone_name.find("Neck") != -1:
		return 0.2
	if bone_name.find("UpLeg") != -1 or bone_name.find("Leg") != -1:
		return 0.24
	if bone_name.find("Shoulder") != -1 or bone_name.find("Arm") != -1 or bone_name.find("ForeArm") != -1:
		return 0.18
	return 0.12

func _is_minor_bone(bone_name: String) -> bool:
	return bone_name.find("Index") != -1 or bone_name.find("Thumb") != -1 or bone_name.find("Middle") != -1 or bone_name.find("Ring") != -1 or bone_name.find("Pinky") != -1 or bone_name.find("Toe") != -1

func _should_disable_bone_collision(bone_name: String) -> bool:
	if bone_name == "_rootJoint":
		return true
	if _is_minor_bone(bone_name):
		return true
	return bone_name.find("Shoulder") != -1 or bone_name.find("Neck") != -1 or bone_name.find("Hand") != -1

func _setup_bone_collision_shapes() -> void:
	if _bone_sim == null:
		return

	for child in _bone_sim.get_children():
		if child is not PhysicalBone3D:
			continue

		var bone := child as PhysicalBone3D
		var shape_node := _get_bone_shape_node(bone)
		if shape_node == null:
			continue

		if _should_disable_bone_collision(bone.bone_name):
			shape_node.disabled = true
			continue

		shape_node.shape = _create_bone_shape(bone.bone_name)
		shape_node.transform = _get_bone_shape_transform(bone.bone_name)
		shape_node.disabled = false

func _get_bone_shape_node(bone: PhysicalBone3D) -> CollisionShape3D:
	if bone == null:
		return null
	return bone.get_node_or_null("CollisionShape3D") as CollisionShape3D

func _create_bone_shape(bone_name: String) -> Shape3D:
	if bone_name.find("Foot") != -1:
		var foot_shape := BoxShape3D.new()
		foot_shape.size = Vector3(5.2, 3.2, 9.5)
		return foot_shape

	var shape := CapsuleShape3D.new()
	if bone_name.find("Hips") != -1:
		shape.radius = 4.0
		shape.height = 12.0
	elif bone_name.find("Spine2") != -1:
		shape.radius = 3.4
		shape.height = 11.0
	elif bone_name.find("Spine1") != -1:
		shape.radius = 3.1
		shape.height = 10.0
	elif bone_name.find("Spine") != -1:
		shape.radius = 2.8
		shape.height = 8.0
	elif bone_name.find("Head") != -1:
		shape.radius = 4.2
		shape.height = 5.0
	elif bone_name.find("UpLeg") != -1:
		shape.radius = 3.1
		shape.height = 20.0
	elif bone_name.find("Leg") != -1:
		shape.radius = 2.7
		shape.height = 18.0
	elif bone_name.find("ForeArm") != -1:
		shape.radius = 2.1
		shape.height = 14.0
	elif bone_name.find("Arm") != -1:
		shape.radius = 2.4
		shape.height = 15.0
	else:
		shape.radius = 2.5
		shape.height = 10.0

	return shape

func _get_bone_shape_transform(bone_name: String) -> Transform3D:
	if bone_name.find("Foot") != -1:
		return Transform3D(BONE_CAPSULE_BASIS, Vector3(0.0, 0.0, 1.8))
	if bone_name.find("UpLeg") != -1:
		return Transform3D(BONE_CAPSULE_BASIS, Vector3(0.0, 0.0, 1.4))
	if bone_name.find("Leg") != -1:
		return Transform3D(BONE_CAPSULE_BASIS, Vector3(0.0, 0.0, 3.2))
	if bone_name.find("Arm") != -1 or bone_name.find("ForeArm") != -1:
		return Transform3D(BONE_CAPSULE_BASIS, Vector3.ZERO)
	if bone_name.find("Head") != -1:
		return Transform3D(BONE_CAPSULE_BASIS, Vector3(0.0, 0.0, 0.8))
	return Transform3D(BONE_CAPSULE_BASIS, Vector3.ZERO)

func _get_detach_impulse(bone: PhysicalBone3D, base_impulse: Vector3, hit_origin: Vector3) -> Vector3:
	var outward := bone.global_position - hit_origin
	if outward.length() <= 0.01:
		outward = bone.global_position - global_position
	if outward.length() > 0.01:
		outward = outward.normalized()
	else:
		outward = Vector3.UP

	var upward_boost := Vector3.UP * maxf(2.0, base_impulse.length() * 0.2)
	var side_burst := outward * maxf(3.0, base_impulse.length() * 0.45)
	return base_impulse * limb_detach_impulse + side_burst + upward_boost

func _align_visual_to_floor() -> void:
	if _visual_root == null or _mesh_instance == null:
		return

	var mesh_aabb := _mesh_instance.get_aabb()
	var mesh_to_root := global_transform.affine_inverse() * _mesh_instance.global_transform
	var min_y := INF

	for corner in _get_aabb_corners(mesh_aabb):
		var local_corner := mesh_to_root * corner
		min_y = minf(min_y, local_corner.y)

	if is_inf(min_y):
		return

	var visual_position := _visual_root.position
	visual_position.y += ground_clearance - min_y
	_visual_root.position = visual_position

func _get_aabb_corners(box: AABB) -> Array[Vector3]:
	var position := box.position
	var size := box.size

	return [
		position,
		position + Vector3(size.x, 0.0, 0.0),
		position + Vector3(0.0, size.y, 0.0),
		position + Vector3(0.0, 0.0, size.z),
		position + Vector3(size.x, size.y, 0.0),
		position + Vector3(size.x, 0.0, size.z),
		position + Vector3(0.0, size.y, size.z),
		position + size,
	]
