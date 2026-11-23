extends Node3D

enum Biome { WASTELAND, RUINED_CITY, DARK_FOREST, WINTER_ICE, TOXIC_MARSH, SCORCHED_CANYON, BURNING_CITY, BURNT_FOREST, OVERGROWN_HIGHWAY }

const ProceduralMaterials = preload("res://levels/procedural_materials.gd")

const GLTF_BARRIER: PackedScene = preload("res://environment/model/decor/FuelStation/models/concrete_road_barrier/concrete_road_barrier_1k.gltf")
const GLTF_CRATE: PackedScene = preload("res://environment/model/decor/FuelStation/models/old_military_crate/old_military_crate_1k.gltf")

static var _shared_box_shapes: Dictionary = {}
const OBSTACLE_DEFS: Array[Dictionary] = [
	{"scene": preload("res://environment/model/decor/wrekers_car/truck_001a_reference_smd_0.tscn"), "y_offset": 1.13, "radius": 4.4},
	{"scene": preload("res://environment/model/decor/wrekers_car/tanker_001a_reference_smd_1.tscn"), "y_offset": 1.50, "radius": 5.2},
	{"scene": preload("res://environment/model/decor/wrekers_car/truck_002a_cab_reference_smd_2.tscn"), "y_offset": 1.44, "radius": 3.8},
	{"scene": preload("res://environment/model/decor/wrekers_car/van_001a_reference_smd_3.tscn"), "y_offset": 0.65, "radius": 3.2},
	{"scene": preload("res://environment/model/decor/wrekers_car/wagon_001a_reference_smd_4.tscn"), "y_offset": 0.56, "radius": 3.0},
	{"scene": null, "y_offset": 0.01, "radius": 1.35},
	{"scene": preload("res://environment/Brigemap/Block/source/barrier.tscn"), "y_offset": 0.0, "radius": 2.1},
]

var biome_type: int = Biome.WASTELAND
var chunk_index: int = 0
var world_seed: int = 1
var chunk_width: float = 560.0
var chunk_length: float = 500.0
var chunk_thickness: float = 800.0
var road_y: float = 0.0

var _has_barn: bool = false
var _road_width: float = 34.0
var _flat_half_width: float = 64.0
var _playable_half_width: float = 58.0
var _chunk_world_z: float = 0.0
var _chunk_xform: Transform3D = Transform3D.IDENTITY
var _chunks_per_bridge: int = 6
var _bridge_shortfall: float = 45.0
## Зарезервированные пятна (x, z, r) для исключения пересечения остовов и столбов
var _placed_spots: Array[Vector3] = []
var _setpiece_z_bands: Array[Vector2] = []

static func get_playable_half_width(p_biome: int) -> float:
	match p_biome:
		Biome.WASTELAND:
			return 58.0
		Biome.RUINED_CITY, Biome.BURNING_CITY:
			return 54.0
		Biome.DARK_FOREST, Biome.BURNT_FOREST:
			return 50.0
		Biome.WINTER_ICE:
			return 54.0
		Biome.TOXIC_MARSH, Biome.OVERGROWN_HIGHWAY:
			return 52.0
		Biome.SCORCHED_CANYON:
			return 56.0
	return 54.0

static func sample_road_center_x(
	world_z: float,
	p_seed: int,
	p_chunk_step: float = 500.0,
	p_chunks_per_bridge: int = 6,
	p_bridge_shortfall: float = 45.0
) -> float:
	if world_z <= 110.0:
		return 0.0
	var start_env: float = 1.0
	if world_z < 260.0:
		var st := clampf((world_z - 110.0) / 150.0, 0.0, 1.0)
		start_env = st * st * (3.0 - 2.0 * st)

	var step: float = maxf(p_chunk_step, 1.0)
	var b_count: int = maxi(p_chunks_per_bridge, 2)
	var first_bridge_start: float = float(b_count) * step - step * 0.5
	var bridge_len: float = maxf(step - p_bridge_shortfall, 40.0)
	var period_len: float = maxf(float(b_count) * step - p_bridge_shortfall, step)
	var lead: float = 155.0
	var bridge_env: float = 1.0
	if world_z >= first_bridge_start - lead:
		var rel: float = fposmod(world_z - (first_bridge_start - lead), period_len)
		if rel < lead:
			var t_in := clampf(rel / lead, 0.0, 1.0)
			bridge_env = 1.0 - t_in * t_in * (3.0 - 2.0 * t_in)
		elif rel <= lead + bridge_len:
			return 0.0
		elif rel < lead + bridge_len + lead:
			var t_out := clampf((rel - (lead + bridge_len)) / lead, 0.0, 1.0)
			bridge_env = t_out * t_out * (3.0 - 2.0 * t_out)

	var s: float = float(absi(p_seed) % 997) * 0.613 + 1.17
	var w1: float = sin(world_z * 0.0046 + s) * 38.0
	var w2: float = sin(world_z * 0.0104 - s * 1.9 + 1.2) * 21.0
	var w3: float = cos(world_z * 0.0185 + s * 0.7) * 8.5
	return (w1 + w2 + w3) * start_env * bridge_env

func _local_road_cx(lz: float) -> float:
	return -sample_road_center_x(_chunk_world_z - lz, world_seed, chunk_length, _chunks_per_bridge, _bridge_shortfall)

func _local_road_yaw(lz: float) -> float:
	var dx: float = _local_road_cx(lz - 1.0) - _local_road_cx(lz)
	return atan2(-dx, 1.0)

func init_chunk_zombies() -> void:
	pass

func setup_procedural(
	p_chunk_idx: int,
	p_biome: int,
	p_world_seed: int,
	p_width: float,
	p_length: float,
	p_thickness: float,
	p_road_y: float,
	skip_landing_zone: bool = false,
	skip_takeoff_zone: bool = false,
	_spawn_barn_here: bool = false,
	p_chunks_per_bridge: int = 6,
	p_bridge_shortfall: float = 45.0
) -> void:
	chunk_index = p_chunk_idx
	biome_type = clampi(p_biome, 0, 8)
	world_seed = p_world_seed
	chunk_width = p_width
	chunk_length = p_length
	chunk_thickness = p_thickness
	road_y = p_road_y
	_chunks_per_bridge = maxi(p_chunks_per_bridge, 2)
	_bridge_shortfall = p_bridge_shortfall
	_placed_spots.clear()
	_setpiece_z_bands.clear()

	_playable_half_width = get_playable_half_width(biome_type)
	match biome_type:
		Biome.WASTELAND:
			_road_width = 34.0
			_flat_half_width = 64.0
		Biome.RUINED_CITY, Biome.BURNING_CITY:
			_road_width = 40.0
			_flat_half_width = p_width * 0.5
		Biome.DARK_FOREST, Biome.BURNT_FOREST:
			_road_width = 30.0
			_flat_half_width = 56.0
		Biome.WINTER_ICE:
			_road_width = 34.0
			_flat_half_width = 62.0
		Biome.TOXIC_MARSH, Biome.OVERGROWN_HIGHWAY:
			_road_width = 32.0
			_flat_half_width = 58.0
		Biome.SCORCHED_CANYON:
			_road_width = 34.0
			_flat_half_width = 62.0

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(world_seed, chunk_index, biome_type))

	var chunk_xform: Transform3D = global_transform if is_inside_tree() else transform
	_chunk_xform = chunk_xform
	_chunk_world_z = chunk_xform.origin.z
	var density: float = 1.0
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm == null and Engine.get_main_loop() is SceneTree:
		sm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("SettingsManager")
	if sm and sm.has_method("get_prop_density"):
		density = float(sm.call("get_prop_density"))

	_has_barn = false

	_build_ground_physics()
	_build_invisible_barriers(skip_takeoff_zone)
	_build_highway_mesh()
	_build_terrain_mesh(chunk_xform, skip_landing_zone, skip_takeoff_zone)
	_build_biome_scenery(rng, chunk_xform, density)
	if chunk_index >= 0:
		_build_post_apoc_highway_details(rng, chunk_xform, density, skip_landing_zone, skip_takeoff_zone)

	if chunk_index >= 0:
		_spawn_obstacles(rng, skip_landing_zone, skip_takeoff_zone)

func _build_ground_physics() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundBody"
	body.collision_layer = 512
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(chunk_width, chunk_thickness, chunk_length)
	col.shape = box
	col.position = Vector3(0.0, road_y - chunk_thickness * 0.5, 0.0)
	body.add_child(col)
	add_child(body)

func _build_invisible_barriers(skip_takeoff_zone: bool) -> void:
	var barriers := StaticBody3D.new()
	barriers.name = "InvisibleBarriers"
	barriers.collision_layer = 1
	barriers.collision_mask = 0
	var phys := PhysicsMaterial.new()
	phys.friction = 0.05
	phys.bounce = 0.15
	barriers.physics_material_override = phys

	var z_half: float = chunk_length * 0.5
	var wall_half_t: float = 1.5
	var wall_y: float = road_y + 65.0
	var seg_count: int = 20
	# Расширенные ненавязчивые границы и свободный въезд на мост (без невидимого сужения перед мостом!)
	var outer_hw: float = _playable_half_width + 12.0
	var bridge_open_z: float = -z_half + 145.0

	for iz in range(seg_count):
		var z_a: float = lerpf(z_half, -z_half, float(iz) / float(seg_count))
		var z_b: float = lerpf(z_half, -z_half, float(iz + 1) / float(seg_count))
		if skip_takeoff_zone and z_b < bridge_open_z:
			continue
		var cx_a: float = _local_road_cx(z_a)
		var cx_b: float = _local_road_cx(z_b)

		for side in [-1.0, 1.0]:
			var p0 := Vector3(cx_a + side * outer_hw, 0.0, z_a)
			var p1 := Vector3(cx_b + side * outer_hw, 0.0, z_b)
			var seg: Vector3 = p1 - p0
			var seg_len: float = seg.length()
			var seg_dir: Vector3 = seg.normalized()
			var out_n := Vector3(-seg_dir.z, 0.0, seg_dir.x).normalized()
			if out_n.x * side < 0.0:
				out_n = -out_n
			var mid: Vector3 = (p0 + p1) * 0.5
			var center := Vector3(mid.x, wall_y, mid.z) + out_n * wall_half_t
			var col_x: Vector3 = Vector3.UP.cross(seg_dir).normalized()

			var col := CollisionShape3D.new()
			var bx := BoxShape3D.new()
			bx.size = Vector3(3.0, 140.0, seg_len + 2.0)
			col.shape = bx
			col.transform = Transform3D(Basis(col_x, Vector3.UP, seg_dir), center)
			barriers.add_child(col)

	if chunk_index == 0:
		var back_col := CollisionShape3D.new()
		back_col.name = "BackStartBarrier"
		var back_box := BoxShape3D.new()
		back_box.size = Vector3(outer_hw * 2.4, 140.0, 4.0)
		back_col.shape = back_box
		back_col.position = Vector3(_local_road_cx(z_half), road_y + 65.0, z_half + 1.5)
		barriers.add_child(back_col)

	add_child(barriers)

