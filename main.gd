extends Node3D

@export var world_environment: WorldEnvironment
@export var car: VehicleBody3D

@export_group("World Generation")
# СПИСОК ЧАНКОВ: Добавляйте сюда сцены в инспекторе. 
# Когда они закончатся, список начнет читаться заново с 0!
@export var chunk_scenes_list: Array[PackedScene] = []
@export var bridge_scene: PackedScene # Сцена моста с Area3D

@export var chunks_ahead: int = 1
@export var chunks_behind: int = 1
@export var update_distance: float = 330.0
@export var chunk_width: float = 350.0
@export var chunk_length: float = 330.0
@export var chunk_thickness: float = 8.0
@export var road_y: float = 0.0
@export var world_origin: Vector3 = Vector3.ZERO
@export var forward_axis: Vector3 = Vector3.BACK

@export_group("Bridge Settings")
@export var bridge_each_nth_chunk: int = 3 # Спавнить мост каждый N-й чанк (например, каждый 3-й)

@export_group("Debug")
@export var verbose_logs: bool = false

var normal_fog_color: Color = Color("a3b2c4")
var scary_red_fog_color: Color = Color("b13d3cff")
var current_fog_tween: Tween
var is_fog_red: bool = false
var _forward: Vector3 = Vector3.BACK
var _chunk_step: float = 120.0
var _chunk_nodes: Dictionary = {}
var _last_checked_distance: float = -INF

# Внутренние переменные для бесконечного цикла мостов и биомов
var current_biome_index: int = 0
var chunks_spawned_counter: int = 0 # Счетчик созданных чанков подряд

func _ready() -> void:
	# СПАВНИМ МАШИНУ ИЗ ВЫБОРА В МАГАЗИНЕ
	var car_path = Game.car_data[Game.selected_car_index].path
	var car_scene = load(car_path)
	car = car_scene.instantiate()
	add_child(car)
	car.global_position = Vector3(0, 0, 0) 
	car.add_to_group("player") 
	_resolve_car()
	
	if chunk_scenes_list.is_empty():
		push_error("Main: Список chunk_scenes_list пуст. Добавьте чанки в инспекторе.")
		return
	if bridge_scene == null:
		push_error("Main: bridge_scene не назначен.")
		return
	if car == null:
		push_error("Main: машина не найдена. Назначь узел car в инспекторе.")
		return

	_forward = forward_axis.normalized()
	if _forward.length_squared() < 0.001:
		_forward = Vector3.BACK
	_chunk_step = maxf(chunk_length, 1.0)

	_cleanup_preplaced_chunks()
	var car_index := _get_chunk_index(_distance_along_forward(car.global_position))
	_ensure_chunks_for_index(car_index)
	_last_checked_distance = float(car_index)

func _process(_delta: float) -> void:
	if car == null or chunk_scenes_list.is_empty():
		return
		
	var distance := _distance_along_forward(car.global_position)
	var current_chunk_index := _get_chunk_index(distance)
	
	var abs_dist = absf(distance)
	var zone_index = floori(abs_dist / 1500.0)
	
	var is_in_red_zone = (zone_index % 2 == 1)
	
	if is_in_red_zone and not is_fog_red:
		is_fog_red = true
		_transition_fog(scary_red_fog_color, 0.1) 
		if verbose_logs: print("Вход в КРАСНУЮ зону сложности! Номер зоны: ", zone_index)
	elif not is_in_red_zone and is_fog_red:
		is_fog_red = false
		_transition_fog(normal_fog_color, 0.01) 
		if verbose_logs: print("Вход в ОБЫЧНУЮ зону! Номер зоны: ", zone_index)
	
	if current_chunk_index == int(_last_checked_distance):
		return 

	_last_checked_distance = float(current_chunk_index)
	_ensure_chunks_for_index(current_chunk_index)

