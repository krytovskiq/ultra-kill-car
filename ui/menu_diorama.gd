extends Node3D

## Controls the 3D zombie-apocalypse diorama rendered behind the Main Menu UI.

const ZOMBIE_SCENE_PATH := "res://entities/zombies/Z1/Z1.tscn"

const ProceduralMaterials = preload("res://levels/procedural_materials.gd")

var _cam: Camera3D = null
var _base_cam_pos := Vector3(-0.35, 1.78, 27.6)
var _look_target := Vector3(-1.65, 0.96, 12.0)
var _hero_car: Node3D = null
var _zombies: Array[Node3D] = []
var _zombie_meta: Array[Dictionary] = []
var _time_acc: float = 0.0
var _smooth_mouse := Vector2.ZERO
var _launching: bool = false
var _launch_timer: float = 0.0
var _launch_done: bool = false
var _launch_start_pos: Vector3 = Vector3.ZERO
var _launch_callback: Callable = Callable()
var _launch_shake: float = 0.0
var _launch_shift_fired: bool = false

func _ready() -> void:
	_cam = get_node_or_null("Camera3D") as Camera3D
	_spawn_hero_car()
	if _cam:
		_cam.position = _base_cam_pos
		_cam.look_at(_look_target, Vector3.UP)
		_cam.make_current()

	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_menu_ambience"):
		sm.call("set_menu_ambience")

	_spawn_fog_zombies()
	_setup_menu_ragdoll_floor()
	_spawn_menu_billboards()
	_spawn_ambient_particles()
	if is_instance_valid(_hero_car) and _hero_car.has_method("update_showcase_lights"):
		_hero_car.call("update_showcase_lights", 0.016)

func _spawn_hero_car() -> void:
	var game_node := get_node_or_null("/root/Game")
	var car_path := "res://entities/vehicles/pikap/pikap.tscn"
	var safe_idx := 0
	if game_node:
		var data: Variant = game_node.get("car_data")
		var idx: int = int(game_node.get("selected_car_index"))
		if data is Array and not (data as Array).is_empty():
			safe_idx = clampi(idx, 0, (data as Array).size() - 1)
			car_path = str((data as Array)[safe_idx].get("path", car_path))

	var ps := load(car_path) as PackedScene
	if ps == null:
		return
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return
	inst.set("is_preview", true)
	_hero_car = inst
	add_child(inst)
	if inst.has_method("apply_car_upgrades"):
		inst.call("apply_car_upgrades", safe_idx)
	inst.position = Vector3(2.85, 0.06, 21.0)
	# Машина стоит ровно вдоль правой полосы шоссе носом по направлению трассы (-Z)
	inst.rotation_degrees = Vector3.ZERO
	if inst.has_method("set_preview_mode"):
		inst.call("set_preview_mode", true, true)


func _spawn_menu_billboards() -> void:
	var placements := [
		{"pos": Vector3(11.6, 0.0, 2.0), "yaw": -0.22, "variant": 0, "sc": 1.08},
		{"pos": Vector3(-11.2, 0.0, -14.0), "yaw": 0.24, "variant": 1, "sc": 1.15},
	]
	for p: Dictionary in placements:
		var mesh := ProceduralMaterials.get_billboard_frame_mesh(int(p["variant"]))
		if mesh == null:
			continue
		var bmi := MeshInstance3D.new()
		bmi.name = "MenuBillboard_%d" % int(p["variant"])
		bmi.mesh = mesh
		bmi.position = p["pos"] as Vector3
		bmi.rotation = Vector3(0.0, float(p["yaw"]), randf_range(-0.04, 0.04))
		bmi.scale = Vector3.ONE * float(p["sc"])
		bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bmi)