func _add_curved_quad_up(
	st: SurfaceTool,
	x0_a: float, x1_a: float, z_a: float,
	x0_b: float, x1_b: float, z_b: float,
	y: float,
	u0: float, u1: float, v0: float, v1: float,
	lat0: float = 0.0, lat1: float = 0.0
) -> void:
	var c0 := Color(clampf((lat0 / 25.0) * 0.5 + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0)
	var c1 := Color(clampf((lat1 / 25.0) * 0.5 + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0)
	st.set_color(c0); st.set_uv(Vector2(u0, v0)); st.add_vertex(Vector3(x0_a, y, z_a))
	st.set_color(c1); st.set_uv(Vector2(u1, v0)); st.add_vertex(Vector3(x1_a, y, z_a))
	st.set_color(c1); st.set_uv(Vector2(u1, v1)); st.add_vertex(Vector3(x1_b, y, z_b))

	st.set_color(c0); st.set_uv(Vector2(u0, v0)); st.add_vertex(Vector3(x0_a, y, z_a))
	st.set_color(c1); st.set_uv(Vector2(u1, v1)); st.add_vertex(Vector3(x1_b, y, z_b))
	st.set_color(c0); st.set_uv(Vector2(u0, v1)); st.add_vertex(Vector3(x0_b, y, z_b))

func _build_highway_mesh() -> void:
	var road_half: float = _road_width * 0.5
	var z_half: float = chunk_length * 0.5
	var road_mesh_inst := MeshInstance3D.new()
	road_mesh_inst.name = "HighwayRoad"
	road_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ry: float = road_y + 0.015
	var uv_u: float = _road_width / 10.0
	var uv_v: float = chunk_length / 10.0
	var z_steps: int = 40
	for iz in range(z_steps):
		var t0 := float(iz) / float(z_steps)
		var t1 := float(iz + 1) / float(z_steps)
		var z0 := lerpf(-z_half, z_half, t0)
		var z1 := lerpf(-z_half, z_half, t1)
		var cx0 := _local_road_cx(z0)
		var cx1 := _local_road_cx(z1)
		_add_curved_quad_up(
			st,
			cx0 - road_half, cx0 + road_half, z0,
			cx1 - road_half, cx1 + road_half, z1,
			ry, 0.0, uv_u, t0 * uv_v, t1 * uv_v,
			-road_half, road_half
		)
	st.generate_normals()
	var road_mesh := st.commit()
	if road_mesh and road_mesh.get_surface_count() > 0:
		var road_mat_key := "asphalt"
		if biome_type == Biome.WINTER_ICE:
			road_mat_key = "asphalt_ice"
		elif biome_type == Biome.TOXIC_MARSH:
			road_mat_key = "asphalt_wet"
		elif biome_type == Biome.SCORCHED_CANYON or biome_type == Biome.BURNING_CITY or biome_type == Biome.BURNT_FOREST:
			road_mat_key = "asphalt_scorched"
		elif biome_type == Biome.OVERGROWN_HIGHWAY:
			road_mat_key = "asphalt_overgrown"
		road_mesh.surface_set_material(0, ProceduralMaterials.get_material(road_mat_key))
	road_mesh_inst.mesh = road_mesh
	add_child(road_mesh_inst)

	# Shoulder solid white lines & dashed multi-lane markings following curve
	var white_st := SurfaceTool.new()
	white_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sy: float = road_y + 0.030
	var line_x: float = road_half - 0.85
	for iz in range(z_steps):
		var z0 := lerpf(-z_half, z_half, float(iz) / float(z_steps))
		var z1 := lerpf(-z_half, z_half, float(iz + 1) / float(z_steps))
		var cx0 := _local_road_cx(z0)
		var cx1 := _local_road_cx(z1)
		_add_curved_quad_up(white_st, cx0 - line_x - 0.16, cx0 - line_x + 0.16, z0, cx1 - line_x - 0.16, cx1 - line_x + 0.16, z1, sy, 0.0, 1.0, 0.0, 1.0, -line_x, -line_x)
		_add_curved_quad_up(white_st, cx0 + line_x - 0.16, cx0 + line_x + 0.16, z0, cx1 + line_x - 0.16, cx1 + line_x + 0.16, z1, sy, 0.0, 1.0, 0.0, 1.0, line_x, line_x)

	var lane_offsets: Array[float] = [-5.5, 5.5]
	if biome_type == Biome.RUINED_CITY or biome_type == Biome.BURNING_CITY:
		lane_offsets = [-13.0, -6.5, 6.5, 13.0]
	var lane_z: float = -z_half + 4.0
	while lane_z + 6.0 <= z_half:
		var cx0 := _local_road_cx(lane_z)
		var cx1 := _local_road_cx(lane_z + 6.0)
		for lx_off in lane_offsets:
			if absf(lx_off) < road_half - 2.0:
				_add_curved_quad_up(white_st, cx0 + lx_off - 0.12, cx0 + lx_off + 0.12, lane_z, cx1 + lx_off - 0.12, cx1 + lx_off + 0.12, lane_z + 6.0, sy, 0.0, 1.0, 0.0, 1.0, lx_off, lx_off)
		lane_z += 16.0

	white_st.generate_normals()
	var white_mesh := white_st.commit()
	if white_mesh and white_mesh.get_surface_count() > 0:
		white_mesh.surface_set_material(0, ProceduralMaterials.get_material("stripe_white"))
	var white_inst := MeshInstance3D.new()
	white_inst.name = "RoadWhiteLines"
	white_inst.mesh = white_mesh
	white_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(white_inst)

	# Centerline yellow markings following curve
	var yellow_st := SurfaceTool.new()
	yellow_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if biome_type == Biome.RUINED_CITY or biome_type == Biome.BURNING_CITY:
		for iz in range(z_steps):
			var z0 := lerpf(-z_half, z_half, float(iz) / float(z_steps))
			var z1 := lerpf(-z_half, z_half, float(iz + 1) / float(z_steps))
			var cx0 := _local_road_cx(z0)
			var cx1 := _local_road_cx(z1)
			_add_curved_quad_up(yellow_st, cx0 - 0.34, cx0 - 0.12, z0, cx1 - 0.34, cx1 - 0.12, z1, sy, 0.0, 1.0, 0.0, 1.0, -0.23, -0.23)
			_add_curved_quad_up(yellow_st, cx0 + 0.12, cx0 + 0.34, z0, cx1 + 0.12, cx1 + 0.34, z1, sy, 0.0, 1.0, 0.0, 1.0, 0.23, 0.23)
	else:
		var dash_z: float = -z_half + 2.0
		while dash_z + 7.0 <= z_half:
			var cx0 := _local_road_cx(dash_z)
			var cx1 := _local_road_cx(dash_z + 7.0)
			_add_curved_quad_up(yellow_st, cx0 - 0.16, cx0 + 0.16, dash_z, cx1 - 0.16, cx1 + 0.16, dash_z + 7.0, sy, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0)
			dash_z += 16.0
	yellow_st.generate_normals()
	var yellow_mesh := yellow_st.commit()
	if yellow_mesh and yellow_mesh.get_surface_count() > 0:
		yellow_mesh.surface_set_material(0, ProceduralMaterials.get_material("stripe_yellow"))
	var yellow_inst := MeshInstance3D.new()
	yellow_inst.name = "RoadCenterLines"
	yellow_inst.mesh = yellow_mesh
	yellow_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(yellow_inst)

func _build_curved_row_xs(cx: float, road_half: float, half_w: float, is_right: bool) -> PackedFloat32Array:
	var arr: PackedFloat32Array = []
	var steps_outer := 12
	if is_right:
		arr.append(cx + road_half)
		if _flat_half_width < half_w - 2.0:
			var flat_r: float = minf(cx + _flat_half_width, half_w - 8.0)
			arr.append(flat_r)
			for i in range(1, steps_outer + 1):
				var t := pow(float(i) / float(steps_outer), 1.3)
				arr.append(lerpf(flat_r, half_w, t))
		else:
			for i in range(1, steps_outer + 1):
				arr.append(lerpf(cx + road_half, half_w, float(i) / float(steps_outer)))
	else:
		var left_pts: PackedFloat32Array = []
		left_pts.append(cx - road_half)
		if _flat_half_width < half_w - 2.0:
			var flat_l: float = maxf(cx - _flat_half_width, -half_w + 8.0)
			left_pts.append(flat_l)
			for i in range(1, steps_outer + 1):
				var t := pow(float(i) / float(steps_outer), 1.3)
				left_pts.append(lerpf(flat_l, -half_w, t))
		else:
			for i in range(1, steps_outer + 1):
				left_pts.append(lerpf(cx - road_half, -half_w, float(i) / float(steps_outer)))
		for i in range(left_pts.size() - 1, -1, -1):
			arr.append(left_pts[i])
	return arr

func _build_terrain_mesh(chunk_xform: Transform3D, skip_landing_zone: bool = false, skip_takeoff_zone: bool = false) -> void:
	var road_half: float = _road_width * 0.5
	var half_w: float = chunk_width * 0.5
	var z_half: float = chunk_length * 0.5

	var z_steps := 40
	var zs: PackedFloat32Array = []
	var cxs: PackedFloat32Array = []
	var rows_left_xs: Array[PackedFloat32Array] = []
	var rows_right_xs: Array[PackedFloat32Array] = []
	for iz in range(z_steps + 1):
		var lz := lerpf(-z_half, z_half, float(iz) / float(z_steps))
		var cx := _local_road_cx(lz)
		zs.append(lz)
		cxs.append(cx)
		rows_left_xs.append(_build_curved_row_xs(cx, road_half, half_w, false))
		rows_right_xs.append(_build_curved_row_xs(cx, road_half, half_w, true))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h_left := _append_curved_terrain_strip(st, rows_left_xs, zs, cxs, chunk_xform)
	var h_right := _append_curved_terrain_strip(st, rows_right_xs, zs, cxs, chunk_xform)

	# Глубокие откосы и береговые склоны по бокам и у воды (чтобы биом у моста не выглядел плоским листом)
	_append_outer_side_skirt(st, -half_w, zs, cxs, h_left, 0, -24.0, true)
	_append_outer_side_skirt(st, half_w, zs, cxs, h_right, rows_right_xs[0].size() - 1, -24.0, false)
	if skip_takeoff_zone:
		_append_coastal_cliff_slope(st, rows_left_xs[0], h_left[0], cxs[0], -z_half, -1.0, road_half)
		_append_coastal_cliff_slope(st, rows_right_xs[0], h_right[0], cxs[0], -z_half, -1.0, road_half)
	if skip_landing_zone:
		var last_r := zs.size() - 1
		_append_coastal_cliff_slope(st, rows_left_xs[last_r], h_left[last_r], cxs[last_r], z_half, 1.0, road_half)
		_append_coastal_cliff_slope(st, rows_right_xs[last_r], h_right[last_r], cxs[last_r], z_half, 1.0, road_half)

	st.index()
	st.generate_normals()

	var mesh := st.commit()
	var mat_key := "desert"
	if biome_type == Biome.RUINED_CITY:
		mat_key = "city_concrete"
	elif biome_type == Biome.BURNING_CITY:
		mat_key = "burnt_city_concrete"
	elif biome_type == Biome.DARK_FOREST:
		mat_key = "forest_ground"
	elif biome_type == Biome.BURNT_FOREST:
		mat_key = "burnt_forest_ground"
	elif biome_type == Biome.OVERGROWN_HIGHWAY:
		mat_key = "overgrown_ground"
	elif biome_type == Biome.WINTER_ICE:
		mat_key = "snow_ground"
	elif biome_type == Biome.TOXIC_MARSH:
		mat_key = "toxic_ground"
	elif biome_type == Biome.SCORCHED_CANYON:
		mat_key = "scorched_ground"
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, ProceduralMaterials.get_material(mat_key))

	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "ProceduralTerrain"
	terrain_inst.mesh = mesh
	terrain_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	terrain_inst.extra_cull_margin = 28.0
	add_child(terrain_inst)

	# Бетонные береговые устои под дорожным полотном на въезде и выезде с моста (закрывают просвет до океана)
	if skip_takeoff_zone or skip_landing_zone:
		_build_bridge_abutments(road_half, z_half, skip_takeoff_zone, skip_landing_zone)

func _append_outer_side_skirt(st: SurfaceTool, x: float, zs: PackedFloat32Array, cxs: PackedFloat32Array, heights: Array[PackedFloat32Array], col_idx: int, bottom_y: float, face_left: bool) -> void:
	for r in range(zs.size() - 1):
		var z0 := zs[r]
		var z1 := zs[r + 1]
		var y0 := heights[r][col_idx]
		var y1 := heights[r + 1][col_idx]
		var t0 := Vector3(x, y0, z0)
		var t1 := Vector3(x, y1, z1)
		var b0 := Vector3(x, bottom_y, z0)
		var b1 := Vector3(x, bottom_y, z1)
		var col0 := Color(clampf(absf(x - cxs[r]) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
		var col1 := Color(clampf(absf(x - cxs[r + 1]) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
		if face_left:
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, y0 * 0.05)); st.add_vertex(t0)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, y1 * 0.05)); st.add_vertex(t1)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, bottom_y * 0.05)); st.add_vertex(b1)
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, y0 * 0.05)); st.add_vertex(t0)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, bottom_y * 0.05)); st.add_vertex(b1)
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, bottom_y * 0.05)); st.add_vertex(b0)
		else:
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, y0 * 0.05)); st.add_vertex(t0)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, bottom_y * 0.05)); st.add_vertex(b1)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, y1 * 0.05)); st.add_vertex(t1)
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, y0 * 0.05)); st.add_vertex(t0)
			st.set_color(col0); st.set_uv(Vector2(z0 * 0.05, bottom_y * 0.05)); st.add_vertex(b0)
			st.set_color(col1); st.set_uv(Vector2(z1 * 0.05, bottom_y * 0.05)); st.add_vertex(b1)

