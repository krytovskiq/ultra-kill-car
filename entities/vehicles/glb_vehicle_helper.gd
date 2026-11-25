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


const _BODY_SKIP_NODE_NAMES := [
	"look", "VisualLightsRig", "LightsRig", "FullUpgradeArmorKit",
	"TurretArmorMount", "Turret_Gun", "base_gun", "PropTriggerArea",
	"EngineDamageFire", "MuzzleFlashRig", "MuzzleVFX",
	"ShadowBlob", "ShadowBlobMesh", "HeadlightProj", "TaillightProj",
	"HeadlightGroundProjection", "TaillightGroundProjection"
]
const _MAX_BATCH_VERTS_PER_SURF := 20000


static func _tex_key(tex: Texture2D) -> String:
	if tex == null:
		return "0"
	if not tex.resource_path.is_empty():
		return tex.resource_path
	return str(tex.get_instance_id())


static func _color_key(c: Color) -> String:
	return "%d,%d,%d,%d" % [roundi(c.r * 1000.0), roundi(c.g * 1000.0), roundi(c.b * 1000.0), roundi(c.a * 1000.0)]


static func _material_signature(mat: Material) -> String:
	if mat == null:
		return "null"
	if not (mat is StandardMaterial3D):
		return "id:" + str(mat.get_instance_id())
	var m := mat as StandardMaterial3D
	var parts := PackedStringArray([
		_color_key(m.albedo_color),
		_tex_key(m.albedo_texture),
		str(roundi(m.metallic * 1000.0)),
		str(roundi(m.metallic_specular * 1000.0)),
		_tex_key(m.metallic_texture),
		str(m.metallic_texture_channel),
		str(roundi(m.roughness * 1000.0)),
		_tex_key(m.roughness_texture),
		str(m.roughness_texture_channel),
		"n1" if m.normal_enabled else "n0",
		str(roundi(m.normal_scale * 1000.0)),
		_tex_key(m.normal_texture),
		"e1" if m.emission_enabled else "e0",
		_color_key(m.emission),
		str(roundi(m.emission_energy_multiplier * 1000.0)),
		_tex_key(m.emission_texture),
		"ao1" if m.ao_enabled else "ao0",
		_tex_key(m.ao_texture),
		str(m.transparency),
		str(roundi(m.alpha_scissor_threshold * 1000.0)),
		str(m.cull_mode),
		str(m.depth_draw_mode),
		str(m.shading_mode),
		"cc1" if m.clearcoat_enabled else "cc0",
		str(roundi(m.clearcoat * 1000.0)),
		str(roundi(m.clearcoat_roughness * 1000.0)),
		"d1" if m.detail_enabled else "d0",
		_tex_key(m.detail_albedo),
		_tex_key(m.detail_normal),
		str(m.detail_uv_layer),
		str(m.detail_blend_mode),
		"%d,%d,%d" % [roundi(m.uv1_scale.x * 1000.0), roundi(m.uv1_scale.y * 1000.0), roundi(m.uv1_scale.z * 1000.0)],
		"%d,%d,%d" % [roundi(m.uv1_offset.x * 1000.0), roundi(m.uv1_offset.y * 1000.0), roundi(m.uv1_offset.z * 1000.0)],
		"tri1" if m.uv1_triplanar else "tri0",
		"vc1" if m.vertex_color_use_as_albedo else "vc0",
		"ns1" if m.disable_receive_shadows else "ns0",
	])
	return "|".join(parts)


static func _should_skip_body_node(node: Node, base_gun_node: Node) -> bool:
	if node == base_gun_node:
		return true
	if node is RaycastWheel or node is VehicleWheel3D or node is CPUParticles3D:
		return true
	var nname: String = node.name
	if nname in _BODY_SKIP_NODE_NAMES:
		return true
	if nname.begins_with("Camera") or nname.begins_with("KitStage_"):
		return true
	return false