func _spawn_fog_zombies() -> void:
	var z_ps := load(ZOMBIE_SCENE_PATH) as PackedScene
	if z_ps == null:
		return
	var spots := [
		Vector3(2.35, 0.04, 14.2),
		Vector3(3.45, 0.04, 11.4),
		Vector3(2.55, 0.04, 6.8),
		Vector3(-0.95, 0.04, 9.2),
		Vector3(3.30, 0.04, 2.2),
		Vector3(0.45, 0.04, -1.8),
	]
	var face_target := Vector3(2.85, 0.04, 21.0)
	_zombies.clear()
	_zombie_meta.clear()
	for i in range(spots.size()):
		var z := z_ps.instantiate() as Node3D
		if z == null:
			continue
		add_child(z)
		z.position = spots[i]
		var t := Vector3(face_target.x, z.position.y, face_target.z)
		if not z.position.is_equal_approx(t):
			z.look_at(t, Vector3.UP)
		var base_yaw := z.rotation.y
		var start_phase := float(i) * 0.77 + 0.15
		if z.has_method("setup_menu_showcase"):
			z.call("setup_menu_showcase", i % 6, i % 6, "IdleTwitch" if (i % 2 == 1) else "Idle", start_phase)
		else:
			z.set("state", 0)
			z.set_physics_process(false)
			if z is CollisionObject3D:
				(z as CollisionObject3D).collision_layer = 0
				(z as CollisionObject3D).collision_mask = 0
			var ap := z.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if ap and ap.has_animation("Idle"):
				ap.play("Idle")
				ap.seek(float(i) * 0.43, true)
		_zombies.append(z)
		_zombie_meta.append({
			"base_pos": spots[i],
			"base_yaw": base_yaw,
			"phase": start_phase,
			"freq": 0.92 + float(i % 3) * 0.24,
			"hit": false,
			"vel": Vector3.ZERO,
			"ang_vel": Vector3.ZERO,
		})

func _setup_menu_ragdoll_floor() -> void:
	if get_node_or_null("MenuRagdollFloor") != null:
		return
	var sb := StaticBody3D.new()
	sb.name = "MenuRagdollFloor"
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(140.0, 1.0, 260.0)
	cs.shape = box
	cs.position = Vector3(0.0, -0.5, -20.0)
	sb.add_child(cs)
	add_child(sb)

func _step_menu_zombies(delta: float, speed_scale: float = 1.0) -> void:
	for i in range(_zombies.size()):
		var z := _zombies[i]
		if not is_instance_valid(z):
			continue
		if i < _zombie_meta.size() and bool(_zombie_meta[i].get("hit", false)):
			continue
		if z.has_method("step_menu_idle"):
			z.call("step_menu_idle", delta, speed_scale)
		if i < _zombie_meta.size():
			var m: Dictionary = _zombie_meta[i]
			var bp: Vector3 = m["base_pos"]
			var byaw: float = float(m["base_yaw"])
			var ph: float = float(m["phase"])
			var freq: float = float(m["freq"])
			var u := _time_acc * freq + ph
			z.rotation.y = byaw + sin(u) * 0.14
			z.position.x = bp.x + sin(u * 0.70) * 0.06
			z.position.z = bp.z + cos(u * 0.55) * 0.04

func _spawn_ambient_particles() -> void:
	var vfx := get_node_or_null("/root/CarVFX")
	var smoke_tex: Texture2D = vfx.get("tex_smoke_puff") as Texture2D if vfx else null
	var spark_tex: Texture2D = vfx.get("tex_smoke") as Texture2D if vfx else null

	if smoke_tex:
		var mist := CPUParticles3D.new()
		mist.name = "MenuGroundMist"
		mist.position = Vector3(-1.2, 0.45, 11.5)
		mist.amount = 14
		mist.lifetime = 6.5
		mist.preprocess = 4.0
		mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		mist.emission_box_extents = Vector3(8.5, 0.4, 8.0)
		mist.direction = Vector3(-1.0, 0.04, 0.2)
		mist.spread = 16.0
		mist.gravity = Vector3(0.0, 0.02, 0.0)
		mist.initial_velocity_min = 0.5
		mist.initial_velocity_max = 1.2
		mist.scale_amount_min = 3.8
		mist.scale_amount_max = 6.8
		mist.angle_min = 0.0
		mist.angle_max = 360.0
		var qm := QuadMesh.new()
		qm.size = Vector2(1.0, 1.0)
		mist.mesh = qm
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = smoke_tex
		mist.material_override = mat
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.70, 1.0])
		ramp.colors = PackedColorArray([
			Color(0.36, 0.39, 0.40, 0.0),
			Color(0.36, 0.39, 0.40, 0.10),
			Color(0.36, 0.39, 0.40, 0.08),
			Color(0.36, 0.39, 0.40, 0.0)
		])
		mist.color_ramp = ramp
		add_child(mist)

	if spark_tex:
		var ash := CPUParticles3D.new()
		ash.name = "MenuEmbers"
		# Strictly bounded to z=13..22 well ahead of camera (z=28.4)
		ash.position = Vector3(0.5, 0.85, 17.5)
		ash.amount = 22
		ash.lifetime = 4.2
		ash.preprocess = 3.0
		ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		ash.emission_box_extents = Vector3(5.5, 1.1, 4.2)
		ash.direction = Vector3(-0.7, 0.45, 0.15)
		ash.spread = 32.0
		ash.gravity = Vector3(-0.08, 0.14, 0.0)
		ash.initial_velocity_min = 0.35
		ash.initial_velocity_max = 1.0
		ash.scale_amount_min = 0.035
		ash.scale_amount_max = 0.085
		var qm2 := QuadMesh.new()
		qm2.size = Vector2(1.0, 1.0)
		ash.mesh = qm2
		var mat2 := StandardMaterial3D.new()
		mat2.vertex_color_use_as_albedo = true
		mat2.vertex_color_is_srgb = true
		mat2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat2.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat2.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat2.billboard_keep_scale = true
		mat2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat2.albedo_texture = spark_tex
		ash.material_override = mat2
		var ramp2 := Gradient.new()
		ramp2.offsets = PackedFloat32Array([0.0, 0.25, 0.80, 1.0])
		ramp2.colors = PackedColorArray([
			Color(1.0, 0.48, 0.14, 0.0),
			Color(1.0, 0.56, 0.20, 0.78),
			Color(0.92, 0.34, 0.10, 0.52),
			Color(0.80, 0.20, 0.04, 0.0)
		])
		ash.color_ramp = ramp2
		add_child(ash)