func _append_coastal_cliff_slope(st: SurfaceTool, xs: PackedFloat32Array, edge_heights: PackedFloat32Array, cx_edge: float, z_edge: float, z_dir: float, road_half: float) -> void:
	# Береговой склон биома плавно уходит на -26м под воду океана (без резкого плоского обрыва)
	var cols := xs.size()
	var z_mid := z_edge + z_dir * 18.0
	var z_deep := z_edge + z_dir * 42.0
	var rows_z: Array[float] = [z_edge, z_mid, z_deep]
	var grid: Array[Array] = []
	for ir in range(rows_z.size()):
		var row_pts: Array[Vector3] = []
		var rz := rows_z[ir]
		for c in range(cols):
			var x := xs[c]
			var is_road_edge := absf(x - cx_edge) <= road_half + 4.5
			var h0 := edge_heights[c]
			var y_pt := h0
			if ir == 1:
				y_pt = -10.5 if is_road_edge else minf(h0 * 0.45 - 7.0, -5.5)
			elif ir == 2:
				y_pt = -26.0
			row_pts.append(Vector3(x, y_pt, rz))
		grid.append(row_pts)

	for ir in range(grid.size() - 1):
		var r0: Array = grid[ir]
		var r1: Array = grid[ir + 1]
		for c in range(cols - 1):
			var p00: Vector3 = r0[c]
			var p10: Vector3 = r0[c + 1]
			var p11: Vector3 = r1[c + 1]
			var p01: Vector3 = r1[c]
			var c00 := Color(clampf(absf(p00.x - cx_edge) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			var c10 := Color(clampf(absf(p10.x - cx_edge) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			if z_dir > 0.0:
				st.set_color(c00); st.set_uv(Vector2(p00.x * 0.05, p00.z * 0.05)); st.add_vertex(p00)
				st.set_color(c10); st.set_uv(Vector2(p10.x * 0.05, p10.z * 0.05)); st.add_vertex(p10)
				st.set_color(c10); st.set_uv(Vector2(p11.x * 0.05, p11.z * 0.05)); st.add_vertex(p11)
				st.set_color(c00); st.set_uv(Vector2(p00.x * 0.05, p00.z * 0.05)); st.add_vertex(p00)
				st.set_color(c10); st.set_uv(Vector2(p11.x * 0.05, p11.z * 0.05)); st.add_vertex(p11)
				st.set_color(c00); st.set_uv(Vector2(p01.x * 0.05, p01.z * 0.05)); st.add_vertex(p01)
			else:
				st.set_color(c00); st.set_uv(Vector2(p00.x * 0.05, p00.z * 0.05)); st.add_vertex(p00)
				st.set_color(c10); st.set_uv(Vector2(p11.x * 0.05, p11.z * 0.05)); st.add_vertex(p11)
				st.set_color(c10); st.set_uv(Vector2(p10.x * 0.05, p10.z * 0.05)); st.add_vertex(p10)
				st.set_color(c00); st.set_uv(Vector2(p00.x * 0.05, p00.z * 0.05)); st.add_vertex(p00)
				st.set_color(c00); st.set_uv(Vector2(p01.x * 0.05, p01.z * 0.05)); st.add_vertex(p01)
				st.set_color(c10); st.set_uv(Vector2(p11.x * 0.05, p11.z * 0.05)); st.add_vertex(p11)

func _build_bridge_abutments(road_half: float, z_half: float, has_takeoff: bool, has_landing: bool) -> void:
	var concrete_mat := ProceduralMaterials.get_material("concrete_rubble")
	var abut_w: float = road_half * 2.0 + 3.0
	var ends: Array[float] = []
	if has_takeoff:
		ends.append(-z_half)
	if has_landing:
		ends.append(z_half)
	for ez: float in ends:
		var z_sign: float = signf(ez)
		var wall := MeshInstance3D.new()
		wall.name = "BridgeHeadAbutment"
		var bmesh := BoxMesh.new()
		bmesh.size = Vector3(abut_w, 24.0, 12.0)
		wall.mesh = bmesh
		wall.material_override = concrete_mat
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		wall.position = Vector3(_local_road_cx(ez), road_y - 12.24, ez - z_sign * 4.5)
		add_child(wall)

func _append_curved_terrain_strip(
	st: SurfaceTool,
	rows_xs: Array[PackedFloat32Array],
	zs: PackedFloat32Array,
	cxs: PackedFloat32Array,
	chunk_xform: Transform3D
) -> Array[PackedFloat32Array]:
	var rows := zs.size()
	var cols := rows_xs[0].size()
	var heights: Array[PackedFloat32Array] = []
	for r in range(rows):
		var row_h := PackedFloat32Array()
		row_h.resize(cols)
		var lz := zs[r]
		var rxs := rows_xs[r]
		for c in range(cols):
			var lx := rxs[c]
			var wp := chunk_xform * Vector3(lx, 0.0, lz)
			row_h[c] = sample_terrain_height(wp.x, wp.z, biome_type, world_seed)
		heights.append(row_h)

	for r in range(rows - 1):
		var z0 := zs[r]
		var z1 := zs[r + 1]
		var xs0 := rows_xs[r]
		var xs1 := rows_xs[r + 1]
		var cx0 := cxs[r]
		var cx1 := cxs[r + 1]
		var hrow0 := heights[r]
		var hrow1 := heights[r + 1]
		for c in range(cols - 1):
			var x00 := xs0[c]
			var x10 := xs0[c + 1]
			var x01 := xs1[c]
			var x11 := xs1[c + 1]
			var p00 := Vector3(x00, hrow0[c], z0)
			var p10 := Vector3(x10, hrow0[c + 1], z0)
			var p11 := Vector3(x11, hrow1[c + 1], z1)
			var p01 := Vector3(x01, hrow1[c], z1)
			var c00 := Color(clampf(absf(x00 - cx0) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			var c10 := Color(clampf(absf(x10 - cx0) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			var c01 := Color(clampf(absf(x01 - cx1) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			var c11 := Color(clampf(absf(x11 - cx1) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)

			st.set_color(c00); st.set_uv(Vector2(x00 * 0.05, z0 * 0.05)); st.add_vertex(p00)
			st.set_color(c10); st.set_uv(Vector2(x10 * 0.05, z0 * 0.05)); st.add_vertex(p10)
			st.set_color(c11); st.set_uv(Vector2(x11 * 0.05, z1 * 0.05)); st.add_vertex(p11)

			st.set_color(c00); st.set_uv(Vector2(x00 * 0.05, z0 * 0.05)); st.add_vertex(p00)
			st.set_color(c11); st.set_uv(Vector2(x11 * 0.05, z1 * 0.05)); st.add_vertex(p11)
			st.set_color(c01); st.set_uv(Vector2(x01 * 0.05, z1 * 0.05)); st.add_vertex(p01)
	return heights

static func sample_terrain_height(world_x: float, world_z: float, p_biome: int, p_seed: int) -> float:
	if p_biome == Biome.RUINED_CITY or p_biome == Biome.BURNING_CITY:
		return 0.0

	var flat_half := 64.0
	match p_biome:
		Biome.WINTER_ICE, Biome.SCORCHED_CANYON:
			flat_half = 62.0
		Biome.TOXIC_MARSH, Biome.OVERGROWN_HIGHWAY:
			flat_half = 58.0
		Biome.DARK_FOREST, Biome.BURNT_FOREST:
			flat_half = 56.0
	var road_cx := sample_road_center_x(world_z, p_seed)
	var lat := world_x - road_cx
	var ax := absf(lat)
	if ax <= flat_half:
		return 0.0

	var edge_t := clampf((ax - flat_half) / 55.0, 0.0, 1.0)
	var blend := edge_t * edge_t * (3.0 - 2.0 * edge_t)
	var s := float(absi(p_seed) % 997) * 0.37

	var h := 0.0
	if p_biome == Biome.WASTELAND:
		var ridge := sin(lat * 0.022 + s) * cos(world_z * 0.014 - s * 0.5)
		var dune := sin(lat * 0.053 - world_z * 0.031 + s * 1.3) * 0.45
		var mesa := maxf(sin(lat * 0.011 + world_z * 0.009 + s), 0.0)
		h = (ridge * 0.5 + 0.5) * 14.0 + dune * 3.5 + pow(mesa, 2.0) * 12.0
		h = maxf(h, 0.4)
	elif p_biome == Biome.WINTER_ICE:
		var peak := sin(lat * 0.020 + s * 0.6) * cos(world_z * 0.017 - s * 0.35)
		var drift := cos(lat * 0.048 - world_z * 0.029 + s * 1.1) * 0.5
		h = (peak * 0.5 + 0.5) * 15.5 + (drift * 0.5 + 0.5) * 4.2
		h = maxf(h, 0.3)
	elif p_biome == Biome.TOXIC_MARSH:
		var bog := sin(lat * 0.028 + s * 0.9) * cos(world_z * 0.019 + s * 0.4)
		var mound := cos(lat * 0.062 - world_z * 0.041 - s) * 0.5
		h = (bog * 0.5 + 0.5) * 6.2 + (mound * 0.5 + 0.5) * 2.4
		h = maxf(h, 0.15)
	elif p_biome == Biome.SCORCHED_CANYON:
		var canyon := maxf(sin(lat * 0.014 - s * 0.7), 0.0)
		var wall_n := sin(lat * 0.024 + s * 0.4) * cos(world_z * 0.015 + s)
		h = (wall_n * 0.5 + 0.5) * 16.0 + pow(canyon, 1.8) * 12.0
		h = maxf(h, 0.6)
	else:
		var hill := sin(lat * 0.026 + s * 0.8) * sin(world_z * 0.021 + s * 0.4)
		var roll := cos(lat * 0.058 + world_z * 0.047 - s) * 0.4
		h = (hill * 0.5 + 0.5) * 11.5 + (roll * 0.5 + 0.5) * 4.5
		h = maxf(h, 0.2)

	return h * blend

func _build_biome_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	match biome_type:
		Biome.WASTELAND:
			_populate_wasteland_scenery(rng, chunk_xform, density)
		Biome.RUINED_CITY:
			_populate_city_scenery(rng, density)
		Biome.DARK_FOREST:
			_populate_forest_scenery(rng, chunk_xform, density)
		Biome.WINTER_ICE:
			_populate_winter_scenery(rng, chunk_xform, density)
		Biome.TOXIC_MARSH:
			_populate_toxic_scenery(rng, chunk_xform, density)
		Biome.SCORCHED_CANYON:
			_populate_scorched_scenery(rng, chunk_xform, density)
		Biome.BURNING_CITY:
			_populate_burning_city_scenery(rng, chunk_xform, density)
		Biome.BURNT_FOREST:
			_populate_burnt_forest_scenery(rng, chunk_xform, density)
		Biome.OVERGROWN_HIGHWAY:
			_populate_overgrown_scenery(rng, chunk_xform, density)

func _build_city_sidewalk_mesh(road_half: float) -> ArrayMesh:
	var z_half := chunk_length * 0.5
	var z_steps := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y_top := road_y + 0.32
	var y_bot := road_y - 0.04
	for side in [-1.0, 1.0]:
		var lat_in: float = side * road_half
		var lat_out: float = side * (road_half + 12.0)
		var l_lo: float = minf(lat_in, lat_out)
		var l_hi: float = maxf(lat_in, lat_out)
		for iz in range(z_steps):
			var z0 := lerpf(-z_half + 1.0, z_half - 1.0, float(iz) / float(z_steps))
			var z1 := lerpf(-z_half + 1.0, z_half - 1.0, float(iz + 1) / float(z_steps))
			var cx0 := _local_road_cx(z0)
			var cx1 := _local_road_cx(z1)
			# Sidewalk top surface
			_add_curved_quad_up(st, cx0 + l_lo, cx0 + l_hi, z0, cx1 + l_lo, cx1 + l_hi, z1, y_top, 0.0, 1.0, 0.0, 1.0, l_lo, l_hi)
			# Inner curb vertical face facing the road
			var vx0 := Vector3(cx0 + lat_in, y_top, z0)
			var vx1 := Vector3(cx1 + lat_in, y_top, z1)
			var bx0 := Vector3(cx0 + lat_in, y_bot, z0)
			var bx1 := Vector3(cx1 + lat_in, y_bot, z1)
			var curb_col := Color(clampf(absf(lat_in) / 60.0, 0.0, 1.0), 0.0, 0.0, 1.0)
			if side > 0.0:
				st.set_color(curb_col); st.set_uv(Vector2(0, 0)); st.add_vertex(vx0)
				st.set_color(curb_col); st.set_uv(Vector2(1, 0)); st.add_vertex(vx1)
				st.set_color(curb_col); st.set_uv(Vector2(1, 1)); st.add_vertex(bx1)
				st.set_color(curb_col); st.set_uv(Vector2(0, 0)); st.add_vertex(vx0)
				st.set_color(curb_col); st.set_uv(Vector2(1, 1)); st.add_vertex(bx1)
				st.set_color(curb_col); st.set_uv(Vector2(0, 1)); st.add_vertex(bx0)
			else:
				st.set_color(curb_col); st.set_uv(Vector2(0, 0)); st.add_vertex(vx0)
				st.set_color(curb_col); st.set_uv(Vector2(1, 1)); st.add_vertex(bx1)
				st.set_color(curb_col); st.set_uv(Vector2(1, 0)); st.add_vertex(vx1)
				st.set_color(curb_col); st.set_uv(Vector2(0, 0)); st.add_vertex(vx0)
				st.set_color(curb_col); st.set_uv(Vector2(0, 1)); st.add_vertex(bx0)
				st.set_color(curb_col); st.set_uv(Vector2(1, 1)); st.add_vertex(bx1)
	st.generate_normals()
	var mesh := st.commit()
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, ProceduralMaterials.get_material("city_concrete"))
	return mesh

func _populate_wasteland_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)
	var rock_min_x := _playable_half_width + 4.0
	var pine_min_x := _playable_half_width + 7.0

	var boulder_mesh := ProceduralMaterials.get_boulder_mesh()
	var rock_count := maxi(roundi(240.0 * density), 28)
	var rock_transforms: Array[Transform3D] = []
	for i in range(rock_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(rock_min_x, max_lat)
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var sx := rng.randf_range(1.4, 6.2)
		var sy := rng.randf_range(1.0, 4.8)
		var sz := rng.randf_range(1.4, 5.8)
		var t := Transform3D()
		t = t.scaled(Vector3(sx, sy, sz))
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t.origin = Vector3(lx, road_y + ly + sy * 0.25, lz)
		rock_transforms.append(t)
	_spawn_multimesh("WastelandRocks", boulder_mesh, rock_transforms)

	var pine_mesh := ProceduralMaterials.get_pine_tree_mesh()
	if pine_mesh:
		var tree_count := maxi(roundi(190.0 * density), 20)
		var tree_transforms: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(pine_min_x, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.70, 1.35)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.1, lz)
			tree_transforms.append(t)
		_spawn_multimesh("WastelandPines", pine_mesh, tree_transforms)

	var ph_desert_rock := ProceduralMaterials.get_ph_boulder_desert_mesh()
	if ph_desert_rock:
		var dr_count := maxi(roundi(28.0 * density), 8)
		var dr_transforms: Array[Transform3D] = []
		for i in range(dr_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 2.0, _playable_half_width + 24.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.9, 2.2)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * rng.randf_range(0.9, 1.3), sc * rng.randf_range(0.85, 1.25), sc))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.08, lz)
			dr_transforms.append(t)
		_spawn_multimesh("WastelandDesertBoulders", ph_desert_rock, dr_transforms, true, 340.0)

	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	if fence_mesh:
		var fc_count := maxi(roundi(18.0 * density), 6)
		var fc_transforms: Array[Transform3D] = []
		for i in range(fc_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 1.5, _playable_half_width + 12.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.95, 1.25)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.UP, _local_road_yaw(lz) + PI * 0.5 + rng.randf_range(-0.35, 0.35))
			t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.09, 0.09))
			t.origin = Vector3(lx, road_y + ly - 0.04, lz)
			fc_transforms.append(t)
		_spawn_multimesh("WastelandChainlink", fence_mesh, fc_transforms, false, 330.0)

	var road_half := _road_width * 0.5
	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var dead_log_mesh := ProceduralMaterials.get_ph_dead_log_mesh()
	var k_prop_count := maxi(roundi(12.0 * density), 5)
	for i in range(k_prop_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.2, _playable_half_width - 4.0)
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.2):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var yaw := _local_road_yaw(lz) + rng.randf_range(-0.55, 0.55)
		var kind_i: int = i % 4
		if kind_i == 0 and fence_mesh:
			_spawn_knockable_mesh("KnockWastelandFence", fence_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw + PI * 0.5, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.4, 0.35), "metal", 85.0, 2.5, 0.04)
		elif kind_i == 1:
			_spawn_barrel_prop("KnockWastelandBarrel", Vector3(lx, road_y + ly + 0.01, lz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
		elif kind_i == 2 and crate_mesh:
			_spawn_knockable_mesh("KnockWastelandCrate", crate_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)
		elif dead_log_mesh:
			_spawn_knockable_mesh("KnockWastelandLog", dead_log_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(4.2, 0.55, 0.55), "wood", 115.0, 3.5, 0.05)

	var k_rock_count := maxi(roundi(8.0 * density), 3)
	for i in range(k_rock_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.5, _playable_half_width - 5.0)
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		if ph_desert_rock and i % 2 == 0:
			var sc_d := rng.randf_range(0.65, 1.05)
			_spawn_knockable_mesh("KnockBoulder", ph_desert_rock, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc_d, Vector3.ZERO, Vector3(2.4 * sc_d, 1.1 * sc_d, 1.4 * sc_d), "concrete", 185.0, 5.5, 0.085)
		else:
			var sc := rng.randf_range(0.75, 1.35)
			_spawn_knockable_mesh("KnockBoulder", boulder_mesh, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3(0.0, sc * 0.45, 0.0), Vector3(1.4 * sc, 1.0 * sc, 1.4 * sc), "concrete", 195.0, 6.0, 0.09)

	var scrub_mesh := ProceduralMaterials.get_shrub_mesh()
	if scrub_mesh:
		var scrub_count := maxi(roundi(180.0 * density), 28)
		var scrub_transforms: Array[Transform3D] = []
		for i in range(scrub_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.0, max_lat)
			if _in_fuel_station_zone(lx, lz):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.65, 1.45)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * 1.15, sc * 0.85, sc * 1.15))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.04, lz)
			scrub_transforms.append(t)
		_spawn_multimesh("WastelandScrub", scrub_mesh, scrub_transforms, false, 315.0)

	var pylon_mesh := ProceduralMaterials.get_ph_utility_pole_mesh()
	if pylon_mesh:
		var zp := -z_half + 22.0
		var pylon_side := 1.0 if (chunk_index % 2) == 0 else -1.0
		while zp < z_half - 20.0:
			var lx := _local_road_cx(zp) + pylon_side * (road_half + 4.8)
			if not _in_fuel_station_zone(lx, zp) and _reserve_spot(lx, zp, 1.6):
				var ly := _local_terrain_y(chunk_xform, lx, zp)
				var rot := Vector3(rng.randf_range(-0.05, 0.05), _local_road_yaw(zp) + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.06, 0.06))
				_spawn_knockable_mesh("KnockPylon", pylon_mesh, Vector3(lx, road_y + ly + 0.04, zp), rot, Vector3.ONE, Vector3.ZERO, Vector3(0.55, 6.8, 0.55), "wood", 135.0, 3.5, 0.045, Vector3(0.0, 3.45, 0.0))
			zp += 52.0

func _populate_city_scenery(rng: RandomNumberGenerator, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 42.0)
	var bldg_min_x := _playable_half_width + 6.0

	# Raised concrete sidewalks following curved boulevard
	var sidewalk_inst := MeshInstance3D.new()
	sidewalk_inst.name = "CitySidewalks"
	sidewalk_inst.mesh = _build_city_sidewalk_mesh(road_half)
	sidewalk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sidewalk_inst.visibility_range_end = 365.0
	add_child(sidewalk_inst)

	var factory_count := maxi(roundi(140.0 * density), 24)
	var tower_buckets: Array[Array] = [[], [], []]
	for i in range(factory_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lat_dist := rng.randf_range(bldg_min_x, max_lat)
		var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
		var lx := _local_road_cx(lz) + side * lat_dist
		var w := rng.randf_range(12.0, 24.0)
		var d := rng.randf_range(12.0, 26.0)
		var max_h := 62.0 if lat_dist > bldg_min_x + 35.0 else 30.0
		var min_h := 22.0 if lat_dist > bldg_min_x + 35.0 else 12.0
		var h := rng.randf_range(min_h, max_h)
		var rot_y := _local_road_yaw(lz) + float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.07, 0.07)
		var t := Transform3D()
		t = t.scaled(Vector3(w, h, d))
		t = t.rotated(Vector3.UP, rot_y)
		t = t.rotated(Vector3.RIGHT, rng.randf_range(-0.025, 0.025))
		t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.025, 0.025))
		t.origin = Vector3(lx, road_y - 0.35, lz)
		var v_idx: int = rng.randi_range(0, 2)
		(tower_buckets[v_idx] as Array).append(t)
	for vi in range(3):
		var t_list: Array[Transform3D] = []
		for xf: Transform3D in (tower_buckets[vi] as Array):
			t_list.append(xf)
		_spawn_multimesh("CityTowers_%d" % vi, ProceduralMaterials.get_city_tower_mesh(vi), t_list, true, 385.0)

	var brick_count := maxi(roundi(120.0 * density), 20)
	var ruin_buckets: Array[Array] = [[], []]
	for i in range(brick_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var brick_max := maxf(max_lat * 0.85, _playable_half_width + 20.0)
		var lz := rng.randf_range(-z_half + 10.0, z_half - 10.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 4.0, brick_max)
		var w := rng.randf_range(9.0, 17.5)
		var d := rng.randf_range(9.0, 19.0)
		var h := rng.randf_range(7.0, 21.0)
		var t := Transform3D()
		t = t.scaled(Vector3(w, h, d))
		t = t.rotated(Vector3.UP, _local_road_yaw(lz) + float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.08, 0.08))
		t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.035, 0.035))
		t.origin = Vector3(lx, road_y - 0.30, lz)
		var r_idx: int = rng.randi_range(0, 1)
		(ruin_buckets[r_idx] as Array).append(t)
	for ri in range(2):
		var r_list: Array[Transform3D] = []
		for xf: Transform3D in (ruin_buckets[ri] as Array):
			r_list.append(xf)
		_spawn_multimesh("CityBrickRuins_%d" % ri, ProceduralMaterials.get_city_ruin_mesh(ri), r_list, true, 365.0)

	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	if fence_mesh:
		var f_count := maxi(roundi(26.0 * density), 8)
		var f_transforms: Array[Transform3D] = []
		for i in range(f_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 0.8, _playable_half_width + 11.0)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.95, 1.25))
			t = t.rotated(Vector3.UP, _local_road_yaw(lz) + PI * 0.5 + rng.randf_range(-0.22, 0.22))
			t.origin = Vector3(lx, road_y - 0.04, lz)
			f_transforms.append(t)
		_spawn_multimesh("CityChainlinkFences", fence_mesh, f_transforms, false, 330.0)

	var barrel_mesh := ProceduralMaterials.get_ph_barrel_mesh()
	if barrel_mesh:
		var b_count := maxi(roundi(24.0 * density), 8)
		var b_transforms: Array[Transform3D] = []
		for i in range(b_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 0.5, _playable_half_width + 14.0)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.9, 1.15))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y - 0.02, lz)
			b_transforms.append(t)
		_spawn_multimesh("CityStreetBarrels", barrel_mesh, b_transforms, false, 320.0)

	# Streetlights along both avenue curbs following curved tangent (PolyHaven detailed lamp)
	var lamp_mesh := ProceduralMaterials.get_ph_street_lamp_mesh()
	var z_pos := -z_half + 24.0
	while z_pos < z_half - 20.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var pole_x: float = cx + side * (road_half + 1.5)
			if _in_fuel_station_zone(pole_x, z_pos) or not _reserve_spot(pole_x, z_pos, 1.6):
				continue
			var tilt := rng.randf_range(-0.06, 0.06) if rng.randf() < 0.30 else 0.0
			_spawn_knockable_streetlight(lamp_mesh, Vector3(pole_x, road_y + 0.32, z_pos), tilt, side, r_yaw)
		z_pos += 48.0

	# Reachable city sidewalk props (KnockableProp: trash cans, hydrants, power boxes, crates, barrels)
	var trash_mesh := ProceduralMaterials.get_ph_trash_can_mesh()
	var hydrant_mesh := ProceduralMaterials.get_ph_fire_hydrant_mesh()
	var pbox_mesh := ProceduralMaterials.get_ph_power_box_mesh()
	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var street_prop_count := maxi(roundi(24.0 * density), 10)
	for i in range(street_prop_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 10.0, z_half - 10.0)
		var lat := rng.randf_range(road_half + 1.8, _playable_half_width - 2.5)
		var lx := _local_road_cx(lz) + side * lat
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var prop_y: float = road_y + (0.33 if lat <= road_half + 12.0 else 0.03)
		var yaw: float = _local_road_yaw(lz) + rng.randf_range(-0.35, 0.35)
		match i % 6:
			0:
				if trash_mesh:
					_spawn_knockable_mesh("KnockCityTrashCan", trash_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.6, 0.95, 0.75), "metal", 55.0, 1.8, 0.025)
			1:
				if hydrant_mesh:
					_spawn_knockable_mesh("KnockCityHydrant", hydrant_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.85, 0.92, 0.55), "metal", 75.0, 2.5, 0.035)
			2:
				if pbox_mesh:
					_spawn_knockable_mesh("KnockCityPowerBox", pbox_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.75, 1.40, 0.65), "metal_electric", 120.0, 3.8, 0.05)
			3:
				if barrel_mesh:
					_spawn_knockable_mesh("KnockCityBarrel", barrel_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.85, 1.25, 0.85), "metal", 60.0, 1.8, 0.028)
			4:
				if crate_mesh:
					_spawn_knockable_mesh("KnockCityCrate", crate_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)
			_:
				if fence_mesh:
					_spawn_knockable_mesh("KnockCityFence", fence_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw + PI * 0.5, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.40, 0.35), "metal", 85.0, 2.5, 0.04)

