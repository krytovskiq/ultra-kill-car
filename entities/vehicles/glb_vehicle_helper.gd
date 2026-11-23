class_name GlbVehicleHelper
extends RefCounted

static var _template_cache: Dictionary = {}
static var _shadow_cache: Dictionary = {}

static func load_glb_instance(res_path: String) -> Node3D:
	if not _template_cache.has(res_path):
		var tpl: Node3D = null
		var packed := ResourceLoader.load(res_path) as PackedScene
		if packed:
			tpl = packed.instantiate() as Node3D
		if tpl == null:
			var doc := GLTFDocument.new()
			var state := GLTFState.new()
			var abs_path: String = ProjectSettings.globalize_path(res_path)
			if doc.append_from_file(abs_path, state) == OK:
				tpl = doc.generate_scene(state) as Node3D
		if tpl == null:
			return null
		_template_cache[res_path] = tpl
	var cached := _template_cache[res_path] as Node3D
	return cached.duplicate() as Node3D

static func get_transform_relative_to(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != ancestor:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

static func get_node_aabb_in_space(node: Node3D, ref_space: Node3D) -> AABB:
	var res := AABB()
	var has_any: bool = false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh:
				var rel_xf: Transform3D = get_transform_relative_to(mi, ref_space)
				var a := mi.mesh.get_aabb()
				var corners := [
					rel_xf * Vector3(a.position.x, a.position.y, a.position.z),
					rel_xf * Vector3(a.end.x, a.position.y, a.position.z),
					rel_xf * Vector3(a.position.x, a.end.y, a.position.z),
					rel_xf * Vector3(a.end.x, a.end.y, a.position.z),
					rel_xf * Vector3(a.position.x, a.position.y, a.end.z),
					rel_xf * Vector3(a.end.x, a.position.y, a.end.z),
					rel_xf * Vector3(a.position.x, a.end.y, a.end.z),
					rel_xf * Vector3(a.end.x, a.end.y, a.end.z),
				]
				for c: Vector3 in corners:
					if not has_any:
						res = AABB(c, Vector3.ZERO)
						has_any = true
					else:
						res = res.expand(c)
		for ch in cur.get_children():
			stack.append(ch)
	return res

static func mount_wheel_node(vehicle: Node3D, model_root: Node3D, wheel_node_name: String, rc_wheel: RaycastWheel, snap_rc_to_hub: bool = true) -> void:
	if vehicle == null or model_root == null or rc_wheel == null:
		return
	var w_node := model_root.find_child(wheel_node_name, true, false) as Node3D
	if w_node == null:
		return
	var w_aabb := get_node_aabb_in_space(w_node, vehicle)
	if snap_rc_to_hub and w_aabb.size.length_squared() > 0.001:
		rc_wheel.position = w_aabb.get_center()
		rc_wheel.wheel_radius = maxf(w_aabb.size.y * 0.5, 0.18)
	rc_wheel._setup_visual_pivots()
	if rc_wheel._steer_pivot:
		rc_wheel._steer_pivot.position = Vector3.ZERO
		rc_wheel._steer_pivot.rotation = Vector3.ZERO
	if rc_wheel._spin_pivot:
		rc_wheel._spin_pivot.position = Vector3.ZERO
		rc_wheel._spin_pivot.rotation = Vector3.ZERO
	var target_parent: Node3D = rc_wheel._spin_pivot if rc_wheel._spin_pivot != null else rc_wheel
	var rel_to_veh: Transform3D = get_transform_relative_to(w_node, vehicle)
	var parent_n := w_node.get_parent()
	if parent_n:
		parent_n.remove_child(w_node)
	target_parent.add_child(w_node)
	# Position wheel mesh inside _spin_pivot using exact local offset from RaycastWheel center
	var rc_inv := Transform3D(Basis.IDENTITY, -rc_wheel.position)
	w_node.transform = rc_inv * rel_to_veh

static func split_buhanka_wheels(vehicle: Node3D, model_root: Node3D, wheel_map: Dictionary) -> void:
	if vehicle == null or model_root == null:
		return
	var buckets := {
		"FL": {"surfaces": []},
		"FR": {"surfaces": []},
		"RL": {"surfaces": []},
		"RR": {"surfaces": []},
	}
	var src_nodes: Array[MeshInstance3D] = []
	for obj_name: String in ["Object_15", "Object_9"]:
		var mi := model_root.find_child(obj_name, true, false) as MeshInstance3D
		if mi and mi.mesh:
			src_nodes.append(mi)
	if src_nodes.is_empty():
		return

	var aabbs := {}
	var has_aabb := {"FL": false, "FR": false, "RL": false, "RR": false}
	for mi: MeshInstance3D in src_nodes:
		var rel_xf: Transform3D = get_transform_relative_to(mi, vehicle)
		var norm_basis: Basis = rel_xf.basis.inverse().transposed()
		for surf in range(mi.mesh.get_surface_count()):
			var arrs := mi.mesh.surface_get_arrays(surf)
			if arrs.size() <= Mesh.ARRAY_VERTEX or not (arrs[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			var verts := arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var norms := (arrs[Mesh.ARRAY_NORMAL] as PackedVector3Array) if (arrs.size() > Mesh.ARRAY_NORMAL and arrs[Mesh.ARRAY_NORMAL] is PackedVector3Array) else PackedVector3Array()
			var uvs := (arrs[Mesh.ARRAY_TEX_UV] as PackedVector2Array) if (arrs.size() > Mesh.ARRAY_TEX_UV and arrs[Mesh.ARRAY_TEX_UV] is PackedVector2Array) else PackedVector2Array()
			var idxs := (arrs[Mesh.ARRAY_INDEX] as PackedInt32Array) if (arrs.size() > Mesh.ARRAY_INDEX and arrs[Mesh.ARRAY_INDEX] is PackedInt32Array) else PackedInt32Array()
			var mat := mi.get_active_material(surf)
			if mat == null:
				mat = mi.mesh.surface_get_material(surf)
			if mat == null:
				var fb := StandardMaterial3D.new()
				fb.albedo_color = Color(0.14, 0.14, 0.15)
				fb.roughness = 0.88
				fb.metallic = 0.05
				mat = fb
			var tri_verts := {"FL": [], "FR": [], "RL": [], "RR": []}
			var tri_norms := {"FL": [], "FR": [], "RL": [], "RR": []}
			var tri_uvs := {"FL": [], "FR": [], "RL": [], "RR": []}

			var tri_count: int = floori(float(idxs.size()) / 3.0) if not idxs.is_empty() else floori(float(verts.size()) / 3.0)
			for t in range(tri_count):
				var i0: int = idxs[t * 3] if not idxs.is_empty() else t * 3
				var i1: int = idxs[t * 3 + 1] if not idxs.is_empty() else t * 3 + 1
				var i2: int = idxs[t * 3 + 2] if not idxs.is_empty() else t * 3 + 2
				var p0: Vector3 = rel_xf * verts[i0]
				var p1: Vector3 = rel_xf * verts[i1]
				var p2: Vector3 = rel_xf * verts[i2]
				var ctr: Vector3 = (p0 + p1 + p2) / 3.0
				var qk: String = ("F" if ctr.z < 0.0 else "R") + ("L" if ctr.x < 0.0 else "R")
				var tv: Array = tri_verts[qk] as Array
				tv.append(p0)
				tv.append(p1)
				tv.append(p2)
				if not norms.is_empty():
					var tn: Array = tri_norms[qk] as Array
					tn.append((norm_basis * norms[i0]).normalized())
					tn.append((norm_basis * norms[i1]).normalized())
					tn.append((norm_basis * norms[i2]).normalized())
				if not uvs.is_empty():
					var tu: Array = tri_uvs[qk] as Array
					tu.append(uvs[i0])
					tu.append(uvs[i1])
					tu.append(uvs[i2])
				for pt: Vector3 in [p0, p1, p2]:
					if not bool(has_aabb[qk]):
						aabbs[qk] = AABB(pt, Vector3.ZERO)
						has_aabb[qk] = true
					else:
						aabbs[qk] = (aabbs[qk] as AABB).expand(pt)

			for qk: String in ["FL", "FR", "RL", "RR"]:
				var pv_arr: Array = tri_verts[qk] as Array
				if pv_arr.is_empty():
					continue
				(buckets[qk]["surfaces"] as Array).append({
					"verts": PackedVector3Array(pv_arr),
					"norms": PackedVector3Array(tri_norms[qk] as Array),
					"uvs": PackedVector2Array(tri_uvs[qk] as Array),
					"mat": mat,
				})

	for qk: String in ["FL", "FR", "RL", "RR"]:
		var rc_w := wheel_map.get(qk) as RaycastWheel
		if rc_w == null or not bool(has_aabb[qk]):
			continue
		var a: AABB = aabbs[qk] as AABB
		var hub: Vector3 = a.get_center()
		rc_w.position = hub
		rc_w.wheel_radius = maxf(a.size.y * 0.5, 0.22)
		rc_w._setup_visual_pivots()
		var pivot: Node3D = rc_w._spin_pivot if rc_w._spin_pivot != null else rc_w
		var w_mesh := ArrayMesh.new()
		for srec: Dictionary in (buckets[qk]["surfaces"] as Array):
			var raw_v := srec["verts"] as PackedVector3Array
			var shifted := PackedVector3Array()
			shifted.resize(raw_v.size())
			for i in range(raw_v.size()):
				shifted[i] = raw_v[i] - hub
			var st_arr := []
			st_arr.resize(Mesh.ARRAY_MAX)
			st_arr[Mesh.ARRAY_VERTEX] = shifted
			var pn := srec["norms"] as PackedVector3Array
			if not pn.is_empty():
				st_arr[Mesh.ARRAY_NORMAL] = pn
			var pu := srec["uvs"] as PackedVector2Array
			if not pu.is_empty():
				st_arr[Mesh.ARRAY_TEX_UV] = pu
			var idx_s: int = w_mesh.get_surface_count()
			w_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st_arr)
			var mat := srec["mat"] as Material
			if mat:
				w_mesh.surface_set_material(idx_s, mat)
		var mi_out := MeshInstance3D.new()
		mi_out.name = "BuhankaWheel_" + qk
		mi_out.mesh = w_mesh
		pivot.add_child(mi_out)

	for mi: MeshInstance3D in src_nodes:
		mi.visible = false
		if mi.get_parent():
			mi.get_parent().remove_child(mi)
		mi.queue_free()

static func make_shadow_tex(cache_key: String, half_w: float = 0.52, half_l: float = 0.68) -> ImageTexture:
	if _shadow_cache.has(cache_key):
		return _shadow_cache[cache_key] as ImageTexture
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
		for x in range(w):
			var u: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var dx: float = absf(u) / maxf(half_w, 0.1)
			var dz: float = absf(v) / maxf(half_l, 0.1)
			var d: float = pow(pow(dx, 3.4) + pow(dz, 4.2), 0.25)
			var alpha: float = clampf(1.0 - smoothstep(0.76, 1.05, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	var tex := ImageTexture.create_from_image(img)
	_shadow_cache[cache_key] = tex
	return tex

static func apply_material_overrides(root_node: Node, rules: Dictionary) -> void:
	if root_node == null or rules.is_empty():
		return
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh:
				for s in range(mi.mesh.get_surface_count()):
					var mat := mi.get_active_material(s) as StandardMaterial3D
					if mat == null or not rules.has(mat.resource_name):
						continue
					var cfg: Dictionary = rules[mat.resource_name] as Dictionary
					var dup := mat.duplicate() as StandardMaterial3D
					if cfg.has("albedo_color"):
						dup.albedo_color = cfg["albedo_color"] as Color
					if cfg.has("metallic"):
						dup.metallic = float(cfg["metallic"])
					if cfg.has("roughness"):
						dup.roughness = float(cfg["roughness"])
					if cfg.has("clearcoat"):
						dup.clearcoat = float(cfg["clearcoat"])
					if cfg.has("detail_albedo") and cfg["detail_albedo"] is Texture2D:
						dup.detail_enabled = true
						dup.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
						dup.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
						dup.detail_albedo = cfg["detail_albedo"] as Texture2D
						if cfg.has("detail_normal") and cfg["detail_normal"] is Texture2D:
							dup.detail_normal = cfg["detail_normal"] as Texture2D
					mi.set_surface_override_material(s, dup)
		for ch in cur.get_children():
			stack.append(ch)
