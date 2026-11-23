extends Node3D

## Атмосферный смерч (природное бедствие): разбрасывает близлежащие объекты,
## оставляя шанс объехать воронку; при попадании внутрь поднимает и закручивает машину,
## затем неровно выбрасывает строго вперёд по направлению трассы.

const ProceduralChunkScript = preload("res://levels/procedural_chunk.gd")
const FUNNEL_SHADER: Shader = preload("res://environment/shaders/tornado_funnel.gdshader")

var _forward: Vector3 = Vector3.BACK
var _world_seed: int = 1
var _chunk_step: float = 500.0
var _chunks_per_bridge: int = 6
var _bridge_shortfall: float = 45.0
var _time_acc: float = 0.0
var _orbit_phase: float = 0.0
var _wander_sign: float = 1.0
var _outer_funnel: MeshInstance3D = null
var _inner_funnel: MeshInstance3D = null
var _wall_cloud: MeshInstance3D = null
var _debris_mm: MultiMeshInstance3D = null
var _debris_data: Array[Dictionary] = []
var _dust_skirt: CPUParticles3D = null
var _pull_timer: float = 0.0

func setup_tornado(
	p_forward: Vector3,
	p_seed: int,
	p_chunk_step: float,
	p_chunks_per_bridge: int,
	p_bridge_shortfall: float,
	phase_seed: float = 0.0
) -> void:
	_forward = p_forward.normalized() if p_forward.length_squared() > 0.001 else Vector3.BACK
	_world_seed = p_seed
	_chunk_step = p_chunk_step
	_chunks_per_bridge = p_chunks_per_bridge
	_bridge_shortfall = p_bridge_shortfall
	_orbit_phase = phase_seed
	_wander_sign = 1.0 if int(round(phase_seed * 10.0)) % 2 == 0 else -1.0

func _ready() -> void:
	_build_visuals()

