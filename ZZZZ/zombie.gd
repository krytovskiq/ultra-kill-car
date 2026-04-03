extends CharacterBody3D

enum ZombieState {
	IDLE,
	CHASE,
	ATTACK,
	DEAD
}

const CAR_LAYER := 1
const GROUND_LAYER := 2
const ZOMBIE_LAYER := 4

@export var speed: float = 14.0
@export var damage: float = 15.0
@export var player_path: NodePath
@export var max_hp: float = 50.0
@export var detection_radius: float = 32.0
@export var lose_target_radius: float = 45.0
@export var attack_range: float = 2.8
@export var attack_cooldown: float = 1.3
@export var death_lifetime: float = 3.5
@export var hit_knockback_multiplier: float = 1.0
@export var hit_knockback_min_upward: float = 0.8

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area3D = $Hit
@onready var root_collider: CollisionShape3D = $RootCollider

var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state: ZombieState = ZombieState.IDLE
var current_hp: float = 0.0
var attack_timer: float = 0.0
var attack_time_left: float = 0.0
var attack_hit_time: float = 0.0
var attack_has_landed: bool = false
var death_timer: float = 0.0
var death_velocity: Vector3 = Vector3.ZERO
var hit_stun_timer: float = 0.0


func _ready() -> void:
	add_to_group("zombie")
	collision_layer = ZOMBIE_LAYER
	collision_mask = GROUND_LAYER | CAR_LAYER
	floor_snap_length = 1.0
	current_hp = max_hp

	if player_path and has_node(player_path):
		player = get_node(player_path) as Node3D
	else:
		player = get_tree().get_first_node_in_group("player") as Node3D

	play_anim("Idle")


func set_player(target: Node3D) -> void:
	player = target


func set_spawn_position(pos: Vector3) -> void:
	if state == ZombieState.IDLE:
		global_position = pos


func _physics_process(delta: float) -> void:
	if attack_timer > 0.0:
		attack_timer -= delta
	if hit_stun_timer > 0.0:
		hit_stun_timer -= delta

	if state == ZombieState.DEAD:
		_process_dead(delta)
		return

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	_apply_gravity(delta)
	_update_state()

	match state:
		ZombieState.IDLE:
			_process_idle(delta)
		ZombieState.CHASE:
			_process_chase(delta)
		ZombieState.ATTACK:
			_process_attack(delta)

	var previous_pos := global_position
	move_and_slide()
	if state == ZombieState.CHASE:
		var moved := global_position.distance_to(previous_pos)
		if moved < 0.001:
			var push := Vector3(velocity.x, 0.0, velocity.z) * delta * 0.7
			if push.length() > 0.0:
				global_position += push


func _update_state() -> void:
	if player == null or not is_instance_valid(player):
		state = ZombieState.IDLE
		return

	if state == ZombieState.ATTACK:
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player <= attack_range and attack_timer <= 0.0 and hit_stun_timer <= 0.0:
		_start_attack()
		return

	if distance_to_player <= detection_radius or (state == ZombieState.CHASE and distance_to_player <= lose_target_radius):
		state = ZombieState.CHASE
		return

	state = ZombieState.IDLE


func _process_idle(delta: float) -> void:
	play_anim("Idle")
	velocity.x = move_toward(velocity.x, 0.0, speed * 2.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, speed * 2.0 * delta)


func _process_chase(delta: float) -> void:
	if player == null:
		return
	play_anim("Run")

	var target_pos := player.global_position
	target_pos.y = global_position.y
	var direction := (target_pos - global_position)
	if direction.length() <= 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	direction = direction.normalized()
	# При масштабе зомби 0.02 иногда физика дает "бег на месте", поэтому чуть поднимаем силу.
	var chase_speed := speed * 1.8
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	velocity.x = move_toward(velocity.x, direction.x * chase_speed, chase_speed * delta)
	velocity.z = move_toward(velocity.z, direction.z * chase_speed, chase_speed * delta)
	_face_to(target_pos)


