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
	if not _knocked or freeze:
		set_physics_process(false)
		return
	var max_v: float = 18.0 if (is_barrel or prop_material == "barrel_blue") else 36.0
	var max_y: float = 4.5 if (is_barrel or prop_material == "barrel_blue") else 16.0
	# Жёсткий предохранитель от улёта пропов в небо
	if linear_velocity.length_squared() > max_v * max_v:
		linear_velocity = linear_velocity.limit_length(max_v)
	if angular_velocity.length_squared() > 14.0 * 14.0:
		angular_velocity = angular_velocity.limit_length(14.0)
	if global_position.y > max_y:
		linear_velocity.y = minf(linear_velocity.y, -2.5)
	if linear_velocity.length_squared() < 0.04 and angular_velocity.length_squared() < 0.04:
		sleeping = true

func knock_down(hit_pos: Vector3, car_vel: Vector3, car_mass: float, trigger_car: Node3D = null) -> Dictionary:
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
	set_physics_process(true)

	var impact_pt := Vector3(global_position.x, hit_pos.y + 0.85, global_position.z)
	var vfx: Node = get_tree().root.get_node_or_null("CarVFX")
	if vfx and vfx.has_method("spawn_crash_debris"):
		vfx.call("spawn_crash_debris", impact_pt, dir, maxf(spd, 10.0), "metal" if prop_material == "barrel_blue" else prop_material)

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_prop_impact"):
		sm.call("play_prop_impact", "metal" if prop_material == "barrel_blue" else prop_material, maxf(spd, 8.0))
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