func _build_visuals() -> void:
	var smoke_tex := load("res://assets/textures/vfx/smoke_flipbook_8x8.png") as Texture2D

	var outer_mesh := _build_sculpted_funnel_mesh(4.8, 30.0, 86.0, 32, 34, 1.45, 0.14)
	var outer_mat := ShaderMaterial.new()
	outer_mat.shader = FUNNEL_SHADER
	if smoke_tex:
		outer_mat.set_shader_parameter("cloud_sheet", smoke_tex)
	outer_mat.set_shader_parameter("scroll_speed", 0.95)
	outer_mat.set_shader_parameter("twist_turns", 3.4)
	outer_mat.set_shader_parameter("fps", 14.0)
	outer_mat.set_shader_parameter("opacity", 0.62)
	outer_mat.set_shader_parameter("top_storm_color", Color(0.14, 0.15, 0.18, 1.0))
	outer_mat.set_shader_parameter("mid_cloud_color", Color(0.32, 0.34, 0.37, 1.0))
	outer_mat.set_shader_parameter("base_dust_color", Color(0.46, 0.38, 0.30, 1.0))
	outer_mat.set_shader_parameter("radial_cap", 0.0)

	_outer_funnel = MeshInstance3D.new()
	_outer_funnel.name = "OuterFunnel"
	_outer_funnel.mesh = outer_mesh
	_outer_funnel.material_override = outer_mat
	_outer_funnel.position = Vector3.ZERO
	_outer_funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_outer_funnel.visibility_range_end = 420.0
	add_child(_outer_funnel)

	var inner_mesh := _build_sculpted_funnel_mesh(2.5, 17.5, 86.0, 28, 30, 0.85, 0.18)
	var inner_mat := ShaderMaterial.new()
	inner_mat.shader = FUNNEL_SHADER
	if smoke_tex:
		inner_mat.set_shader_parameter("cloud_sheet", smoke_tex)
	inner_mat.set_shader_parameter("scroll_speed", 1.75)
	inner_mat.set_shader_parameter("twist_turns", 4.6)
	inner_mat.set_shader_parameter("fps", 16.0)
	inner_mat.set_shader_parameter("opacity", 0.90)
	inner_mat.set_shader_parameter("top_storm_color", Color(0.08, 0.09, 0.11, 1.0))
	inner_mat.set_shader_parameter("mid_cloud_color", Color(0.22, 0.24, 0.27, 1.0))
	inner_mat.set_shader_parameter("base_dust_color", Color(0.34, 0.28, 0.22, 1.0))
	inner_mat.set_shader_parameter("radial_cap", 0.0)

	_inner_funnel = MeshInstance3D.new()
	_inner_funnel.name = "InnerCore"
	_inner_funnel.mesh = inner_mesh
	_inner_funnel.material_override = inner_mat
	_inner_funnel.position = Vector3.ZERO
	_inner_funnel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_inner_funnel.visibility_range_end = 420.0
	add_child(_inner_funnel)

	var cap_mesh := _build_wall_cloud_cap_mesh()
	var cap_mat := ShaderMaterial.new()
	cap_mat.shader = FUNNEL_SHADER
	if smoke_tex:
		cap_mat.set_shader_parameter("cloud_sheet", smoke_tex)
	cap_mat.set_shader_parameter("scroll_speed", 0.42)
	cap_mat.set_shader_parameter("twist_turns", 2.1)
	cap_mat.set_shader_parameter("fps", 10.0)
	cap_mat.set_shader_parameter("opacity", 0.88)
	cap_mat.set_shader_parameter("top_storm_color", Color(0.07, 0.08, 0.10, 1.0))
	cap_mat.set_shader_parameter("mid_cloud_color", Color(0.16, 0.17, 0.20, 1.0))
	cap_mat.set_shader_parameter("base_dust_color", Color(0.16, 0.17, 0.20, 1.0))
	cap_mat.set_shader_parameter("radial_cap", 1.0)

	_wall_cloud = MeshInstance3D.new()
	_wall_cloud.name = "SupercellWallCloud"
	_wall_cloud.mesh = cap_mesh
	_wall_cloud.material_override = cap_mat
	_wall_cloud.position = Vector3.ZERO
	_wall_cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_cloud.visibility_range_end = 460.0
	add_child(_wall_cloud)

	_build_debris_multimesh()

	var skirt_tex: Texture2D = smoke_tex
	var skirt_is_flipbook: bool = (skirt_tex != null)
	if skirt_tex == null:
		var vfx := get_node_or_null("/root/CarVFX")
		skirt_tex = vfx.get("tex_smoke_puff") as Texture2D if vfx else null
	if skirt_tex:
		var qm := QuadMesh.new()
		qm.size = Vector2(5.4, 5.4)
		var dm := StandardMaterial3D.new()
		dm.vertex_color_use_as_albedo = true
		dm.vertex_color_is_srgb = true
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		dm.billboard_keep_scale = true
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.albedo_texture = skirt_tex
		if skirt_is_flipbook:
			dm.particles_anim_h_frames = 8
			dm.particles_anim_v_frames = 8
			dm.particles_anim_loop = true
		qm.material = dm

		_dust_skirt = CPUParticles3D.new()
		_dust_skirt.name = "TornadoDustSkirt"
		_dust_skirt.mesh = qm
		_dust_skirt.position = Vector3(0.0, 1.4, 0.0)
		_dust_skirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_dust_skirt.visibility_range_end = 360.0
		_dust_skirt.amount = 48
		_dust_skirt.lifetime = 1.55
		_dust_skirt.local_coords = false
		if skirt_is_flipbook:
			_dust_skirt.anim_speed_min = 0.75
			_dust_skirt.anim_speed_max = 1.35
			_dust_skirt.anim_offset_max = 1.0
		_dust_skirt.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_dust_skirt.emission_ring_axis = Vector3.UP
		_dust_skirt.emission_ring_radius = 10.5
		_dust_skirt.emission_ring_inner_radius = 2.2
		_dust_skirt.emission_ring_height = 3.2
		_dust_skirt.direction = Vector3(0.0, 1.0, 0.0)
		_dust_skirt.spread = 52.0
		_dust_skirt.gravity = Vector3(0.0, 4.8, 0.0)
		_dust_skirt.initial_velocity_min = 6.5
		_dust_skirt.initial_velocity_max = 16.5
		_dust_skirt.tangential_accel_min = 20.0
		_dust_skirt.tangential_accel_max = 32.0
		_dust_skirt.scale_amount_min = 1.6
		_dust_skirt.scale_amount_max = 3.6
		_dust_skirt.angle_max = 360.0
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.24, 0.78, 1.0])
		ramp.colors = PackedColorArray([
			Color(0.38, 0.32, 0.26, 0.0),
			Color(0.36, 0.30, 0.24, 0.68),
			Color(0.28, 0.25, 0.22, 0.42),
			Color(0.22, 0.20, 0.18, 0.0),
		])
		_dust_skirt.color_ramp = ramp
		add_child(_dust_skirt)

