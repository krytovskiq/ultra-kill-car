extends RigidBody3D

enum ZombieState { IDLE, CHASE, ATTACK, DEAD, FALLEN }
@export var get_up_time: float = 0.5
@export var speed: int = 8
@export var damage: float = 15.0
@export var player_path: NodePath
@export var max_hp: float = 50.0
@export var detection_radius: float = 32.0
@export var lose_target_radius: float = 45.0
@export var attack_range: float = 2.8
@export var attack_cooldown: float = 1.3
@export var death_lifetime: float = 3.5
@export var high_speed_threshold: float = 20.0 

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var root_collider: CollisionShape3D = $CollisionShape3D

var player: Node3D
var state: ZombieState = ZombieState.IDLE
var current_hp: float = 0.0
var attack_timer: float = 0.0
var attack_time_left: float = 0.0
var hit_stun_timer: float = 0.0

# Замена velocity для RigidBody
var _internal_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("zombie")
	current_hp = max_hp
	
	# Настройка физики RigidBody
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 4

	if player_path and has_node(player_path):
		player = get_node(player_path) as Node3D
	else:
		player = get_tree().get_first_node_in_group("player") as Node3D

	play_anim("Idle")
	# Подключаем сигнал столкновения
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node):
	if state == ZombieState.DEAD or state == ZombieState.FALLEN: return
	if body.is_in_group("player") or body is VehicleBody3D:
		var car_vel = body.linear_velocity
		var speed = car_vel.length()
		if speed > 20.0: # Если летим быстро — смерть
			die(car_vel, speed)
		elif speed > 5.0: # Если средняя скорость — сбиваем с ног
			knockdown(car_vel)

func _physics_process(delta: float) -> void:
	if state == ZombieState.DEAD or state == ZombieState.FALLEN: return

	if attack_timer > 0.0: attack_timer -= delta
	if hit_stun_timer > 0.0: hit_stun_timer -= delta

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D

	_update_state()

	match state:
		ZombieState.IDLE: _process_idle(delta)
		ZombieState.CHASE: _process_chase(delta)
		ZombieState.ATTACK: _process_attack(delta)

	# Перемещение "замороженного" RigidBody
	global_position += _internal_velocity * delta

func _update_state() -> void:
	if player == null or not is_instance_valid(player):
		state = ZombieState.IDLE
		return
	if state == ZombieState.ATTACK: return

	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range and attack_timer <= 0.0 and hit_stun_timer <= 0.0:
		_start_attack()
	elif dist <= detection_radius or (state == ZombieState.CHASE and dist <= lose_target_radius):
		state = ZombieState.CHASE
	else:
		state = ZombieState.IDLE

func _process_idle(delta: float) -> void:
	play_anim("Idle")
	_internal_velocity = _internal_velocity.move_toward(Vector3.ZERO, speed * delta)

func _process_chase(delta: float) -> void:
	if !player: return
	play_anim("Run")
	var target_pos = player.global_position
	var dir = (target_pos - global_position).normalized()
	dir.y = 0
	_internal_velocity = dir * speed
	_face_to(target_pos)

func _start_attack() -> void:
	state = ZombieState.ATTACK
	_internal_velocity = Vector3.ZERO
	play_anim("Attack")
	attack_time_left = 1.0

func _process_attack(delta: float) -> void:
	attack_time_left -= delta
	if attack_time_left <= 0.0: state = ZombieState.CHASE

func _face_to(target: Vector3) -> void:
	var look_pos = target
	look_pos.y = global_position.y
	if global_position.distance_to(look_pos) > 0.1:
		look_at(look_pos, Vector3.UP)

func play_anim(anim_name: String) -> void:
	if anim_player.current_animation != anim_name:
		anim_player.play(anim_name)

func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD: return
	state = ZombieState.DEAD
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	# Даем импульс
	apply_central_impulse(impact_force * 0.5) 
	
	if anim_player.has_animation("Dead"):
		play_anim("Dead")


func take_damage(amount: float, knockback: Vector3 = Vector3.ZERO) -> void:
	if state == ZombieState.DEAD: return
	current_hp -= amount
	if current_hp <= 0.0:
		die(knockback, knockback.length())
		
func knockdown(impact_force: Vector3):
	if state == ZombieState.DEAD or state == ZombieState.FALLEN: 
		return
	
	state = ZombieState.FALLEN

	# 2. Даем Godot один тик, чтобы он подготовил объект к полету
	await get_tree().physics_frame
	
	# 3. ПРИНУДИТЕЛЬНО даем пинок
	# Мы берем направление удара машины, усиливаем его и ОБЯЗАТЕЛЬНО подбрасываем вверх
	var push_direction = impact_force.normalized()
	var strength = impact_force.length()
	
	# Напрямую задаем линейную скорость (лучше, чем импульс для маленьких весов)
	linear_velocity = (push_direction * strength * 1.5) + (Vector3.UP * 10.0)
	# Добавляем хаотичное вращение в полете
	angular_velocity = Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))

	if anim_player.has_animation("Dead"):
		anim_player.play("Dead")
	
	# 4. Таймер вставания (без строчки freeze = true в конце)
	await get_tree().create_timer(3.0).timeout
	_get_up_simple()

func _get_up_simple():
	if state == ZombieState.DEAD: return
	
	if anim_player.has_animation("Dead"):
		anim_player.play("Dead", -1, -1.0, true)
		await anim_player.animation_finished
	
	state = ZombieState.CHASE

func _get_up():
	if state == ZombieState.DEAD: return
	
	# Чтобы он не вставал "в воздухе", сначала ставим его на землю
	# (Здесь можно добавить проверку лучем RayCast вниз, если нужно)
	
	if anim_player.has_animation("Dead"):
		anim_player.play("Dead", -1, -1.0, true)
		await anim_player.animation_finished
	
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	state = ZombieState.CHASE
