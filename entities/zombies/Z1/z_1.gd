extends CharacterBody3D

enum ZombieState { IDLE, CHASE, ATTACK, DEAD, FALLEN }

@export_group("Zombie Settings")
@export var max_hp: float = 50.0
@export var walk_speed: float = 2.0    
@export var run_speed: float = 7.0     
@export var damage: int = 9
@export var attack_range: float = 2.7
@export var detection_radius: float = 300.0
@export var lose_target_radius: float = 310.0

@export_group("Timers")
@export var attack_cooldown: float = 1.5
@export var get_up_time: float = 1.5

@onready var skeleton: Skeleton3D = null
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var player: Node3D
var state: ZombieState = ZombieState.IDLE
var current_hp: float = 0.0
var attack_timer: float = 0.0
var target_z: float = 0.0
var current_speed: float = 3.0        
var _internal_velocity: Vector3 = Vector3.ZERO
var _chase_anim: String = "Walk"       

# ОПТИМИЗАЦИЯ: Предрасчет радиусов в квадрате, чтобы избавиться от sqrt()
@onready var attack_range_sq: float = attack_range * attack_range
@onready var detection_radius_sq: float = detection_radius * detection_radius
@onready var lose_target_radius_sq: float = lose_target_radius * lose_target_radius


func _ready() -> void:
	skeleton = get_node_or_null("Run/Skeleton3D")
	
	# === ОПТИМИЗАЦИЯ РЭГДОЛЛА ===
	# Удаляем мелкие кости, чтобы они не мешали и не сворачивали труп в "пакет"

	if skeleton:
		for child in skeleton.get_children():
			if child is MeshInstance3D:
				child.extra_cull_margin = 250.0 # Предотвращает мгновенное исчезновение при рэгдолле!

		var sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
		if sim:
			for child in sim.get_children():
				if child is PhysicalBone3D:
					var n = child.name
					if "Index" in n or "Thumb" in n or "Middle" in n or "Ring" in n or "Pinky" in n or "Toe" in n:
						child.queue_free()
	# ============================

	add_to_group("zombie")
	current_hp = max_hp
	current_speed = walk_speed
	
	# Подключаем сигнал окончания анимации ОДИН раз, вместо опасных await
	anim_player.animation_finished.connect(_on_animation_finished)
	
	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D

func _physics_process(delta: float) -> void:
	# Если зомби мертв или сбит, обрабатываем физику отлета
	if state == ZombieState.DEAD or state == ZombieState.FALLEN:
		position.z = move_toward(position.z, target_z, 8.0 * delta)
		return

	# УДАЛЕНО: Строка position.z = move_toward..., которая уносила зомби на нулевой метр карты!


	if player and is_instance_valid(player):
		var dist_to_p = global_position.distance_squared_to(player.global_position)
		if dist_to_p > 250000.0:
			return

	if attack_timer > 0.0: 
		attack_timer -= delta

	if player == null or not is_instance_valid(player):
		_find_player()
		state = ZombieState.IDLE
		_internal_velocity = Vector3.ZERO
		return

	_update_state_and_movement(delta)

	# Движение живого зомби (работает правильно)
	global_position += _internal_velocity * delta


func _update_state_and_movement(delta: float) -> void:
	# Если зомби уже атакует, принудительно держим скорость нулевой и выходим
	if state == ZombieState.ATTACK:
		_internal_velocity = Vector3.ZERO
		return

	var dist_sq := global_position.distance_squared_to(player.global_position)
	
	# 1. Состояние АТАКИ (срабатывает, если подошел близко и кулдаун прошел)
	if dist_sq <= attack_range_sq and attack_timer <= 0.0:
		state = ZombieState.ATTACK
		_internal_velocity = Vector3.ZERO
		play_anim("Attack")
		if player and player.has_method("take_damage"):
			player.take_damage(damage)
		attack_timer = attack_cooldown
		return 
			
	# 2. Состояние ПОГОНИ
	elif dist_sq <= detection_radius_sq or (state == ZombieState.CHASE and dist_sq <= lose_target_radius_sq):
		state = ZombieState.CHASE
		play_anim(_chase_anim) 
		
		var dir := global_position.direction_to(player.global_position)
		dir.y = 0 
		_internal_velocity = dir * current_speed
		
		if _internal_velocity.length_squared() > 0.01:
			var target_look = global_position + _internal_velocity
			look_at(target_look, Vector3.UP)
			
	# 3. Состояние ПОКОЯ (ИСПРАВЛЕНО: теперь включает Idle, а не Walk)
	else:
		state = ZombieState.IDLE
		if anim_player.has_animation("Idle"):
			play_anim("Idle")
		else:
			play_anim("Walk") # если анимации покоя нет вообще
		_internal_velocity = _internal_velocity.move_toward(Vector3.ZERO, current_speed * delta)
		
