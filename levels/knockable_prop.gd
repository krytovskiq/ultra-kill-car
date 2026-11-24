extends RigidBody3D
class_name KnockableProp

var prop_material: String = "metal"
var prop_mass: float = 120.0
var damage_to_car: float = 4.0
var speed_drag_factor: float = 0.06
var prop_height: float = 4.0
var is_explosive_barrel: bool = false
var is_barrel: bool = false
var blast_radius: float = 12.5
var blast_car_damage_min: int = 20
var blast_car_damage_max: int = 30

var _knocked: bool = false
var _detonated: bool = false
var _deformed: bool = false
var _knocked_ms: int = 0
var _prev_vel: Vector3 = Vector3.ZERO
var _last_fall_sfx_ms: int = 0
var _fall_sound_count: int = 0
var _fall_audio_active: bool = false


func enable_fall_audio() -> void:
	_fall_audio_active = true
	_knocked_ms = Time.get_ticks_msec()
	_prev_vel = linear_velocity
	set_physics_process(true)

func _ready() -> void:
	# Слой 8 (только проп-триггер, без жёсткого упора о корпус машины): машина не тормозит в ноль при контакте
	collision_layer = 8
	collision_mask = 524
	mass = prop_mass
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = true
	if is_barrel and not is_explosive_barrel:
		linear_damp = 0.65
		angular_damp = 0.72
	else:
		angular_damp = 0.38
		linear_damp = 0.18
	set_physics_process(false)
	add_to_group("knockable_prop")
	add_to_group("object_hit")
	if is_explosive_barrel:
		add_to_group("explosive_barrel")


func _physics_process(_delta: float) -> void:
	if (not _knocked and not _fall_audio_active) or freeze:
		set_physics_process(false)
		return
	if _knocked:
		var max_v: float = 18.0 if (is_barrel or prop_material == "barrel_blue") else 36.0
		var max_y: float = 4.5 if (is_barrel or prop_material == "barrel_blue") else 16.0
		# Жёсткий предохранитель от улёта пропов в небо
		if linear_velocity.length_squared() > max_v * max_v:
			linear_velocity = linear_velocity.limit_length(max_v)
		if angular_velocity.length_squared() > 14.0 * 14.0:
			angular_velocity = angular_velocity.limit_length(14.0)
		if global_position.y > max_y:
			linear_velocity.y = minf(linear_velocity.y, -2.5)
	if _fall_audio_active and not sleeping and _fall_sound_count < 4:
		var now_ms: int = Time.get_ticks_msec()
		var dv: float = (_prev_vel - linear_velocity).length()
		var vert_bounce: float = linear_velocity.y - _prev_vel.y
		if now_ms - _knocked_ms >= 110 and now_ms - _last_fall_sfx_ms >= 150:
			if (dv >= 2.2 or (_prev_vel.y < -1.8 and vert_bounce >= 1.6)) and global_position.y < 14.0:
				_last_fall_sfx_ms = now_ms
				_fall_sound_count += 1
				var impact_spd: float = maxf(dv, absf(_prev_vel.y))
				if SoundManager != null and SoundManager.has_method("play_prop_fall"):
					SoundManager.play_prop_fall(prop_material, impact_spd, global_position, false)
	_prev_vel = linear_velocity
	if linear_velocity.length_squared() < 0.04 and angular_velocity.length_squared() < 0.04:
		sleeping = true
		if Time.get_ticks_msec() - _knocked_ms > 450:
			_fall_audio_active = false