func _start_attack() -> void:
	state = ZombieState.ATTACK
	velocity.x = 0.0
	velocity.z = 0.0
	attack_has_landed = false

	var attack_name := _pick_attack_animation()
	play_anim(attack_name)

	var anim_length := 1.1
	if anim_player.has_animation(attack_name):
		anim_length = anim_player.get_animation(attack_name).length / maxf(anim_player.speed_scale, 0.01)
	attack_time_left = maxf(anim_length, 0.6)
	attack_hit_time = attack_time_left * 0.45


func _process_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, speed * 3.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, speed * 3.0 * delta)

	if player != null and is_instance_valid(player):
		var look_target := player.global_position
		look_target.y = global_position.y
		_face_to(look_target)

	attack_time_left -= delta

	if not attack_has_landed and attack_time_left <= attack_hit_time:
		attack_has_landed = true
		_try_deal_attack_damage()

	if attack_time_left <= 0.0:
		attack_timer = attack_cooldown
		state = ZombieState.CHASE


func _process_dead(delta: float) -> void:
	if not is_on_floor():
		death_velocity.y -= gravity * delta
	else:
		death_velocity.x = move_toward(death_velocity.x, 0.0, 9.0 * delta)
		death_velocity.z = move_toward(death_velocity.z, 0.0, 9.0 * delta)

	velocity = death_velocity
	move_and_slide()
	death_timer -= delta
	if death_timer <= 0.0:
		queue_free()


func _try_deal_attack_damage() -> void:
	if player == null or not is_instance_valid(player):
		return

	var distance_to_player := global_position.distance_to(player.global_position)
	if distance_to_player > attack_range + 0.9:
		return

	if player.has_method("take_damage"):
		player.take_damage(damage)
	elif player.has_method("hit"):
		player.hit(damage)


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if state == ZombieState.DEAD:
		return

	current_hp -= amount
	hit_stun_timer = maxf(hit_stun_timer, 0.35)
	if knockback != Vector3.ZERO:
		var applied_knockback := knockback * hit_knockback_multiplier
		applied_knockback.y = maxf(applied_knockback.y, hit_knockback_min_upward)
		velocity += applied_knockback
		if state == ZombieState.ATTACK:
			state = ZombieState.CHASE

	if current_hp <= 0.0:
		die(knockback, knockback.length())


func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD:
		return

	state = ZombieState.DEAD
	attack_time_left = 0.0
	attack_timer = 0.0
	death_timer = death_lifetime

	# Оставляем коллизию только с землей, чтобы труп падал и не бил машину.
	collision_layer = 0
	collision_mask = GROUND_LAYER
	attack_area.monitoring = false
	if root_collider:
		root_collider.disabled = false

	var impulse := impact_force
	if impulse == Vector3.ZERO:
		impulse = -global_transform.basis.z * 4.0 + Vector3.UP * 3.0

	death_velocity = impulse * 0.35
	death_velocity.y += clampf(impact_speed * 0.05, 1.2, 6.0)

	if anim_player.has_animation("Dead"):
		play_anim("Dead")
	else:
		play_anim("Idle")



func _pick_attack_animation() -> String:
	var variants := PackedStringArray(["Attack", "Attack_2", "Attack2"])
	var available: Array[String] = []
	for anim_name in variants:
		if anim_player.has_animation(anim_name):
			available.append(anim_name)
	if available.is_empty():
		return "Idle"
	return available[randi_range(0, available.size() - 1)]


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.1


func _face_to(target: Vector3) -> void:
	var flat_target := target
	flat_target.y = global_position.y
	if flat_target.distance_to(global_position) < 0.01:
		return
	look_at(flat_target, Vector3.UP)


func play_anim(anim_name: String) -> void:
	if not anim_player.has_animation(anim_name):
		return
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)


func _spawn_flash(position: Vector3, color: Color, size: float) -> void:
	var pulse := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35 * size
	pulse.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	pulse.material_override = mat

	pulse.transparency = 0.0
	pulse.global_position = position
	get_tree().current_scene.add_child(pulse)

	var tween := get_tree().create_tween()
	tween.tween_property(pulse, "scale", Vector3.ONE * (2.8 * size), 0.26).from(Vector3.ONE * (0.15 * size))
	tween.parallel().tween_property(pulse, "transparency", 1.0, 0.26)
	tween.finished.connect(Callable(pulse, "queue_free"))