static func _append_surface_chunk(
	entries: Array[Dictionary],
	mat: Material,
	out_mesh: ArrayMesh
) -> void:
	if entries.is_empty():
		return
	var need_uv2 := false
	var need_col := false
	var need_tan := false
	for e in entries:
		var m: Mesh = e["mesh"] as Mesh
		var s := int(e["surf"])
		var s_arr := m.surface_get_arrays(s)
		if s_arr.size() > Mesh.ARRAY_TEX_UV2 and s_arr[Mesh.ARRAY_TEX_UV2] != null:
			need_uv2 = true
		if s_arr.size() > Mesh.ARRAY_COLOR and s_arr[Mesh.ARRAY_COLOR] != null:
			need_col = true
		if s_arr.size() > Mesh.ARRAY_TANGENT and s_arr[Mesh.ARRAY_TANGENT] != null:
			need_tan = true
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D
		if not smat.normal_enabled and not (smat.detail_enabled and smat.detail_normal != null):
			need_tan = false
		if not smat.vertex_color_use_as_albedo:
			need_col = false

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var cols := PackedColorArray()
	var tans := PackedFloat32Array()
	var indices := PackedInt32Array()

	for e in entries:
		var m := e["mesh"] as Mesh
		var s := int(e["surf"])
		var xf := e["xf"] as Transform3D
		var arr := m.surface_get_arrays(s)
		if arr.is_empty():
			continue
		var s_verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		if s_verts.is_empty():
			continue
		var s_norms_v: Variant = arr[Mesh.ARRAY_NORMAL]
		var s_uvs_v: Variant = arr[Mesh.ARRAY_TEX_UV]
		var s_uv2s_v: Variant = arr[Mesh.ARRAY_TEX_UV2]
		var s_cols_v: Variant = arr[Mesh.ARRAY_COLOR]
		var s_tans_v: Variant = arr[Mesh.ARRAY_TANGENT]
		var s_idx_v: Variant = arr[Mesh.ARRAY_INDEX]

		var s_norms: PackedVector3Array = s_norms_v if s_norms_v is PackedVector3Array else PackedVector3Array()
		var s_uvs: PackedVector2Array = s_uvs_v if s_uvs_v is PackedVector2Array else PackedVector2Array()
		var s_uv2s: PackedVector2Array = s_uv2s_v if s_uv2s_v is PackedVector2Array else PackedVector2Array()
		var s_cols: PackedColorArray = s_cols_v if s_cols_v is PackedColorArray else PackedColorArray()
		var s_tans: PackedFloat32Array = s_tans_v if s_tans_v is PackedFloat32Array else PackedFloat32Array()

		var v_base := verts.size()
		var n_xf := xf.basis.inverse().transposed()
		var t_xf := xf.basis.orthonormalized()
		var det_neg := xf.basis.determinant() < 0.0

		for i in range(s_verts.size()):
			verts.append(xf * s_verts[i])
			if i < s_norms.size():
				norms.append((n_xf * s_norms[i]).normalized())
			else:
				norms.append(Vector3.UP)
			if i < s_uvs.size():
				uvs.append(s_uvs[i])
			else:
				uvs.append(Vector2.ZERO)
			if need_uv2:
				if i < s_uv2s.size():
					uv2s.append(s_uv2s[i])
				elif i < s_uvs.size():
					uv2s.append(s_uvs[i])
				else:
					uv2s.append(Vector2.ZERO)
			if need_col:
				if i < s_cols.size():
					cols.append(s_cols[i])
				else:
					cols.append(Color.WHITE)
			if need_tan:
				var ti := i * 4
				if ti + 3 < s_tans.size():
					var tv := (t_xf * Vector3(s_tans[ti], s_tans[ti + 1], s_tans[ti + 2])).normalized()
					tans.append(tv.x)
					tans.append(tv.y)
					tans.append(tv.z)
					tans.append(s_tans[ti + 3])
				else:
					tans.append(t_xf.x.x)
					tans.append(t_xf.x.y)
					tans.append(t_xf.x.z)
					tans.append(1.0)

		if s_idx_v is PackedInt32Array and not (s_idx_v as PackedInt32Array).is_empty():
			var s_idx: PackedInt32Array = s_idx_v
			if det_neg:
				var k := 0
				while k + 2 < s_idx.size():
					indices.append(v_base + s_idx[k])
					indices.append(v_base + s_idx[k + 2])
					indices.append(v_base + s_idx[k + 1])
					k += 3
			else:
				for idx_val in s_idx:
					indices.append(v_base + idx_val)
		else:
			var k := 0
			while k + 2 < s_verts.size():
				if det_neg:
					indices.append(v_base + k)
					indices.append(v_base + k + 2)
					indices.append(v_base + k + 1)
				else:
					indices.append(v_base + k)
					indices.append(v_base + k + 1)
					indices.append(v_base + k + 2)
				k += 3

	if verts.is_empty() or indices.is_empty():
		return
	var surf_arr := []
	surf_arr.resize(Mesh.ARRAY_MAX)
	surf_arr[Mesh.ARRAY_VERTEX] = verts
	surf_arr[Mesh.ARRAY_NORMAL] = norms
	surf_arr[Mesh.ARRAY_TEX_UV] = uvs
	if need_uv2:
		surf_arr[Mesh.ARRAY_TEX_UV2] = uv2s
	if need_col:
		surf_arr[Mesh.ARRAY_COLOR] = cols
	if need_tan:
		surf_arr[Mesh.ARRAY_TANGENT] = tans
	surf_arr[Mesh.ARRAY_INDEX] = indices
	var s_new := out_mesh.get_surface_count()
	out_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surf_arr)
	if mat != null:
		out_mesh.surface_set_material(s_new, mat)


