extends Node3D

@export var world_environment: WorldEnvironment
@export var car: VehicleBody3D

@export_group("World Generation")
@export var chunk_scenes_list: Array[PackedScene] = []
@export var bridge_scene: PackedScene 

@export var chunks_ahead: int = 2
@export var chunks_behind: int = 1
@export var chunk_width: float = 380.0
@export var chunk_length: float = 500.0
@export var chunk_thickness: float = 800.0
@export var road_y: float = 0.0
@export var world_origin: Vector3 = Vector3.ZERO
@export var forward_axis: Vector3 = Vector3.BACK

@export_group("Bridge Settings")
@export var bridge_interval_meters: float = 500.0

@export_group("Динамический Спавн Зомби")
@export var base_spawn_cooldown: float = 0.25 
@export var spawn_distance_ahead: float = 330.0 
@export var road_spawn_width: float = 150.0 

@export_group("Debug")
@export var verbose_logs: bool = false

var normal_fog_color: Color = Color("0d1117")      
var scary_red_fog_color: Color = Color("6c1717ff")   
var current_fog_tween: Tween
var is_fog_red: bool = false

var _forward: Vector3 = Vector3.BACK
var _chunk_step: float = 500.0
var _chunk_nodes: Dictionary = {}
var _last_checked_distance: float = -INF

var spawn_timer: float = 0.0
var current_spawn_cooldown: float = 1.2

func _ready() -> void:
	var car_path: String = Game.car_data[Game.selected_car_index].path
	var car_scene: PackedScene = load(car_path)
	car = car_scene.instantiate() as VehicleBody3D
	add_child(car)
	car.global_position = Vector3.ZERO
	car.add_to_group("player") 
	
	current_spawn_cooldown = base_spawn_cooldown
	
	if chunk_scenes_list.is_empty() or bridge_scene == null or car == null:
		push_error("Main: Критические ресурсы не назначены в Инспекторе!")
		return

	_forward = forward_axis.normalized()
	if _forward.length_squared() < 0.001:
		_forward = Vector3.BACK
	_chunk_step = maxf(chunk_length, 1.0)

	_cleanup_preplaced_chunks()
	var car_index: int = _get_chunk_index(_distance_along_forward(car.global_position))
	_ensure_chunks_for_index(car_index)
	_last_checked_distance = float(car_index)

func _process(delta: float) -> void:
	if car == null or chunk_scenes_list.is_empty():
		return
		
	var distance: float = _distance_along_forward(car.global_position)
	var current_chunk_index: int = _get_chunk_index(distance)
	
	var passed_500m_steps: int = floori(absf(distance) / 500.0)
	current_spawn_cooldown = maxf(base_spawn_cooldown - (passed_500m_steps * 0.1), 0.25)
	spawn_timer += delta
	if spawn_timer >= current_spawn_cooldown:
		spawn_timer = 0.0
		_spawn_single_zombie_ahead()
	
	var zone_index: int = floor(abs(distance) / 20000.0)
	var is_in_red_zone: bool = (zone_index % 2 == 1)
	
	if is_in_red_zone and not is_fog_red:
		is_fog_red = true
		_transition_fog(0.5) 
		
	elif not is_in_red_zone and is_fog_red:
		is_fog_red = false
		_transition_fog(2.0)
		
	if current_chunk_index == int(_last_checked_distance):
		return 

	_last_checked_distance = float(current_chunk_index)
	_ensure_chunks_for_index(current_chunk_index)

func _ensure_chunks_for_index(current_index: int) -> void:
	var min_index: int = current_index - maxi(chunks_behind, 1)
	var max_index: int = current_index + maxi(chunks_ahead, 2)

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
	var abs_index: int = abs(index)
	
	var chunks_per_bridge: int = floori(bridge_interval_meters / _chunk_step)
	if chunks_per_bridge <= 0: chunks_per_bridge = 6

	var is_bridge: bool = (abs_index > 0 and abs_index % chunks_per_bridge == 0)

	if is_bridge:
		if bridge_scene != null:
			chunk = bridge_scene.instantiate() as Node3D
		else:
			push_error("Main: bridge_scene is null!")
			return
	else:
		var list_size: int = chunk_scenes_list.size()
		if list_size == 0:
			push_error("Main: chunk_scenes_list is empty!")
			return
			
		var calculated_biome: int = fposmod(floori(float(abs_index) / float(chunks_per_bridge)), list_size)
		var scene_to_spawn: PackedScene = chunk_scenes_list[calculated_biome]
		
		if scene_to_spawn == null:
			push_error("Main: chunk_scenes_list[%d] is null! Проверьте, что в массиве в Инспекторе нет пустых слотов." % calculated_biome)
			# Попытка найти первый непустой элемент как запасной вариант, чтобы игра не крашилась
			for s in chunk_scenes_list:
				if s != null:
					scene_to_spawn = s
					break
					
		if scene_to_spawn != null:
			chunk = scene_to_spawn.instantiate() as Node3D
		else:
			push_error("Main: Не удалось найти валидную сцену чанка для спавна.")
			return

	if chunk == null: return

	var chunk_z_pos: float = _chunk_step * float(index)
	
	var how_many_bridges_passed: int = floori(float(abs_index) / float(chunks_per_bridge))
	if abs_index % chunks_per_bridge == 0 and abs_index > 0:
		how_many_bridges_passed -= 1
		
	chunk_z_pos -= float(how_many_bridges_passed) * 0.0

	var chunk_origin: Vector3 = world_origin + _forward * chunk_z_pos
	var chunk_basis: Basis = Basis.looking_at(_forward, Vector3.UP)
	
	add_child(chunk)
	chunk.global_transform = Transform3D(chunk_basis, Vector3(chunk_origin.x, road_y, chunk_origin.z))

	if chunk.has_method("configure_chunk"):
		chunk.call("configure_chunk", chunk_width, chunk_length, chunk_thickness, road_y)

	if chunk.has_method("init_chunk_zombies"):
		chunk.call("init_chunk_zombies")

	_chunk_nodes[index] = chunk

func _spawn_single_zombie_ahead() -> void:
	var safe_fog_distance: float = 320.0
	
	var spawn_pos: Vector3 = car.global_position + _forward * safe_fog_distance
	
	spawn_pos.x += randf_range(-road_spawn_width, road_spawn_width)
	
	spawn_pos.y = road_y
	
	ZombiePool.spawn_zombie_at(spawn_pos)

func advance_to_next_biome() -> void:
	pass

func _cleanup_preplaced_chunks() -> void:
	for child in get_children():
		if child == car: continue
		if child.name.to_lower().contains("chunk") or child.name.to_lower().contains("bridge"):
			child.queue_free()

func _distance_along_forward(world_position: Vector3) -> float:
	return (world_position - world_origin).dot(_forward)

func _get_chunk_index(distance_along_forward: float) -> int:
	return int(floor(distance_along_forward / _chunk_step))
	
func _transition_fog(target_energy: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return
		
	if not world_environment.environment.resource_local_to_scene:
		world_environment.environment = world_environment.environment.duplicate()
		
	var env: Environment = world_environment.environment
	env.fog_enabled = true
	
	if current_fog_tween:
		current_fog_tween.kill()
		
	current_fog_tween = create_tween()
	
	current_fog_tween.tween_property(env, "fog_light_energy", target_energy, 1.5)