func knock_down(hit_pos: Vector3, car_vel: Vector3, car_mass: float, trigger_car: Node3D = null, contact_pos: Vector3 = Vector3.INF) -> Dictionary:
	if _knocked:
		return {}
	if is_explosive_barrel:
		if _detonated:
			return {}
		detonate(trigger_car)
		return {
			"damage": 0.0,
			"drag": speed_drag_factor,
			"prop_mass": prop_mass,
			"mat": prop_material,
			"exploded": true,
		}
	_knocked = true

	var horiz_vel := Vector3(car_vel.x, 0.0, car_vel.z)
	var spd: float = horiz_vel.length()
	var dir: Vector3 = horiz_vel.normalized() if spd > 0.25 else (global_position - hit_pos)
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()

	var impact_pt: Vector3 = contact_pos if contact_pos.is_finite() else Vector3(global_position.x, hit_pos.y + 0.72, global_position.z)
	_apply_impact_deformation(impact_pt, dir, spd)

	var side_vec := Vector3(-dir.z, 0.0, dir.x)
	var lateral_offset: float = signf((global_position - hit_pos).dot(side_vec))
	if absf(lateral_offset) < 0.2:
		lateral_offset = -1.0 if (get_instance_id() % 2) == 0 else 1.0

	var launch_vel := Vector3.ZERO
	var launch_ang := Vector3.ZERO
	if prop_material == "barrel_blue" or is_barrel:
		var launch_spd: float = clampf(spd * 0.42 + 3.2, 4.0, 16.5)
		var mass_boost: float = clampf(car_mass / maxf(prop_mass * 14.0, 450.0), 0.75, 1.15)
		launch_vel = (dir * 0.68 + side_vec * (lateral_offset * 0.58) + Vector3(0.0, 0.22, 0.0)).normalized() * minf(launch_spd * mass_boost, 17.5)
		var spin_axis_b := dir.cross(Vector3.UP).normalized()
		launch_ang = (spin_axis_b * randf_range(2.4, 4.6) + Vector3.UP * (lateral_offset * randf_range(1.2, 2.8)))
	else:
		var launch_spd: float = clampf(spd * 0.95 + 5.5, 6.5, 34.0)
		var mass_boost: float = clampf(car_mass / maxf(prop_mass * 10.0, 200.0), 0.72, 2.25)
		launch_vel = (dir * 0.85 + side_vec * (lateral_offset * 0.30) + Vector3(0.0, 0.44, 0.0)).normalized() * (launch_spd * mass_boost)
		var spin_axis := dir.cross(Vector3.UP).normalized()
		launch_ang = (spin_axis * randf_range(3.2, 6.4) + Vector3.UP * (lateral_offset * randf_range(1.8, 3.8))) * clampf(launch_spd * 0.09, 0.7, 2.4)

	# Оставляем проп на слое 8 навсегда, чтобы разлетающиеся обломки не цеплялись обратно за шасси/колёса
	collision_layer = 8
	collision_mask = 524
	freeze = false
	sleeping = false
	if prop_material == "barrel_blue" or is_barrel:
		linear_velocity = launch_vel.limit_length(17.5)
		angular_velocity = launch_ang.limit_length(7.5)
	else:
		linear_velocity = launch_vel.limit_length(34.0)
		angular_velocity = launch_ang.limit_length(12.0)
	enable_fall_audio()

	var vfx_pt := impact_pt if impact_pt.is_finite() else Vector3(global_position.x, hit_pos.y + 0.85, global_position.z)
	var vfx: Node = get_tree().root.get_node_or_null("CarVFX")
	if vfx and vfx.has_method("spawn_crash_debris"):
		vfx.call("spawn_crash_debris", vfx_pt, dir, maxf(spd, 10.0), prop_material)

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_prop_impact"):
		sm.call("play_prop_impact", "metal" if (prop_material == "barrel_blue" or prop_material == "hydrant") else prop_material, maxf(spd, 8.0))
	elif sm and sm.has_method("play_sfx"):
		match prop_material:
			"wood":
				sm.call("play_sfx", "prop_snap_wood", -2.0, randf_range(0.90, 1.12))
			"concrete":
				sm.call("play_sfx", "prop_crumble_concrete", -1.5, randf_range(0.88, 1.10))
			_:
				sm.call("play_sfx", "prop_clang_metal", -2.0, randf_range(0.90, 1.12))

	return {
		"damage": damage_to_car,
		"drag": speed_drag_factor,
		"prop_mass": prop_mass,
		"mat": prop_material,
	}