static func _build_chunked_body_mesh(entries: Array[Dictionary]) -> ArrayMesh:
	var out_mesh := ArrayMesh.new()
	var groups: Dictionary = {} # mat_sig -> Array[Dictionary]
	var group_mats: Dictionary = {} # mat_sig -> Material
	for e in entries:
		var sig: String = e["sig"] as String
		if not groups.has(sig):
			var arr: Array[Dictionary] = []
			groups[sig] = arr
			group_mats[sig] = e["mat"] as Material
		(groups[sig] as Array[Dictionary]).append(e)

	for sig in groups.keys():
		var list: Array[Dictionary] = groups[sig] as Array[Dictionary]
		var mat: Material = group_mats[sig] as Material
		var chunk: Array[Dictionary] = []
		var chunk_verts := 0
		for e in list:
			var m: Mesh = e["mesh"] as Mesh
			var s := int(e["surf"])
			var s_arr_v: PackedVector3Array = m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var sv: int = s_arr_v.size()
			if not chunk.is_empty() and chunk_verts + sv > _MAX_BATCH_VERTS_PER_SURF:
				_append_surface_chunk(chunk, mat, out_mesh)
				chunk.clear()
				chunk_verts = 0
			chunk.append(e)
			chunk_verts += sv
		if not chunk.is_empty():
			_append_surface_chunk(chunk, mat, out_mesh)
	return out_mesh


static func optimize_static_body_meshes(vehicle: Node3D) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return
	var base_gun_val: Variant = vehicle.get("base_gun")
	var base_gun_node: Node = base_gun_val as Node if base_gun_val is Node else null

	var shadow_entries: Array[Dictionary] = []
	var noshadow_entries: Array[Dictionary] = []
	var replaced_nodes: Array[MeshInstance3D] = []

	var stack: Array[Dictionary] = []
	for ch in vehicle.get_children():
		if _should_skip_body_node(ch, base_gun_node):
			continue
		var xf := (ch as Node3D).transform if ch is Node3D else Transform3D.IDENTITY
		stack.append({"node": ch, "xf": xf})

	while not stack.is_empty():
		var item: Dictionary = stack.pop_back() as Dictionary
		var cur: Node = item["node"] as Node
		var cur_xf: Transform3D = item["xf"] as Transform3D
		if _should_skip_body_node(cur, base_gun_node):
			continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.visible and mi.mesh != null and mi.skin == null:
				var all_supported := true
				var surf_count := mi.mesh.get_surface_count()
				for s in range(surf_count):
					if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
						all_supported = false
						break
					var m_check := mi.get_active_material(s)
					if m_check is ShaderMaterial:
						all_supported = false
						break
				if all_supported and surf_count > 0:
					var base_cast_sh := mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					for s in range(surf_count):
						var mat := mi.get_active_material(s)
						var is_translucent := false
						if mat is StandardMaterial3D:
							var sm := mat as StandardMaterial3D
							if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and sm.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
								is_translucent = true
						var entry := {
							"mesh": mi.mesh,
							"surf": s,
							"xf": cur_xf,
							"mat": mat,
							"sig": _material_signature(mat),
						}
						if base_cast_sh and not is_translucent:
							shadow_entries.append(entry)
						else:
							noshadow_entries.append(entry)
					replaced_nodes.append(mi)

		for ch in cur.get_children():
			if _should_skip_body_node(ch, base_gun_node):
				continue
			var next_xf := cur_xf
			if ch is Node3D:
				next_xf = cur_xf * (ch as Node3D).transform
			stack.append({"node": ch, "xf": next_xf})

	if replaced_nodes.size() <= 2:
		return

	if not shadow_entries.is_empty():
		var sh_mesh := _build_chunked_body_mesh(shadow_entries)
		if sh_mesh.get_surface_count() > 0:
			var sh_mi := MeshInstance3D.new()
			sh_mi.name = "BodyBatchedShadow"
			sh_mi.mesh = sh_mesh
			sh_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			vehicle.add_child(sh_mi)

	if not noshadow_entries.is_empty():
		var nsh_mesh := _build_chunked_body_mesh(noshadow_entries)
		if nsh_mesh.get_surface_count() > 0:
			var nsh_mi := MeshInstance3D.new()
			nsh_mi.name = "BodyBatchedNoShadow"
			nsh_mi.mesh = nsh_mesh
			nsh_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vehicle.add_child(nsh_mi)

	for old_mi in replaced_nodes:
		if not is_instance_valid(old_mi):
			continue
		if old_mi.get_child_count() == 0:
			old_mi.queue_free()
		else:
			old_mi.mesh = null
			old_mi.material_override = null
			old_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

