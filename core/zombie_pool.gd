extends Node

const GRID_CELL_SIZE := 4.0
const INV_GRID_CELL_SIZE := 0.25
const MAX_ACTIVE_RAGDOLLS := 24
const ZOMBIE_MODEL_COUNT := 7

var zombie_scene: PackedScene = load("res://entities/zombies/Z1/Z1.tscn")
var _zombie_shader: Shader = preload("res://entities/zombies/shaders/zombie_headlight.gdshader")
var pool: Array[Node3D] = []
var active_zombies: Array[Node3D] = []
var active_ragdolls: int = 0

var cleanup_timer: float = 0.0
var _shared_materials: Dictionary = {}
var _fallback_white_tex: ImageTexture = null
var _external_model_files: Array[String] = [
	"cop.glb",
	"soldier.glb",
	"prisoner.glb",
	"parasite.glb",
	"girl.glb",
	"skeletonzombie.glb"
]
var _cached_model_parts: Dictionary = {}
var _grid: Dictionary = {}
var _cell_array_pool: Array[Array] = []
var _grid_frame: int = -1
var _empty_cell: Array = []

func _process(delta: float) -> void:
	cleanup_timer += delta
	if cleanup_timer > 0.40:
		cleanup_timer = 0.0
		_validate_pool()
		_cleanup_distant_zombies()

func _validate_pool() -> void:
	for i in range(pool.size() - 1, -1, -1):
		if not is_instance_valid(pool[i]):
			pool.remove_at(i)

	for i in range(active_zombies.size() - 1, -1, -1):
		if not is_instance_valid(active_zombies[i]):
			active_zombies.remove_at(i)

	if active_zombies.is_empty():
		active_ragdolls = 0

