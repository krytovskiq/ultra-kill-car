extends RigidBody3D

@export var speed = 5.0
@export var target_path : NodePath

@onready var nav_agent = $NavigationAgent3D
@onready var anim_player = $"../../../../../../../AnimationPlayer"

var target_node = null
var is_dead = false

func _ready():
	# Настройка физики, чтобы монстр не падал на бок при ходьбе
	lock_rotation = true 
	if target_path:
		target_node = get_node(target_path)

func _physics_process(delta):
	if is_dead or not target_node:
		return

	# 1. Обновляем цель для навигации
	nav_agent.target_position = target_node.global_position
	
	if nav_agent.is_navigation_finished():
		anim_player.play("Idle")
		linear_velocity = Vector3.ZERO # Останавливаем физическое тело
		return

	# 2. Получаем направление движения
	var next_path_pos = nav_agent.get_next_path_position()
	var direction = (next_path_pos - global_position).normalized()
	
	# 3. Двигаем через linear_velocity (физически корректно)
	# Мы оставляем текущую скорость по Y (гравитацию), но меняем X и Z
	linear_velocity.x = direction.x * speed
	linear_velocity.z = direction.z * speed
	
	# 4. Поворот и анимация
	if direction.length() > 0:
		# Поворачиваем меш плавно в сторону движения
		var look_dir = Vector2(direction.z, direction.x)
		rotation.y = look_dir.angle()
		anim_player.play("Run")

# Вызывай это, когда хочешь "сбить" монстра
func die(_damage = null):
	if is_dead: return
	is_dead = true # Теперь он падает как тряпичная кукла
	
	is_dead = true
	lock_rotation = false # Разрешаем ему упасть на бок
	anim_player.play("Dead")
	
	# Даем небольшой пинок при смерти для эффекта
	apply_central_impulse(Vector3.UP * 2 + Vector3.BACK * 3) 
