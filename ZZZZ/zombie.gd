extends RigidBody3D

@export var speed = 4.0
@export var target_path : NodePath # Выбери игрока в инспекторе

@onready var nav_agent = $NavigationAgent3D
@onready var anim_player = $AnimationPlayer

var target_node = null
var is_dead = false

func _ready():
	# Блокируем вращение, чтобы физика не роняла его при ходьбе
	lock_rotation = true
	# Если модель задом наперед, развернем визуальную часть один раз
	# Замени "Sketchfab_Scene" на имя твоего первого дочернего узла модели
	if has_node("Sketchfab_Scene"):
		$Sketchfab_Scene.rotation_degrees.y = 180 
	
	if target_path:
		target_node = get_node(target_path)

func _physics_process(_delta):
	if is_dead or not target_node:
		return

	# Обновляем цель (позиция игрока)
	nav_agent.target_position = target_node.global_position
	
	if nav_agent.is_navigation_finished():
		anim_player.play("Idle")
		linear_velocity = Vector3.ZERO
		return

	# Навигация
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	# Двигаем физическое тело (сохраняем гравитацию по Y)
	linear_velocity.x = direction.x * speed
	linear_velocity.z = direction.z * speed
	
	# Плавный поворот в сторону движения
	if direction.length() > 0:
		var look_target = global_position + Vector3(direction.x, 0, direction.z)
		look_at(look_target, Vector3.UP)
		anim_player.play("Run")

	# Дистанция для атаки (если близко - атакуем)
	if global_position.distance_to(target_node.global_position) < 2.0:
		attack()

func attack():
	# Выбираем рандомную атаку из твоих нарезанных
	var attack_anim = ["Attack", "Attack2"].pick_random()
	if anim_player.current_animation != attack_anim:
		anim_player.play(attack_anim)

# Вызывай это, когда игрок "сбивает" или стреляет в монстра
func die(_damage = null):
	if is_dead: return
	is_dead = true
	
	lock_rotation = false # Теперь он физически может упасть
	anim_player.play("Dead") # Рандомная смерть
	
	# Небольшой физический импульс назад при смерти
	apply_central_impulse(Vector3.UP * 3 + Vector3.BACK * 5)
