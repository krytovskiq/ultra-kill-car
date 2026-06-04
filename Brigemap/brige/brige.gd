extends Node3D

static var global_distance_counter: float = 0.0

@export_group("Размеры чанка")
@export var chunk_width: float = 380.0
@export var chunk_length: float = 330.0
@export var chunk_thickness: float = 80.0
@export var surface_y: float = 0.0

@export var zombie_scene: PackedScene 
@export var zombie_count: int = 10     

var my_zombies: Array[Node3D] = []

@export var barn_scene: PackedScene 
@export var barn_interval: float = 1300.0 

@onready var _collision_shape: CollisionShape3D = $GroundBody/CollisionShape3D
@onready var _mesh_instance: MeshInstance3D = $GroundBody/MeshInstance3D

@export_group("Декорации")
@export var object1: PackedScene 
@export var object2: PackedScene
@export var object3: PackedScene
@export var object4: PackedScene
@export var object5: PackedScene

# --- НАСТРОЙКИ MULTIMESH ФОНА ГОРОДА ---
@export_group("Фон Города (MultiMesh)")
@export var building_mesh: Mesh                 # Перетащи сюда 3D-модель здания
@export var buildings_count: int = 400          # Количество домов
@export var background_depth: float = 250.0     # Как далеко вбок уходит город

var _is_trigger_activated: bool = false

func _ready() -> void:
	_apply_chunk_geometry()
	_spawn_random_objects()
	
	# Если в инспекторе чанка выбрана модель здания, генерируем город
	if building_mesh:
		_generate_simple_multimesh_city()
	
	global_distance_counter += chunk_length 
	if global_distance_counter >= barn_interval:
		spawn_barn(self)
		global_distance_counter = 0.0 
		
	# НАДЕЖНЫЙ ПОИСК: Ищем Area3D на сцене моста, даже если она внутри Bridge_007
	var trigger = find_child("Area3D", true, false)
	if trigger and trigger is Area3D:
		trigger.body_entered.connect(_on_car_entered_trigger)

# Функция для генерации города по бокам через MultiMesh
func _generate_simple_multimesh_city() -> void:
	var mm_instance = MultiMeshInstance3D.new()
	add_child(mm_instance)
	mm_instance.position = Vector3.ZERO
	
	var mm_res = MultiMesh.new()
	mm_res.transform_format = MultiMesh.TRANSFORM_3D
	mm_res.mesh = building_mesh
	mm_res.instance_count = buildings_count
	mm_instance.multimesh = mm_res
	
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	for i in range(buildings_count):
		var side = -1 if rng.randf() < 0.5 else 1
		var pos_x = side * rng.randf_range(chunk_width / 2.0, chunk_width / 2.0 + background_depth)
		var pos_z = rng.randf_range(-chunk_length / 2.0, chunk_length / 2.0)
		var pos_y = rng.randf_range(-5.0, surface_y)
		var position = Vector3(pos_x, pos_y, pos_z)
		
		var scale_x = rng.randf_range(1.0, 2.5)
		var max_height = 28.0 if abs(pos_x) > (chunk_width / 2.0 + 40.0) else 10.0
		var scale_y = rng.randf_range(4.0, max_height)
		var scale_z = rng.randf_range(1.0, 2.5)
		
		var t = Transform3D()
		t = t.scaled(Vector3(scale_x, scale_y, scale_z))
		t = t.rotated(Vector3(0, 1, 0), rng.randf_range(0, TAU)) 
		t = t.rotated(Vector3(1, 0, 0), rng.randf_range(-0.12, 0.12)) 
		t = t.rotated(Vector3(0, 0, 1), rng.randf_range(-0.12, 0.12)) 
		t.origin = position
		
		mm_res.set_instance_transform(i, t)

# Срабатывает автоматически, когда машина проезжает через Area3D
func _on_car_entered_trigger(body: Node3D) -> void:
	if _is_trigger_activated:
		return
		
	# Проверяем, что коснулся именно игрок (машина)
	if body.is_in_group("player") or body is VehicleBody3D:
		_is_trigger_activated = true
		
		# Отправляем команду в main.gd на спавн следующего куска дороги
		var main_script = get_parent()
		if main_script and main_script.has_method("spawn_next_chunk_from_trigger"):
			main_script.call("spawn_next_chunk_from_trigger")
			
			# Удаляем саму форму триггера, чтобы он больше физически не работал
			var shape = find_child("CollisionShape3D", true, false)
			if is_instance_valid(shape):
				shape.queue_free()

func init_chunk_zombies() -> void:
	await get_tree().physics_frame
	spawn_zombies()

func spawn_zombies():
	for i in range(zombie_count):
		var random_x = randf_range(-chunk_width / 2.5, chunk_width / 2.5)
		var random_z = randf_range(-chunk_length / 2.0, chunk_length / 2.0)
		var spawn_pos = global_position + Vector3(random_x, surface_y, random_z)
		
		var zombie = ZombiePool.spawn_zombie_at(spawn_pos)
		if zombie:
			zombie.scale = Vector3(1.0, 1.0, 1.0)
			if not my_zombies.has(zombie):
				my_zombies.append(zombie)

func _apply_chunk_geometry() -> void:
	if _collision_shape:
		if _collision_shape.shape:
			_collision_shape.shape = _collision_shape.shape.duplicate()
		var shape_res = _collision_shape.shape as BoxShape3D
		if shape_res == null:
			shape_res = BoxShape3D.new()
			_collision_shape.shape = shape_res
		shape_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_collision_shape.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

	if _mesh_instance:
		if _mesh_instance.mesh:
			_mesh_instance.mesh = _mesh_instance.mesh.duplicate()
		var mesh_res = _mesh_instance.mesh as BoxMesh
		if mesh_res == null:
			mesh_res = BoxMesh.new()
			_mesh_instance.mesh = mesh_res
		mesh_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_mesh_instance.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

func _spawn_random_objects():
	var objects_to_spawn = randi_range(20, 30)
	var objects = []
	if object1: objects.append(object1)
	if object2: objects.append(object2)
	if object3: objects.append(object3)
	if object4: objects.append(object4)
	if object5: objects.append(object5)
	
	if objects.is_empty(): return

	for i in range(objects_to_spawn):
		var selected_scene = objects.pick_random()
		var instance = selected_scene.instantiate()
		add_child(instance)
		
		var random_x = randf_range(-chunk_width / 3.0, chunk_width / 3.0)
		var random_z = randf_range(-chunk_length / 2.5, chunk_length / 2.5)
		
		instance.position = Vector3(random_x, surface_y, random_z)
		instance.rotation.y = randf_range(0, TAU)
	print("Обьект создан")

func spawn_barn(parent_chunk: Node3D):
	if not barn_scene: return
	var barn = barn_scene.instantiate()
	parent_chunk.add_child(barn)
	barn.position = Vector3(0, 0.1, 0) 
	barn.rotation = Vector3.ZERO
	print("Амбар заспавнен!")

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	for zombie in my_zombies:
		if is_instance_valid(zombie):
			ZombiePool.return_zombie(zombie)
	my_zombies.clear()
	queue_free()

func _exit_tree() -> void:
	_clear_and_return_zombies()

func _clear_and_return_zombies() -> void:
	for zombie in my_zombies:
		if is_instance_valid(zombie):
			ZombiePool.return_zombie(zombie)
	my_zombies.clear()