func _resolve_car() -> void:
	if car != null:
		return
	car = get_node_or_null("car") as VehicleBody3D
	if car == null:
		car = get_tree().get_first_node_in_group("player") as VehicleBody3D

func _ensure_chunks_for_index(current_index: int) -> void:
	var min_index: int = current_index - maxi(chunks_behind, 0)
	var max_index: int = current_index + maxi(chunks_ahead, 1)

	# 1. Спавним новые чанки
	for index in range(min_index, max_index + 1):
		if not _chunk_nodes.has(index):
			_spawn_chunk(index)
			
	var remove_list: Array[int] = []
	for key in _chunk_nodes.keys():
		var index := int(key)
		var chunk = _chunk_nodes[index]
		if not is_instance_valid(chunk) or index < min_index or index > max_index:
			remove_list.append(index)
			
	for index in remove_list:
		var chunk = _chunk_nodes[index]
		if is_instance_valid(chunk):
			chunk.queue_free() 
		_chunk_nodes.erase(index)

func _spawn_chunk(index: int) -> void:
	var chunk: Node3D = null
	
	# Считаем текущий шаг. Если дошли до N-го чанка (например, 3), то спавним мост
	chunks_spawned_counter += 1
	
	if chunks_spawned_counter >= bridge_each_nth_chunk:
		chunk = bridge_scene.instantiate() as Node3D
		chunks_spawned_counter = 0 # Сбрасываем счетчик чанков
		if verbose_logs: print("Генератор: Спавним МОСТ на индексе ", index)
	else:
		# Спавним обычный чанк из списка
		var active_scene = chunk_scenes_list[current_biome_index]
		chunk = active_scene.instantiate() as Node3D
		if verbose_logs: print("Генератор: Спавним обычный чанк №", current_biome_index, " на индексе ", index)

	if chunk == null:
		push_error("Main: Не удалось создать чанк/мост.")
		return

	var chunk_origin := world_origin + _forward * (_chunk_step * float(index))
	var chunk_basis := Basis.looking_at(_forward, Vector3.UP)
	
	add_child(chunk)
	chunk.global_transform = Transform3D(chunk_basis, Vector3(chunk_origin.x, road_y, chunk_origin.z))

	if chunk.has_method("configure_chunk"):
		chunk.call("configure_chunk", chunk_width, chunk_length, chunk_thickness, road_y)

	if chunk.has_method("init_chunk_zombies"):
		chunk.init_chunk_zombies()

	_chunk_nodes[index] = chunk

# ЭТУ ФУНКЦИЮ БЕСКОНЕЧНО ВЫЗЫВАЕТ МОСТ ПРИ КАСАНИИ СВОЕЙ Area3D
func advance_to_next_biome() -> void:
	# Формула (%) делает цикл бесконечным: 0 -> 1 -> 2 -> снова 0 -> 1...
	current_biome_index = (current_biome_index + 1) % chunk_scenes_list.size()
	print("Генератор: Мост пройден! Следующие чанки будут типа №: ", current_biome_index)

func _cleanup_preplaced_chunks() -> void:
	for child in get_children():
		var child_node := child as Node
		if child_node == null or child_node == car:
			continue
		
		# Удаляем любые старые чанки или мосты, оставшиеся в редакторе перед запуском
		if child_node.name.to_lower().contains("chunk") or child_node.name.to_lower().contains("bridge"):
			child_node.queue_free()


func _distance_along_forward(world_position: Vector3) -> float:
	return (world_position - world_origin).dot(_forward)

func _get_chunk_index(distance_along_forward: float) -> int:
	return int(floor(distance_along_forward / _chunk_step))
	
func _transition_fog(target_color: Color, target_density: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return
		
	var env = world_environment.environment
	env.fog_enabled = true
		
	if current_fog_tween:
		current_fog_tween.kill()
		
	current_fog_tween = create_tween()
	current_fog_tween.tween_property(env, "fog_light_color", target_color, 5.0)