func detonate(trigger_car: Node3D = null) -> Dictionary:
	if _detonated:
		return {}
	_detonated = true
	_knocked = true

	var blast_pos := global_position
	var tree := get_tree()
	visible = false
	collision_layer = 0
	collision_mask = 0
	freeze = true
	remove_from_group("explosive_barrel")
	remove_from_group("knockable_prop")
	remove_from_group("object_hit")

	var vfx: Node = tree.root.get_node_or_null("CarVFX") if tree else null
	if vfx and vfx.has_method("spawn_barrel_explosion"):
		vfx.call("spawn_barrel_explosion", blast_pos, blast_radius)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_barrel_explosion"):
		sm.call("play_barrel_explosion")

	var kills := 0
	var blast_sq := blast_radius * blast_radius
	if tree:
		for z_node in tree.get_nodes_in_group("zombie"):
			if not is_instance_valid(z_node) or not (z_node is Node3D):
				continue
			if z_node.get("state") == 3:
				continue
			var dz := (z_node as Node3D).global_position - blast_pos
			dz.y = 0.0
			var d2 := dz.length_squared()
			if d2 <= blast_sq:
				var d := maxf(sqrt(d2), 0.1)
				var out_dir := dz / d
				var falloff := 1.0 - clampf(d / maxf(blast_radius, 1.0), 0.0, 0.72)
				if d <= 8.5 and z_node.has_method("die"):
					z_node.call("die", out_dir * (20.0 * falloff), 26.0 * falloff)
					kills += 1
				elif z_node.has_method("knockdown"):
					z_node.call("knockdown", out_dir * 12.5)

	var credit_car: Node3D = trigger_car if is_instance_valid(trigger_car) else null
	if credit_car == null and tree:
		for p in tree.get_nodes_in_group("player"):
			if is_instance_valid(p) and p is Node3D:
				credit_car = p as Node3D
				break
	if kills > 0 and credit_car and credit_car.has_method("on_barrel_explosion_kills"):
		credit_car.call("on_barrel_explosion_kills", kills)

	if tree:
		var damaged_cars: Array[Node3D] = []
		for p in tree.get_nodes_in_group("player"):
			if is_instance_valid(p) and p is Node3D:
				damaged_cars.append(p as Node3D)
		if is_instance_valid(trigger_car) and not damaged_cars.has(trigger_car):
			damaged_cars.append(trigger_car)
		for p_car in damaged_cars:
			var dp := p_car.global_position - blast_pos
			dp.y = 0.0
			var d := dp.length()
			if p_car == trigger_car or d <= blast_radius:
				var car_dmg := 0
				if p_car == trigger_car or d <= 6.5:
					car_dmg = randi_range(blast_car_damage_min, blast_car_damage_max)
				else:
					var scaled_dmg := lerpf(float(blast_car_damage_min), 10.0, (d - 6.5) / maxf(blast_radius - 6.5, 1.0))
					car_dmg = maxi(roundi(scaled_dmg), 8)
				if p_car.has_method("take_damage"):
					p_car.call("take_damage", car_dmg, "ПОДРЫВ ТОПЛИВНОЙ БОЧКИ")
				if p_car.has_method("shake_camera"):
					p_car.call("shake_camera", clampf(1.1 - d / maxf(blast_radius, 1.0), 0.35, 0.95))
				var out_dir := (dp / d) if d > 0.15 else Vector3.FORWARD
				if p_car is RigidBody3D:
					var rb := p_car as RigidBody3D
					var p_falloff := 1.0 - clampf(d / maxf(blast_radius, 1.0), 0.0, 0.70)
					rb.apply_central_impulse((out_dir * 3.5 + Vector3.UP * 0.6) * rb.mass * p_falloff)
				if p_car != trigger_car and p_car.has_method("apply_body_deformation"):
					p_car.call("apply_body_deformation", blast_pos + Vector3.UP * 0.65, -out_dir * 16.0, 0.75)

		for nb_node in tree.get_nodes_in_group("explosive_barrel"):
			if not is_instance_valid(nb_node) or nb_node == self or not (nb_node is Node3D):
				continue
			var dist_sq := ((nb_node as Node3D).global_position - blast_pos).length_squared()
			if dist_sq <= 90.25 and nb_node.has_method("detonate"):
				var wr: WeakRef = weakref(nb_node)
				var wr_car: WeakRef = weakref(trigger_car) if is_instance_valid(trigger_car) else WeakRef.new()
				tree.create_timer(randf_range(0.12, 0.24)).timeout.connect(
					func():
						var b_ref := wr.get_ref() as Node
						if b_ref and is_instance_valid(b_ref) and b_ref.has_method("detonate"):
							var c_ref := wr_car.get_ref() as Node3D
							b_ref.call("detonate", c_ref)
				)

	call_deferred("queue_free")
	return {"exploded": true, "kills": kills}

const _PRESERVED_SURF_FLAGS_MASK: int = (
	(Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT)
	| (Mesh.ARRAY_FORMAT_CUSTOM_MASK << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT)
	| Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
	| Mesh.ARRAY_FLAG_USE_2D_VERTICES
)
const MAX_PROP_DEFORM_VERTS: int = 45000

