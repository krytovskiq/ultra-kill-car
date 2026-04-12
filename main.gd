extends Node3D

@export var chunk_scene: PackedScene
@export var car: VehicleBody3D

@export_group("World Generation")
@export var chunks_ahead: int = 10
@export var chunks_behind: int = 2
@export var update_distance: float = 30.0
@export var chunk_width: float = 44.0
@export var chunk_length: float = 120.0
@export var chunk_thickness: float = 8.0
@export var road_y: float = 0.0
@export var world_origin: Vector3 = Vector3.ZERO
@export var forward_axis: Vector3 = Vector3.BACK

@export_group("Debug")
@export var verbose_logs: bool = false

var _forward: Vector3 = Vector3.BACK
var _chunk_step: float = 120.0
var _chunk_nodes: Dictionary = {}
var _last_checked_distance: float = -INF


func _ready() -> void:
	_resolve_car()
	if chunk_scene == null:
		push_error("Main: chunk_scene не назначен.")
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
	_last_checked_distance = _distance_along_forward(car.global_position)


func _process(_delta: float) -> void:
	if car == null or chunk_scene == null:
		return

	var distance := _distance_along_forward(car.global_position)
	if absf(distance - _last_checked_distance) < update_distance:
		return

	_last_checked_distance = distance
	_ensure_chunks_for_index(_get_chunk_index(distance))


func _resolve_car() -> void:
	if car != null:
		return
	car = get_node_or_null("car") as VehicleBody3D
	if car == null:
		car = get_tree().get_first_node_in_group("player") as VehicleBody3D


func _ensure_chunks_for_index(current_index: int) -> void:
	var min_index: int = current_index - maxi(chunks_behind, 0)
	var max_index: int = current_index + maxi(chunks_ahead, 1)

	for index in range(min_index, max_index + 1):
		if not _chunk_nodes.has(index):
			_spawn_chunk(index)

	var remove_list: Array[int] = []
	for key in _chunk_nodes.keys():
		var index := int(key)
		if index < min_index or index > max_index:
			remove_list.append(index)

	for index in remove_list:
		var chunk: Node = _chunk_nodes[index]
		if is_instance_valid(chunk):
			chunk.queue_free()
		_chunk_nodes.erase(index)


func _spawn_chunk(index: int) -> void:
	var chunk := chunk_scene.instantiate() as Node3D
	if chunk == null:
		push_error("Main: chunk_scene должен быть Node3D-сценой.")
		return

	var chunk_origin := world_origin + _forward * (_chunk_step * float(index))
	var chunk_basis := Basis.looking_at(_forward, Vector3.UP)
	add_child(chunk)
	chunk.global_transform = Transform3D(chunk_basis, Vector3(chunk_origin.x, road_y, chunk_origin.z))

	if chunk.has_method("configure_chunk"):
		chunk.call("configure_chunk", chunk_width, chunk_length, chunk_thickness, road_y)

	_chunk_nodes[index] = chunk
	if verbose_logs:
		print("Chunk ", index, " @ ", chunk.global_position)


func _cleanup_preplaced_chunks() -> void:
	if chunk_scene == null:
		return
	var chunk_scene_path := chunk_scene.resource_path
	if chunk_scene_path.is_empty():
		return

	for child in get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node == car:
			continue
		if child_node.scene_file_path == chunk_scene_path:
			child_node.queue_free()


func _distance_along_forward(world_position: Vector3) -> float:
	return (world_position - world_origin).dot(_forward)


func _get_chunk_index(distance_along_forward: float) -> int:
	return int(floor(distance_along_forward / _chunk_step))