func _build_sculpted_funnel_mesh(r_bot: float, r_top: float, height: float, rad_segs: int, rings: int, bend_amp: float, flute_amp: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for ri in range(rings + 1):
		var t: float = float(ri) / float(rings)
		var y: float = t * height
		var flare: float = pow(t, 1.55)
		var base_r: float = lerpf(r_bot, r_top, flare)
		var bend_x: float = sin(t * 4.5) * bend_amp
		var bend_z: float = cos(t * 3.8 + 0.6) * bend_amp * 0.72
		for si in range(rad_segs + 1):
			var u: float = float(si) / float(rad_segs)
			var ang: float = u * TAU
			var rib: float = 1.0 + flute_amp * sin(ang * 5.0 + t * 9.0) * (0.25 + 0.75 * t)
			var r: float = base_r * rib
			var vx: float = bend_x + cos(ang) * r
			var vz: float = bend_z + sin(ang) * r
			verts.append(Vector3(vx, y, vz))
			uvs.append(Vector2(u, 1.0 - t))
	var stride: int = rad_segs + 1
	for ri in range(rings):
		for si in range(rad_segs):
			var i0: int = ri * stride + si
			var i1: int = i0 + 1
			var i2: int = (ri + 1) * stride + si
			var i3: int = i2 + 1
			st.set_uv(uvs[i0]); st.add_vertex(verts[i0])
			st.set_uv(uvs[i2]); st.add_vertex(verts[i2])
			st.set_uv(uvs[i1]); st.add_vertex(verts[i1])
			st.set_uv(uvs[i1]); st.add_vertex(verts[i1])
			st.set_uv(uvs[i2]); st.add_vertex(verts[i2])
			st.set_uv(uvs[i3]); st.add_vertex(verts[i3])
	st.generate_normals()
	return st.commit()

func _build_wall_cloud_cap_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rad_segs: int = 32
	var rings: int = 8
	var verts: Array[Vector3] = []
	var uvs: Array[Vector2] = []
	for ri in range(rings + 1):
		var t: float = float(ri) / float(rings)
		var base_r: float = lerpf(10.0, 72.0, pow(t, 0.85))
		var base_y: float = lerpf(74.0, 91.0, pow(t, 0.72))
		for si in range(rad_segs + 1):
			var u: float = float(si) / float(rad_segs)
			var ang: float = u * TAU
			var billow: float = sin(ang * 4.0 + t * 5.0) * 2.4 * t + cos(ang * 7.0 - t * 3.0) * 1.4
			var r: float = base_r + billow * 0.65
			var y: float = base_y + billow
			verts.append(Vector3(cos(ang) * r, y, sin(ang) * r))
			uvs.append(Vector2(u, t))
	var stride: int = rad_segs + 1
	for ri in range(rings):
		for si in range(rad_segs):
			var i0: int = ri * stride + si
			var i1: int = i0 + 1
			var i2: int = (ri + 1) * stride + si
			var i3: int = i2 + 1
			st.set_uv(uvs[i0]); st.add_vertex(verts[i0])
			st.set_uv(uvs[i1]); st.add_vertex(verts[i1])
			st.set_uv(uvs[i2]); st.add_vertex(verts[i2])
			st.set_uv(uvs[i1]); st.add_vertex(verts[i1])
			st.set_uv(uvs[i3]); st.add_vertex(verts[i3])
			st.set_uv(uvs[i2]); st.add_vertex(verts[i2])
	st.generate_normals()
	return st.commit()

func _build_debris_multimesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [
		Vector3(-0.48, -0.18, -0.32), Vector3(0.52, -0.22, -0.26),
		Vector3(0.42, 0.20, -0.30), Vector3(-0.38, 0.24, -0.22),
		Vector3(-0.42, -0.20, 0.34), Vector3(0.46, -0.14, 0.28),
		Vector3(0.54, 0.22, 0.24), Vector3(-0.44, 0.16, 0.32)
	]
	var faces := [[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7], [1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]]
	for f in faces:
		st.add_vertex(pts[f[0]]); st.add_vertex(pts[f[1]]); st.add_vertex(pts[f[2]])
		st.add_vertex(pts[f[0]]); st.add_vertex(pts[f[2]]); st.add_vertex(pts[f[3]])
	st.generate_normals()
	var chunk_mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.28, 1.0)
	mat.roughness = 0.86
	chunk_mesh.surface_set_material(0, mat)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = chunk_mesh
	var count: int = 48
	mm.instance_count = count

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_orbit_phase) ^ 7193
	_debris_data.clear()
	for i in range(count):
		var h: float = rng.randf_range(1.5, 52.0)
		var t_h: float = h / 86.0
		var r_base: float = lerpf(6.5, 26.0, pow(t_h, 1.15)) + rng.randf_range(-1.8, 3.2)
		_debris_data.append({
			"angle": rng.randf_range(0.0, TAU),
			"radius": r_base,
			"height": h,
			"ang_vel": rng.randf_range(2.6, 5.8),
			"tumble_x": rng.randf_range(1.5, 4.5),
			"tumble_z": rng.randf_range(1.5, 4.5),
			"scale": Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.5, 1.4), rng.randf_range(0.8, 2.1)),
			"phase": rng.randf_range(0.0, TAU),
		})

	_debris_mm = MultiMeshInstance3D.new()
	_debris_mm.name = "TornadoOrbitingDebris"
	_debris_mm.multimesh = mm
	_debris_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris_mm.visibility_range_end = 360.0
	add_child(_debris_mm)
	_update_debris(0.0)