func _apply_impact_deformation(hit_world_pos: Vector3, hit_dir: Vector3, hit_speed: float) -> void:
	if _deformed:
		return
	_deformed = true

	var strength: float = clampf((hit_speed - 2.0) / 18.0, 0.45, 1.0)
	var dent_ratio: float = 0.48
	var dent_rad_k: float = 0.58
	var max_dent_clamp: float = 0.44
	var squash_k: float = 0.30
	var crease_amp: float = 0.32
	if prop_material == "wood":
		dent_ratio = 0.40
		dent_rad_k = 0.54
		max_dent_clamp = 0.40
		squash_k = 0.26
		crease_amp = 0.42
	elif prop_material == "concrete":
		dent_ratio = 0.28
		dent_rad_k = 0.48
		max_dent_clamp = 0.30
		squash_k = 0.18
		crease_amp = 0.48
	elif prop_material == "metal" or prop_material == "barrel_blue" or prop_material == "metal_electric" or prop_material == "hydrant":
		dent_ratio = 0.52
		dent_rad_k = 0.62
		max_dent_clamp = 0.48
		squash_k = 0.34
		crease_amp = 0.34

	var meshes: Array[MeshInstance3D] = []
	var stack: Array[Node] = [self]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D and not (cur is CPUParticles3D):
			var c_mi := cur as MeshInstance3D
			if c_mi.visible and c_mi.mesh != null:
				meshes.append(c_mi)
		for ch in cur.get_children():
			stack.append(ch)

	for mi: MeshInstance3D in meshes:
		var world_xf: Transform3D = mi.global_transform if mi.is_inside_tree() else (global_transform * mi.transform)
		var inv_xf: Transform3D = world_xf.affine_inverse()
		var local_hit: Vector3 = inv_xf * hit_world_pos
		var local_dir: Vector3 = inv_xf.basis * hit_dir
		if local_dir.length_squared() < 0.0001:
			local_dir = Vector3.FORWARD
		else:
			local_dir = local_dir.normalized()

		var did_vertex_dent: bool = false
		if mi.mesh is ArrayMesh:
			var src_mesh := mi.mesh as ArrayMesh
			var surf_count: int = src_mesh.get_surface_count()
			var total_verts: int = 0
			var all_tris: bool = surf_count > 0
			for s in range(surf_count):
				if src_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					all_tris = false
					break
				var arrs := src_mesh.surface_get_arrays(s)
				if arrs.size() > Mesh.ARRAY_VERTEX and arrs[Mesh.ARRAY_VERTEX] is PackedVector3Array:
					total_verts += (arrs[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

			if all_tris and total_verts > 0 and total_verts <= MAX_PROP_DEFORM_VERTS:
				var dup_mesh := ArrayMesh.new()
				var aabb: AABB = src_mesh.get_aabb()
				var diag: float = maxf(aabb.size.length(), 0.45)
				var dent_rad: float = maxf(diag * dent_rad_k, 0.72)
				var max_dent: float = minf(diag * dent_ratio * strength, diag * max_dent_clamp)
				local_hit = local_hit.clamp(aabb.position - Vector3.ONE * 0.22, aabb.end + Vector3.ONE * 0.22)

				var ov_mats: Array[Material] = []
				var mat_override_saved: Material = mi.material_override
				for s in range(surf_count):
					ov_mats.append(mi.get_surface_override_material(s))
					var s_flags: int = src_mesh.surface_get_format(s) & _PRESERVED_SURF_FLAGS_MASK
					var arrays: Array = src_mesh.surface_get_arrays(s).duplicate(false)
					var mat: Material = src_mesh.surface_get_material(s)
					if arrays.size() <= Mesh.ARRAY_VERTEX or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
						continue
					var orig_verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
					var vc: int = orig_verts.size()
					var cur_verts := orig_verts.duplicate()
					var has_norms: bool = arrays.size() > Mesh.ARRAY_NORMAL and (arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array) and (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == vc
					var orig_norms: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array) if has_norms else PackedVector3Array()

					for vi in range(vc):
						var v: Vector3 = orig_verts[vi]
						var d: float = v.distance_to(local_hit)
						if d < dent_rad:
							var t: float = clampf(1.0 - d / dent_rad, 0.0, 1.0)
							var falloff: float = 0.5 - 0.5 * cos(t * PI)
							var buckle: float = sin(v.x * 7.5 + v.z * 6.8) * 0.5 + cos(v.y * 8.2 - v.z * 5.9) * 0.5
							var crease: float = clampf(1.0 + crease_amp * buckle, 0.65, 1.45)
							var radial_out: Vector3 = (v - local_hit).slide(local_dir)
							if radial_out.length_squared() > 0.0001:
								radial_out = radial_out.normalized()
							else:
								radial_out = Vector3.ZERO
							v += local_dir * (max_dent * falloff * crease)
							v += radial_out * (max_dent * 0.28 * sin(t * PI))
							cur_verts[vi] = v
					arrays[Mesh.ARRAY_VERTEX] = cur_verts

					if has_norms and vc >= 3:
						var has_idx: bool = arrays.size() > Mesh.ARRAY_INDEX and (arrays[Mesh.ARRAY_INDEX] is PackedInt32Array)
						var idx_arr: PackedInt32Array = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array) if has_idx else PackedInt32Array()
						@warning_ignore("integer_division")
						var tri_cnt: int = (idx_arr.size() / 3) if has_idx else (vc / 3)
						if tri_cnt > 0:
							var acc_n := PackedVector3Array()
							acc_n.resize(vc)
							for ti in range(tri_cnt):
								var b: int = ti * 3
								var i0: int = idx_arr[b] if has_idx else b
								var i1: int = idx_arr[b + 1] if has_idx else (b + 1)
								var i2: int = idx_arr[b + 2] if has_idx else (b + 2)
								var p0: Vector3 = cur_verts[i0]
								var p1: Vector3 = cur_verts[i1]
								var p2: Vector3 = cur_verts[i2]
								var fn: Vector3 = (p2 - p0).cross(p1 - p0)
								var p0o: Vector3 = orig_verts[i0]
								var p1o: Vector3 = orig_verts[i1]
								var p2o: Vector3 = orig_verts[i2]
								var fno: Vector3 = (p2o - p0o).cross(p1o - p0o)
								var n_avg: Vector3 = orig_norms[i0] + orig_norms[i1] + orig_norms[i2]
								if fno.dot(n_avg) < 0.0:
									fn = -fn
								acc_n[i0] += fn
								acc_n[i1] += fn
								acc_n[i2] += fn
							var out_n := PackedVector3Array()
							out_n.resize(vc)
							for vi in range(vc):
								var gn: Vector3 = acc_n[vi]
								out_n[vi] = gn.normalized() if gn.length_squared() > 0.00001 else orig_norms[vi]
							arrays[Mesh.ARRAY_NORMAL] = out_n

					dup_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, s_flags)
					if mat != null:
						dup_mesh.surface_set_material(dup_mesh.get_surface_count() - 1, mat)

				if dup_mesh.get_surface_count() == surf_count:
					mi.mesh = dup_mesh
					if mat_override_saved != null:
						mi.material_override = mat_override_saved
					for s in range(surf_count):
						if ov_mats[s] != null:
							mi.set_surface_override_material(s, ov_mats[s])
					did_vertex_dent = true

		# Постоянное смятие и наклон профиля для мгновенной читаемости с трассы
		var eff_sq: float = squash_k * (0.62 if did_vertex_dent else 1.0) * strength
		var ax := Vector3(absf(local_dir.x), absf(local_dir.y), absf(local_dir.z))
		var max_comp: float = maxf(maxf(ax.x, ax.y), maxf(ax.z, 0.001))
		ax /= max_comp
		var sq_scale := Vector3(
			clampf(1.0 - ax.x * eff_sq + (1.0 - ax.x) * eff_sq * 0.36, 0.56, 1.35),
			clampf(1.0 - ax.y * eff_sq * 0.58 + (1.0 - ax.y) * eff_sq * 0.22, 0.66, 1.26),
			clampf(1.0 - ax.z * eff_sq + (1.0 - ax.z) * eff_sq * 0.36, 0.56, 1.35)
		)
		mi.scale *= sq_scale
		var bend_axis: Vector3 = Vector3.UP.cross(local_dir)
		if bend_axis.length_squared() > 0.001:
			mi.rotate(bend_axis.normalized(), deg_to_rad((9.5 if did_vertex_dent else 16.0) * strength))
