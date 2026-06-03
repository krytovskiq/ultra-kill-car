extends Node

var zombie_scene: PackedScene = preload("res://Zombie/Z1/Z1.tscn") # Укажите ваш путь к zombie.tscn
var pool: Array[Node3D] = []
var pool_size: int = 330 
var is_initialized: bool = false # Флаг, чтобы не создавать зомби дважды

func _ready() -> void:
	# Ждем загрузки текущего кадра
	await get_tree().process_frame
	
	# ПРОВЕРКА: Если мы сейчас находимся в Главном Меню, то ПРЕКРАЩАЕМ работу функции.
	# Зомби на старте в меню создаваться НЕ БУДУТ!
	if get_tree().current_scene.name == "Menu" or "menu" in get_tree().current_scene.scene_file_path.to_lower():
		print("Пул зомби: Обнаружено меню. Ожидаем старта игры...")
		return
		
	# Если игра запущена сразу с игровой сцены (для тестов), наполняем пул мгновенно
	init_pool()

# Новая функция, которая вызывается один раз для наполнения пула перед гонкой
func init_pool() -> void:
	if is_initialized: 
		return
		
	is_initialized = true
	
	print("Пул зомби: Начинаю генерацию ", pool_size, " зомби для игры...")
	for i in range(pool_size):
		_create_new_pool_zombie()


func _create_new_pool_zombie() -> Node3D:
	var zombie = zombie_scene.instantiate()
	
	# МАКСИМАЛЬНАЯ ОПТИМИЗАЦИЯ: Полностью выключаем узел (он не ест FPS вообще)
	zombie.visible = false
	zombie.process_mode = PROCESS_MODE_DISABLED 
	
	#zombie.global_position = Vector3(0, -500.0, 0)
	get_tree().current_scene.add_child(zombie)
	pool.append(zombie)
	return zombie


func spawn_zombie_at(global_pos: Vector3) -> Node3D:
	for i in range(pool.size() - 1, -1, -1):
		var zombie = pool[i]
		if not is_instance_valid(zombie):
			pool.remove_at(i)
			continue
			
		# Ищем выключенного зомби
		if zombie.process_mode == PROCESS_MODE_DISABLED:
			zombie.global_position = global_pos
			zombie.visible = true
			
			# ВКЛЮЧАЕМ логику и физику обратно (теперь он начнет работать)
			zombie.process_mode = PROCESS_MODE_INHERIT 
			
			var distance_from_start = absf(global_pos.z)
			var zombie_zone_index = floori(distance_from_start / 150.0)
			var should_run: bool = (zombie_zone_index % 2 == 1)
			
			if zombie.has_method("reset_zombie"):
				zombie.reset_zombie(should_run)
			return zombie
			
	var extra_zombie = _create_new_pool_zombie()
	extra_zombie.global_position = global_pos
	extra_zombie.visible = true
	extra_zombie.process_mode = PROCESS_MODE_INHERIT
	return extra_zombie
	
func return_zombie(zombie: Node3D):
	if is_instance_valid(zombie):
		zombie.visible = false
		
		# Это ПОЛНОСТЬЮ выключает анимации, физику и логику зомби в памяти
		zombie.process_mode = PROCESS_MODE_DISABLED 
		
		zombie.global_position = Vector3(0, -500.0, 0)