func play_launch_transition(on_finished: Callable = Callable()) -> void:
	if _launching:
		return
	_launching = true
	_launch_timer = 0.0
	_launch_done = false
	_launch_shift_fired = false
	_launch_callback = on_finished

	if is_instance_valid(_hero_car):
		_hero_car.rotation_degrees = Vector3.ZERO
		_launch_start_pos = _hero_car.position
		if _hero_car.has_method("start_burnout_vfx"):
			_hero_car.call("start_burnout_vfx", true)

func _step_launch_transition(delta: float) -> void:
	_launch_timer += delta
	_launch_shake = maxf(_launch_shake - delta * 2.2, 0.0)
	if is_instance_valid(_hero_car):
		var fwd_dir := Vector3.FORWARD
		var sm := get_node_or_null("/root/SoundManager")

		if _launch_timer < 0.92:
			# Реалистичный бёрнаут на месте: приседание кормы, крен от крутящего момента и проскальзывание перед срывом
			var t1 := clampf(_launch_timer / 0.92, 0.0, 1.0)
			var creep_z := lerpf(0.0, 0.55, t1 * t1 * t1)
			var jitter_x := sin(_launch_timer * 42.0) * 0.018 * clampf(t1 * 2.0, 0.0, 1.0)
			var jitter_y := sin(_launch_timer * 68.0) * 0.006
			_hero_car.position = _launch_start_pos + Vector3(jitter_x, jitter_y, -creep_z)
			_hero_car.rotation = Vector3(
				lerpf(0.0, 0.036, sqrt(t1)),
				sin(_launch_timer * 14.0) * 0.014 * t1,
				sin(t1 * PI) * 0.022 + sin(_launch_timer * 32.0) * 0.008
			)
			if _hero_car.has_method("step_burnout_visuals"):
				_hero_car.call("step_burnout_visuals", delta, lerpf(24.0, 50.0, t1), sin(_launch_timer * 14.0) * -0.10 * t1, lerpf(1.06, 1.72, t1), -9.5, false)
		else:
			# Нелинейный разгон с вилянием кормы, контррулением и переключением передачи
			var t_el := _launch_timer - 0.92
			var t2 := clampf(t_el / 0.96, 0.0, 1.0)
			var accel_dist := 0.55 + 38.0 * pow(t2, 1.55)
			var x_sway := sin(t_el * 5.2) * exp(-t_el * 1.65) * 0.52
			var yaw_off := cos(t_el * 5.2) * exp(-t_el * 1.55) * 0.060
			var steer_vis := clampf(-yaw_off * 2.4, -0.35, 0.35)
			var shift_window := 1.0 - clampf(absf(t_el - 0.49) / 0.09, 0.0, 1.0)
			if not _launch_shift_fired and t_el >= 0.44:
				_launch_shift_fired = true
				if sm and sm.has_method("play_vehicle_sfx"):
					sm.call("play_vehicle_sfx", "gear_shift_up", -4.8, 1.02)
					sm.call("play_vehicle_sfx", "exhaust_backfire", -8.5, 0.96)
			var pitch_squat := lerpf(0.032 * exp(-t_el * 1.1), -0.016, shift_window)
			var rpm_p := lerpf(1.26, 2.02, t2) - shift_window * 0.42
			_hero_car.position = _launch_start_pos + Vector3(x_sway, 0.0, -accel_dist) + fwd_dir * 0.0
			_hero_car.rotation = Vector3(pitch_squat, yaw_off, -yaw_off * 0.32)
			if _hero_car.has_method("step_burnout_visuals"):
				_hero_car.call("step_burnout_visuals", delta, lerpf(20.0, 50.0, t2), steer_vis, rpm_p, lerpf(-13.5, -36.0, t2), true)

			for i in range(_zombies.size()):
				if i >= _zombie_meta.size() or bool(_zombie_meta[i].get("hit", false)):
					continue
				var z := _zombies[i]
				if not is_instance_valid(z):
					continue
				var dx := z.position.x - _hero_car.position.x
				var dz := z.position.z - _hero_car.position.z
				if absf(dz) < 3.0 and absf(dx) < 2.6:
					_zombie_meta[i]["hit"] = true
					var side_push := signf(dx) if absf(dx) > 0.18 else (-1.0 if (i % 2 == 0) else 1.0)
					var impact_vec := Vector3(side_push * randf_range(5.5, 11.0), randf_range(6.0, 10.0), -randf_range(24.0, 34.0))
					if z.has_method("trigger_menu_ragdoll"):
						z.call("trigger_menu_ragdoll", impact_vec, 25.0)
					_launch_shake = 0.55
					CarVFX.spawn_impact(z.global_position + Vector3.UP, "blood")
					if sm and sm.has_method("play_zombie_hit_thud"):
						sm.call("play_zombie_hit_thud", 78.0, true)

		if is_instance_valid(_cam):
			var p_cam := clampf(_launch_timer / 1.80, 0.0, 1.0)
			var goal_pos := _base_cam_pos + Vector3(-1.4, -0.18, -2.6) * p_cam
			if _launch_shake > 0.005:
				goal_pos += Vector3(sin(_launch_timer * 58.0), cos(_launch_timer * 67.0), 0.0) * (_launch_shake * 0.24)
			_cam.position = _cam.position.lerp(goal_pos, clampf(delta * 4.5, 0.0, 1.0))
			_cam.fov = lerpf(_cam.fov, 60.0, clampf(delta * 3.5, 0.0, 1.0))
			var target := _hero_car.position + Vector3(0.0, 0.90, -4.0)
			if not _cam.global_position.is_equal_approx(target):
				_cam.look_at(_look_target.lerp(target, 0.55), Vector3.UP)

	if _launch_timer >= 1.92 and not _launch_done:
		_launch_done = true
		if is_instance_valid(_hero_car) and _hero_car.has_method("set_preview_mode"):
			_hero_car.call("set_preview_mode", true, false)
		var sm := get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("stop_transient_sfx"):
			sm.call("stop_transient_sfx")
		if _launch_callback.is_valid():
			_launch_callback.call()
		else:
			SceneTransition.transition_to_scene("res://levels/main.tscn", 0.22, 0.50)

