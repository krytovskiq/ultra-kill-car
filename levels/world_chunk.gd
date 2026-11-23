extends Node3D

static var global_distance_counter: float = 0.0

@export_group("Размеры чанка")
@export var chunk_width: float = 380.0
@export var chunk_length: float = 500.0
@export var chunk_thickness: float = 45.0
@export var surface_y: float = 0.0

@export_group("Окружение")
@export var barn_scene: PackedScene
@export var barn_interval: float = 1300.0

@export_group("Декорации")
@export var object1: PackedScene
@export var object2: PackedScene
@export var object3: PackedScene
@export var object4: PackedScene
@export var object5: PackedScene
@export var object6: PackedScene

@onready var _collision_shape: CollisionShape3D = get_node_or_null("GroundBody/CollisionShape3D")
@onready var _mesh_instance: MeshInstance3D = get_node_or_null("GroundBody/MeshInstance3D")

var _geometry_configured: bool = false

func _ready() -> void:
	_apply_chunk_geometry()

# Метод пустой для совместимости с main.gd
func init_chunk_zombies() -> void:
	pass

func configure_chunk(c_width: float, c_length: float, c_thickness: float, c_road_y: float, skip_landing_zone: bool = false) -> void:
	chunk_width = c_width
	chunk_length = c_length
	chunk_thickness = c_thickness
	surface_y = c_road_y

	_apply_chunk_geometry()

	# На стартовом куске (близко к z=0) не спавним препятствия перед носом
	if absf(global_position.z) < 150.0:
		return

	_spawn_random_objects(skip_landing_zone)

func _apply_chunk_geometry() -> void:
	if _collision_shape:
		if not _geometry_configured:
			if not _collision_shape.shape:
				_collision_shape.shape = BoxShape3D.new()
			else:
				_collision_shape.shape = _collision_shape.shape.duplicate()
		var shape_res := _collision_shape.shape as BoxShape3D
		if shape_res:
			shape_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_collision_shape.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

	if _mesh_instance:
		if not _geometry_configured:
			if not _mesh_instance.mesh:
				_mesh_instance.mesh = BoxMesh.new()
			else:
				_mesh_instance.mesh = _mesh_instance.mesh.duplicate()
		var mesh_res := _mesh_instance.mesh as BoxMesh
		if mesh_res:
			mesh_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_mesh_instance.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

	_geometry_configured = true

func _spawn_random_objects(skip_landing_zone: bool = false) -> void:
	var objects: Array[PackedScene] = []
	for obj in [object1, object2, object3, object4, object5, object6]:
		if obj != null:
			objects.append(obj)
	if objects.is_empty():
		return

	var objects_to_spawn: int = randi_range(20, 30)
	var min_z := -chunk_length / 2.5
	var max_z := chunk_length / 2.5
	# При выезде с моста (чанк повернут на 180°, локальный +Z смотрит в -Z мира) оставляем зону приземления чистой
	if skip_landing_zone:
		max_z = minf(max_z, chunk_length * 0.25)

	for i in range(objects_to_spawn):
		var random_x: float = randf_range(-chunk_width / 3.0, chunk_width / 3.0)
		var random_z: float = randf_range(min_z, max_z)

		var instance := objects.pick_random().instantiate() as Node3D
		if instance == null:
			continue
		add_child(instance)
		instance.position = Vector3(random_x, surface_y, random_z)
		instance.rotation.y = randf_range(0.0, TAU)

func spawn_barn(_parent_chunk: Node3D) -> void:
	pass

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	pass # Делегируем удаление чанков main.gd по дистанции

func _on_exit_pressed() -> void:
	get_tree().quit()