func _populate_forest_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)
	var tree_min_x := _playable_half_width + 3.0

	var pine_mesh := ProceduralMaterials.get_pine_tree_mesh()
	if pine_mesh:
		var tree_count := maxi(roundi(850.0 * density), 110)
		var tree_transforms: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 3.0, z_half - 3.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(tree_min_x, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.85, 1.65)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.1, lz)
			tree_transforms.append(t)
		_spawn_multimesh("ForestPines", pine_mesh, tree_transforms)

	var boulder_mesh := ProceduralMaterials.get_mossy_boulder_mesh()
	var rock_count := maxi(roundi(160.0 * density), 20)
	var rock_transforms: Array[Transform3D] = []
	for i in range(rock_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 2.5, max_lat)
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var sx := rng.randf_range(1.2, 4.6)
		var sy := rng.randf_range(0.9, 3.4)
		var sz := rng.randf_range(1.2, 4.4)
		var t := Transform3D()
		t = t.scaled(Vector3(sx, sy, sz))
		t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
		t.origin = Vector3(lx, road_y + ly + sy * 0.25, lz)
		rock_transforms.append(t)
	_spawn_multimesh("ForestRocks", boulder_mesh, rock_transforms)

	var shrub_mesh := ProceduralMaterials.get_shrub_mesh()
	if shrub_mesh:
		var under_count := maxi(roundi(260.0 * density), 40)
		var under_transforms: Array[Transform3D] = []
		for i in range(under_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 3.0, z_half - 3.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 2.5, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.75, 1.55)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * 1.25, sc * 0.9, sc * 1.25))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.04, lz)
			under_transforms.append(t)
		_spawn_multimesh("ForestUndergrowth", shrub_mesh, under_transforms, false, 315.0)

	var ph_dead_log := ProceduralMaterials.get_ph_dead_log_mesh()
	var fallback_log := ProceduralMaterials.get_log_mesh()
	var log_mesh: Mesh = (ph_dead_log as Mesh) if ph_dead_log != null else (fallback_log as Mesh)
	var is_ph_log: bool = (ph_dead_log != null)
	if log_mesh:
		var log_count := maxi(roundi(34.0 * density), 8)
		var log_transforms: Array[Transform3D] = []
		for i in range(log_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 2.0, max_lat - 10.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.85, 1.35))
			if not is_ph_log:
				t = t.rotated(Vector3.FORWARD, PI * 0.5 + rng.randf_range(-0.08, 0.08))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + (0.02 if is_ph_log else 0.25), lz)
			log_transforms.append(t)
		_spawn_multimesh("ForestFallenLogs", log_mesh, log_transforms, false, 325.0)

		var k_log_count := maxi(roundi(10.0 * density), 4)
		for i in range(k_log_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.8, _playable_half_width - 4.0)
			if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.5):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var yaw := rng.randf_range(0.0, TAU)
			if is_ph_log:
				_spawn_knockable_mesh("KnockForestLog", log_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw, 0.0), Vector3(0.95, 0.95, 0.95), Vector3.ZERO, Vector3(4.3, 0.62, 0.62), "wood", 130.0, 4.0, 0.065, Vector3(0.0, 0.32, 0.0))
			else:
				_spawn_knockable_mesh("KnockForestLog", log_mesh, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, yaw, 0.0), Vector3(0.85, 0.85, 0.85), Vector3(0.0, 0.36, 0.0), Vector3(4.4, 0.68, 0.68), "wood", 130.0, 4.0, 0.065, Vector3(0.0, 0.36, 0.0), Vector3(0.0, 0.0, PI * 0.5))

	for mr_i in range(3):
		var mr_mesh := ProceduralMaterials.get_ph_moss_rock_mesh(mr_i)
		if mr_mesh:
			var mr_cnt := maxi(roundi(10.0 * density), 3)
			var mr_xf: Array[Transform3D] = []
			for i in range(mr_cnt):
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
				var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 1.5, _playable_half_width + 20.0)
				var ly := _local_terrain_y(chunk_xform, lx, lz)
				var sc := rng.randf_range(0.85, 1.85)
				var t := Transform3D()
				t = t.scaled(Vector3.ONE * sc)
				t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				t.origin = Vector3(lx, road_y + ly - 0.06, lz)
				mr_xf.append(t)
			_spawn_multimesh("ForestMossRocks_%d" % mr_i, mr_mesh, mr_xf, false, 330.0)

	var k_fr_rock_count := maxi(roundi(8.0 * density), 3)
	for i in range(k_fr_rock_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.2, _playable_half_width - 4.5)
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var mr := ProceduralMaterials.get_ph_moss_rock_mesh(i % 3)
		if mr:
			var sc := rng.randf_range(0.70, 1.15)
			_spawn_knockable_mesh("KnockForestRock", mr, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3.ZERO, Vector3(1.5 * sc, 1.0 * sc, 1.5 * sc), "concrete", 185.0, 5.5, 0.085)
		else:
			var sc := rng.randf_range(0.75, 1.30)
			_spawn_knockable_mesh("KnockForestRock", boulder_mesh, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3(0.0, sc * 0.45, 0.0), Vector3(1.4 * sc, 1.0 * sc, 1.4 * sc), "concrete", 195.0, 6.0, 0.09)

	var rail_mesh := ProceduralMaterials.get_guardrail_mesh()
	var z_pos := -z_half + 12.0
	while z_pos < z_half - 12.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var rail_x: float = cx + side * (road_half + 1.5)
			if _in_fuel_station_zone(rail_x, z_pos) or not _reserve_spot(rail_x, z_pos, 3.0):
				continue
			if rng.randf() < 0.55 and rail_mesh:
				var yaw := r_yaw + rng.randf_range(-0.04, 0.04)
				_spawn_knockable_mesh("KnockGuardrail", rail_mesh, Vector3(rail_x, road_y + 0.03, z_pos), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.45, 0.88, 14.0), "metal", 95.0, 3.0, 0.045, Vector3(0.0, 0.44, 0.0))
		z_pos += 26.0


