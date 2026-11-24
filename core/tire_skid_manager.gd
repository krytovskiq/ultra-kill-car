class_name TireSkidManager
extends Node3D

## Менеджер следов шин (дрифт, жёсткое торможение, занос на гололёде и бёрнаут).
## Использует кольцевой буфер квадов в одном ArrayMesh (минимум draw call'ов).

const MAX_SEGMENTS: int = 900
const MIN_STEP_DIST_SQ: float = 0.14 * 0.14
const MAX_STEP_DIST_SQ: float = 4.5 * 4.5
const BURNOUT_STAMP_INTERVAL_MS: int = 90
const TRAIL_TIMEOUT_MS: int = 320
const MESH_REBUILD_INTERVAL_MS: int = 45

var _mesh_inst: MeshInstance3D = null
var _mesh: ArrayMesh = null
var _mat: StandardMaterial3D = null
var _tread_tex: ImageTexture = null
var _last_rebuild_ms: int = 0

var _verts: PackedVector3Array = PackedVector3Array()
var _normals: PackedVector3Array = PackedVector3Array()
var _uvs: PackedVector2Array = PackedVector2Array()
var _colors: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()

var _write_idx: int = 0
var _active_count: int = 0
var _total_emitted: int = 0
var _dirty: bool = false
var _wheel_states: Dictionary = {}


func _ready() -> void:
	name = "TireSkidManager"
	_init_buffers()
	_tread_tex = _build_tread_texture()

	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = _tread_tex
	_mat.albedo_color = Color.WHITE
	_mat.vertex_color_use_as_albedo = true
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat.roughness = 0.90
	_mat.metallic = 0.02
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mat.no_depth_test = false

	_mesh = ArrayMesh.new()
	_mesh_inst = MeshInstance3D.new()
	_mesh_inst.name = "SkidMesh"
	_mesh_inst.mesh = _mesh
	_mesh_inst.material_override = _mat
	_mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Огромный AABB предотвращает преждевременную отсечку по фрустуму при езде вперёд по шоссе
	_mesh_inst.custom_aabb = AABB(Vector3(-50000.0, -500.0, -50000.0), Vector3(100000.0, 1000.0, 100000.0))
	add_child(_mesh_inst)


func _init_buffers() -> void:
	var v_count := MAX_SEGMENTS * 4
	var i_count := MAX_SEGMENTS * 6
	_verts.resize(v_count)
	_normals.resize(v_count)
	_uvs.resize(v_count)
	_colors.resize(v_count)
	_indices.resize(i_count)
	for s in range(MAX_SEGMENTS):
		var vb := s * 4
		var ib := s * 6
		_verts[vb + 0] = Vector3.ZERO
		_verts[vb + 1] = Vector3.ZERO
		_verts[vb + 2] = Vector3.ZERO
		_verts[vb + 3] = Vector3.ZERO
		_normals[vb + 0] = Vector3.UP
		_normals[vb + 1] = Vector3.UP
		_normals[vb + 2] = Vector3.UP
		_normals[vb + 3] = Vector3.UP
		_colors[vb + 0] = Color(0.0, 0.0, 0.0, 0.0)
		_colors[vb + 1] = Color(0.0, 0.0, 0.0, 0.0)
		_colors[vb + 2] = Color(0.0, 0.0, 0.0, 0.0)
		_colors[vb + 3] = Color(0.0, 0.0, 0.0, 0.0)
		_indices[ib + 0] = vb + 0
		_indices[ib + 1] = vb + 1
		_indices[ib + 2] = vb + 2
		_indices[ib + 3] = vb + 0
		_indices[ib + 4] = vb + 2
		_indices[ib + 5] = vb + 3


