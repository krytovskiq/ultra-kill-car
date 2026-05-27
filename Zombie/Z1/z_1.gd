extends RigidBody3D

enum ZombieState { IDLE, CHASE, ATTACK, DEAD, FALLEN }

@export_group("Zombie Settings")
@export var max_hp: float = 50.0
@export var speed: int = 8
@export var damage: int = 10
@export var attack_range: float = 3.0
@export var detection_radius: float = 500.0
@export var lose_target_radius: float = 200.0

@export_group("Timers")
@export var attack_cooldown: float = 3.5
@export var get_up_time: float = 3.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var player: Node3D
var state: ZombieState = ZombieState.IDLE
var current_hp: float = 0.0
var attack_timer: float = 0.0
var target_z: float = 0.0
var _internal_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("zombie")
	current_hp = max_hp
	
	# Настройка RigidBody для работы в режиме кинематического перемещения
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	# Ищем игрока в группе
	player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	# Если мертв или лежит, обрабатываем только плавный отлет по Z
	if state == ZombieState.DEAD or state == ZombieState.FALLEN:
		position.z = move_toward(position.z, target_z, 8.0 * delta)
		return

	# Восстановление Z в 0, если зомби жив и на ногах
	position.z = move_toward(position.z, 0.0, 4.0 * delta)

	if attack_timer > 0.0: 
		attack_timer -= delta

	# Проверка валидности игрока
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
		state = ZombieState.IDLE
		return

	_update_state_and_movement(delta)

	# Перемещение узла
	global_position += _internal_velocity * delta

func _update_state_and_movement(delta: float) -> void:
	var dist := global_position.distance_to(player.global_position)
	
	# 1. Состояние АТАКИ
	if dist <= attack_range and attack_timer <= 0.0:
		state = ZombieState.ATTACK
		_internal_velocity = Vector3.ZERO
		play_anim("Attack")
		attack_timer = attack_cooldown
		# Возврат к погоне после завершения анимации атаки
		await anim_player.animation_finished
		if state == ZombieState.ATTACK: 
			state = ZombieState.CHASE
			
	# 2. Состояние ПОГОНИ
	elif dist <= detection_radius or (state == ZombieState.CHASE and dist <= lose_target_radius):
		state = ZombieState.CHASE
		play_anim("Run")
		
		var dir = (player.global_position - global_position).normalized()
		dir.y = 0 # Не взлетаем вверх
		_internal_velocity = dir * speed
		
		# Плавный поворот в сторону игрока
		var look_pos = player.global_position
		look_pos.y = global_position.y
		if global_position.distance_to(look_pos) > 0.1:
			look_at(look_pos, Vector3.UP)
			
	# 3. Состояние ПОКОЯ
	else:
		state = ZombieState.IDLE
		play_anim("Walk") # По твоему коду в IDLE он тоже бежит
		_internal_velocity = _internal_velocity.move_toward(Vector3.ZERO, speed * delta)

func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD: return
	state = ZombieState.DEAD
	
	# Выключаем коллизии, чтобы не мешать машине ехать дальше
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	
	# Рассчитываем плавный локальный сдвиг назад по Z от скорости машины
	target_z = remap(impact_speed, 0.0, 30.0, -1.0, -4.0)
	target_z = clamp(target_z, -4.0, -1.0)
	
	play_anim("Death")

func knockdown(impact_force: Vector3):
	if state == ZombieState.DEAD or state == ZombieState.FALLEN: return
	state = ZombieState.FALLEN
	_internal_velocity = Vector3.ZERO
	
	# Сдвиг по Z для нокдауна (чуть слабее, чем при смерти)
	var speed_mps = impact_force.length()
	target_z = remap(speed_mps, 0.0, 20.0, -0.5, -2.0)
	target_z = clamp(target_z, -2.0, -0.5)

	play_anim("Death")
	
	# Таймер падения и подъема
	await get_tree().create_timer(get_up_time).timeout
	_get_up()

func _get_up():
	if state == ZombieState.DEAD: return
	
	# Проигрываем анимацию смерти задом наперед, чтобы он плавно встал
	if anim_player.has_animation("Death"):
		anim_player.play("Death", -1, -1.0, true)
		await anim_player.animation_finished
	
	state = ZombieState.CHASE

func play_anim(anim_name: String) -> void:
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