func _process(delta: float) -> void:
	_time_acc += delta
	_step_menu_zombies(delta, 1.0)
	if is_instance_valid(_hero_car) and _hero_car.has_method("update_showcase_lights"):
		_hero_car.call("update_showcase_lights", delta)
	if not is_instance_valid(_cam):
		return
	if not _cam.current:
		_cam.make_current()
	if _launching:
		_step_launch_transition(delta)
		return
	var vp := get_viewport()
	var target_mouse := Vector2.ZERO
	if vp and vp.get_visible_rect().size.x > 10.0 and vp.get_visible_rect().size.y > 10.0:
		var sz := vp.get_visible_rect().size
		var mp := vp.get_mouse_position()
		target_mouse = Vector2(
			clampf((mp.x / sz.x) * 2.0 - 1.0, -1.0, 1.0),
			clampf((mp.y / sz.y) * 2.0 - 1.0, -1.0, 1.0)
		)
	_smooth_mouse = _smooth_mouse.lerp(target_mouse, clampf(delta * 4.0, 0.0, 1.0))

	var breath_x := sin(_time_acc * 0.42) * 0.10
	var breath_y := cos(_time_acc * 0.58) * 0.06
	_cam.position = _base_cam_pos + Vector3(
		breath_x + _smooth_mouse.x * 0.28,
		breath_y - _smooth_mouse.y * 0.12,
		sin(_time_acc * 0.28) * 0.08
	)
	_cam.look_at(_look_target + Vector3(_smooth_mouse.x * 0.18, -_smooth_mouse.y * 0.08, 0.0), Vector3.UP)
