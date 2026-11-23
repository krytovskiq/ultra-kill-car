extends Node3D

const ProceduralMaterials = preload("res://levels/procedural_materials.gd")
const KnockablePropScript = preload("res://levels/knockable_prop.gd")

static var _cached_ocean_mesh: PlaneMesh = null
static var _cached_pier_mesh: BoxMesh = null
static var _cached_crossbeam_mesh: BoxMesh = null
static var _cached_rock_mesh: SphereMesh = null

func _ready() -> void:
	_build_animated_ocean()
	_build_bridge_piers()
	_build_coastal_banks_and_rocks()
	_replace_coastal_barriers_with_fences()

func _build_animated_ocean() -> void:
	if _cached_ocean_mesh == null:
		_cached_ocean_mesh = PlaneMesh.new()
		# Wide & long ocean sheet extending cleanly beneath sloped biome coastal cliffs on both ends
		_cached_ocean_mesh.size = Vector2(2400.0, 620.0)
		_cached_ocean_mesh.subdivide_width = 140
		_cached_ocean_mesh.subdivide_depth = 104

	var ocean_mi := MeshInstance3D.new()
	ocean_mi.name = "AnimatedOceanSurface"
	ocean_mi.mesh = _cached_ocean_mesh
	ocean_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean_mi.extra_cull_margin = 24.0
	var ocean_mat: Material = ProceduralMaterials.get_material("ocean_water")
	if ocean_mat is ShaderMaterial:
		(ocean_mat as ShaderMaterial).set_shader_parameter("shore_z_half_span", 268.0)
	ocean_mi.material_override = ocean_mat
	ocean_mi.position = Vector3(0.0, -12.4, 22.0)
	add_child(ocean_mi)

func _build_bridge_piers() -> void:
	if _cached_pier_mesh == null:
		_cached_pier_mesh = BoxMesh.new()
		_cached_pier_mesh.size = Vector3(3.2, 16.5, 4.0)
	if _cached_crossbeam_mesh == null:
		_cached_crossbeam_mesh = BoxMesh.new()
		_cached_crossbeam_mesh.size = Vector3(17.2, 2.6, 3.6)

	var concrete_mat: Material = ProceduralMaterials.get_material("concrete_rubble")
	var pier_z_coords: Array[float] = [-122.4, -56.6, 9.1, 74.9, 140.7]

	var piers_root := Node3D.new()
	piers_root.name = "BridgeOceanPiers"
	add_child(piers_root)

	for z_pos: float in pier_z_coords:
		for side: float in [-1.0, 1.0]:
			var pier := MeshInstance3D.new()
			pier.mesh = _cached_pier_mesh
			pier.material_override = concrete_mat
			pier.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pier.position = Vector3(side * 6.6, -11.8, z_pos)
			piers_root.add_child(pier)

		var beam := MeshInstance3D.new()
		beam.mesh = _cached_crossbeam_mesh
		beam.material_override = concrete_mat
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.position = Vector3(0.0, -5.2, z_pos)
		piers_root.add_child(beam)

func _build_coastal_banks_and_rocks() -> void:
	if _cached_rock_mesh == null:
		_cached_rock_mesh = SphereMesh.new()
		_cached_rock_mesh.radius = 6.5
		_cached_rock_mesh.height = 9.0
		_cached_rock_mesh.radial_segments = 10
		_cached_rock_mesh.rings = 6

	var rock_mat: Material = ProceduralMaterials.get_material("rock")
	var moss_mat: Material = ProceduralMaterials.get_material("mossy_rock")

	var banks_root := Node3D.new()
	banks_root.name = "OceanCoastalBanks"
	add_child(banks_root)

	# Coastal sea-stacks and rocks emerging organically from ocean waves outside highway |X| >= 24.0
	var rock_spots: Array[Vector3] = [
		Vector3(-42.0, -11.2, -165.0),
		Vector3(48.0, -11.0, -145.0),
		Vector3(-68.0, -10.8, -45.0),
		Vector3(64.0, -11.4, 25.0),
		Vector3(-52.0, -11.0, 118.0),
		Vector3(56.0, -10.9, 160.0),
		Vector3(-30.0, -11.4, 224.0),
		Vector3(32.0, -11.3, -182.0),
		Vector3(-28.0, -11.3, -180.0),
		Vector3(34.0, -11.2, 222.0),
	]
	for i in range(rock_spots.size()):
		var r_mi := MeshInstance3D.new()
		r_mi.mesh = _cached_rock_mesh
		r_mi.material_override = moss_mat if (i % 2) == 0 else rock_mat
		r_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		r_mi.position = rock_spots[i]
		r_mi.scale = Vector3(1.55 + float(i % 3) * 0.40, 0.72 + float(i % 2) * 0.24, 1.35 + float((i + 1) % 3) * 0.35)
		r_mi.rotation.y = float(i) * 1.15
		banks_root.add_child(r_mi)


func _replace_coastal_barriers_with_fences() -> void:
	var old_barriers: Array[Node3D] = []
	for ch in get_children():
		if ch is Node3D and String(ch.name).begins_with("Barrier"):
			old_barriers.append(ch as Node3D)
	if old_barriers.is_empty():
		return

	var mesh_stop: ArrayMesh = ProceduralMaterials.get_bridge_stop_fence_mesh(true)
	var mesh_plain: ArrayMesh = ProceduralMaterials.get_bridge_stop_fence_mesh(false)
	var dist_stop_xforms: Array[Transform3D] = []
	var dist_plain_xforms: Array[Transform3D] = []

	var fence_shape := BoxShape3D.new()
	fence_shape.size = Vector3(3.85, 2.48, 0.50)

	var idx := 0
	for b: Node3D in old_barriers:
		var pos: Vector3 = b.position
		remove_child(b)
		b.queue_free()
		var use_stop: bool = (idx % 2) == 0
		if absf(pos.x) <= 84.0:
			var kp := KnockablePropScript.new()
			kp.name = "BridgeStopFence_%d" % idx
			kp.prop_material = "metal"
			kp.prop_mass = 80.0
			kp.damage_to_car = 2.0
			kp.speed_drag_factor = 0.04
			kp.prop_height = 2.48
			kp.position = pos
			kp.rotation = Vector3.ZERO
			var mi := MeshInstance3D.new()
			mi.mesh = mesh_stop if use_stop else mesh_plain
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = 280.0
			kp.add_child(mi)
			var col := CollisionShape3D.new()
			col.shape = fence_shape
			col.position = Vector3(0.0, 1.24, 0.0)
			kp.add_child(col)
			add_child(kp)
		else:
			var xf := Transform3D(Basis.IDENTITY, pos)
			if use_stop:
				dist_stop_xforms.append(xf)
			else:
				dist_plain_xforms.append(xf)
		idx += 1

	for entry: Dictionary in [
		{"name": "DistantCoastFencesStop", "mesh": mesh_stop, "list": dist_stop_xforms},
		{"name": "DistantCoastFencesPlain", "mesh": mesh_plain, "list": dist_plain_xforms},
	]:
		var list_xf: Array = entry["list"] as Array
		if list_xf.is_empty():
			continue
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(entry["name"])
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = 310.0
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = entry["mesh"] as Mesh
		mm.instance_count = list_xf.size()
		for j in range(list_xf.size()):
			mm.set_instance_transform(j, list_xf[j] as Transform3D)
		mmi.multimesh = mm
		add_child(mmi)