func _populate_winter_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)
	var tree_min_x := _playable_half_width + 4.0

	var snow_pine := ProceduralMaterials.get_snow_pine_tree_mesh()
	if snow_pine:
		var tree_count := maxi(roundi(560.0 * density), 75)
		var tree_transforms: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(tree_min_x, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.80, 1.55)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.1, lz)
			tree_transforms.append(t)
		_spawn_multimesh("WinterPines", snow_pine, tree_transforms, true, 375.0)

	var snow_rock := ProceduralMaterials.get_snow_boulder_mesh()
	if snow_rock:
		var rock_count := maxi(roundi(195.0 * density), 24)
		var rock_transforms: Array[Transform3D] = []
		for i in range(rock_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 3.0, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sx := rng.randf_range(1.4, 5.2)
			var sy := rng.randf_range(1.0, 3.8)
			var sz := rng.randf_range(1.4, 4.8)
			var t := Transform3D()
			t = t.scaled(Vector3(sx, sy, sz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + sy * 0.22, lz)
			rock_transforms.append(t)
		_spawn_multimesh("WinterRocks", snow_rock, rock_transforms, true, 365.0)

		var k_snow_rocks := maxi(roundi(8.0 * density), 3)
		for i in range(k_snow_rocks):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.5, _playable_half_width - 4.5)
			if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.75, 1.28)
			_spawn_knockable_mesh("KnockSnowBoulder", snow_rock, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3(0.0, sc * 0.45, 0.0), Vector3(1.4 * sc, 1.0 * sc, 1.4 * sc), "concrete", 190.0, 5.5, 0.085)

	var bank_mesh := ProceduralMaterials.get_snow_bank_mesh()
	if bank_mesh:
		var bank_count := maxi(roundi(95.0 * density), 18)
		var bank_transforms: Array[Transform3D] = []
		for i in range(bank_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 2.2, _playable_half_width + 26.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var t := Transform3D()
			t = t.scaled(Vector3(rng.randf_range(1.1, 2.0), rng.randf_range(0.75, 1.45), rng.randf_range(1.4, 2.6)))
			t = t.rotated(Vector3.UP, _local_road_yaw(lz) + rng.randf_range(-0.45, 0.45) + PI * 0.5)
			t.origin = Vector3(lx, road_y + ly + 0.05, lz)
			bank_transforms.append(t)
		_spawn_multimesh("WinterSnowbanks", bank_mesh, bank_transforms, false, 340.0)

	var rail_mesh := ProceduralMaterials.get_guardrail_mesh()
	var z_pos := -z_half + 14.0
	while z_pos < z_half - 14.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var rail_x: float = cx + side * (road_half + 1.6)
			if not _in_fuel_station_zone(rail_x, z_pos) and rng.randf() < 0.48 and _reserve_spot(rail_x, z_pos, 3.0) and rail_mesh:
				var yaw := r_yaw + rng.randf_range(-0.04, 0.04)
				_spawn_knockable_mesh("KnockWinterRail", rail_mesh, Vector3(rail_x, road_y + 0.03, z_pos), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.45, 0.88, 14.0), "metal", 110.0, 3.5, 0.05, Vector3(0.0, 0.44, 0.0))
		z_pos += 30.0

	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var w_prop_cnt := maxi(roundi(8.0 * density), 3)
	for i in range(w_prop_cnt):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.2, _playable_half_width - 4.0)
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		if i % 2 == 0:
			_spawn_barrel_prop("KnockWinterBarrel", Vector3(lx, road_y + ly + 0.01, lz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
		elif crate_mesh:
			_spawn_knockable_mesh("KnockWinterCrate", crate_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, _local_road_yaw(lz) + rng.randf_range(-0.5, 0.5), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)

	var pylon_mesh := ProceduralMaterials.get_ph_utility_pole_mesh()
	if pylon_mesh:
		var zp := -z_half + 26.0
		var pylon_side := -1.0 if (chunk_index % 2) == 0 else 1.0
		while zp < z_half - 22.0:
			var lx := _local_road_cx(zp) + pylon_side * (road_half + 4.8)
			if not _in_fuel_station_zone(lx, zp) and _reserve_spot(lx, zp, 1.6):
				var ly := _local_terrain_y(chunk_xform, lx, zp)
				var rot := Vector3(rng.randf_range(-0.05, 0.05), _local_road_yaw(zp) + rng.randf_range(-0.15, 0.15), rng.randf_range(-0.07, 0.07))
				_spawn_knockable_mesh("KnockWinterPylon", pylon_mesh, Vector3(lx, road_y + ly + 0.04, zp), rot, Vector3.ONE, Vector3.ZERO, Vector3(0.55, 6.8, 0.55), "wood", 135.0, 3.5, 0.045, Vector3(0.0, 3.45, 0.0))
			zp += 56.0


func _populate_toxic_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)

	var toxic_pine := ProceduralMaterials.get_toxic_pine_tree_mesh()
	if toxic_pine:
		var tree_count := maxi(roundi(420.0 * density), 55)
		var tree_transforms: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 4.0, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.75, 1.45)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.12, lz)
			tree_transforms.append(t)
		_spawn_multimesh("ToxicPines", toxic_pine, tree_transforms, true, 360.0)

	var toxic_rock := ProceduralMaterials.get_toxic_boulder_mesh()
	if toxic_rock:
		var rock_count := maxi(roundi(150.0 * density), 24)
		var rock_transforms: Array[Transform3D] = []
		for i in range(rock_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 2.5, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sx := rng.randf_range(1.2, 4.4)
			var sy := rng.randf_range(0.8, 3.0)
			var sz := rng.randf_range(1.2, 4.2)
			var t := Transform3D()
			t = t.scaled(Vector3(sx, sy, sz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + sy * 0.20, lz)
			rock_transforms.append(t)
		_spawn_multimesh("ToxicRocks", toxic_rock, rock_transforms, false, 345.0)

	for mr_i in range(3, 6):
		var mr := ProceduralMaterials.get_ph_moss_rock_mesh(mr_i)
		if mr:
			var mr_cnt := maxi(roundi(10.0 * density), 3)
			var mr_xf: Array[Transform3D] = []
			for i in range(mr_cnt):
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
				var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 1.0, _playable_half_width + 20.0)
				var ly := _local_terrain_y(chunk_xform, lx, lz)
				var sc := rng.randf_range(0.85, 1.8)
				var t := Transform3D()
				t = t.scaled(Vector3.ONE * sc)
				t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				t.origin = Vector3(lx, road_y + ly - 0.06, lz)
				mr_xf.append(t)
			_spawn_multimesh("ToxicMossRocks_%d" % mr_i, mr, mr_xf, false, 325.0)

	var shrub_mesh := ProceduralMaterials.get_shrub_mesh()
	if shrub_mesh:
		var sc_cnt := maxi(roundi(220.0 * density), 36)
		var scrub_transforms: Array[Transform3D] = []
		for i in range(sc_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 2.2, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.8, 1.65)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * 1.2, sc * 0.95, sc * 1.2))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.04, lz)
			scrub_transforms.append(t)
		_spawn_multimesh("ToxicBogBrush", shrub_mesh, scrub_transforms, false, 315.0)

	# Roadside knockable quarantine barrels, chainlink fences & crates
	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var k_cnt := maxi(roundi(11.0 * density), 4)
	for i in range(k_cnt):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.2, _playable_half_width - 4.5)
		if not _reserve_spot(lx, lz, 2.0):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var yaw := _local_road_yaw(lz) + rng.randf_range(-0.4, 0.4)
		if i % 3 == 0 and fence_mesh:
			_spawn_knockable_mesh("KnockToxicFence", fence_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw + PI * 0.5, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.40, 0.35), "metal", 80.0, 2.2, 0.035)
		elif i % 3 == 1:
			_spawn_barrel_prop("KnockToxicBarrel", Vector3(lx, road_y + ly + 0.01, lz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
		elif crate_mesh:
			_spawn_knockable_mesh("KnockToxicCrate", crate_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)


func _populate_scorched_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)

	var scorched_rock := ProceduralMaterials.get_scorched_boulder_mesh()
	if scorched_rock:
		var rock_count := maxi(roundi(280.0 * density), 36)
		var rock_transforms: Array[Transform3D] = []
		for i in range(rock_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 3.5, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sx := rng.randf_range(1.6, 6.8)
			var sy := rng.randf_range(1.2, 5.6)
			var sz := rng.randf_range(1.6, 6.2)
			var t := Transform3D()
			t = t.scaled(Vector3(sx, sy, sz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + sy * 0.25, lz)
			rock_transforms.append(t)
		_spawn_multimesh("ScorchedBoulders", scorched_rock, rock_transforms, true, 375.0)

		var k_sr := maxi(roundi(8.0 * density), 3)
		for i in range(k_sr):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.0, _playable_half_width - 4.5)
			if not _reserve_spot(lx, lz, 2.0):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.75, 1.32)
			_spawn_knockable_mesh("KnockScorchedRock", scorched_rock, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3(0.0, sc * 0.45, 0.0), Vector3(1.4 * sc, 1.0 * sc, 1.4 * sc), "concrete", 190.0, 5.5, 0.085)

	var ph_desert_rock := ProceduralMaterials.get_ph_boulder_desert_mesh()
	if ph_desert_rock:
		var sr_cnt := maxi(roundi(24.0 * density), 6)
		var sr_xf: Array[Transform3D] = []
		for i in range(sr_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 1.5, _playable_half_width + 22.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.95, 2.2)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.08, lz)
			sr_xf.append(t)
		_spawn_multimesh("ScorchedDesertRocks", ph_desert_rock, sr_xf, false, 340.0)

	var scorched_pine := ProceduralMaterials.get_scorched_pine_tree_mesh()
	if scorched_pine:
		var tree_count := maxi(roundi(140.0 * density), 18)
		var tree_transforms: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 6.0, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.65, 1.25)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.12, lz)
			tree_transforms.append(t)
		_spawn_multimesh("ScorchedTrees", scorched_pine, tree_transforms, false, 355.0)

	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	var dead_log := ProceduralMaterials.get_ph_dead_log_mesh()
	var k_pan := maxi(roundi(10.0 * density), 4)
	for i in range(k_pan):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.5, _playable_half_width - 4.0)
		if not _reserve_spot(lx, lz, 2.2):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var yaw := _local_road_yaw(lz) + rng.randf_range(-0.45, 0.45)
		if i % 3 == 0 and fence_mesh:
			_spawn_knockable_mesh("KnockScorchedFence", fence_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw + PI * 0.5, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.40, 0.35), "metal", 85.0, 2.5, 0.04)
		elif i % 3 == 1:
			_spawn_barrel_prop("KnockScorchedBarrel", Vector3(lx, road_y + ly + 0.01, lz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
		elif dead_log:
			_spawn_knockable_mesh("KnockScorchedLog", dead_log, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(4.2, 0.55, 0.55), "wood", 110.0, 3.2, 0.048)


func _populate_burning_city_scenery(rng: RandomNumberGenerator, _chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 42.0)
	var bldg_min_x := _playable_half_width + 6.0

	var sidewalk_inst := MeshInstance3D.new()
	sidewalk_inst.name = "BurningCitySidewalks"
	sidewalk_inst.mesh = _build_city_sidewalk_mesh(road_half)
	sidewalk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sidewalk_inst.visibility_range_end = 365.0
	add_child(sidewalk_inst)

	var factory_count := maxi(roundi(135.0 * density), 24)
	var tower_buckets: Array[Array] = [[], [], []]
	for i in range(factory_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lat_dist := rng.randf_range(bldg_min_x, max_lat)
		var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
		var lx := _local_road_cx(lz) + side * lat_dist
		var w := rng.randf_range(12.0, 24.0)
		var d := rng.randf_range(12.0, 26.0)
		var max_h := 62.0 if lat_dist > bldg_min_x + 35.0 else 30.0
		var min_h := 22.0 if lat_dist > bldg_min_x + 35.0 else 12.0
		var h := rng.randf_range(min_h, max_h)
		var rot_y := _local_road_yaw(lz) + float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.07, 0.07)
		var t := Transform3D()
		t = t.scaled(Vector3(w, h, d))
		t = t.rotated(Vector3.UP, rot_y)
		t = t.rotated(Vector3.RIGHT, rng.randf_range(-0.03, 0.03))
		t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.03, 0.03))
		t.origin = Vector3(lx, road_y - 0.35, lz)
		var v_idx: int = rng.randi_range(0, 2)
		(tower_buckets[v_idx] as Array).append(t)
	for vi in range(3):
		var t_list: Array[Transform3D] = []
		for xf: Transform3D in (tower_buckets[vi] as Array):
			t_list.append(xf)
		_spawn_multimesh("BurningCityTowers_%d" % vi, ProceduralMaterials.get_burnt_city_tower_mesh(vi), t_list, true, 385.0)

	var brick_count := maxi(roundi(115.0 * density), 20)
	var ruin_buckets: Array[Array] = [[], []]
	for i in range(brick_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var brick_max := maxf(max_lat * 0.85, _playable_half_width + 20.0)
		var lz := rng.randf_range(-z_half + 10.0, z_half - 10.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 4.0, brick_max)
		var w := rng.randf_range(9.0, 17.5)
		var d := rng.randf_range(9.0, 19.0)
		var h := rng.randf_range(7.0, 21.0)
		var t := Transform3D()
		t = t.scaled(Vector3(w, h, d))
		t = t.rotated(Vector3.UP, _local_road_yaw(lz) + float(rng.randi_range(0, 3)) * PI * 0.5 + rng.randf_range(-0.08, 0.08))
		t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.035, 0.035))
		t.origin = Vector3(lx, road_y - 0.30, lz)
		var r_idx: int = rng.randi_range(0, 1)
		(ruin_buckets[r_idx] as Array).append(t)
	for ri in range(2):
		var r_list: Array[Transform3D] = []
		for xf: Transform3D in (ruin_buckets[ri] as Array):
			r_list.append(xf)
		_spawn_multimesh("BurningCityRuins_%d" % ri, ProceduralMaterials.get_burnt_city_ruin_mesh(ri), r_list, true, 365.0)

	var fire_mesh := ProceduralMaterials.get_fire_cluster_mesh()
	if fire_mesh:
		var fire_count := maxi(roundi(85.0 * density), 24)
		var fire_xf: Array[Transform3D] = []
		for i in range(fire_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lat := rng.randf_range(road_half + 1.8, _playable_half_width + 24.0)
			var lx := _local_road_cx(lz) + side * lat
			if _in_fuel_station_zone(lx, lz):
				continue
			var sc_xz := rng.randf_range(1.6, 3.8)
			var sc_y := rng.randf_range(1.8, 4.8)
			var t := Transform3D()
			t = t.scaled(Vector3(sc_xz, sc_y, sc_xz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			var py: float = road_y + (0.28 if lat <= road_half + 12.0 else 0.0)
			t.origin = Vector3(lx, py, lz)
			fire_xf.append(t)
		var bldg_pool: Array[Transform3D] = []
		for arr_t: Array in tower_buckets:
			for xf: Transform3D in arr_t:
				bldg_pool.append(xf)
		for arr_r: Array in ruin_buckets:
			for xf: Transform3D in arr_r:
				bldg_pool.append(xf)
		if not bldg_pool.is_empty():
			var elev_target: int = mini(maxi(roundi(22.0 * density), 8), bldg_pool.size())
			for ei in range(elev_target):
				var b_xf: Transform3D = bldg_pool[rng.randi_range(0, bldg_pool.size() - 1)]
				var b_scale: Vector3 = b_xf.basis.get_scale()
				var fh: float = b_scale.y * rng.randf_range(0.32, 0.72)
				var fx: float = b_xf.origin.x + rng.randf_range(-b_scale.x * 0.22, b_scale.x * 0.22)
				var fz: float = b_xf.origin.z + rng.randf_range(-b_scale.z * 0.22, b_scale.z * 0.22)
				var e_xz := rng.randf_range(1.8, 3.6)
				var e_y := rng.randf_range(2.2, 4.4)
				var et := Transform3D()
				et = et.scaled(Vector3(e_xz, e_y, e_xz))
				et = et.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				et.origin = Vector3(fx, b_xf.origin.y + fh, fz)
				fire_xf.append(et)
		_spawn_multimesh("BurningCityFires", fire_mesh, fire_xf, false, 330.0)
		var smoke_mesh := ProceduralMaterials.get_fire_smoke_plume_mesh()
		if smoke_mesh and not fire_xf.is_empty():
			var smoke_xf: Array[Transform3D] = []
			for si in range(fire_xf.size()):
				if si % 5 == 1 or si % 5 == 3:
					continue
				var f_xf: Transform3D = fire_xf[si]
				var s_xz := rng.randf_range(1.05, 1.75)
				var s_y := rng.randf_range(1.00, 1.85)
				var st_xf := Transform3D()
				st_xf = st_xf.scaled(Vector3(s_xz, s_y, s_xz))
				st_xf = st_xf.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				st_xf.origin = Vector3(f_xf.origin.x, f_xf.origin.y + 0.35, f_xf.origin.z)
				smoke_xf.append(st_xf)
			_spawn_multimesh("BurningCitySmokePlumes", smoke_mesh, smoke_xf, false, 370.0)

	var rubble_mesh := ProceduralMaterials.get_scorched_boulder_mesh()
	if rubble_mesh:
		var rub_count := maxi(roundi(38.0 * density), 12)
		var rub_xf: Array[Transform3D] = []
		for ri2 in range(rub_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lat := rng.randf_range(road_half + 1.4, _playable_half_width + 6.0)
			var lx := _local_road_cx(lz) + side * lat
			if _in_fuel_station_zone(lx, lz):
				continue
			var sx := rng.randf_range(0.55, 1.45)
			var sy := rng.randf_range(0.25, 0.72)
			var sz := rng.randf_range(0.55, 1.45)
			var rt := Transform3D()
			rt = rt.scaled(Vector3(sx, sy, sz))
			rt = rt.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			rt = rt.rotated(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			rt.origin = Vector3(lx, road_y + 0.14 + sy * 0.22, lz)
			rub_xf.append(rt)
		_spawn_multimesh("BurningCityRubble", rubble_mesh, rub_xf, false, 340.0)

	for li in range(6):
		var side := -1.0 if (li % 2 == 0) else 1.0
		var lz := lerpf(-z_half + 35.0, z_half - 35.0, (float(li) + 0.5) / 6.0)
		var lx := _local_road_cx(lz) + side * (road_half + 4.5)
		var fl := OmniLight3D.new()
		fl.name = "BurningCityFireLight_%d" % li
		fl.position = Vector3(lx, road_y + 3.2, lz)
		fl.light_color = Color(1.0, 0.48, 0.12)
		fl.light_energy = 3.0
		fl.omni_range = 32.0
		fl.omni_attenuation = 1.6
		fl.shadow_enabled = false
		add_child(fl)

	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	if fence_mesh:
		var f_count := maxi(roundi(24.0 * density), 8)
		var f_transforms: Array[Transform3D] = []
		for i in range(f_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 0.8, _playable_half_width + 11.0)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.95, 1.25))
			t = t.rotated(Vector3.UP, _local_road_yaw(lz) + PI * 0.5 + rng.randf_range(-0.22, 0.22))
			t.origin = Vector3(lx, road_y - 0.04, lz)
			f_transforms.append(t)
		_spawn_multimesh("BurningCityFences", fence_mesh, f_transforms, false, 330.0)

	var barrel_mesh := ProceduralMaterials.get_ph_barrel_mesh()
	if barrel_mesh:
		var b_count := maxi(roundi(24.0 * density), 8)
		var b_transforms: Array[Transform3D] = []
		for i in range(b_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 0.5, _playable_half_width + 14.0)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.9, 1.15))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y - 0.02, lz)
			b_transforms.append(t)
		_spawn_multimesh("BurningCityBarrels", barrel_mesh, b_transforms, false, 320.0)

	var lamp_mesh := ProceduralMaterials.get_ph_street_lamp_mesh()
	var z_pos := -z_half + 24.0
	while z_pos < z_half - 20.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var pole_x: float = cx + side * (road_half + 1.5)
			if _in_fuel_station_zone(pole_x, z_pos) or not _reserve_spot(pole_x, z_pos, 1.6):
				continue
			var tilt := rng.randf_range(-0.08, 0.08) if rng.randf() < 0.35 else 0.0
			_spawn_knockable_streetlight(lamp_mesh, Vector3(pole_x, road_y + 0.32, z_pos), tilt, side, r_yaw)
		z_pos += 48.0

	var trash_mesh := ProceduralMaterials.get_ph_trash_can_mesh()
	var hydrant_mesh := ProceduralMaterials.get_ph_fire_hydrant_mesh()
	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var street_prop_count := maxi(roundi(24.0 * density), 10)
	for i in range(street_prop_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 10.0, z_half - 10.0)
		var lat := rng.randf_range(road_half + 1.8, _playable_half_width - 2.5)
		var lx := _local_road_cx(lz) + side * lat
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var prop_y: float = road_y + (0.33 if lat <= road_half + 12.0 else 0.03)
		var yaw: float = _local_road_yaw(lz) + rng.randf_range(-0.35, 0.35)
		match i % 5:
			0:
				_spawn_barrel_prop("KnockBurningBarrel", Vector3(lx, prop_y, lz), yaw, rng.randf() < 0.60)
			1:
				if trash_mesh:
					_spawn_knockable_mesh("KnockBurningTrashCan", trash_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.6, 0.95, 0.75), "metal", 55.0, 1.8, 0.025)
			2:
				if hydrant_mesh:
					_spawn_knockable_mesh("KnockBurningHydrant", hydrant_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.85, 0.92, 0.55), "metal", 75.0, 2.5, 0.035)
			3:
				if crate_mesh:
					_spawn_knockable_mesh("KnockBurningCrate", crate_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)
			_:
				if fence_mesh:
					_spawn_knockable_mesh("KnockBurningFence", fence_mesh, Vector3(lx, prop_y, lz), Vector3(0.0, yaw + PI * 0.5, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.40, 0.35), "metal", 85.0, 2.5, 0.04)


