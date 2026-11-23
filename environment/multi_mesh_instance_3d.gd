extends MultiMeshInstance3D

@export var total_trees: int = 800
@export var area_width: float = 350.0
@export var area_depth: float = 500.0
@export var road_width: float = 250.0

func _ready() -> void:
	if multimesh == null:
		return
	multimesh = multimesh.duplicate()

	var quality_ratio: float = SettingsManager.get_prop_density()

	var actual_count := maxi(roundi(float(total_trees) * quality_ratio), 0)
	multimesh.instance_count = actual_count

	var min_x := road_width * 0.5
	var max_x := maxf(area_width * 0.5, min_x + 1.0)
	var half_depth := area_depth * 0.5

	for i in range(actual_count):
		var side := -1.0 if randf() < 0.5 else 1.0
		var pos := Vector3(
			side * randf_range(min_x, max_x),
			0.0,
			randf_range(-half_depth, half_depth)
		)

		var t := Transform3D()
		t = t.scaled(Vector3.ONE * randf_range(0.8, 1.5))
		t = t.rotated(Vector3(1, 0, 0), deg_to_rad(-90))
		t = t.rotated(Vector3(0, 1, 0), randf_range(0, TAU))
		t.origin = pos

		multimesh.set_instance_transform(i, t)
