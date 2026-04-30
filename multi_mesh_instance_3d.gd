extends MultiMeshInstance3D

@export var total_trees: int = 1400       # Общее количество деревьев
@export var area_width: float = 250.0    # Ширина всего поля
@export var area_depth: float = 120.0    # Длина поля (вглубь)
@export var road_width: float = 150.0     # Ширина дороги (где деревьев НЕ будет)

func _ready():
	multimesh.instance_count = total_trees
	
	for i in range(total_trees):
		var pos = Vector3.ZERO
		
		# Генерируем позицию, пока она попадает на дорогу
		while true:
			pos.x = randf_range(-area_width / 2, area_width / 2)
			if abs(pos.x) > road_width / 2: # Если дерево НЕ на дороге
				break
		
		pos.z = randf_range(0, -area_depth) # Распределяем вглубь
		
		var t = Transform3D()
		t = t.scaled(Vector3.ONE * randf_range(0.8, 1.5))
		# 1. Исправляем "лежачее" положение (подбери угол 90 или -90)
		t = t.rotated(Vector3(1, 0, 0), deg_to_rad(-90)) 
		
		# 2. Рандомный поворот вокруг своей оси (чтобы не были одинаковыми)
		t = t.rotated(Vector3(0, 1, 0), randf_range(0, TAU))
		
		# 3. Устанавливаем позицию
		t.origin = pos
		
		multimesh.set_instance_transform(i, t)