func _populate_burnt_forest_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)
	var tree_min_x := _playable_half_width + 3.5

	var burnt_tree := ProceduralMaterials.get_burnt_tree_mesh()
	if burnt_tree:
		var tree_count := maxi(roundi(720.0 * density), 110)
		var tree_xf: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 3.0, z_half - 3.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(tree_min_x, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.85, 1.65)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t = t.rotated(Vector3.RIGHT, rng.randf_range(-0.14, 0.14))
			t = t.rotated(Vector3.FORWARD, rng.randf_range(-0.14, 0.14))
			t.origin = Vector3(lx, road_y + ly - 0.10, lz)
			tree_xf.append(t)
		_spawn_multimesh("BurntForestTrees", burnt_tree, tree_xf, true, 380.0)

	var fire_mesh := ProceduralMaterials.get_fire_cluster_mesh()
	if fire_mesh:
		var smolder_count := maxi(roundi(50.0 * density), 16)
		var smolder_xf: Array[Transform3D] = []
		for i in range(smolder_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 8.0, z_half - 8.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.5, _playable_half_width + 26.0)
			if _in_fuel_station_zone(lx, lz):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc_xz := rng.randf_range(0.9, 2.1)
			var sc_y := rng.randf_range(0.95, 2.25)
			var t := Transform3D()
			t = t.scaled(Vector3(sc_xz, sc_y, sc_xz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.02, lz)
			smolder_xf.append(t)
		_spawn_multimesh("BurntForestSmolders", fire_mesh, smolder_xf, false, 320.0)
		var forest_smoke := ProceduralMaterials.get_fire_smoke_plume_mesh()
		if forest_smoke and not smolder_xf.is_empty():
			var f_smoke_xf: Array[Transform3D] = []
			for si in range(0, smolder_xf.size(), 2):
				var f_xf: Transform3D = smolder_xf[si]
				var s_xz := rng.randf_range(0.85, 1.45)
				var s_y := rng.randf_range(0.85, 1.45)
				var st_xf := Transform3D()
				st_xf = st_xf.scaled(Vector3(s_xz, s_y, s_xz))
				st_xf = st_xf.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				st_xf.origin = Vector3(f_xf.origin.x, f_xf.origin.y + 0.25, f_xf.origin.z)
				f_smoke_xf.append(st_xf)
			_spawn_multimesh("BurntForestSmokePlumes", forest_smoke, f_smoke_xf, false, 350.0)

	for li in range(4):
		var side := -1.0 if (li % 2 == 0) else 1.0
		var lz := lerpf(-z_half + 45.0, z_half - 45.0, (float(li) + 0.5) / 4.0)
		var lx := _local_road_cx(lz) + side * (road_half + 5.0)
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var el := OmniLight3D.new()
		el.name = "BurntForestEmberLight_%d" % li
		el.position = Vector3(lx, road_y + ly + 2.4, lz)
		el.light_color = Color(1.0, 0.36, 0.08)
		el.light_energy = 2.8
		el.omni_range = 22.0
		el.omni_attenuation = 1.6
		el.shadow_enabled = false
		add_child(el)

	var scorched_rock := ProceduralMaterials.get_scorched_boulder_mesh()
	if scorched_rock:
		var rock_count := maxi(roundi(130.0 * density), 20)
		var rock_xf: Array[Transform3D] = []
		for i in range(rock_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 4.0, z_half - 4.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 2.5, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sx := rng.randf_range(1.2, 4.4)
			var sy := rng.randf_range(0.9, 3.2)
			var sz := rng.randf_range(1.2, 4.2)
			var t := Transform3D()
			t = t.scaled(Vector3(sx, sy, sz))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + sy * 0.24, lz)
			rock_xf.append(t)
		_spawn_multimesh("BurntForestRocks", scorched_rock, rock_xf, false, 360.0)

	var ph_desert_rock := ProceduralMaterials.get_ph_boulder_desert_mesh()
	if ph_desert_rock:
		var dr_cnt := maxi(roundi(20.0 * density), 6)
		var dr_xf: Array[Transform3D] = []
		for i in range(dr_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 1.5, _playable_half_width + 22.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.9, 2.0)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.08, lz)
			dr_xf.append(t)
		_spawn_multimesh("BurntForestBoulders", ph_desert_rock, dr_xf, false, 340.0)

	var ph_dead_log := ProceduralMaterials.get_ph_dead_log_mesh()
	var fallback_log := ProceduralMaterials.get_log_mesh()
	var log_mesh: Mesh = (ph_dead_log as Mesh) if ph_dead_log != null else (fallback_log as Mesh)
	var is_ph_log: bool = (ph_dead_log != null)
	if log_mesh:
		var log_count := maxi(roundi(32.0 * density), 8)
		var log_xf: Array[Transform3D] = []
		for i in range(log_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width + 2.0, max_lat - 10.0)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * rng.randf_range(0.85, 1.35))
			if not is_ph_log:
				t = t.rotated(Vector3.FORWARD, PI * 0.5 + rng.randf_range(-0.08, 0.08))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly + (0.02 if is_ph_log else 0.25), lz)
			log_xf.append(t)
		_spawn_multimesh("BurntForestLogs", log_mesh, log_xf, false, 330.0)

		var k_log_cnt := maxi(roundi(9.0 * density), 4)
		for i in range(k_log_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.8, _playable_half_width - 4.0)
			if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.5):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var yaw := rng.randf_range(0.0, TAU)
			if is_ph_log:
				_spawn_knockable_mesh("KnockBurntLog", log_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw, 0.0), Vector3(0.95, 0.95, 0.95), Vector3.ZERO, Vector3(4.3, 0.62, 0.62), "wood", 125.0, 3.8, 0.06, Vector3(0.0, 0.32, 0.0))
			else:
				_spawn_knockable_mesh("KnockBurntLog", log_mesh, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, yaw, 0.0), Vector3(0.85, 0.85, 0.85), Vector3(0.0, 0.36, 0.0), Vector3(4.4, 0.68, 0.68), "wood", 125.0, 3.8, 0.06, Vector3(0.0, 0.36, 0.0), Vector3(0.0, 0.0, PI * 0.5))

	if scorched_rock:
		var k_rock_cnt := maxi(roundi(8.0 * density), 3)
		for i in range(k_rock_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.0, _playable_half_width - 4.5)
			if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.75, 1.30)
			_spawn_knockable_mesh("KnockBurntRock", scorched_rock, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3(0.0, sc * 0.45, 0.0), Vector3(1.4 * sc, 1.0 * sc, 1.4 * sc), "concrete", 190.0, 5.5, 0.085)

	var rail_mesh := ProceduralMaterials.get_guardrail_mesh()
	var z_pos := -z_half + 14.0
	while z_pos < z_half - 14.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var rail_x: float = cx + side * (road_half + 1.5)
			if _in_fuel_station_zone(rail_x, z_pos) or not _reserve_spot(rail_x, z_pos, 3.0):
				continue
			if rng.randf() < 0.48 and rail_mesh:
				var yaw := r_yaw + rng.randf_range(-0.06, 0.06)
				_spawn_knockable_mesh("KnockBurntGuardrail", rail_mesh, Vector3(rail_x, road_y + 0.03, z_pos), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.45, 0.88, 14.0), "metal", 95.0, 3.0, 0.045, Vector3(0.0, 0.44, 0.0))
		z_pos += 28.0


func _populate_overgrown_scenery(rng: RandomNumberGenerator, chunk_xform: Transform3D, density: float) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var max_lat := maxf(chunk_width * 0.5 - 78.0, _playable_half_width + 36.0)
	var tree_min_x := _playable_half_width + 3.5

	var grass_mesh := ProceduralMaterials.get_tall_grass_clump_mesh()
	if grass_mesh:
		var grass_count := maxi(roundi(1500.0 * density), 280)
		var grass_xf: Array[Transform3D] = []
		for i in range(grass_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 2.0, z_half - 2.0)
			var cx := _local_road_cx(lz)
			var lx: float
			var py: float
			var sc: float
			if rng.randf() < 0.35:
				if rng.randf() < 0.25:
					lx = cx + rng.randf_range(-1.8, 1.8)
				else:
					lx = cx + side * rng.randf_range(road_half - 4.5, road_half + 2.5)
				if _in_fuel_station_zone(lx, lz):
					continue
				py = road_y + 0.01
				sc = rng.randf_range(0.65, 1.25)
			else:
				lx = cx + side * rng.randf_range(road_half + 1.5, _playable_half_width + 32.0)
				if _in_fuel_station_zone(lx, lz):
					continue
				py = road_y + _local_terrain_y(chunk_xform, lx, lz) - 0.04
				sc = rng.randf_range(1.0, 2.1)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * rng.randf_range(0.95, 1.30), sc, sc * rng.randf_range(0.95, 1.30)))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, py, lz)
			grass_xf.append(t)
		_spawn_multimesh("OvergrownTallGrass", grass_mesh, grass_xf, false, 310.0)

	var pine_mesh := ProceduralMaterials.get_pine_tree_mesh()
	if pine_mesh:
		var tree_count := maxi(roundi(460.0 * density), 80)
		var pine_xf: Array[Transform3D] = []
		for i in range(tree_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 3.0, z_half - 3.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(tree_min_x, max_lat)
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.85, 1.65)
			var t := Transform3D()
			t = t.scaled(Vector3.ONE * sc)
			t = t.rotated(Vector3.RIGHT, deg_to_rad(-90.0))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.10, lz)
			pine_xf.append(t)
		_spawn_multimesh("OvergrownPines", pine_mesh, pine_xf, true, 380.0)

	var shrub_mesh := ProceduralMaterials.get_shrub_mesh()
	if shrub_mesh:
		var shrub_count := maxi(roundi(240.0 * density), 48)
		var shrub_xf: Array[Transform3D] = []
		for i in range(shrub_count):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 3.0, z_half - 3.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 2.2, max_lat)
			if _in_fuel_station_zone(lx, lz):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var sc := rng.randf_range(0.80, 1.65)
			var t := Transform3D()
			t = t.scaled(Vector3(sc * 1.25, sc * 0.92, sc * 1.25))
			t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
			t.origin = Vector3(lx, road_y + ly - 0.04, lz)
			shrub_xf.append(t)
		_spawn_multimesh("OvergrownShrubs", shrub_mesh, shrub_xf, false, 335.0)

	for mr_i in range(3):
		var mr_mesh := ProceduralMaterials.get_ph_moss_rock_mesh(mr_i)
		if mr_mesh:
			var mr_cnt := maxi(roundi(12.0 * density), 4)
			var mr_xf: Array[Transform3D] = []
			for i in range(mr_cnt):
				var side := -1.0 if rng.randf() < 0.5 else 1.0
				var lz := rng.randf_range(-z_half + 6.0, z_half - 6.0)
				var lx := _local_road_cx(lz) + side * rng.randf_range(_playable_half_width - 1.0, _playable_half_width + 20.0)
				var ly := _local_terrain_y(chunk_xform, lx, lz)
				var sc := rng.randf_range(0.85, 1.85)
				var t := Transform3D()
				t = t.scaled(Vector3.ONE * sc)
				t = t.rotated(Vector3.UP, rng.randf_range(0.0, TAU))
				t.origin = Vector3(lx, road_y + ly - 0.06, lz)
				mr_xf.append(t)
			_spawn_multimesh("OvergrownMossRocks_%d" % mr_i, mr_mesh, mr_xf, false, 340.0)

	var k_rock_cnt := maxi(roundi(7.0 * density), 3)
	for i in range(k_rock_cnt):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lz := rng.randf_range(-z_half + 14.0, z_half - 14.0)
		var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 5.0, _playable_half_width - 4.5)
		if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.0):
			continue
		var ly := _local_terrain_y(chunk_xform, lx, lz)
		var mr := ProceduralMaterials.get_ph_moss_rock_mesh(i % 3)
		if mr:
			var sc := rng.randf_range(0.70, 1.15)
			_spawn_knockable_mesh("KnockOvergrownRock", mr, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE * sc, Vector3.ZERO, Vector3(1.5 * sc, 1.0 * sc, 1.5 * sc), "concrete", 185.0, 5.5, 0.085)

	var ph_dead_log := ProceduralMaterials.get_ph_dead_log_mesh()
	var fallback_log := ProceduralMaterials.get_log_mesh()
	var log_mesh: Mesh = (ph_dead_log as Mesh) if ph_dead_log != null else (fallback_log as Mesh)
	var is_ph_log: bool = (ph_dead_log != null)
	if log_mesh:
		var k_log_cnt := maxi(roundi(8.0 * density), 4)
		for i in range(k_log_cnt):
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var lz := rng.randf_range(-z_half + 12.0, z_half - 12.0)
			var lx := _local_road_cx(lz) + side * rng.randf_range(road_half + 3.8, _playable_half_width - 4.0)
			if _in_fuel_station_zone(lx, lz) or not _reserve_spot(lx, lz, 2.5):
				continue
			var ly := _local_terrain_y(chunk_xform, lx, lz)
			var yaw := rng.randf_range(0.0, TAU)
			if is_ph_log:
				_spawn_knockable_mesh("KnockOvergrownLog", log_mesh, Vector3(lx, road_y + ly + 0.03, lz), Vector3(0.0, yaw, 0.0), Vector3(0.95, 0.95, 0.95), Vector3.ZERO, Vector3(4.3, 0.62, 0.62), "wood", 130.0, 4.0, 0.065, Vector3(0.0, 0.32, 0.0))
			else:
				_spawn_knockable_mesh("KnockOvergrownLog", log_mesh, Vector3(lx, road_y + ly + 0.04, lz), Vector3(0.0, yaw, 0.0), Vector3(0.85, 0.85, 0.85), Vector3(0.0, 0.36, 0.0), Vector3(4.4, 0.68, 0.68), "wood", 130.0, 4.0, 0.065, Vector3(0.0, 0.36, 0.0), Vector3(0.0, 0.0, PI * 0.5))

	var rail_mesh := ProceduralMaterials.get_guardrail_mesh()
	var z_pos := -z_half + 14.0
	while z_pos < z_half - 14.0:
		var cx := _local_road_cx(z_pos)
		var r_yaw := _local_road_yaw(z_pos)
		for side in [-1.0, 1.0]:
			var rail_x: float = cx + side * (road_half + 1.5)
			if _in_fuel_station_zone(rail_x, z_pos) or not _reserve_spot(rail_x, z_pos, 3.0):
				continue
			if rng.randf() < 0.45 and rail_mesh:
				var yaw := r_yaw + rng.randf_range(-0.05, 0.05)
				_spawn_knockable_mesh("KnockOvergrownGuardrail", rail_mesh, Vector3(rail_x, road_y + 0.03, z_pos), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(0.45, 0.88, 14.0), "metal", 95.0, 3.0, 0.045, Vector3(0.0, 0.44, 0.0))
		z_pos += 28.0


func _reserve_spot(lx: float, lz: float, radius: float) -> bool:
	for sp: Vector3 in _placed_spots:
		var min_d: float = sp.z + radius
		var dx: float = lx - sp.x
		var dz: float = lz - sp.y
		if dx * dx + dz * dz < min_d * min_d:
			return false
	_placed_spots.append(Vector3(lx, lz, radius))
	return true


