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

# Новые переменные для настройки отлета
@export var high_speed_threshold: float = 20.0 

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var attack_area: Area3D = $Hit
@onready var root_collider: CollisionShape3D = $CollisionShape3D

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

	move_and_slide()
	
	# ПРОВЕРКА НА УДАР МАШИНОЙ
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var obj = collision.get_collider()
		if obj.is_in_group("player") or obj is VehicleBody3D:
			var car_vel = Vector3.ZERO
			if obj is VehicleBody3D:
				car_vel = obj.linear_velocity
			die(car_vel, car_vel.length())


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
	var chase_speed := speed * 1.8
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
	attack_time_left = 1.0 # Упростил для стабильности


func _process_attack(delta: float) -> void:
	attack_time_left -= delta
	if attack_time_left <= 0.0:
		state = ZombieState.CHASE


func _process_dead(delta: float) -> void:
	death_velocity.y -= gravity * delta
	velocity = death_velocity
	move_and_slide()
	death_timer -= delta
	if death_timer <= 0.0:
		queue_free()


func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD:
		return

	state = ZombieState.DEAD
	death_timer = death_lifetime

	# Выключаем коллизии с машиной, чтобы пролетала насквозь
	collision_layer = 0
	collision_mask = GROUND_LAYER 
	
	if anim_player.has_animation("Dead"):
		play_anim("Dead")

	# ТВОЯ ХОТЕЛКА: ОТЛЕТ НАЗАД
	var forward_dir = impact_force.normalized()
	if impact_speed > high_speed_threshold:
		# На большой скорости летит НАЗАД (инверсия) и сильно ВВЕРХ
		death_velocity = (-forward_dir * impact_speed * 1.5) + (Vector3.UP * 12.0)
	else:
		# На малой - летит вперед
		death_velocity = (forward_dir * impact_speed * 0.7) + (Vector3.UP * 5.0)
	
	# Добавляем рандом в бока
	death_velocity += global_transform.basis.x * randf_range(-4.0, 4.0)


func _face_to(target: Vector3) -> void:
	var flat_target := target
	flat_target.y = global_position.y
	if flat_target.distance_to(global_position) < 0.1: return
	look_at(flat_target, Vector3.UP)


func play_anim(anim_name: String) -> void:
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name)

func _pick_attack_animation() -> String:
	return "Attack" # Упростил для примера
	
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		# Небольшая прижимная сила, чтобы snap работал лучше
		velocity.y = -0.1
		
func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if state == ZombieState.DEAD:
		return

	current_hp -= amount
	
	# Если есть отдача, прикладываем её (для пушек на будущее)
	if knockback != Vector3.ZERO:
		velocity += knockback

	if current_hp <= 0.0:
		# Если здоровья нет — вызываем ту самую функцию смерти с отлетом
		die(knockback, knockback.length())