func get_shared_surface_material(orig_mat: Material, variant_idx: int = 0, is_external_model: bool = false) -> ShaderMaterial:
	var v_idx: int = 6 if variant_idx == 6 else posmod(variant_idx, 6)
	var key := "default_%d_%d" % [v_idx, 1 if is_external_model else 0]
	var sm: StandardMaterial3D = orig_mat as StandardMaterial3D
	var tex: Texture2D = null
	var tint := Color.WHITE
	var rough := 0.85
	var metal := 0.02
	var em_col := Color.BLACK
	var em_e := 0.0
	var tex_path: String = ""
	var em_on: bool = false
	var alpha_cut_val: float = 0.0
	if sm:
		if sm.albedo_texture:
			tex_path = sm.albedo_texture.resource_path if sm.albedo_texture.resource_path != "" else ("emb_" + str(sm.albedo_texture.get_instance_id()))
		em_on = sm.emission_enabled
		em_e = sm.emission_energy_multiplier if em_on else 0.0
		em_col = sm.emission if em_on else Color.BLACK
		tex = sm.albedo_texture
		tint = sm.albedo_color
		rough = clampf(sm.roughness, 0.45, 0.96)
		metal = sm.metallic
		if sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
			alpha_cut_val = clampf(sm.alpha_scissor_threshold, 0.15, 0.75)
		elif sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			alpha_cut_val = 0.35
		key = "%s|%d|%.2f|%.2f|%s|v%d|e%d" % [tex_path, 1 if em_on else 0, em_e, alpha_cut_val, tint.to_html(false), v_idx, 1 if is_external_model else 0]

	if _shared_materials.has(key):
		return _shared_materials[key] as ShaderMaterial

	if tex == null:
		if _fallback_white_tex == null:
			var img := Image.create_from_data(1, 1, false, Image.FORMAT_RGBA8, PackedByteArray([255, 255, 255, 255]))
			_fallback_white_tex = ImageTexture.create_from_image(img)
		tex = _fallback_white_tex

	var is_skin: bool = tex_path.contains("kao") or tex_path.contains("em100")
	var skin_tints: Array[Color] = [
		Color(1.00, 0.98, 0.94, 1.0),
		Color(0.94, 0.78, 0.76, 1.0),
		Color(0.76, 0.92, 0.70, 1.0),
		Color(0.64, 0.60, 0.56, 1.0),
		Color(0.92, 0.84, 0.72, 1.0),
		Color(0.76, 0.84, 0.95, 1.0),
		Color(0.08, 0.08, 0.08, 1.0)
	]
	var cloth_tints: Array[Color] = [
		Color(1.00, 1.00, 1.00, 1.0),
		Color(0.72, 0.28, 0.25, 1.0),
		Color(0.74, 0.72, 0.44, 1.0),
		Color(0.42, 0.40, 0.42, 1.0),
		Color(0.84, 0.54, 0.34, 1.0),
		Color(0.38, 0.48, 0.68, 1.0),
		Color(0.07, 0.07, 0.07, 1.0)
	]
	var ext_tints: Array[Color] = [
		Color(1.00, 1.00, 1.00, 1.0),
		Color(0.96, 0.90, 0.88, 1.0),
		Color(0.88, 0.95, 0.86, 1.0),
		Color(0.86, 0.84, 0.82, 1.0),
		Color(0.96, 0.92, 0.84, 1.0),
		Color(0.88, 0.92, 0.98, 1.0),
		Color(0.09, 0.09, 0.09, 1.0)
	]
	var eye_cols: Array[Color] = [
		Color(1.0, 0.35, 0.12, 1.0),
		Color(1.0, 0.12, 0.08, 1.0),
		Color(0.65, 1.0, 0.22, 1.0),
		Color(1.0, 0.55, 0.14, 1.0),
		Color(1.0, 0.78, 0.20, 1.0),
		Color(0.42, 0.86, 1.0, 1.0),
		Color(1.0, 0.42, 0.05, 1.0)
	]
	var blood_amts: Array[float] = [0.18, 0.62, 0.28, 0.48, 0.32, 0.24, 0.0]
	var ext_blood_amts: Array[float] = [0.10, 0.26, 0.14, 0.22, 0.16, 0.12, 0.0]

	var mod_col: Color = ext_tints[v_idx] if is_external_model else (skin_tints[v_idx] if is_skin else cloth_tints[v_idx])
	var final_tint := Color(tint.r * mod_col.r, tint.g * mod_col.g, tint.b * mod_col.b, tint.a)
	if em_on:
		em_col = eye_cols[v_idx]

	var mat := ShaderMaterial.new()
	mat.shader = _zombie_shader
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", final_tint)
	mat.set_shader_parameter("roughness_val", 0.95 if v_idx == 6 else rough)
	mat.set_shader_parameter("metallic_val", 0.02 if v_idx == 6 else metal)
	mat.set_shader_parameter("base_emission", em_col)
	mat.set_shader_parameter("base_emission_energy", em_e)
	mat.set_shader_parameter("grime_seed", float(v_idx) * 2.17 + 0.5)
	mat.set_shader_parameter("blood_amount", ext_blood_amts[v_idx] if is_external_model else blood_amts[v_idx])
	mat.set_shader_parameter("alpha_cut", alpha_cut_val)
	mat.set_shader_parameter("char_amount", 1.0 if v_idx == 6 else 0.0)
	_shared_materials[key] = mat
	return mat

