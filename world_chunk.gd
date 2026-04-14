extends Node3D

@export_group("Размеры чанка")
@export var chunk_width: float = 75.0
@export var chunk_length: float = 120.0
@export var chunk_thickness: float = 8.0
@export var surface_y: float = 0.0

@export var zombie_scene: PackedScene # Сюда перетащи Zombie.tscn в инспекторе
@export var zombie_count: int = 2      # Сколько зомби на один кусок дороги

@onready var _collision_shape: CollisionShape3D = $GroundBody/CollisionShape3D
@onready var _mesh_instance: MeshInstance3D = $GroundBody/MeshInstance3D
@onready var _exit_point: Marker3D = $ExitPoint

@export_group("Декорации")
@export var object1: PackedScene 
@export var object2: PackedScene
@export var object3: PackedScene
@export var spawn_chance: float = 0.5 # Шанс появления объекта на чанке
@export var object_scale: float = 0.009

func _ready() -> void:
	# Чтобы твои правки из инспектора применились при старте
	_apply_chunk_geometry()
	spawn_zombies() # Вызываем спавн при появлении чанка
	_spawn_random_objects()
func spawn_zombies():
	if not zombie_scene: return
	
	for i in range(zombie_count):
		var zombie = zombie_scene.instantiate()
		add_child(zombie)
		
		# --- ВОТ ЭТА СТРОЧКА УМЕНЬШАЕТ ЗОМБИ ---
		# (0.3, 0.3, 0.3) — это 30% от оригинального размера. Подбери число под себя.
		zombie.scale = Vector3(0.028, 0.028, 0.028) 
		
		# Генерируем случайную позицию на полотне дороги
		var random_x = randf_range(-chunk_width / 2.5, chunk_width / 2.5)
		var random_z = randf_range(-chunk_length / 2.0, chunk_length / 2.0)
		
		# Ставим зомби на поверхность (surface_y)
		# Прибавляем 0.5 к высоте, чтобы они не спавнились "по пояс" в земле
		zombie.position = Vector3(random_x, surface_y + 0.5, random_z)

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

	# 3. Точка стыковки (МАКСИМАЛЬНО ВАЖНО)
	if _exit_point:
		# Ставим маркер ровно на границу чанка. 
		# Т.к. центр в 0, край будет на ДЛИНА / 2
		_exit_point.position = Vector3(0.0, surface_y, -chunk_length / 2.0)
		
func _spawn_random_objects():
	if randf() > spawn_chance:
		return
	
	var objects = []
	if object1: objects.append(object1)
	if object2: objects.append(object2)
	if object3: objects.append(object3)
	
	if objects.is_empty():
		return
		
	var selected_scene = objects.pick_random()
	var instance = selected_scene.instantiate()
	add_child(instance)
	
	# --- ВОТ ЭТА СТРОЧКА УМЕНЬШАЕТ ОБЪЕКТ ---
	instance.scale = Vector3(object_scale, object_scale, object_scale)
	
	var random_x = randf_range(-chunk_width / 3.0, chunk_width / 3.0)
	var random_z = randf_range(-chunk_length / 2.5, chunk_length / 2.5)
	
	# Не забудь чуть приподнять по Y (например +0.5), 
	# если объекты спавнятся наполовину в земле из-за уменьшения
	instance.position = Vector3(random_x, surface_y, random_z)
	instance.rotation.y = randf_range(0, TAU)
