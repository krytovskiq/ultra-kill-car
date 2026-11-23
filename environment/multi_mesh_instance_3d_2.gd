extends MultiMeshInstance3D

@export var total_trees: int = 1400       # Общее количество деревьев
@export var area_width: float = 150.0    # Ширина всего поля
@export var area_depth: float = 120.0    # Длина поля (вглубь)
@export var road_width: float = 0.0      # Ширина дороги (где деревьев НЕ будет)

func _ready() -> void:
	if multimesh == null:
		return
	multimesh = multimesh.duplicate()
	multimesh.instance_count = total_trees

	var min_x := road_width * 0.5
	var max_x := maxf(area_width * 0.5, min_x + 1.0)

	for i in range(total_trees):
		var side := -1.0 if randf() < 0.5 else 1.0
		var pos := Vector3(
			side * randf_range(min_x, max_x),
			0.0,
			randf_range(0.0, -area_depth)
		)

		var t := Transform3D()
		t = t.scaled(Vector3.ONE * randf_range(0.8, 1.5))
		t = t.rotated(Vector3(1, 0, 0), deg_to_rad(0))
		t = t.rotated(Vector3(0, 1, 0), randf_range(0, TAU))
		t.origin = pos

		multimesh.set_instance_transform(i, t)