func get_zombie_model_parts(model_idx: int, ref_sk: Skeleton3D, ref_run_xform: Transform3D, orig_parts: Array) -> Array:
	var m_idx: int = posmod(model_idx, ZOMBIE_MODEL_COUNT)
	if m_idx == 0 or ref_sk == null:
		return orig_parts
	if _cached_model_parts.has(m_idx):
		return _cached_model_parts[m_idx] as Array

	var glb_file: String = _external_model_files[m_idx - 1]
	var abs_path: String = ProjectSettings.globalize_path("res://entities/zombies/models/" + glb_file)
	var doc := GLTFDocument.new()
	var gltf_state := GLTFState.new()
	var err: int = doc.append_from_file(abs_path, gltf_state)
	if err != OK:
		_cached_model_parts[m_idx] = orig_parts
		return orig_parts

	var root_node: Node = doc.generate_scene(gltf_state)
	if root_node == null:
		_cached_model_parts[m_idx] = orig_parts
		return orig_parts

	var c_sk: Skeleton3D = _find_skeleton_recursive(root_node)
	var c_mis: Array[MeshInstance3D] = []
	_find_skinned_meshes_recursive(root_node, c_mis)
	if c_sk == null or c_mis.is_empty():
		root_node.free()
		_cached_model_parts[m_idx] = orig_parts
		return orig_parts

	var inv_run: Transform3D = ref_run_xform.affine_inverse()
	var r180 := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	var parts: Array = []

	for c_mi: MeshInstance3D in c_mis:
		if c_mi.mesh == null or c_mi.skin == null:
			continue
		var src_skin: Skin = c_mi.skin
		var new_skin := Skin.new()
		var b_count: int = src_skin.get_bind_count()
		for b in range(b_count):
			var b_name: String = String(src_skin.get_bind_name(b))
			var c_idx: int = c_sk.find_bone(b_name) if b_name != "" else src_skin.get_bind_bone(b)
			if c_idx < 0 or c_idx >= c_sk.get_bone_count():
				c_idx = 0
			var z_idx: int = _map_bone_to_ref_skeleton(c_sk, c_idx, ref_sk)
			var g_src: Transform3D = c_sk.get_bone_global_rest(c_idx)
			var g_dst: Transform3D = ref_sk.get_bone_global_rest(z_idx)
			var b_src: Transform3D = src_skin.get_bind_pose(b)
			var b_dst: Transform3D = g_dst.affine_inverse() * inv_run * r180 * g_src * b_src
			new_skin.add_named_bind(ref_sk.get_bone_name(z_idx), b_dst)

		var surf_mats: Array[Material] = []
		for s in range(c_mi.mesh.get_surface_count()):
			var active_mat: Material = c_mi.get_active_material(s)
			if active_mat:
				surf_mats.append(active_mat.duplicate() as Material)
			else:
				surf_mats.append(StandardMaterial3D.new())

		parts.append({
			"mesh": c_mi.mesh.duplicate(),
			"skin": new_skin,
			"materials": surf_mats
		})

	root_node.free()
	if parts.is_empty():
		_cached_model_parts[m_idx] = orig_parts
		return orig_parts

	_cached_model_parts[m_idx] = parts
	return parts

