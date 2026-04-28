extends Node3D
static var global_distance_counter: float = 0.0

@export_group("Размеры чанка")
@export var chunk_width: float = 150.0
@export var chunk_length: float = 120.0
@export var chunk_thickness: float = 8.0
@export var surface_y: float = 0.0

@export var zombie_scene: PackedScene # Сюда перетащи Zombie.tscn в инспекторе
@export var zombie_count: int = 10     # Сколько зомби на один кусок дороги

@export var barn_scene: PackedScene # Сцена амбара
@export var barn_interval: float = 800.0 # Интервал в метрах

@onready var _collision_shape: CollisionShape3D = $GroundBody/CollisionShape3D
@onready var _mesh_instance: MeshInstance3D = $GroundBody/MeshInstance3D

@export_group("Декорации")
@export var object1: PackedScene 
@export var object2: PackedScene
@export var object3: PackedScene
@export var object4: PackedScene


func _ready() -> void:
	var notifier = VisibleOnScreenNotifier3D.new()
	# Настраиваем размер зоны видимости (чуть больше самого чанка)
	notifier.aabb = AABB(Vector3(-chunk_width/2, -5, -chunk_length/2), Vector3(chunk_width, 10, chunk_length))
	add_child(notifier)
	notifier.screen_exited.connect(_on_visible_on_screen_notifier_3d_screen_exited)
	_apply_chunk_geometry()
	spawn_zombies()
	_spawn_random_objects()
	global_distance_counter += chunk_length # Прибавляем длину чанка к счетчику
	if global_distance_counter >= barn_interval:
		spawn_barn(self)
		global_distance_counter = 0.0 

func spawn_zombies():
	if not zombie_scene: return
	for i in range(zombie_count):
		var zombie = zombie_scene.instantiate()
		zombie.scale = Vector3(0.03, 0.03, 0.03) 
		add_child(zombie)
		
		# Генерируем случайную позицию на полотне дороги
		var random_x = randf_range(-chunk_width / 2.5, chunk_width / 2.5)
		var random_z = randf_range(-chunk_length / 2.0, chunk_length / 2.0)
		
		# Ставим зомби на поверхность (surface_y)
		# Прибавляем 0.5 к высоте, чтобы они не спавнились "по пояс" в земле
		zombie.position = Vector3(random_x, surface_y + 1.5, random_z)

func _apply_chunk_geometry() -> void:
	# 1. Настройка коллизии (физический пол)
	if _collision_shape:
		# Делаем ресурс уникальным, чтобы чанки не слипались
		if _collision_shape.shape:
			_collision_shape.shape = _collision_shape.shape.duplicate()
		
		var shape_res = _collision_shape.shape as BoxShape3D
		if shape_res == null:
			shape_res = BoxShape3D.new()
			_collision_shape.shape = shape_res
		
		shape_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		# Центрируем коллизию, чтобы верх был на surface_y
		_collision_shape.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

	# 2. Настройка визуала (то, что мы видим)
	if _mesh_instance:
		# Тоже делаем меш уникальным
		if _mesh_instance.mesh:
			_mesh_instance.mesh = _mesh_instance.mesh.duplicate()
			
		var mesh_res = _mesh_instance.mesh as BoxMesh
		if mesh_res == null:
			mesh_res = BoxMesh.new()
			_mesh_instance.mesh = mesh_res
		
		# Делаем меш ТАКИМ ЖЕ по размеру, как коллизия, чтобы не было обмана зрения
		mesh_res.size = Vector3(chunk_width, chunk_thickness, chunk_length)
		_mesh_instance.position = Vector3(0.0, surface_y - chunk_thickness * 0.5, 0.0)

func _spawn_random_objects():
	var objects_to_spawn = randi_range(3, 6) # Случайное число объектов от 3 до 6
	
	var objects = []
	if object1: objects.append(object1)
	if object2: objects.append(object2)
	if object3: objects.append(object3)
	if object4: objects.append(object4)
	
	if objects.is_empty(): return

	for i in range(objects_to_spawn): # Запускаем цикл
		var selected_scene = objects.pick_random()
		var instance = selected_scene.instantiate()
		add_child(instance)
		
		var random_x = randf_range(-chunk_width / 3.0, chunk_width / 3.0)
		var random_z = randf_range(-chunk_length / 2.5, chunk_length / 2.5)
		
		instance.position = Vector3(random_x, surface_y, random_z)
		instance.rotation.y = randf_range(0, TAU)
	print("Объект заспавнен аналогично амбару!")

func spawn_barn(parent_chunk: Node3D):
	if not barn_scene: return # Защита от вылета
	var barn = barn_scene.instantiate()
	parent_chunk.add_child(barn)
	# Приподнимаем на 0.1, чтобы не было мерцания текстур пола
	barn.position = Vector3(0, 0.1, 0) 
	barn.rotation = Vector3.ZERO
	print("Амбар заспавнен!")

func _on_visible_on_screen_notifier_3d_screen_exited() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Считаем расстояние между машиной и этим чанком
		var dist = global_position.distance_to(player.global_position)
		
		# Если машина уехала дальше чем на 200 метров — удаляем чанк
		# (200 метров достаточно, чтобы игрок не видел исчезновения)
		if dist > 50.0:
			queue_free()
