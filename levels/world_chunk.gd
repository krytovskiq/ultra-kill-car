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

@onready var _collision_shape: CollisionShape3D = $GroundBody/CollisionShape3D
@onready var _mesh_instance: MeshInstance3D = $GroundBody/MeshInstance3D

func _ready() -> void:
	_apply_chunk_geometry()
	
	global_distance_counter += chunk_length 
	if global_distance_counter >= barn_interval:
		spawn_barn(self)
		global_distance_counter = 0.0 

# Метод пустой, чтобы main.gd не ругался при спавне чанков
func init_chunk_zombies() -> void:
	pass

func configure_chunk(c_width: float, c_length: float, c_thickness: float, c_road_y: float) -> void:
	self.chunk_width = c_width
	self.chunk_length = c_length
	self.chunk_thickness = c_thickness
	self.surface_y = c_road_y
	
	_apply_chunk_geometry()
	
	# Если это стартовый кусок (близко к z=0), не спавним препятствия перед носом
	if abs(global_position.z) < 150.0:
		return
		
	_spawn_random_objects()


func _apply_chunk_geometry() -> void:
	if _collision_shape:
		if not _collision_shape.shape: _collision_shape.shape = BoxShape3D.new()
		else: _collision_shape.shape = _collision_shape.shape.duplicate()
		var shape_res := _collision_shape.shape as BoxShape3D
		shape_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_collision_shape.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

	if _mesh_instance:
		if not _mesh_instance.mesh: _mesh_instance.mesh = BoxMesh.new()
		else: _mesh_instance.mesh = _mesh_instance.mesh.duplicate()
		var mesh_res := _mesh_instance.mesh as BoxMesh
		mesh_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_mesh_instance.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

func _spawn_random_objects() -> void:
	var objects: Array[PackedScene] = []
	if object1: objects.append(object1)
	if object2: objects.append(object2)
	if object3: objects.append(object3)
	if object4: objects.append(object4)
	if object5: objects.append(object5)
	if object6: objects.append(object6)
	if objects.is_empty(): return

	var objects_to_spawn: int = randi_range(20, 30) 
	for i in range(objects_to_spawn): 
		var instance: Node3D = objects.pick_random().instantiate() as Node3D
		add_child(instance)
		var random_x: float = randf_range(-chunk_width / 3.0, chunk_width / 3.0)
		var random_z: float = randf_range(-chunk_length / 2.5, chunk_length / 2.5)
		instance.position = Vector3(random_x, surface_y, random_z)
		instance.rotation.y = randf_range(0.0, TAU)

func spawn_barn(parent_chunk: Node3D) -> void:
	if not barn_scene: return 
	var barn: Node3D = barn_scene.instantiate() as Node3D
	parent_chunk.add_child(barn)
	barn.position = Vector3(0.0, 0.1, 0.0) 
	barn.rotation = Vector3.ZERO

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	pass # Делегируем удаление чанков main.gd по дистанции, чтобы чанк не исчезал, если игрок просто отвернулся


func _on_exit_pressed() -> void:
	get_tree().quit()