func _build_tread_texture() -> ImageTexture:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var v := float(y) / float(sz - 1)
		for x in range(sz):
			var u := float(x) / float(sz - 1)
			var edge_dist := absf(u - 0.5) * 2.0
			var edge_fade := 1.0 - smoothstep(0.68, 1.0, edge_dist)

			# Продольные водоотводные канавки + боковой шеврон протектора
			var groove1 := smoothstep(0.04, 0.11, absf(u - 0.34))
			var groove2 := smoothstep(0.04, 0.11, absf(u - 0.66))
			var center_groove := smoothstep(0.02, 0.06, absf(u - 0.50))
			var chevron_phase := fposmod(v * 6.0 + absf(u - 0.5) * 2.2, 1.0)
			var lug := 0.72 + 0.28 * smoothstep(0.18, 0.42, chevron_phase)

			var noise_seed := sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453
			var grain := 0.86 + 0.14 * (noise_seed - floorf(noise_seed))

			var tread_alpha := edge_fade * groove1 * groove2 * (0.65 + 0.35 * center_groove) * lug * grain
			var darkness := 0.90 + 0.10 * grain
			img.set_pixel(x, y, Color(darkness, darkness, darkness, clampf(tread_alpha, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	if not _dirty or _mesh == null:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_rebuild_ms < MESH_REBUILD_INTERVAL_MS:
		return
	_last_rebuild_ms = now_ms
	_dirty = false
	_rebuild_mesh()


func _rebuild_mesh() -> void:
	_mesh.clear_surfaces()
	if _active_count <= 0:
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func emit_wheel_mark(
	wheel_id: int,
	contact_pos: Vector3,
	normal: Vector3,
	fwd_dir: Vector3,
	width: float,
	intensity: float,
	mark_color: Color = Color(0.035, 0.035, 0.04, 0.86)
) -> void:
	if intensity <= 0.04:
		break_wheel_trail(wheel_id)
		return

	var nrm := normal.normalized() if normal.length_squared() > 0.01 else Vector3.UP
	var fwd := fwd_dir - nrm * fwd_dir.dot(nrm)
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	else:
		fwd = fwd.normalized()

	var right_dir := fwd.cross(nrm).normalized()
	if right_dir.length_squared() < 0.001:
		right_dir = Vector3.RIGHT
	var half_w := clampf(width, 0.16, 0.62) * 0.5
	var pos := contact_pos + nrm * 0.024
	var now_ms := Time.get_ticks_msec()

	var target_alpha := clampf(mark_color.a * intensity, 0.08, 0.92)
	var col := Color(mark_color.r, mark_color.g, mark_color.b, target_alpha)

	if not _wheel_states.has(wheel_id):
		# Начинаем след с короткого контакта-пятна (особенно важно для старта бёрнаута)
		var start_p := pos - fwd * 0.24
		var end_p := pos + fwd * 0.10
		_push_quad(
			start_p - right_dir * half_w,
			start_p + right_dir * half_w,
			end_p + right_dir * half_w,
			end_p - right_dir * half_w,
			nrm,
			0.0,
			0.45,
			Color(col.r, col.g, col.b, col.a * 0.55),
			col
		)
		_wheel_states[wheel_id] = {
			"pos": pos,
			"right": right_dir * half_w,
			"nrm": nrm,
			"col": col,
			"u_coord": 0.45,
			"last_ms": now_ms,
			"last_stamp_ms": now_ms,
		}
		return

	var st: Dictionary = _wheel_states[wheel_id]
	var prev_pos: Vector3 = st["pos"]
	var dist_sq := prev_pos.distance_squared_to(pos)

	if (now_ms - int(st["last_ms"])) > TRAIL_TIMEOUT_MS or dist_sq > MAX_STEP_DIST_SQ:
		_wheel_states.erase(wheel_id)
		emit_wheel_mark(wheel_id, contact_pos, normal, fwd_dir, width, intensity, mark_color)
		return

	if dist_sq < MIN_STEP_DIST_SQ:
		# Колесо почти на месте (бёрнаут перед стартом) — оставляем густой резиновый след под шиной
		if (now_ms - int(st["last_stamp_ms"])) >= BURNOUT_STAMP_INTERVAL_MS:
			var jitter := (float(_total_emitted % 5) - 2.0) * 0.015
			var stamp_start := pos - fwd * 0.30 + right_dir * jitter
			var stamp_end := pos + fwd * 0.28 + right_dir * jitter
			_push_quad(
				stamp_start - right_dir * (half_w * 1.12),
				stamp_start + right_dir * (half_w * 1.12),
				stamp_end + right_dir * (half_w * 1.12),
				stamp_end - right_dir * (half_w * 1.12),
				nrm,
				0.0,
				0.9,
				Color(col.r, col.g, col.b, col.a * 0.58),
				Color(col.r, col.g, col.b, col.a * 0.72)
			)
			st["last_stamp_ms"] = now_ms
			st["last_ms"] = now_ms
		return

	var dist := sqrt(dist_sq)
	var prev_right: Vector3 = st["right"]
	var cur_right := right_dir * half_w
	var u0: float = float(st["u_coord"])
	var u1: float = u0 + dist * 0.85
	var prev_col: Color = st["col"]

	_push_quad(
		prev_pos - prev_right,
		prev_pos + prev_right,
		pos + cur_right,
		pos - cur_right,
		nrm,
		u0,
		u1,
		prev_col,
		col
	)

	st["pos"] = pos
	st["right"] = cur_right
	st["nrm"] = nrm
	st["col"] = col
	st["u_coord"] = u1
	st["last_ms"] = now_ms
	st["last_stamp_ms"] = now_ms


func break_wheel_trail(wheel_id: int) -> void:
	_wheel_states.erase(wheel_id)


func clear_all() -> void:
	_wheel_states.clear()
	_write_idx = 0
	_active_count = 0
	_init_buffers()
	_dirty = true


func get_active_segment_count() -> int:
	return _active_count


func get_total_emitted() -> int:
	return _total_emitted


func _push_quad(
	p0_l: Vector3,
	p0_r: Vector3,
	p1_r: Vector3,
	p1_l: Vector3,
	nrm: Vector3,
	u0: float,
	u1: float,
	c0: Color,
	c1: Color
) -> void:
	var vb := _write_idx * 4
	_verts[vb + 0] = p0_l
	_verts[vb + 1] = p0_r
	_verts[vb + 2] = p1_r
	_verts[vb + 3] = p1_l

	_normals[vb + 0] = nrm
	_normals[vb + 1] = nrm
	_normals[vb + 2] = nrm
	_normals[vb + 3] = nrm

	_uvs[vb + 0] = Vector2(0.0, u0)
	_uvs[vb + 1] = Vector2(1.0, u0)
	_uvs[vb + 2] = Vector2(1.0, u1)
	_uvs[vb + 3] = Vector2(0.0, u1)

	_colors[vb + 0] = c0
	_colors[vb + 1] = c0
	_colors[vb + 2] = c1
	_colors[vb + 3] = c1

	_write_idx = (_write_idx + 1) % MAX_SEGMENTS
	_active_count = mini(_active_count + 1, MAX_SEGMENTS)
	_total_emitted += 1
	_dirty = true