# ОПТИМИЗАЦИЯ: Единый обработчик завершения всех анимаций (вместо await)
func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "Attack" and state == ZombieState.ATTACK:
		state = ZombieState.CHASE
	elif anim_name == "Death" and state == ZombieState.DEAD:
		# Отрезаем сигнал перед возвратом в пул, чтобы не было утечек памяти
		if anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.disconnect(_on_animation_finished)
		ZombiePool.return_zombie(self)
	elif anim_name == "Death" and state == ZombieState.FALLEN:
		state = ZombieState.CHASE
func reset_zombie(is_running: bool = false) -> void:
	state = ZombieState.IDLE
	set_physics_process(true) # Включаем обратно физику перемещения
	# Возвращаем коллизию (слой 4 = значение 8)
	collision_layer = 8
	collision_mask = 1
	

	if skeleton:
		for child in skeleton.get_children():
			if child is MeshInstance3D:
				child.extra_cull_margin = 250.0 # Предотвращает мгновенное исчезновение при рэгдолле!

		var sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
		if sim:
			sim.physical_bones_stop_simulation()
		
	if is_running:
		current_speed = run_speed
		_chase_anim = "Run"
	else:
		current_speed = walk_speed
		_chase_anim = "Walk"
		
	play_anim("Walk")

func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0) -> void:
	if state == ZombieState.DEAD: return
	state = ZombieState.DEAD
	_internal_velocity = Vector3.ZERO
	
	# Полностью отключаем коллизию у самого зомби, чтобы он не стопил машину
	collision_layer = 0
	collision_mask = 0
	
	var sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
	if sim:
		anim_player.stop()
		sim.physical_bones_start_simulation()
		set_physics_process(false) # Останавливаем физику капсулы, чтобы зомби не полз вперед!
		
		# Чтобы рэгдолл был похож на тело, а не на "целлофановый пакет",
		# мы применяем сильный импульс ТОЛЬКО к туловищу (таз и позвоночник).
		# Руки и ноги просто полетят за телом по инерции.
		# Чтобы суставы не растягивались (из-за чего сетка тянется как пакет),
		# мы задаем ОДИНАКОВУЮ начальную скорость сразу ВСЕМ костям!
		# Так они полетят как единое целое, не разрывая суставы.
		# Приподнимаем зомби над землей, чтобы ноги не цеплялись за текстуры пола и не отрывались
		global_position.y += 0.5
		
		var launch_vel = impact_force * 0.4 + Vector3(0, 10.0, 0)
		for child in sim.get_children():
			if child is PhysicalBone3D:
				# Даем импульс пропорционально массе, чтобы движок физики не сходил с ума
				child.apply_central_impulse(launch_vel * child.mass)
				# Крутим сильно, чтобы пробить высокое сопротивление (angular_damp)
				child.angular_velocity = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))
		
		# Труп лежит 5 секунд
		get_tree().create_timer(5.0).timeout.connect(func(): ZombiePool.return_zombie(self))
	else:
		target_z = remap(impact_speed, 0.0, 30.0, -1.0, -4.0)
		target_z = clamp(target_z, -4.0, -1.0)
		play_anim("Death")

func knockdown(impact_force: Vector3):
	if state == ZombieState.DEAD or state == ZombieState.FALLEN: return
	state = ZombieState.FALLEN
	_internal_velocity = Vector3.ZERO
	
	var speed_mps = impact_force.length()
	target_z = remap(speed_mps, 0.0, 20.0, -0.5, -2.0)
	target_z = clamp(target_z, -2.0, -0.5)

	play_anim("Death")
	
	# Для таймера подъема await безопасен, так как knockdown вызывается разово (по триггеру)
	await get_tree().create_timer(get_up_time).timeout
	_get_up()

func _get_up():
	if state == ZombieState.DEAD: return
	
	if anim_player.has_animation("Death"):
		anim_player.play("Death", -1, -1.0, true)
		# Ждем завершения реверса анимации вставания
		await anim_player.animation_finished
	
	state = ZombieState.CHASE

func play_anim(anim_name: String) -> void:
	if anim_player.has_animation(anim_name) and anim_player.current_animation != anim_name:
		anim_player.play(anim_name)
