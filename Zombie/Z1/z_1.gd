extends RigidBody3D

enum ZombieState { IDLE, CHASE, ATTACK, DEAD, FALLEN }

@export_group("Zombie Settings")
@export var max_hp: float = 50.0
@export var walk_speed: float = 3.0    # Скорость до 2000 метров
@export var run_speed: float = 8.0     # Скорость после 2000 метров
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
var current_speed: float = 3.0        # Текущая скорость (меняется пулом)
var _internal_velocity: Vector3 = Vector3.ZERO
var _chase_anim: String = "Walk"       # Базовая анимация бега/ходьбы для текущей сложности

func _ready() -> void:
	add_to_group("zombie")
	current_hp = max_hp
	current_speed = walk_speed
	
	# Настройка RigidBody для работы в режиме кинематического перемещения
	freeze = true
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	
	# Первичный поиск игрока
	_find_player()

func _find_player() -> void:
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

	# Проверка валидности игрока (ОПТИМИЗИРОВАНО: ищем только если ссылка пустая)
	if player == null or not is_instance_valid(player):
		_find_player()
		state = ZombieState.IDLE
		_internal_velocity = Vector3.ZERO
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
		play_anim(_chase_anim) # Включает Walk или Run в зависимости от дистанции трассы
		
		var dir = (player.global_position - global_position).normalized()
		dir.y = 0 # Не взлетаем вверх
		_internal_velocity = dir * current_speed
		
		# Плавный поворот в сторону игрока
		if _internal_velocity.length_squared() > 0.01:
			var target_angle = atan2(-_internal_velocity.x, -_internal_velocity.z)
			rotation.y = target_angle
			
	# 3. Состояние ПОКОЯ
	else:
		state = ZombieState.IDLE
		play_anim("Walk") 
		_internal_velocity = _internal_velocity.move_toward(Vector3.ZERO, current_speed * delta)

# ФУНКЦИЯ СБРОСА ДЛЯ ПУЛА (Вызывается автоматически при повторном спавне)
func reset_zombie(is_running: bool = false) -> void:
	state = ZombieState.IDLE
	current_hp = max_hp
	attack_timer = 0.0
	target_z = 0.0
	_internal_velocity = Vector3.ZERO
	
	
	# Настройка сложности в зависимости от пройденных игроком метров
	if is_running:
		current_speed = run_speed
		_chase_anim = "Run"
	else:
		current_speed = walk_speed
		_chase_anim = "Walk"
		
	# Принудительно запускаем базовую анимацию
	play_anim("Walk")

func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD: return
	state = ZombieState.DEAD
	_internal_velocity = Vector3.ZERO
	
	# Выключаем коллизии, чтобы не мешать машине ехать дальше и не сбивать труп повторно
	set_collision_layer_value(3, false)
	set_collision_mask_value(1, false)
	
	# Рассчитываем плавный локальный сдвиг назад по Z от скорости машины
	target_z = remap(impact_speed, 0.0, 30.0, -1.0, -4.0)
	target_z = clamp(target_z, -4.0, -1.0)
	
	play_anim("Death")
	
	# ИСПРАВЛЕНО: Ждем завершения анимации смерти, прежде чем убрать зомби в пул!
	if anim_player.is_playing():
		await anim_player.animation_finished
		
	# Только теперь, когда он красиво отлетел и упал, убираем его с экрана
	ZombiePool.return_zombie(self)

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