func _update_debris(delta: float) -> void:
	if not is_instance_valid(_debris_mm) or _debris_mm.multimesh == null:
		return
	var mm := _debris_mm.multimesh
	for i in range(_debris_data.size()):
		var d: Dictionary = _debris_data[i]
		var ang: float = float(d["angle"]) + float(d["ang_vel"]) * delta
		d["angle"] = ang
		var r: float = float(d["radius"])
		var h: float = float(d["height"]) + sin(_time_acc * 1.8 + float(d["phase"])) * 1.4
		var b := Basis.from_euler(Vector3(_time_acc * float(d["tumble_x"]), ang, _time_acc * float(d["tumble_z"])))
		b = b.scaled(d["scale"] as Vector3)
		var origin := Vector3(cos(ang) * r, h, sin(ang) * r)
		mm.set_instance_transform(i, Transform3D(b, origin))

func _physics_process(delta: float) -> void:
	_time_acc += delta
	if is_instance_valid(_outer_funnel):
		_outer_funnel.rotation.y += delta * 2.8
	if is_instance_valid(_inner_funnel):
		_inner_funnel.rotation.y -= delta * 5.2
	if is_instance_valid(_wall_cloud):
		_wall_cloud.rotation.y += delta * 0.45
	_update_debris(delta)

	# Медленное смещение смерча по шоссе с волнообразным ходом поперёк полос (игрок видит издалека и может объехать)
	global_position += _forward * (8.5 * delta)
	var road_cx: float = ProceduralChunkScript.sample_road_center_x(global_position.z, _world_seed, _chunk_step, _chunks_per_bridge, _bridge_shortfall)
	var target_x: float = road_cx + sin(_time_acc * 0.44 + _orbit_phase) * 24.0 * _wander_sign
	global_position.x = lerpf(global_position.x, target_x, clampf(delta * 1.4, 0.0, 1.0))

	var tree := get_tree()
	if tree == null:
		return

	# Проверяем захват игрока только в пределах радиуса воронки
	var player := tree.get_first_node_in_group("player") as RigidBody3D
	if is_instance_valid(player):
		var dx: float = player.global_position.x - global_position.x
		var dz: float = player.global_position.z - global_position.z
		if (dx * dx + dz * dz) <= 11.5 * 11.5 and player.has_method("enter_tornado_capture"):
			player.call("enter_tornado_capture", global_position, _forward)

	_pull_timer += delta
	if _pull_timer < 0.08:
		return
	var step_dt: float = _pull_timer
	_pull_timer = 0.0

	var v_pos := global_position
	var pull_r_sq := 26.0 * 26.0
	for p_node in tree.get_nodes_in_group("knockable_prop"):
		if not (p_node is RigidBody3D):
			continue
		var rb := p_node as RigidBody3D
		if not is_instance_valid(rb):
			continue
		var to_v := v_pos - rb.global_position
		var h_sq := to_v.x * to_v.x + to_v.z * to_v.z
		if h_sq > pull_r_sq or rb.global_position.y > 42.0:
			continue
		rb.freeze = false
		rb.sleeping = false
		var dist: float = sqrt(maxf(h_sq, 0.5))
		var in_dir := Vector3(to_v.x, 0.0, to_v.z) / dist
		var tang_dir := Vector3(-in_dir.z, 0.0, in_dir.x)
		var falloff: float = clampf(1.0 - dist / 26.0, 0.18, 1.0)
		var force_vec := (tang_dir * 42.0 + in_dir * 18.0 + Vector3.UP * 36.0) * rb.mass * falloff
		rb.apply_central_force(force_vec)
		rb.angular_velocity += Vector3(randf_range(-4.0, 4.0), 8.0, randf_range(-4.0, 4.0)) * step_dt

	for z_node in ZombiePool.get_nearby_zombies(v_pos):
		if not is_instance_valid(z_node):
			continue
		var z_state = z_node.get("state")
		if z_state != null and int(z_state) == 3:
			continue
		var to_z := z_node.global_position - v_pos
		if (to_z.x * to_z.x + to_z.z * to_z.z) <= 18.0 * 18.0 and z_node.has_method("die"):
			var tang := Vector3(-to_z.z, 0.0, to_z.x).normalized()
			z_node.call("die", tang * 22.0 + Vector3.UP * 14.0, 24.0)
