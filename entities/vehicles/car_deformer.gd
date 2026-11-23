class_name CarDeformer
extends RefCounted

## Система реальной 3D-деформации кузова автомобиля при столкновениях с объектами и обломками.
## Дублирует геометрию кузова конкретного экземпляра машины и вминает вершины в зоне удара
## с сохранением защищённой зоны салона, складок металла и PBR-материалов (включая патину).

const MAX_DENT_M: float = 0.38
const DEFORM_COOLDOWN_MS: int = 90
const _PRESERVED_SURFACE_FLAGS_MASK: int = (
	(Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	| Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	| Mesh.ARRAY_FLAG_USE_2D_VERTICES
)

var hit_count: int = 0
var total_deformation_m: float = 0.0

var _initialized: bool = false
var _last_deform_ms: int = -10000
var _entries: Array[Dictionary] = []

func _ensure_initialized(vehicle: Node3D) -> void:
	if _initialized or vehicle == null or not is_instance_valid(vehicle):
		return
	_initialized = true
	var root_inv := vehicle.global_transform.affine_inverse()
	var meshes: Array[MeshInstance3D] = []
	_collect_body_meshes(vehicle, meshes)

	for mi: MeshInstance3D in meshes:
		if not (mi.mesh is ArrayMesh):
			continue
		var src_mesh := mi.mesh as ArrayMesh
		var surf_count := src_mesh.get_surface_count()
		if surf_count <= 0:
			continue

		var mesh_to_car: Transform3D = root_inv * mi.global_transform
		var car_to_mesh: Transform3D = mesh_to_car.affine_inverse()
		var norm_to_car: Basis = car_to_mesh.basis.transposed()
		var norm_to_mesh: Basis = mesh_to_car.basis.transposed()

		var dup_mesh := ArrayMesh.new()
		var surf_records: Array[Dictionary] = []
		var valid_any := false

		for s in range(surf_count):
			var prim := src_mesh.surface_get_primitive_type(s)
			var surf_flags: int = src_mesh.surface_get_format(s) & _PRESERVED_SURFACE_FLAGS_MASK
			var arrays: Array = src_mesh.surface_get_arrays(s)
			var mat: Material = src_mesh.surface_get_material(s)
			var ov_mat: Material = mi.get_surface_override_material(s)

			if arrays.size() <= Mesh.ARRAY_VERTEX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				surf_records.append({"skip": true, "prim": prim, "flags": surf_flags, "arrays": arrays, "mat": mat, "ov_mat": ov_mat})
				if not arrays.is_empty():
					dup_mesh.add_surface_from_arrays(prim, arrays, [], {}, surf_flags)
					if mat:
						dup_mesh.surface_set_material(dup_mesh.get_surface_count() - 1, mat)
				continue

			var raw_verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			if raw_verts.is_empty():
				continue
			valid_any = true

			var has_norms: bool = arrays.size() > Mesh.ARRAY_NORMAL and (arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array) and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == raw_verts.size()
			var raw_norms := (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array) if has_norms else PackedVector3Array()

			var v_count := raw_verts.size()
			var orig_car := PackedVector3Array()
			orig_car.resize(v_count)
			var cur_car := PackedVector3Array()
			cur_car.resize(v_count)
			var norm_car := PackedVector3Array()
			if has_norms:
				norm_car.resize(v_count)

			var aabb := AABB()
			for i in range(v_count):
				var vc: Vector3 = mesh_to_car * raw_verts[i]
				orig_car[i] = vc
				cur_car[i] = vc
				if has_norms:
					norm_car[i] = (norm_to_car * raw_norms[i]).normalized()
				if i == 0:
					aabb = AABB(vc, Vector3.ZERO)
				else:
					aabb = aabb.expand(vc)

			var clean_arrays: Array = arrays.duplicate(false)
			dup_mesh.add_surface_from_arrays(prim, clean_arrays, [], {}, surf_flags)
			var new_s := dup_mesh.get_surface_count() - 1
			if mat:
				dup_mesh.surface_set_material(new_s, mat)

			surf_records.append({
				"skip": false,
				"prim": prim,
				"flags": surf_flags,
				"arrays": clean_arrays,
				"mat": mat,
				"ov_mat": ov_mat,
				"orig_car": orig_car,
				"cur_car": cur_car,
				"orig_norms_car": norm_car,
				"cur_norms_car": norm_car.duplicate() if has_norms else PackedVector3Array(),
				"aabb_car": aabb,
			})

		if not valid_any:
			continue

		mi.mesh = dup_mesh
		for s in range(mini(surf_records.size(), dup_mesh.get_surface_count())):
			var rec: Dictionary = surf_records[s]
			var ov: Material = rec.get("ov_mat") as Material
			if ov != null:
				mi.set_surface_override_material(s, ov)

		_entries.append({
			"mi": mi,
			"car_to_mesh": car_to_mesh,
			"norm_to_mesh": norm_to_mesh,
			"surfaces": surf_records,
		})

func _collect_body_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is RaycastWheel or child is CPUParticles3D:
			continue
		var cname := child.name
		if cname == "LightsRig" or cname == "FullUpgradeArmorKit" or cname == "EngineDamageFire" or cname == "MuzzleVFX":
			continue
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		_collect_body_meshes(child, out)

func deform_at_world_point(
	vehicle: Node3D,
	world_hit_pos: Vector3,
	impact_vel_world: Vector3,
	hull_half_extents: Vector2,
	severity: float = 1.0
) -> float:
	if vehicle == null or not is_instance_valid(vehicle):
		return 0.0
	var now_ms := Time.get_ticks_msec()
	if now_ms - _last_deform_ms < DEFORM_COOLDOWN_MS:
		return 0.0

	_ensure_initialized(vehicle)
	if _entries.is_empty():
		return 0.0

	var root_xform := vehicle.global_transform
	var hit_local: Vector3 = root_xform.affine_inverse() * world_hit_pos
	var hx: float = maxf(hull_half_extents.x, 0.85)
	var hz: float = maxf(hull_half_extents.y, 1.90)
	var impact_pt := Vector3(
		clampf(hit_local.x, -hx, hx),
		clampf(hit_local.y, 0.45, 1.15),
		clampf(hit_local.z, -hz, hz)
	)

	var vel_local: Vector3 = root_xform.basis.inverse() * impact_vel_world
	var push_vel: Vector3 = -vel_local.normalized() if vel_local.length_squared() > 0.04 else Vector3.BACK
	var to_core: Vector3 = (Vector3(0.0, 0.78, 0.0) - impact_pt)
	var to_core_dir: Vector3 = to_core.normalized() if to_core.length_squared() > 0.01 else Vector3.BACK
	var push_dir: Vector3 = (push_vel * 0.68 + to_core_dir * 0.32).normalized()

	var sev: float = clampf(severity, 0.30, 1.55)
	var radius_m: float = clampf(1.05 + sev * 0.45, 1.00, 1.78)
	var radius_sq: float = radius_m * radius_m
	var step_m: float = clampf(0.08 + sev * 0.095, 0.07, 0.22)
	var dent_sum: float = 0.0

	for entry: Dictionary in _entries:
		var mi := entry["mi"] as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		var car_to_mesh: Transform3D = entry["car_to_mesh"]
		var norm_to_mesh: Basis = entry["norm_to_mesh"]
		var surfaces: Array = entry["surfaces"]
		var entry_dirty := false

		for s_var in surfaces:
			var rec := s_var as Dictionary
			if bool(rec.get("skip", true)):
				continue
			var aabb: AABB = rec["aabb_car"]
			if not aabb.grow(radius_m + MAX_DENT_M).has_point(impact_pt):
				continue

			var orig_car: PackedVector3Array = rec["orig_car"]
			var cur_car: PackedVector3Array = rec["cur_car"]
			var orig_norms: PackedVector3Array = rec["orig_norms_car"]
			var cur_norms: PackedVector3Array = rec["cur_norms_car"]
			var has_norms: bool = not orig_norms.is_empty()
			var v_count := cur_car.size()
			var surf_dirty := false

			for i in range(v_count):
				var v := cur_car[i]
				var d := v - impact_pt
				# Локальная деформация вокруг реальной точки удара без вытягивания «пик» по всей крыше
				var d_eff := Vector3(d.x, d.y * 0.92, d.z * 0.86)
				var dist_sq := d_eff.length_squared()
				if dist_sq >= radius_sq:
					continue

				var dist := sqrt(dist_sq)
				var u := 1.0 - dist / radius_m
				var falloff := u * u * (3.0 - 2.0 * u)

				var v0 := orig_car[i]
				# Жёсткая защита силовой клетки салона, лобового стекла и дуг кузова от игольчатых заломов
				var cabin_guard := 1.0
				if v0.y > 1.08 and absf(v0.x) < 0.82 and v0.z > -0.78 and v0.z < 0.88:
					cabin_guard = 0.06
				elif v0.y > 1.15:
					cabin_guard = minf(cabin_guard, 0.14)

				# Плавный низкочастотный изгиб листового металла без острых пил
				var buckle: float = sin(v0.x * 3.8 + v0.z * 3.2) * 0.5 + cos(v0.z * 4.4 - v0.y * 3.6) * 0.5
				var disp: Vector3 = push_dir * (step_m * falloff * cabin_guard)
				disp += to_core_dir * (step_m * 0.16 * falloff * buckle * cabin_guard)
				# Аккуратный горб/подгиб капота вверх от лобового удара
				if v0.z < -0.60 and v0.y > 0.62 and v0.y < 1.12:
					var hood_arch: float = clampf(1.0 - absf(v0.x) * 0.72, 0.25, 1.0)
					disp.y += step_m * 0.26 * hood_arch * falloff
				# Мягкая вмятина боковых крыльев и дверей без острых шипов
				if absf(v0.x) > 0.58 and v0.y > 0.42 and v0.y < 1.12:
					disp.x += signf(v0.x) * buckle * step_m * 0.16 * falloff * cabin_guard
					disp.y += buckle * step_m * 0.08 * falloff * cabin_guard

				var target_v := v + disp
				var total_off := target_v - v0
				if total_off.length() > MAX_DENT_M:
					target_v = v0 + total_off.normalized() * MAX_DENT_M
				if v0.y >= 0.34 and target_v.y < 0.32:
					target_v.y = 0.32

				var move_len := (target_v - v).length()
				if move_len > 0.0005:
					cur_car[i] = target_v
					dent_sum += move_len
					surf_dirty = true
					if has_norms:
						var n0 := orig_norms[i]
						var n_crumple := Vector3(buckle * 0.22, absf(buckle) * 0.14, -buckle * 0.18) * clampf((target_v - v0).length() / 0.18, 0.15, 0.85)
						cur_norms[i] = (n0 - push_dir * (0.28 * falloff * cabin_guard) + n_crumple).normalized()

			if surf_dirty:
				entry_dirty = true
				var out_arrays: Array = rec["arrays"]
				var out_v := PackedVector3Array()
				out_v.resize(v_count)
				for i in range(v_count):
					out_v[i] = car_to_mesh * cur_car[i]
				out_arrays[Mesh.ARRAY_VERTEX] = out_v
				if has_norms:
					var out_n := PackedVector3Array()
					out_n.resize(v_count)
					for i in range(v_count):
						out_n[i] = (norm_to_mesh * cur_norms[i]).normalized()
					out_arrays[Mesh.ARRAY_NORMAL] = out_n

		if entry_dirty:
			var rebuilt := ArrayMesh.new()
			for s_var in surfaces:
				var rec := s_var as Dictionary
				var arrays: Array = rec["arrays"]
				if arrays.is_empty():
					continue
				rebuilt.add_surface_from_arrays(int(rec["prim"]), arrays, [], {}, int(rec.get("flags", 0)))
				var s_idx := rebuilt.get_surface_count() - 1
				var mat: Material = rec.get("mat") as Material
				if mat:
					rebuilt.surface_set_material(s_idx, mat)
			mi.mesh = rebuilt
			for s_idx in range(mini(surfaces.size(), rebuilt.get_surface_count())):
				var rec := surfaces[s_idx] as Dictionary
				var ov: Material = rec.get("ov_mat") as Material
				if ov != null:
					mi.set_surface_override_material(s_idx, ov)

	if dent_sum > 0.001:
		_last_deform_ms = now_ms
		hit_count += 1
		total_deformation_m += dent_sum
	return dent_sum