func _build_post_apoc_highway_details(
	rng: RandomNumberGenerator,
	chunk_xform: Transform3D,
	density: float,
	skip_landing_zone: bool,
	skip_takeoff_zone: bool
) -> void:
	var z_half := chunk_length * 0.5
	var road_half := _road_width * 0.5
	var min_z := -z_half + (135.0 if skip_takeoff_zone else 24.0)
	var max_z := z_half - (170.0 if skip_landing_zone else (55.0 if chunk_index == 0 else 24.0))
	if max_z <= min_z + 25.0:
		return

	# 1. Наддорожные стальные порталы (Highway Overhead Gantries) — повернуты по касательной к изгибу трассы
	var gantry_mesh := ProceduralMaterials.get_overhead_gantry_mesh()
	if gantry_mesh and not skip_takeoff_zone:
		var gantry_count := 2 if (max_z - min_z) > 260.0 else 1
		var x_scale := (road_half + 2.8) / 19.0
		var gx_leg := 19.0 * x_scale
		for g_idx in range(gantry_count):
			var frac := (float(g_idx) + 0.5) / float(gantry_count)
			var gz := lerpf(min_z + 20.0, max_z - 20.0, frac) + rng.randf_range(-18.0, 18.0)
			if chunk_index == 0 and g_idx == 0 and gz > -32.0:
				gz = -78.0
			var g_cx := _local_road_cx(gz)
			var g_yaw := _local_road_yaw(gz)
			if not _reserve_spot(g_cx - gx_leg, gz, 2.2) or not _reserve_spot(g_cx + gx_leg, gz, 2.2):
				continue
			var gantry_mi := MeshInstance3D.new()
			gantry_mi.name = "HighwayGantry_%d" % g_idx
			gantry_mi.mesh = gantry_mesh
			gantry_mi.scale = Vector3(x_scale, 1.0, 1.0)
			gantry_mi.position = Vector3(g_cx, road_y, gz)
			gantry_mi.rotation = Vector3(rng.randf_range(-0.02, 0.02), g_yaw + rng.randf_range(-0.03, 0.03), rng.randf_range(-0.025, 0.025))
			gantry_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gantry_mi.visibility_range_end = 365.0
			add_child(gantry_mi)

			var leg_body := StaticBody3D.new()
			leg_body.collision_layer = 1
			leg_body.collision_mask = 0
			leg_body.position = Vector3(g_cx, road_y, gz)
			leg_body.rotation = Vector3(0.0, g_yaw, 0.0)
			for side in [-1.0, 1.0]:
				var lcol := CollisionShape3D.new()
				lcol.shape = _get_box_shape(Vector3(0.75, 8.8, 0.75))
				lcol.position = Vector3(side * gx_leg, 4.4, 0.0)
				leg_body.add_child(lcol)
			add_child(leg_body)

	# 2. Высокие ржавые билборды вдоль шоссе (сценические + сбиваемые у обочины)
	var scenic_bb_count := maxi(roundi(2.5 * density), 1)
	for i in range(scenic_bb_count):
		var side := -1.0 if ((chunk_index + i) % 2 == 0) else 1.0
		var bz := rng.randf_range(min_z + 10.0, max_z - 10.0)
		var bx := _local_road_cx(bz) + side * (_playable_half_width + rng.randf_range(4.5, 11.5))
		var by := _local_terrain_y(chunk_xform, bx, bz)
		var b_var := (absi(chunk_index) * 3 + i) % 4
		var bb_mesh := ProceduralMaterials.get_billboard_frame_mesh(b_var)
		if bb_mesh:
			var bmi := MeshInstance3D.new()
			bmi.name = "RoadsideBillboard_%d" % i
			bmi.mesh = bb_mesh
			var sc := rng.randf_range(0.95, 1.25)
			bmi.scale = Vector3.ONE * sc
			bmi.position = Vector3(bx, road_y + by - 0.1, bz)
			bmi.rotation = Vector3(rng.randf_range(-0.04, 0.04), _local_road_yaw(bz) - side * rng.randf_range(0.14, 0.34), rng.randf_range(-0.08, 0.08))
			bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			bmi.visibility_range_end = 360.0
			add_child(bmi)

	# Сбиваемый небольшой придорожный рекламный щит на широкой обочине
	if rng.randf() < 0.75:
		var side_k := 1.0 if (chunk_index % 2 == 0) else -1.0
		var kbz := rng.randf_range(min_z + 18.0, max_z - 18.0)
		var kbx := _local_road_cx(kbz) + side_k * rng.randf_range(road_half + 7.0, _playable_half_width - 5.5)
		if _reserve_spot(kbx, kbz, 3.4):
			var kby := _local_terrain_y(chunk_xform, kbx, kbz)
			var kbb_mesh := ProceduralMaterials.get_billboard_frame_mesh(rng.randi_range(0, 3))
			if kbb_mesh:
				_spawn_knockable_mesh(
					"KnockBillboard",
					kbb_mesh,
					Vector3(kbx, road_y + kby + 0.04, kbz),
					Vector3(0.0, _local_road_yaw(kbz) - side_k * 0.20, rng.randf_range(-0.07, 0.07)),
					Vector3.ONE * 0.68,
					Vector3.ZERO,
					Vector3(3.8, 4.4, 0.55),
					"metal",
					175.0,
					4.5,
					0.06,
					Vector3(0.0, 2.2, 0.0)
				)

	# 3. Предупреждающие и карантинные дорожные знаки (сбиваемые)
	var sign_count := maxi(roundi(4.0 * density), 2)
	for i in range(sign_count):
		var side := -1.0 if (i % 2 == 0) else 1.0
		var sz := rng.randf_range(min_z + 8.0, max_z - 8.0)
		var sx := _local_road_cx(sz) + side * (road_half + rng.randf_range(1.9, 3.2))
		if _in_fuel_station_zone(sx, sz) or not _reserve_spot(sx, sz, 1.4):
			continue
		var sy := _local_terrain_y(chunk_xform, sx, sz)
		var is_haz := rng.randf() < 0.45
		var s_mesh := ProceduralMaterials.get_road_sign_mesh(is_haz)
		if s_mesh:
			_spawn_knockable_mesh(
				"KnockRoadSign",
				s_mesh,
				Vector3(sx, road_y + sy + 0.03, sz),
				Vector3(rng.randf_range(-0.05, 0.05), _local_road_yaw(sz) + rng.randf_range(-0.25, 0.25), rng.randf_range(-0.10, 0.10)),
				Vector3.ONE * 1.15,
				Vector3.ZERO,
				Vector3(0.85, 2.8, 0.45),
				"metal",
				65.0,
				2.2,
				0.025,
				Vector3(0.0, 1.4, 0.0)
			)

	# 4. Военные и деревянные ящики / бочки у обочины (сбиваемые пропы)
	var ph_crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var crate_count := maxi(roundi(4.0 * density), 2)
	for i in range(crate_count):
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var cz := rng.randf_range(min_z + 12.0, max_z - 12.0)
		var cx := _local_road_cx(cz) + side * rng.randf_range(road_half + 2.6, _playable_half_width - 4.0)
		if _in_fuel_station_zone(cx, cz) or not _reserve_spot(cx, cz, 1.6):
			continue
		var cy := _local_terrain_y(chunk_xform, cx, cz)
		if i % 3 == 1 and ph_crate_mesh:
			_spawn_knockable_mesh("KnockHighwayCrate", ph_crate_mesh, Vector3(cx, road_y + cy + 0.03, cz), Vector3(0.0, rng.randf_range(0.0, TAU), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)
		elif i % 3 == 2:
			_spawn_barrel_prop("KnockHighwayBarrel", Vector3(cx, road_y + cy + 0.01, cz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
		elif GLTF_CRATE:
			var kp := KnockableProp.new()
			kp.name = "KnockMilitaryCrate"
			kp.prop_material = "wood"
			kp.prop_mass = 90.0
			kp.damage_to_car = 2.5
			kp.speed_drag_factor = 0.035
			kp.prop_height = 1.05
			kp.position = Vector3(cx, road_y + cy + 0.03, cz)
			kp.rotation = Vector3(0.0, rng.randf_range(0.0, TAU), 0.0)
			var c_vis := GLTF_CRATE.instantiate() as Node3D
			if c_vis:
				c_vis.scale = Vector3.ONE * 1.25
				kp.add_child(c_vis)
				_optimize_obstacle_node(c_vis, 325.0, true)
			var col := CollisionShape3D.new()
			col.shape = _get_box_shape(Vector3(1.15, 0.95, 1.15))
			col.position = Vector3(0.0, 0.48, 0.0)
			kp.add_child(col)
			add_child(kp)

	# 5. Далёкий дым от сгоревшего остова на обочине для атмосферности
	if density >= 0.75 and rng.randf() < 0.72:
		var side_s := 1.0 if rng.randf() < 0.5 else -1.0
		var sm_z := rng.randf_range(min_z + 30.0, max_z - 30.0)
		var sm_x := _local_road_cx(sm_z) + side_s * rng.randf_range(_playable_half_width + 2.5, _playable_half_width + 16.0)
		var sm_y := _local_terrain_y(chunk_xform, sm_x, sm_z)
		var smoke := _create_distant_wreck_smoke()
		smoke.position = Vector3(sm_x, road_y + sm_y + 1.0, sm_z)
		add_child(smoke)


func _create_distant_wreck_smoke() -> CPUParticles3D:
	var smk := CPUParticles3D.new()
	smk.name = "WreckHorizonSmoke"
	smk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smk.amount = 9
	smk.lifetime = 3.2
	smk.local_coords = false
	var qm := QuadMesh.new()
	qm.size = Vector2(2.8, 2.8)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.vertex_color_use_as_albedo = true
	var vfx_node: Node = get_node_or_null("/root/CarVFX")
	if vfx_node == null and Engine.get_main_loop() is SceneTree:
		vfx_node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("CarVFX")
	if vfx_node:
		var puff_tex: Variant = vfx_node.get("tex_smoke_puff")
		if puff_tex == null:
			puff_tex = vfx_node.get("tex_smoke")
		if puff_tex is Texture2D:
			mat.albedo_texture = puff_tex as Texture2D
	qm.material = mat
	smk.mesh = qm
	smk.direction = Vector3(0.18, 1.0, -0.10).normalized()
	smk.spread = 16.0
	smk.gravity = Vector3(0.0, 0.35, 0.0)
	smk.initial_velocity_min = 1.4
	smk.initial_velocity_max = 2.6
	smk.scale_amount_min = 0.85
	smk.scale_amount_max = 2.1
	smk.visibility_range_end = 330.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.75, 1.0])
	grad.colors = PackedColorArray([
		Color(0.12, 0.11, 0.11, 0.0),
		Color(0.15, 0.14, 0.14, 0.36),
		Color(0.24, 0.23, 0.23, 0.16),
		Color(0.32, 0.32, 0.32, 0.0),
	])
	smk.color_ramp = grad
	return smk

func _in_fuel_station_zone(_lx: float, _lz: float) -> bool:
	return false

func _in_setpiece_band(lz: float) -> bool:
	for b: Vector2 in _setpiece_z_bands:
		if lz >= b.x and lz <= b.y:
			return true
	return false

func _curve_point(lat: float, lz: float, dz_off: float = 0.0) -> Vector3:
	var cx: float = _local_road_cx(lz)
	var ry: float = _local_road_yaw(lz)
	var off: Vector3 = Basis(Vector3.UP, ry) * Vector3(lat, 0.0, dz_off)
	return Vector3(cx + off.x, road_y, lz + off.z)

func _find_straight_z(target_z: float, min_z: float, max_z: float) -> float:
	var lo: float = min_z + 24.0
	var hi: float = max_z - 24.0
	if hi <= lo:
		return clampf(target_z, min_z, max_z)
	var best_z: float = clampf(target_z, lo, hi)
	var best_score: float = INF
	var z: float = lo
	while z <= hi:
		var yaw_c: float = absf(_local_road_yaw(z))
		var curv: float = absf(_local_road_yaw(z - 12.0) - _local_road_yaw(z + 12.0))
		var score: float = yaw_c * 3.0 + curv * 1.5 + absf(z - target_z) * 0.0006
		if score < best_score:
			best_score = score
			best_z = z
		z += 4.0
	return best_z


func _spawn_stunt_ramp(pos: Vector3, yaw: float, width: float = 8.4, height: float = 2.6, length: float = 11.5) -> void:
	_reserve_spot(pos.x, pos.z, 6.2)
	var sb := StaticBody3D.new()
	sb.name = "StuntRamp"
	sb.collision_layer = 513
	sb.collision_mask = 0
	sb.position = pos
	sb.rotation = Vector3(0.0, yaw, 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = ProceduralMaterials.get_stunt_ramp_mesh(width, height, length)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 360.0
	sb.add_child(mi)
	var hw := width * 0.5
	var hl := length * 0.5
	var col := CollisionShape3D.new()
	var cvx := ConvexPolygonShape3D.new()
	cvx.points = PackedVector3Array([
		Vector3(-hw, 0.0, -hl),
		Vector3(hw, 0.0, -hl),
		Vector3(-hw, 0.0, hl),
		Vector3(hw, 0.0, hl),
		Vector3(-hw, height, -hl),
		Vector3(hw, height, -hl),
	])
	col.shape = cvx
	sb.add_child(col)
	add_child(sb)


func _place_varied_barricade_prop(
	rng: RandomNumberGenerator,
	px: float,
	pz: float,
	yaw: float,
	allow_barrier: bool
) -> bool:
	if _in_fuel_station_zone(px, pz):
		return false
	var ly: float = _local_terrain_y(_chunk_xform, px, pz)
	if allow_barrier and rng.randf() < 0.22:
		if _reserve_spot(px, pz, 2.3):
			_spawn_knockable_concrete_barrier(Vector3(px, road_y + ly + 0.04, pz), yaw + rng.randf_range(-0.14, 0.14))
			return true
		return false

	var roll: int = rng.randi_range(0, 9)
	if roll <= 2:
		var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
		if fence_mesh and _reserve_spot(px, pz, 2.2):
			_spawn_knockable_mesh("KnockBarricadeFence", fence_mesh, Vector3(px, road_y + ly + 0.03, pz), Vector3(0.0, yaw, 0.0), Vector3.ONE, Vector3.ZERO, Vector3(3.85, 2.40, 0.35), "metal", 85.0, 2.5, 0.04)
			return false
	elif roll <= 5:
		if _reserve_spot(px, pz, 1.4):
			_spawn_barrel_prop("KnockBarricadeBarrel", Vector3(px, road_y + ly + 0.01, pz), rng.randf_range(0.0, TAU), rng.randf() < 0.55)
			return false
	elif roll <= 7:
		var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
		if crate_mesh and _reserve_spot(px, pz, 1.6):
			_spawn_knockable_mesh("KnockBarricadeCrate", crate_mesh, Vector3(px, road_y + ly + 0.03, pz), Vector3(0.0, yaw + rng.randf_range(-0.35, 0.35), 0.0), Vector3.ONE, Vector3.ZERO, Vector3(1.75, 0.80, 0.95), "wood", 75.0, 2.0, 0.032)
			return false

	var wreck_idx: int = rng.randi_range(0, 4)
	_place_obstacle_at(rng, px, pz, wreck_idx, yaw + rng.randf_range(-0.35, 0.35), true)
	return false


func _place_varied_barricade_line(
	rng: RandomNumberGenerator,
	line_z: float,
	gap_lat: float,
	gap_half: float,
	ry: float,
	road_half: float,
	alt_gap_lat: float = 9999.0,
	alt_gap_half: float = 0.0
) -> void:
	var barriers_placed: int = 0
	var prev_was_barrier: bool = false
	var lat: float = -road_half - 10.0
	var max_lat: float = road_half + 10.0
	while lat <= max_lat:
		var in_main_gap: bool = absf(lat - gap_lat) < (gap_half + 1.5)
		var in_alt_gap: bool = (alt_gap_half > 0.0) and absf(lat - alt_gap_lat) < (alt_gap_half + 1.2)
		if not in_main_gap and not in_alt_gap:
			var pt := _curve_point(lat, line_z, rng.randf_range(-1.2, 1.2))
			var allow_b: bool = (barriers_placed < 2) and (not prev_was_barrier) and (absf(lat) <= road_half + 3.0)
			var placed_b := _place_varied_barricade_prop(rng, pt.x, pt.z, ry + rng.randf_range(-0.22, 0.22), allow_b)
			prev_was_barrier = placed_b
			if placed_b:
				barriers_placed += 1
		else:
			prev_was_barrier = false
		lat += rng.randf_range(5.0, 7.6)


func _spawn_tactical_setpieces(rng: RandomNumberGenerator, min_z: float, max_z: float) -> void:
	if chunk_index < 1:
		return
	var span := max_z - min_z
	if span < 95.0:
		return

	var road_half := _road_width * 0.5
	var slots: Array[float] = []
	if chunk_index >= 2 and span > 300.0:
		slots = [lerpf(min_z + 55.0, max_z - 55.0, 0.30), lerpf(min_z + 55.0, max_z - 55.0, 0.72)]
	else:
		slots = [lerpf(min_z + 45.0, max_z - 45.0, 0.52)]

	var spawned_ramp: bool = false
	for s_i in range(slots.size()):
		var sz := slots[s_i] + rng.randf_range(-16.0, 16.0)
		var kind := (absi(chunk_index) * 2 + s_i + rng.randi_range(0, 3)) % 4
		var ry := _local_road_yaw(sz)

		match kind:
			0: # BarricadeBreach: смешанный завал с широким проездом без светящихся маяков
				_setpiece_z_bands.append(Vector2(sz - 28.0, sz + 28.0))
				var lane_choices := [-road_half * 0.60, 0.0, road_half * 0.60]
				var gap_lat: float = lane_choices[rng.randi_range(0, lane_choices.size() - 1)]
				_place_varied_barricade_line(rng, sz, gap_lat, 4.8, ry, road_half)

			1: # ChicaneSqueeze: двойная змейка с чередующимися широкими проходами
				_setpiece_z_bands.append(Vector2(sz - 44.0, sz + 44.0))
				var first_right := (rng.randi() % 2 == 0)
				for leg in range(2):
					var leg_z := sz + (24.0 if leg == 0 else -24.0)
					var leg_yaw := _local_road_yaw(leg_z)
					var open_side := (1.0 if first_right else -1.0) * (1.0 if leg == 0 else -1.0)
					var open_lat := open_side * (road_half * 0.56)
					_place_varied_barricade_line(rng, leg_z, open_lat, 4.9, leg_yaw, road_half)

			2: # SmashGateBarricade: баррикада с пробивными жёлто-чёрными воротами в проходе
				_setpiece_z_bands.append(Vector2(sz - 28.0, sz + 28.0))
				var gate_lat := rng.randf_range(-road_half * 0.45, road_half * 0.45)
				var gate_pt := _curve_point(gate_lat, sz, 0.0)
				var gate_mesh := ProceduralMaterials.get_smash_gate_mesh()
				if gate_mesh and _reserve_spot(gate_pt.x, gate_pt.z, 2.5):
					_spawn_knockable_mesh(
						"KnockQuarantineGate",
						gate_mesh,
						Vector3(gate_pt.x, road_y + 0.04, gate_pt.z),
						Vector3(0.0, ry, 0.0),
						Vector3.ONE,
						Vector3.ZERO,
						Vector3(7.6, 2.2, 0.45),
						"wood",
						80.0,
						2.0,
						0.03,
						Vector3(0.0, 1.15, 0.0)
					)
				_place_varied_barricade_line(rng, sz, gate_lat, 4.7, ry, road_half)

			_: # RampBypass: прямой трамплин по полосе на ровном участке трассы + фланговый объезд
				var ramp_z: float = _find_straight_z(sz, min_z, max_z)
				if absf(_local_road_yaw(ramp_z)) < 0.24 and not _in_setpiece_band(ramp_z):
					var ramp_yaw: float = _local_road_yaw(ramp_z)
					var ramp_lat: float = rng.randf_range(-road_half * 0.30, road_half * 0.30)
					_setpiece_z_bands.append(Vector2(ramp_z - 30.0, ramp_z + 30.0))
					_spawn_stunt_ramp(Vector3(_local_road_cx(ramp_z) + ramp_lat, road_y, ramp_z), ramp_yaw, 8.4, 2.65, 12.0)
					spawned_ramp = true
					var bypass_side: float = -1.0 if ramp_lat >= 0.0 else 1.0
					var bypass_lat: float = bypass_side * (road_half + 3.2)
					_place_varied_barricade_line(rng, ramp_z, ramp_lat, 6.2, ramp_yaw, road_half, bypass_lat, 4.2)
				else:
					_setpiece_z_bands.append(Vector2(sz - 28.0, sz + 28.0))
					_place_varied_barricade_line(rng, sz, rng.randf_range(-4.0, 4.0), 4.8, ry, road_half)

	if not spawned_ramp and (chunk_index == 1 or rng.randf() < 0.72):
		var target_rz: float = lerpf(min_z + 36.0, max_z - 36.0, 0.48)
		var ramp_z: float = _find_straight_z(target_rz, min_z, max_z)
		if absf(_local_road_yaw(ramp_z)) < 0.24 and not _in_setpiece_band(ramp_z):
			var ramp_yaw: float = _local_road_yaw(ramp_z)
			var lanes: Array[float] = [-4.5, 0.0, 4.5]
			var ramp_lat: float = lanes[rng.randi_range(0, lanes.size() - 1)]
			_setpiece_z_bands.append(Vector2(ramp_z - 28.0, ramp_z + 28.0))
			_spawn_stunt_ramp(Vector3(_local_road_cx(ramp_z) + ramp_lat, road_y, ramp_z), ramp_yaw, 8.4, 2.65, 12.0)

func _spawn_obstacles(rng: RandomNumberGenerator, skip_landing_zone: bool, skip_takeoff_zone: bool) -> void:
	if chunk_index < 0 or OBSTACLE_DEFS.is_empty():
		return

	# Более плавная и честная прогрессия сложности (без скачка в непроходимый завал со 2-го биома)
	var difficulty: float = clampf(float(maxi(chunk_index, 0)) / 28.0, 0.0, 1.0)
	var z_half: float = chunk_length * 0.5
	var min_z: float = -z_half + 18.0
	var max_z: float = z_half - 18.0
	if chunk_index == 0:
		max_z = minf(max_z, -40.0)
	if skip_takeoff_zone:
		min_z = maxf(min_z, -z_half + 125.0)
	if skip_landing_zone:
		max_z = minf(max_z, z_half - 165.0)

	if max_z <= min_z + 10.0:
		return

	_spawn_tactical_setpieces(rng, min_z, max_z)

	var road_half: float = _road_width * 0.5
	var safe_gap: float = lerpf(8.4, 5.8, difficulty)
	var safe_lat: float = rng.randf_range(-4.0, 4.0) if chunk_index == 0 else rng.randf_range(-road_half + safe_gap, road_half - safe_gap)
	var step_min: float = lerpf(58.0, 38.0, difficulty)
	var step_max: float = lerpf(74.0, 50.0, difficulty)
	var roadblock_chance: float = lerpf(0.0, 0.16, clampf((difficulty - 0.25) / 0.75, 0.0, 1.0))
	var shoulder_min: float = road_half + 3.0
	var shoulder_max: float = maxf(_playable_half_width - 5.0, shoulder_min + 2.0)
	var band_z: float = max_z

	while band_z >= min_z:
		if _in_setpiece_band(band_z):
			band_z -= step_min * 0.7
			continue
		safe_lat = clampf(safe_lat + rng.randf_range(-8.0, 8.0), -road_half + safe_gap, road_half - safe_gap)
		var ry := _local_road_yaw(band_z)

		if not (_has_barn and absf(band_z) < 38.0) and rng.randf() < roadblock_chance:
			var alt_gap_enabled: bool = rng.randf() < 0.50
			var alt_gap_lat: float = rng.randf_range(shoulder_min, shoulder_max) * (-1.0 if safe_lat > 0.0 else 1.0)
			_place_varied_barricade_line(
				rng,
				band_z,
				safe_lat,
				safe_gap,
				ry,
				road_half - 1.5,
				alt_gap_lat if alt_gap_enabled else 9999.0,
				4.8 if alt_gap_enabled else 0.0
			)
		else:
			var base_items: int = roundi(lerpf(1.2, 3.4, difficulty))
			var band_items: int = mini(base_items + rng.randi_range(0, 1), 4)
			for _j in range(band_items):
				var o_lat: float = rng.randf_range(-road_half + 1.5, road_half - 1.5)
				var lz: float = band_z + rng.randf_range(-8.0, 8.0)
				if absf(o_lat - safe_lat) < safe_gap or _in_setpiece_band(lz):
					continue
				var ox := _local_road_cx(lz) + o_lat
				if _in_fuel_station_zone(ox, lz):
					continue
				_place_obstacle_at(rng, ox, lz)

		# Off-road wrecks & debris scattered across the wide curved shoulders
		var shoulder_count: int = rng.randi_range(1, 2 if difficulty < 0.6 else 3)
		for _s in range(shoulder_count):
			if rng.randf() < 0.70:
				var side: float = -1.0 if rng.randf() < 0.5 else 1.0
				var slz: float = band_z + rng.randf_range(-10.0, 10.0)
				if _in_setpiece_band(slz):
					continue
				var sx: float = _local_road_cx(slz) + side * rng.randf_range(shoulder_min, shoulder_max)
				if not _in_fuel_station_zone(sx, slz):
					_place_obstacle_at(rng, sx, slz)

		band_z -= rng.randf_range(step_min, step_max)

func _place_obstacle_at(rng: RandomNumberGenerator, lx: float, lz: float, forced_idx: int = -1, forced_yaw: float = NAN, ignore_setpiece_band: bool = false) -> void:
	if _in_fuel_station_zone(lx, lz) or (not ignore_setpiece_band and _in_setpiece_band(lz)):
		return
	var def_idx: int = clampi(forced_idx, 0, OBSTACLE_DEFS.size() - 1) if forced_idx >= 0 else rng.randi_range(0, OBSTACLE_DEFS.size() - 1)
	var entry: Dictionary = OBSTACLE_DEFS[def_idx]
	var radius: float = float(entry.get("radius", 2.8))
	var px: float = lx
	var pz: float = lz
	if not _reserve_spot(px, pz, radius):
		if ignore_setpiece_band:
			return
		px = lx + rng.randf_range(-3.5, 3.5)
		pz = lz + rng.randf_range(-4.5, 4.5)
		if _in_fuel_station_zone(px, pz) or not _reserve_spot(px, pz, radius):
			return
	var yaw := rng.randf_range(0.0, TAU) if is_nan(forced_yaw) else forced_yaw
	var ly: float = _local_terrain_y(_chunk_xform, px, pz)
	if def_idx == 5:
		_spawn_barrel_prop("RoadBarrel", Vector3(px, road_y + ly + 0.01, pz), yaw, rng.randf() < 0.55)
		return
	if def_idx == 6:
		_spawn_knockable_concrete_barrier(Vector3(px, road_y + ly + 0.04, pz), yaw)
		return
	var ps: PackedScene = entry["scene"] as PackedScene
	var y_off: float = float(entry["y_offset"])
	if ps == null:
		return
	var obj := ps.instantiate() as Node3D
	if obj == null:
		return
	add_child(obj)
	obj.position = Vector3(px, road_y + ly + y_off, pz)
	obj.rotation = Vector3(0.0, yaw, 0.0)
	_optimize_obstacle_node(obj, 265.0, false)

static func _get_box_shape(size: Vector3) -> BoxShape3D:
	var key := Vector3i(roundi(size.x * 100.0), roundi(size.y * 100.0), roundi(size.z * 100.0))
	if _shared_box_shapes.has(key):
		return _shared_box_shapes[key] as BoxShape3D
	var bx := BoxShape3D.new()
	bx.size = size
	_shared_box_shapes[key] = bx
	return bx

func _spawn_barrel_prop(node_name: String, pos: Vector3, yaw: float, explosive: bool) -> void:
	var b_mesh: Mesh = ProceduralMaterials.get_ph_barrel_mesh() if explosive else ProceduralMaterials.get_ph_blue_barrel_mesh()
	if b_mesh == null:
		return
	var kp := KnockableProp.new()
	kp.name = ("%s_Red" % node_name) if explosive else ("%s_Blue" % node_name)
	kp.is_barrel = true
	kp.is_explosive_barrel = explosive
	kp.prop_material = "metal" if explosive else "barrel_blue"
	kp.prop_mass = 65.0
	kp.damage_to_car = 2.0
	kp.speed_drag_factor = 0.024
	kp.prop_height = 1.18
	kp.position = pos
	kp.rotation = Vector3(0.0, yaw, 0.0)

	var mi := MeshInstance3D.new()
	mi.mesh = b_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 255.0
	kp.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = _get_box_shape(Vector3(0.78, 1.16, 0.78))
	col.position = Vector3(0.0, 0.58, 0.0)
	kp.add_child(col)
	add_child(kp)

func _spawn_knockable_box(
	node_name: String,
	mesh_res: Mesh,
	pos: Vector3,
	rot: Vector3,
	box_size: Vector3,
	local_offset: Vector3,
	mat_kind: String,
	p_mass: float,
	p_dmg: float,
	drag_k: float
) -> void:
	_spawn_knockable_mesh(node_name, mesh_res, pos, rot, box_size, local_offset, box_size, mat_kind, p_mass, p_dmg, drag_k, local_offset)

func _spawn_knockable_mesh(
	node_name: String,
	mesh_res: Mesh,
	pos: Vector3,
	rot: Vector3,
	mesh_scale: Vector3,
	mesh_local_pos: Vector3,
	col_size: Vector3,
	mat_kind: String,
	p_mass: float,
	p_dmg: float,
	drag_k: float,
	col_local_pos: Vector3 = Vector3.ZERO,
	mesh_rot: Vector3 = Vector3.ZERO
) -> void:
	if mesh_res == null:
		return
	var kp := KnockableProp.new()
	kp.name = node_name
	kp.prop_material = mat_kind
	kp.prop_mass = p_mass
	kp.damage_to_car = p_dmg
	kp.speed_drag_factor = drag_k
	kp.prop_height = col_size.y
	kp.position = pos
	kp.rotation = rot

	var mi := MeshInstance3D.new()
	mi.mesh = mesh_res
	mi.scale = mesh_scale
	mi.position = mesh_local_pos
	mi.rotation = mesh_rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 255.0
	kp.add_child(mi)

	var col := CollisionShape3D.new()
	col.shape = _get_box_shape(col_size)
	col.position = col_local_pos if col_local_pos != Vector3.ZERO else Vector3(0.0, col_size.y * 0.5 + 0.01, 0.0)
	kp.add_child(col)
	add_child(kp)

func _spawn_knockable_streetlight(lamp_mesh: Mesh, pos: Vector3, tilt: float, side: float, yaw: float = 0.0) -> void:
	var kp := KnockableProp.new()
	kp.name = "KnockStreetlight"
	kp.prop_material = "metal_electric"
	kp.prop_mass = 155.0
	kp.damage_to_car = 5.0
	kp.speed_drag_factor = 0.055
	kp.prop_height = 6.0 if lamp_mesh != null else 7.6
	kp.position = pos
	kp.rotation = Vector3(0.0, yaw + (0.0 if side < 0.0 else PI), tilt)

	if lamp_mesh != null:
		var mi := MeshInstance3D.new()
		mi.mesh = lamp_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 275.0
		kp.add_child(mi)

		var col := CollisionShape3D.new()
		col.shape = _get_box_shape(Vector3(0.45, 5.8, 0.45))
		col.position = Vector3(0.0, 2.92, 0.0)
		kp.add_child(col)
	else:
		var pole_mesh := ProceduralMaterials.get_unit_box_mesh("pole_steel")
		var glow_mesh := ProceduralMaterials.get_unit_box_mesh("lamp_glow")
		var pole_h := 7.6
		var p_mi := MeshInstance3D.new()
		p_mi.mesh = pole_mesh
		p_mi.scale = Vector3(0.24, pole_h, 0.24)
		p_mi.position = Vector3(0.0, pole_h * 0.5, 0.0)
		p_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p_mi.visibility_range_end = 275.0
		kp.add_child(p_mi)

		var bulb_mi := MeshInstance3D.new()
		bulb_mi.mesh = glow_mesh
		bulb_mi.scale = Vector3(0.45, 0.35, 0.45)
		bulb_mi.position = Vector3(0.0, pole_h + 0.15, 0.0)
		bulb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bulb_mi.visibility_range_end = 265.0
		kp.add_child(bulb_mi)

		var col := CollisionShape3D.new()
		col.shape = _get_box_shape(Vector3(0.42, pole_h - 0.2, 0.42))
		col.position = Vector3(0.0, pole_h * 0.5 + 0.04, 0.0)
		kp.add_child(col)
	add_child(kp)

func _spawn_knockable_concrete_barrier(pos: Vector3, yaw: float) -> void:
	var kp := KnockableProp.new()
	kp.name = "KnockConcreteBarrier"
	kp.prop_material = "concrete"
	kp.prop_mass = 340.0
	kp.damage_to_car = 11.0
	kp.speed_drag_factor = 0.14
	kp.prop_height = 1.20
	kp.position = pos
	kp.rotation = Vector3(0.0, yaw, 0.0)

	var ph_bar := ProceduralMaterials.get_ph_concrete_barrier_mesh()
	if ph_bar:
		var mi := MeshInstance3D.new()
		mi.mesh = ph_bar
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 255.0
		kp.add_child(mi)
	elif GLTF_BARRIER:
		var bar_vis := GLTF_BARRIER.instantiate() as Node3D
		if bar_vis:
			bar_vis.scale = Vector3.ONE * 1.45
			kp.add_child(bar_vis)
			_optimize_obstacle_node(bar_vis, 255.0, true)

	var col := CollisionShape3D.new()
	col.shape = _get_box_shape(Vector3(2.20, 1.12, 0.90))
	col.position = Vector3(0.0, 0.58, 0.0)
	kp.add_child(col)
	add_child(kp)

static var _wreck_phys_mat: PhysicsMaterial = null

func _get_wreck_phys_mat() -> PhysicsMaterial:
	if _wreck_phys_mat == null:
		_wreck_phys_mat = PhysicsMaterial.new()
		_wreck_phys_mat.friction = 0.24
		_wreck_phys_mat.bounce = 0.08
	return _wreck_phys_mat

func _optimize_obstacle_node(node: Node, vis_end: float, disable_shadow: bool) -> void:
	if node is RigidBody3D and not (node is KnockableProp):
		var rb := node as RigidBody3D
		rb.can_sleep = true
		# Статически замораживаем остовы до удара машиной — не срываются в полёт при исчезновении соседнего чанка
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
		rb.sleeping = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		if rb.mass > 1100.0:
			rb.mass = clampf(rb.mass * 0.28, 260.0, 1150.0)
		elif rb.mass > 400.0:
			rb.mass = clampf(rb.mass * 0.55, 220.0, 680.0)
		if rb.physics_material_override == null:
			rb.physics_material_override = _get_wreck_phys_mat()
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.visibility_range_end = vis_end
		if disable_shadow:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.material_override and not (mi.material_override is ShaderMaterial):
			mi.material_override = ProceduralMaterials.get_lit_prop_material(mi.material_override)
		elif mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var active_m := mi.get_active_material(s)
				if active_m and not (active_m is ShaderMaterial):
					mi.set_surface_override_material(s, ProceduralMaterials.get_lit_prop_material(active_m))
	for child in node.get_children():
		_optimize_obstacle_node(child, vis_end, disable_shadow)

func _local_terrain_y(chunk_xform: Transform3D, lx: float, lz: float) -> float:
	var wp := chunk_xform * Vector3(lx, 0.0, lz)
	return sample_terrain_height(wp.x, wp.z, biome_type, world_seed)

func _spawn_multimesh(node_name: String, mesh: Mesh, transforms: Array[Transform3D], cast_shadow: bool = true, vis_end: float = 320.0) -> void:
	if mesh == null or transforms.is_empty():
		return
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	# Держим дальность отрисовки строго дальше 100% стены тумана (178м), чтобы чанки и деревья не "выпрыгивали" перед глазами
	mmi.visibility_range_end = clampf(maxf(vis_end, 305.0), 305.0, 390.0)
	if not cast_shadow:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	add_child(mmi)

func _add_quad_up(st: SurfaceTool, x0: float, z0: float, x1: float, z1: float, y: float, u_max: float, v_max: float) -> void:
	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(x0, y, z0))
	st.set_uv(Vector2(u_max, 0.0))
	st.add_vertex(Vector3(x1, y, z0))
	st.set_uv(Vector2(u_max, v_max))
	st.add_vertex(Vector3(x1, y, z1))

	st.set_uv(Vector2(0.0, 0.0))
	st.add_vertex(Vector3(x0, y, z0))
	st.set_uv(Vector2(u_max, v_max))
	st.add_vertex(Vector3(x1, y, z1))
	st.set_uv(Vector2(0.0, v_max))
	st.add_vertex(Vector3(x0, y, z1))