func _find_skeleton_recursive(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n as Skeleton3D
	for c in n.get_children():
		var found: Skeleton3D = _find_skeleton_recursive(c)
		if found:
			return found
	return null

func _find_skinned_meshes_recursive(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.skin != null:
			out.append(mi)
	for c in n.get_children():
		_find_skinned_meshes_recursive(c, out)

func _clean_mixamo_bone_name(raw_name: String) -> String:
	var s: String = raw_name
	var colon_idx: int = s.find(":")
	if colon_idx >= 0:
		s = s.substr(colon_idx + 1)
	if s.begins_with("mixamorig_"):
		s = s.substr(10)
	elif s.begins_with("mixamorig"):
		s = s.substr(9)
	var reg := RegEx.new()
	reg.compile("_[0-9]+$")
	var m: RegExMatch = reg.search(s)
	if m:
		s = s.substr(0, m.get_start())
	return s

func _map_bone_to_ref_skeleton(c_sk: Skeleton3D, c_idx: int, ref_sk: Skeleton3D) -> int:
	var curr: int = c_idx
	while curr >= 0:
		var raw_name: String = c_sk.get_bone_name(curr)
		var clean: String = _clean_mixamo_bone_name(raw_name)
		# Keep all 5 fingers unified on LeftHand / RightHand so external GLB hands/claws never split between Index and Middle fingers
		if clean.begins_with("LeftHand") and clean != "LeftHand":
			var lh_idx: int = ref_sk.find_bone("mixamorig_LeftHand")
			if lh_idx >= 0:
				return lh_idx
		elif clean.begins_with("RightHand") and clean != "RightHand":
			var rh_idx: int = ref_sk.find_bone("mixamorig_RightHand")
			if rh_idx >= 0:
				return rh_idx
		var target_idx: int = ref_sk.find_bone("mixamorig_" + clean)
		if target_idx >= 0:
			return target_idx
		target_idx = ref_sk.find_bone(clean)
		if target_idx >= 0:
			return target_idx
		curr = c_sk.get_bone_parent(curr)
	var hips_idx: int = ref_sk.find_bone("mixamorig_Hips")
	return hips_idx if hips_idx >= 0 else 0

func update_headlight_uniforms(
	left_pos: Vector3,
	right_pos: Vector3,
	dir: Vector3,
	intensity: float,
	hl_color: Color = Color(1.0, 0.94, 0.78, 1.0),
	hl_range: float = 62.0
) -> void:
	if _shared_materials.is_empty():
		return
	var n_dir := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	for mat: ShaderMaterial in _shared_materials.values():
		mat.set_shader_parameter("hl_left_pos", left_pos)
		mat.set_shader_parameter("hl_right_pos", right_pos)
		mat.set_shader_parameter("hl_dir", n_dir)
		mat.set_shader_parameter("hl_intensity", intensity)
		mat.set_shader_parameter("hl_color", hl_color)
		mat.set_shader_parameter("hl_range", hl_range)

func try_acquire_ragdoll() -> bool:
	if active_ragdolls >= MAX_ACTIVE_RAGDOLLS:
		return false
	active_ragdolls += 1
	return true

func release_ragdoll() -> void:
	active_ragdolls = maxi(active_ragdolls - 1, 0)

func _ensure_spatial_grid() -> void:
	var pf: int = Engine.get_physics_frames()
	if pf == _grid_frame:
		return
	_grid_frame = pf
	for k in _grid.keys():
		var arr: Array = _grid[k]
		arr.clear()
		_cell_array_pool.append(arr)
	_grid.clear()

	for z: Node3D in active_zombies:
		if not is_instance_valid(z) or not z.visible:
			continue
		var zp := z.global_position
		var cell := Vector2i(floori(zp.x * INV_GRID_CELL_SIZE), floori(zp.z * INV_GRID_CELL_SIZE))
		if _grid.has(cell):
			(_grid[cell] as Array).append(z)
		else:
			var arr: Array = _cell_array_pool.pop_back() if _cell_array_pool.size() > 0 else []
			arr.append(z)
			_grid[cell] = arr

func get_grid_cell(cx: int, cz: int) -> Array:
	_ensure_spatial_grid()
	return _grid.get(Vector2i(cx, cz), _empty_cell)

func get_nearby_zombies(world_pos: Vector3) -> Array[Node3D]:
	_ensure_spatial_grid()
	var cx: int = floori(world_pos.x * INV_GRID_CELL_SIZE)
	var cz: int = floori(world_pos.z * INV_GRID_CELL_SIZE)
	var out: Array[Node3D] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket: Array = _grid.get(Vector2i(cx + dx, cz + dz), _empty_cell)
			for item in bucket:
				if is_instance_valid(item):
					out.append(item as Node3D)
	return out

func _deactivate_zombie(zombie: Node3D) -> void:
	zombie.process_mode = Node.PROCESS_MODE_DISABLED
	zombie.hide()
	zombie.set_process(false)
	zombie.set_physics_process(false)
	if zombie is CollisionObject3D:
		zombie.collision_layer = 0
		zombie.collision_mask = 0
	if zombie.has_method("on_pooled"):
		zombie.on_pooled()

func prewarm_zombies(count: int, parent_node: Node) -> void:
	_validate_pool()
	var needed := count - pool.size()
	for i in range(maxi(needed, 0)):
		var zombie := zombie_scene.instantiate() as Node3D
		parent_node.add_child(zombie)
		_deactivate_zombie(zombie)
		pool.append(zombie)

func prewarm_zombies_batch(target_count: int, batch_size: int, parent_node: Node) -> bool:
	_validate_pool()
	var needed := maxi(target_count - pool.size(), 0)
	var step_count := mini(maxi(batch_size, 1), needed)
	for i in range(step_count):
		var zombie := zombie_scene.instantiate() as Node3D
		parent_node.add_child(zombie)
		_deactivate_zombie(zombie)
		pool.append(zombie)
	return pool.size() >= target_count

func _cleanup_distant_zombies() -> void:
	var main_node := get_tree().current_scene
	if not main_node or not "car" in main_node or not is_instance_valid(main_node.car):
		return

	var car: Node3D = main_node.car
	var forward_vector: Vector3 = main_node.get("_forward") if "_forward" in main_node else Vector3.BACK
	var right_vector: Vector3 = Vector3(-forward_vector.z, 0.0, forward_vector.x)
	var now_ms: int = Time.get_ticks_msec()

	for i in range(active_zombies.size() - 1, -1, -1):
		var zombie := active_zombies[i]
		if not is_instance_valid(zombie):
			active_zombies.remove_at(i)
			continue

		var z_st = zombie.get("state")
		var is_dead: bool = (z_st != null and int(z_st) == 3)
		var z_pos: Vector3 = zombie.call("get_visual_world_position") if (is_dead and zombie.has_method("get_visual_world_position")) else zombie.global_position
		var rel_pos: Vector3 = z_pos - car.global_position
		var dist_along_forward: float = rel_pos.dot(forward_vector)
		var lat_dist: float = absf(rel_pos.dot(right_vector))

		if is_dead:
			var dead_start: int = int(zombie.get("_dead_start_ms")) if zombie.get("_dead_start_ms") != null else 0
			var dead_age_ms: int = (now_ms - dead_start) if dead_start > 0 else 99999
			if dead_age_ms < 3200:
				if dist_along_forward < -95.0 or dist_along_forward > 195.0 or lat_dist > 115.0:
					return_zombie(zombie)
			elif dist_along_forward < -65.0 or dist_along_forward > 185.0 or lat_dist > 105.0:
				return_zombie(zombie)
		else:
			if dist_along_forward < -22.0 or dist_along_forward > 175.0 or lat_dist > 92.0:
				return_zombie(zombie)

func spawn_zombie_at(global_pos: Vector3, difficulty: float = 0.0, force_run: bool = false) -> Node3D:
	if zombie_scene == null:
		return null

	var zombie: Node3D = null
	while pool.size() > 0:
		var candidate := pool.pop_back() as Node3D
		if is_instance_valid(candidate):
			zombie = candidate
			break

	if zombie != null:
		zombie.process_mode = Node.PROCESS_MODE_INHERIT
		zombie.show()
		zombie.set_process(true)
		zombie.set_physics_process(true)
	else:
		zombie = zombie_scene.instantiate() as Node3D
		var target_parent: Node = get_tree().current_scene
		if target_parent == null:
			target_parent = get_tree().root
		if target_parent:
			target_parent.add_child(zombie)

	zombie.global_position = global_pos

	var main_node := get_tree().current_scene
	var should_run: bool = force_run
	if not should_run and difficulty == 0.0 and main_node and "is_fog_red" in main_node:
		should_run = main_node.is_fog_red

	if zombie.has_method("reset_zombie"):
		zombie.reset_zombie(should_run, difficulty)

	if not active_zombies.has(zombie):
		active_zombies.append(zombie)
	_grid_frame = -1

	return zombie

func return_zombie(zombie: Node3D) -> void:
	if not is_instance_valid(zombie):
		return
	active_zombies.erase(zombie)
	_grid_frame = -1
	if not pool.has(zombie):
		_deactivate_zombie(zombie)
		pool.append(zombie)
