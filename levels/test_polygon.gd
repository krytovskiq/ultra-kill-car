extends Node3D

const FONT_RUSSO: FontFile = preload("res://assets/fonts/RussoOne-Regular.ttf")
const FONT_JURA: FontFile = preload("res://assets/fonts/Jura-Variable.ttf")

const COLLISION_LAYER_GROUND: int = 513 # Слой 1 (1) + Слой 10 (512) для RaycastWheel и кузова

const SPAWN_POS := Vector3(0.0, 0.10, 0.0)
const ICE_RECT := Rect2(38.0, -135.0, 22.0, 115.0)

var _world_env: WorldEnvironment = null
var _sun_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null
var _arena_root: Node3D = null
var _phys_mat_ground: PhysicsMaterial = null
var _phys_mat_ice: PhysicsMaterial = null

var _mat_grid_floor: StandardMaterial3D = null
var _mat_grid_obstacle: StandardMaterial3D = null
var _mat_grid_ramp: StandardMaterial3D = null
var _mat_accent_orange: StandardMaterial3D = null
var _mat_grid_ice: StandardMaterial3D = null

var _orbit_cam: Camera3D = null
var _cam_yaw_offset: float = 0.0
var _cam_pitch_deg: float = 16.0
var _cam_dist: float = 5.4
var _cam_target_dist: float = 5.4
var _cam_follow_heading: bool = true
var _cam_free_mouse: bool = false
var _cam_dragging: bool = false
var _cam_focus_pos: Vector3 = Vector3(0.0, 1.0, 0.0)
var _cam_Mouse_Sens: float = 0.24

var _active_car: RigidBody3D = null
var _current_car_idx: int = 0
var _kit_mode: int = 0 # 0 = Как в гараже, 1 = Полный обвес 3/3, 2 = Сток 0/3

var _ui_layer: CanvasLayer = null
var _lbl_car_title: Label = null
var _btn_kit_mode: Button = null
var _btn_cam_mode: Button = null
var _btn_free_mouse: Button = null
var _lbl_telemetry: Label = null
var _wheel_bars: Array[ProgressBar] = []
var _wheel_pct_labels: Array[Label] = []

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var g: Node = get_node_or_null("/root/Game")
	if g != null:
		var data_v: Variant = g.get("car_data")
		if data_v is Array and not (data_v as Array).is_empty():
			_current_car_idx = clampi(int(g.get("selected_car_index")), 0, (data_v as Array).size() - 1)

	_init_materials()
	_setup_environment()
	_build_test_arena()
	_setup_orbit_camera()
	_build_polygon_hud()
	_spawn_vehicle(_current_car_idx, SPAWN_POS, 0.0)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Метод, который опрашивает vehicle_base.gd для проверки покрытия под машиной
func get_surface_grip_profile(world_pos: Vector3) -> Dictionary:
	var p2 := Vector2(world_pos.x, world_pos.z)
	if ICE_RECT.has_point(p2):
		return {
			"is_ice": true,
			"grip_scale": 0.52,
			"brake_scale": 0.44,
			"yaw_assist_scale": 0.60,
		}
	return {
		"is_ice": false,
		"grip_scale": 1.0,
		"brake_scale": 1.0,
		"yaw_assist_scale": 1.0,
	}

func _init_materials() -> void:
	_phys_mat_ground = PhysicsMaterial.new()
	_phys_mat_ground.friction = 1.0
	_phys_mat_ground.bounce = 0.0

	_phys_mat_ice = PhysicsMaterial.new()
	_phys_mat_ice.friction = 0.45
	_phys_mat_ice.bounce = 0.0

	var tex_floor := _create_beamng_grid_texture(
		Color(0.26, 0.28, 0.31),
		Color(0.22, 0.24, 0.27),
		Color(0.14, 0.16, 0.18),
		Color(0.50, 0.54, 0.58)
	)
	_mat_grid_floor = StandardMaterial3D.new()
	_mat_grid_floor.albedo_texture = tex_floor
	_mat_grid_floor.roughness = 0.88
	_mat_grid_floor.metallic = 0.02
	_mat_grid_floor.uv1_triplanar = true
	_mat_grid_floor.uv1_world_triplanar = true
	_mat_grid_floor.uv1_scale = Vector3(0.2, 0.2, 0.2) # 1 повтор текстуры = 5 метров (сетка 1м + 5м)

	var tex_obs := _create_beamng_grid_texture(
		Color(0.19, 0.21, 0.24),
		Color(0.16, 0.18, 0.21),
		Color(0.10, 0.11, 0.13),
		Color(0.88, 0.48, 0.14)
	)
	_mat_grid_obstacle = StandardMaterial3D.new()
	_mat_grid_obstacle.albedo_texture = tex_obs
	_mat_grid_obstacle.roughness = 0.82
	_mat_grid_obstacle.metallic = 0.05
	_mat_grid_obstacle.uv1_triplanar = true
	_mat_grid_obstacle.uv1_world_triplanar = true
	_mat_grid_obstacle.uv1_scale = Vector3(0.2, 0.2, 0.2)

	var tex_ramp := _create_beamng_grid_texture(
		Color(0.23, 0.25, 0.29),
		Color(0.20, 0.22, 0.25),
		Color(0.12, 0.14, 0.16),
		Color(0.92, 0.62, 0.16)
	)
	_mat_grid_ramp = StandardMaterial3D.new()
	_mat_grid_ramp.albedo_texture = tex_ramp
	_mat_grid_ramp.roughness = 0.80
	_mat_grid_ramp.metallic = 0.06
	_mat_grid_ramp.uv1_triplanar = true
	_mat_grid_ramp.uv1_world_triplanar = true
	_mat_grid_ramp.uv1_scale = Vector3(0.2, 0.2, 0.2)

	var tex_ice := _create_beamng_grid_texture(
		Color(0.34, 0.46, 0.58),
		Color(0.30, 0.41, 0.52),
		Color(0.22, 0.32, 0.42),
		Color(0.62, 0.78, 0.92)
	)
	_mat_grid_ice = StandardMaterial3D.new()
	_mat_grid_ice.albedo_texture = tex_ice
	_mat_grid_ice.roughness = 0.22
	_mat_grid_ice.metallic = 0.08
	_mat_grid_ice.uv1_triplanar = true
	_mat_grid_ice.uv1_world_triplanar = true
	_mat_grid_ice.uv1_scale = Vector3(0.2, 0.2, 0.2)

	_mat_accent_orange = StandardMaterial3D.new()
	_mat_accent_orange.albedo_color = Color(0.84, 0.40, 0.10)
	_mat_accent_orange.roughness = 0.65

func _create_beamng_grid_texture(c_tile_a: Color, c_tile_b: Color, c_sub_line: Color, c_major_line: Color) -> ImageTexture:
	# 250x250 пикселей на квадрат 5x5 метров (50 пикселей = 1 метр)
	var size: int = 250
	var sub: int = 50
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	for y in range(size):
		var ty: int = int(float(y) / float(sub))
		var my: int = y % sub
		for x in range(size):
			var tx: int = int(float(x) / float(sub))
			var mx: int = x % sub
			var col: Color = c_tile_a if ((tx + ty) % 2 == 0) else c_tile_b
			if mx == 0 or my == 0 or mx == sub - 1 or my == sub - 1:
				col = col.lerp(c_sub_line, 0.82)
			if x <= 2 or y <= 2 or x >= size - 2 or y >= size - 2:
				col = c_major_line
			img.set_pixel(x, y, col)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _setup_environment() -> void:
	_world_env = WorldEnvironment.new()
	_world_env.name = "PolygonEnvironment"
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.38, 0.48, 0.60)
	sky_mat.sky_horizon_color = Color(0.62, 0.66, 0.72)
	sky_mat.ground_horizon_color = Color(0.48, 0.52, 0.56)
	sky_mat.ground_bottom_color = Color(0.28, 0.30, 0.33)
	sky_mat.sun_angle_max = 26.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.70, 0.74, 0.79)
	env.ambient_light_energy = 0.56
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.88
	env.fog_enabled = true
	env.fog_light_color = Color(0.58, 0.63, 0.69)
	env.fog_density = 0.0011
	env.fog_sky_affect = 0.20
	_world_env.environment = env
	add_child(_world_env)

	_sun_light = DirectionalLight3D.new()
	_sun_light.name = "SunLight"
	_sun_light.light_color = Color(1.0, 0.97, 0.92)
	_sun_light.light_energy = 0.78
	_sun_light.shadow_enabled = true
	_sun_light.directional_shadow_max_distance = 140.0
	_sun_light.rotation_degrees = Vector3(-48.0, 36.0, 0.0)
	add_child(_sun_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.name = "FillLight"
	_fill_light.light_color = Color(0.72, 0.80, 0.92)
	_fill_light.light_energy = 0.22
	_fill_light.shadow_enabled = false
	_fill_light.rotation_degrees = Vector3(-32.0, -142.0, 0.0)
	add_child(_fill_light)

func _build_test_arena() -> void:
	_arena_root = Node3D.new()
	_arena_root.name = "TestArena"
	add_child(_arena_root)

	# 1. Огромный серый пол в стиле BeamNG GridMap (700 x 700 м)
	_add_static_box("MainFloor", Vector3(0.0, -0.5, -40.0), Vector3(700.0, 1.0, 700.0), Vector3.ZERO, _mat_grid_floor)

	# Бортики по периметру полигона
	_add_static_box("WallNorth", Vector3(0.0, 2.0, -385.0), Vector3(700.0, 4.0, 2.0), Vector3.ZERO, _mat_grid_obstacle)
	_add_static_box("WallSouth", Vector3(0.0, 2.0, 305.0), Vector3(700.0, 4.0, 2.0), Vector3.ZERO, _mat_grid_obstacle)
	_add_static_box("WallWest", Vector3(-345.0, 2.0, -40.0), Vector3(2.0, 4.0, 700.0), Vector3.ZERO, _mat_grid_obstacle)
	_add_static_box("WallEast", Vector3(345.0, 2.0, -40.0), Vector3(2.0, 4.0, 700.0), Vector3.ZERO, _mat_grid_obstacle)

	# Стартовая рамка-ориентир
	_add_static_box("StartMarkerL", Vector3(-3.2, 0.03, 0.0), Vector3(0.35, 0.06, 6.5), Vector3.ZERO, _mat_accent_orange)
	_add_static_box("StartMarkerR", Vector3(3.2, 0.03, 0.0), Vector3(0.35, 0.06, 6.5), Vector3.ZERO, _mat_accent_orange)
	_add_zone_sign("СТАРТОВАЯ ПЛОЩАДКА // BEAMNG ТЕСТ ПОДВЕСКИ", Vector3(0.0, 3.8, -9.0), Color(0.98, 0.76, 0.30))

	# =========================================================================
	# ДОРОЖКА 1 (X = -22): ГРЕБЁНКА И ПРОГРЕССИВНЫЕ КОЧКИ (Speed Bumps & Washboard)
	# =========================================================================
	_add_zone_sign("1. ГРЕБЁНКА И КОЧКИ\n(Сжатие / Отбой / Пробой)", Vector3(-22.0, 3.3, -17.0), Color(0.95, 0.62, 0.24))
	_add_lane_borders(-22.0, 6.4, -18.0, -118.0)

	# Мелкая частая гребёнка (14 рёбер, высота 0.07..0.09 м)
	for i in range(14):
		var z_pos: float = -22.0 - float(i) * 2.1
		var h: float = 0.075 if (i % 2 == 0) else 0.095
		_add_chamfered_bump("Washboard_%d" % i, Vector3(-22.0, 0.0, z_pos), 5.6, h, 0.72, _mat_grid_obstacle)

	# Крупные кочки прогрессивной высоты (0.12 м .. 0.26 м)
	for i in range(8):
		var z_pos: float = -58.0 - float(i) * 6.8
		var h: float = 0.12 + float(i) * 0.02
		_add_chamfered_bump("BigBump_%d" % i, Vector3(-22.0, 0.0, z_pos), 5.6, h, 1.45, _mat_grid_obstacle)

	# =========================================================================
	# ДОРОЖКА 2 (X = -7.5): АРТИКУЛЯЦИЯ И ШАХМАТНЫЕ КОЧКИ (Диагональное вывешивание)
	# =========================================================================
	_add_zone_sign("2. ШАХМАТНЫЕ КОЧКИ\n(Крен / Стабилизатор / Артикуляция)", Vector3(-7.5, 3.3, -17.0), Color(0.95, 0.62, 0.24))
	_add_lane_borders(-7.5, 6.4, -18.0, -118.0)

	for i in range(14):
		var side: float = -1.35 if (i % 2 == 0) else 1.35
		var z_pos: float = -23.0 - float(i) * 6.2
		var h: float = 0.20 + float(i % 4) * 0.035
		_add_chamfered_bump("ArticMogul_%d" % i, Vector3(-7.5 + side, 0.0, z_pos), 2.55, h, 3.2, _mat_grid_obstacle)

	# =========================================================================
	# ДОРОЖКА 3 (X = +7.5): ПЛАВНЫЕ ВОЛНЫ ПОДВЕСКИ (Раскачка / Клевок / Приседание)
	# =========================================================================
	_add_zone_sign("3. ВОЛНЫ ПОДВЕСКИ\n(Плавная раскачка на скорости)", Vector3(7.5, 3.3, -17.0), Color(0.95, 0.62, 0.24))
	_add_lane_borders(7.5, 6.4, -18.0, -126.0)

	for i in range(8):
		var z_pos: float = -25.0 - float(i) * 11.5
		var h: float = 0.34 + float(i % 3) * 0.08
		_add_chamfered_bump("WaveRoller_%d" % i, Vector3(7.5, 0.0, z_pos), 5.8, h, 5.4, _mat_grid_ramp)

	# =========================================================================
	# ДОРОЖКА 4 (X = +25): 3 ТРАМПЛИНА (12°, 19°, 26°) + СТОЛЫ ПРИЗЕМЛЕНИЯ
	# =========================================================================
	_add_zone_sign("4. ТРАМПЛИНЫ (12° / 19° / 26°)\n(Баланс в полёте и приземление)", Vector3(25.0, 3.6, -17.0), Color(0.98, 0.72, 0.22))
	_build_jump_ramp("JumpLow", Vector3(19.0, 0.0, -34.0), 4.6, 8.5, 12.0, 18.0)
	_build_jump_ramp("JumpMed", Vector3(25.0, 0.0, -34.0), 4.6, 10.0, 19.0, 24.0)
	_build_jump_ramp("JumpHigh", Vector3(31.0, 0.0, -34.0), 4.6, 11.5, 25.0, 30.0)

	# =========================================================================
	# ЗОНА 5 (X = -42): БОКОВОЙ УКЛОН 18° И ЗМЕЙКА (Тест центра тяжести и рулёжки)
	# =========================================================================
	_add_zone_sign("5. БОКОВОЙ УКЛОН 18° И ЗМЕЙКА\n(Центр тяжести и управляемость)", Vector3(-42.0, 3.5, -17.0), Color(0.48, 0.86, 0.98))
	# Продольный наклонный пандус для езды одним боком выше другого
	_add_static_box("SideSlopeEntry", Vector3(-39.0, 0.25, -24.0), Vector3(6.5, 0.9, 8.0), Vector3(8.0, 0.0, 0.0), _mat_grid_ramp)
	_add_static_box("SideSlopeBank", Vector3(-39.0, 0.72, -55.0), Vector3(7.2, 1.2, 56.0), Vector3(0.0, 0.0, -18.0), _mat_grid_ramp)

	# Колонны для змейки (слалома) на X = -52
	for i in range(8):
		var z_pos: float = -24.0 - float(i) * 13.5
		_add_static_box("SlalomPillar_%d" % i, Vector3(-52.0, 1.1, z_pos), Vector3(0.85, 2.2, 0.85), Vector3.ZERO, _mat_accent_orange)

	# =========================================================================
	# ЗОНА 6 (X = +49): ЛЕДЯНАЯ ПОЛОСА (Тест заноса, сцепления и торможения)
	# =========================================================================
	_add_zone_sign("6. ЛЕДЯНАЯ ПОЛОСА\n(Тест заноса, ручника и тормозов)", Vector3(49.0, 3.5, -17.0), Color(0.55, 0.88, 1.0))
	var ice_center := Vector3(ICE_RECT.position.x + ICE_RECT.size.x * 0.5, 0.015, ICE_RECT.position.y + ICE_RECT.size.y * 0.5)
	_add_static_box("IcePatch", ice_center, Vector3(ICE_RECT.size.x, 0.03, ICE_RECT.size.y), Vector3.ZERO, _mat_grid_ice, _phys_mat_ice)

func _add_lane_borders(center_x: float, width: float, z_start: float, z_end: float) -> void:
	var length: float = absf(z_end - z_start)
	var mid_z: float = (z_start + z_end) * 0.5
	var half_w: float = width * 0.5
	_add_static_box("LaneBorderL_%s" % str(roundi(center_x)), Vector3(center_x - half_w, 0.025, mid_z), Vector3(0.18, 0.05, length), Vector3.ZERO, _mat_accent_orange)
	_add_static_box("LaneBorderR_%s" % str(roundi(center_x)), Vector3(center_x + half_w, 0.025, mid_z), Vector3(0.18, 0.05, length), Vector3.ZERO, _mat_accent_orange)

func _add_chamfered_bump(node_name: String, center_ground: Vector3, width: float, height: float, total_len: float, mat: Material) -> void:
	# Строим плавную 3-секционную кочку (заезд + вершина + съезд), чтобы колёса RaycastWheel отрабатывали реалистично без застревания
	var slope_len: float = total_len * 0.44
	var flat_len: float = total_len * 0.34
	var angle_rad: float = atan2(height, slope_len)
	var angle_deg: float = rad_to_deg(angle_rad)
	var hyp: float = sqrt(slope_len * slope_len + height * height)
	var thickness: float = maxf(height * 1.35, 0.24)

	# Заезд (смотрит к +Z, поднимается к -Z)
	var entry_z: float = center_ground.z + (flat_len * 0.5 + slope_len * 0.45)
	var entry_y: float = height * 0.5 - (thickness * 0.5) * cos(angle_rad)
	_add_static_box(
		node_name + "_Up",
		Vector3(center_ground.x, entry_y, entry_z),
		Vector3(width, thickness, hyp),
		Vector3(angle_deg, 0.0, 0.0),
		mat
	)
	# Центральная полка
	_add_static_box(
		node_name + "_Top",
		Vector3(center_ground.x, height * 0.5, center_ground.z),
		Vector3(width, height, flat_len),
		Vector3.ZERO,
		mat
	)
	# Съезд (спускается дальше к -Z)
	var exit_z: float = center_ground.z - (flat_len * 0.5 + slope_len * 0.45)
	_add_static_box(
		node_name + "_Down",
		Vector3(center_ground.x, entry_y, exit_z),
		Vector3(width, thickness, hyp),
		Vector3(-angle_deg, 0.0, 0.0),
		mat
	)

func _build_jump_ramp(base_name: String, start_pos: Vector3, width: float, ramp_len: float, angle_deg: float, gap_len: float) -> void:
	var ang_rad: float = deg_to_rad(angle_deg)
	var peak_h: float = sin(ang_rad) * ramp_len
	var horiz_len: float = cos(ang_rad) * ramp_len
	var thickness: float = 0.85

	# Плавный клин заезда на трамплин
	_add_chamfered_bump(base_name + "_LeadIn", Vector3(start_pos.x, 0.0, start_pos.z + 1.2), width, 0.16, 2.6, _mat_grid_ramp)

	# Наклонный взлётный трамплин
	var ramp_center := Vector3(
		start_pos.x,
		peak_h * 0.5 - (thickness * 0.5) * cos(ang_rad),
		start_pos.z - horiz_len * 0.5
	)
	_add_static_box(base_name + "_Launch", ramp_center, Vector3(width, thickness, ramp_len), Vector3(angle_deg, 0.0, 0.0), _mat_grid_ramp)

	# Опорная тумба под кромкой отрыва
	var deck_len: float = 2.4
	var deck_z: float = start_pos.z - horiz_len - deck_len * 0.5 + 0.15
	_add_static_box(base_name + "_Lip", Vector3(start_pos.x, peak_h * 0.5, deck_z), Vector3(width, peak_h, deck_len), Vector3.ZERO, _mat_grid_obstacle)

	# Приёмный стол приземления через gap_len метров
	var land_start_z: float = deck_z - deck_len * 0.5 - gap_len
	var land_table_len: float = 6.0
	var land_h: float = maxf(peak_h * 0.82, 0.85)
	_add_static_box(
		base_name + "_LandTable",
		Vector3(start_pos.x, land_h * 0.5, land_start_z - land_table_len * 0.5),
		Vector3(width + 1.2, land_h, land_table_len),
		Vector3.ZERO,
		_mat_grid_obstacle
	)

	var down_ang_deg: float = maxf(angle_deg * 0.65, 10.0)
	var down_rad: float = deg_to_rad(down_ang_deg)
	var down_len: float = land_h / maxf(sin(down_rad), 0.12)
	var down_horiz: float = cos(down_rad) * down_len
	var down_z: float = land_start_z - land_table_len - down_horiz * 0.5 + 0.2
	_add_static_box(
		base_name + "_LandSlope",
		Vector3(start_pos.x, land_h * 0.5 - (thickness * 0.5) * cos(down_rad), down_z),
		Vector3(width + 1.2, thickness, down_len),
		Vector3(-down_ang_deg, 0.0, 0.0),
		_mat_grid_ramp
	)

func _add_static_box(
	node_name: String,
	pos: Vector3,
	size: Vector3,
	rot_deg: Vector3,
	mat: Material,
	phys_mat: PhysicsMaterial = null
) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.name = node_name
	sb.collision_layer = COLLISION_LAYER_GROUND
	sb.collision_mask = 0
	sb.physics_material_override = phys_mat if phys_mat != null else _phys_mat_ground
	sb.position = pos
	sb.rotation_degrees = rot_deg

	var col := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	col.shape = box_shape
	sb.add_child(col)

	var mi := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mi.mesh = box_mesh
	mi.material_override = mat
	sb.add_child(mi)

	_arena_root.add_child(sb)
	return sb

func _add_zone_sign(title_text: String, pos: Vector3, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.position = pos
	lbl.text = title_text
	lbl.font = FONT_RUSSO
	lbl.font_size = 54
	lbl.outline_size = 14
	lbl.modulate = color
	lbl.outline_modulate = Color(0.06, 0.07, 0.09, 0.95)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	_arena_root.add_child(lbl)

func _setup_orbit_camera() -> void:
	_orbit_cam = Camera3D.new()
	_orbit_cam.name = "PolygonOrbitCamera"
	_orbit_cam.fov = 68.0
	_orbit_cam.near = 0.08
	_orbit_cam.far = 900.0
	_orbit_cam.current = true
	add_child(_orbit_cam)

func _spawn_vehicle(car_idx: int, spawn_pos: Vector3, yaw_rad: float = 0.0) -> void:
	var g: Node = get_node_or_null("/root/Game")
	if g == null:
		return
	var data_v: Variant = g.get("car_data")
	if not (data_v is Array) or (data_v as Array).is_empty():
		return
	var data: Array = data_v as Array
	_current_car_idx = posmod(car_idx, data.size())
	g.set("selected_car_index", _current_car_idx)

	if is_instance_valid(_active_car):
		_active_car.queue_free()
		_active_car = null

	var car_info: Dictionary = data[_current_car_idx] as Dictionary
	var car_path: String = str(car_info.get("path", ""))
	if car_path.is_empty():
		return

	var packed := load(car_path) as PackedScene
	if packed == null:
		return

	var inst := packed.instantiate() as RigidBody3D
	if inst == null:
		return

	inst.name = "TestVehicle"
	add_child(inst)
	inst.global_position = spawn_pos
	inst.global_rotation = Vector3(0.0, yaw_rad, 0.0)
	inst.linear_velocity = Vector3.ZERO
	inst.angular_velocity = Vector3.ZERO
	inst.set("_landing_cooldown", 1.5)
	_active_car = inst

	# Отключаем встроенную камеру машины ТОЛЬКО на этой тестовой карте,
	# чтобы работал наш свободный 360° обзор вокруг транспорта
	var car_cam := inst.get_node_or_null("look/Camera3D") as Camera3D
	if is_instance_valid(car_cam):
		car_cam.current = false
		car_cam.set_physics_process(false)
		car_cam.set_process(false)
	var look_pivot := inst.get_node_or_null("look")
	if is_instance_valid(look_pivot):
		look_pivot.set_physics_process(false)
		look_pivot.set_process(false)

	# Скрываем верхние рейдовые панели HUD машины (HP/Топливо/Метры рейда),
	# оставляя нижний спидометр/тахометр/передачу и меню паузы
	var panels_v: Variant = inst.get("_hud_panels")
	if panels_v is Array:
		for p_item in (panels_v as Array):
			var ctrl := p_item as Control
			if is_instance_valid(ctrl) and ctrl.name != "ApocSpeedPanel":
				ctrl.visible = false
	var car_hud := inst.get_node_or_null("Hud")
	if is_instance_valid(car_hud):
		for child in car_hud.get_children():
			if child is Control and child.name != "ApocSpeedPanel" and child.name != "Pause":
				(child as Control).visible = false

	_orbit_cam.current = true
	_cam_focus_pos = inst.global_position + Vector3(0.0, 0.85, 0.0)
	_apply_current_kit_mode()
	_update_header_labels()
	_update_orbit_camera_transform(1.0)

func _apply_current_kit_mode() -> void:
	if not is_instance_valid(_active_car):
		return
	var snd_id: String = str(_active_car.get("engine_sound_id"))
	if _kit_mode == 0:
		if _active_car.has_method("apply_car_upgrades"):
			_active_car.call("apply_car_upgrades", _current_car_idx)
	elif _kit_mode == 1:
		var full_stages: Dictionary = {
			"fuel": 3,
			"engine": 3,
			"armor": 3,
			"chassis": 3,
			"full_set": true,
		}
		CarArmorKit.apply_staged_kits(_active_car, snd_id, full_stages)
		if _active_car.has_method("refresh_armor_kit_refs"):
			_active_car.call("refresh_armor_kit_refs")
	else:
		var stock_stages: Dictionary = {
			"fuel": 0,
			"engine": 0,
			"armor": 0,
			"chassis": 0,
			"full_set": false,
		}
		CarArmorKit.apply_staged_kits(_active_car, snd_id, stock_stages)
		if _active_car.has_method("refresh_armor_kit_refs"):
			_active_car.call("refresh_armor_kit_refs")
	_update_header_labels()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_cam_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			_toggle_free_mouse()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_cam_target_dist = clampf(_cam_target_dist - 0.55, 1.85, 15.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_cam_target_dist = clampf(_cam_target_dist + 0.55, 1.85, 15.0)

	elif event is InputEventMouseMotion:
		if _cam_dragging or _cam_free_mouse:
			var mm := event as InputEventMouseMotion
			_cam_yaw_offset -= mm.relative.x * _cam_Mouse_Sens
			_cam_pitch_deg = clampf(_cam_pitch_deg + mm.relative.y * _cam_Mouse_Sens * 0.85, -8.0, 78.0)

	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			match ke.keycode:
				KEY_1, KEY_BRACKETLEFT:
					_switch_car(-1)
				KEY_2, KEY_BRACKETRIGHT:
					_switch_car(1)
				KEY_R:
					_reset_car_to_start()
				KEY_E:
					_unflip_car_in_place()
				KEY_T:
					_cycle_kit_mode()
				KEY_C:
					_reset_camera_behind()
				KEY_F:
					_toggle_camera_follow_heading()
				KEY_V:
					_toggle_free_mouse()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_active_car):
		return

	# На тестовом полигоне машина всегда с полным баком и полной прочностью
	var max_f: float = float(_active_car.get("max_fuel"))
	var max_h: int = int(_active_car.get("health"))
	_active_car.set("current_fuel", maxf(max_f, 100.0))
	_active_car.set("current_hp", maxi(max_h, 100))

	if _active_car.global_position.y < -25.0:
		_reset_car_to_start()

	_update_orbit_camera_transform(delta)
	_update_telemetry_hud()

func _update_orbit_camera_transform(delta: float) -> void:
	if not is_instance_valid(_orbit_cam) or not is_instance_valid(_active_car):
		return

	_cam_dist = lerpf(_cam_dist, _cam_target_dist, clampf(delta * 14.0, 0.0, 1.0))
	var target_focus: Vector3 = _active_car.global_position + Vector3(0.0, 0.85, 0.0)
	_cam_focus_pos = _cam_focus_pos.lerp(target_focus, clampf(delta * 22.0, 0.0, 1.0))

	var base_yaw_deg: float = 0.0
	if _cam_follow_heading:
		var fwd: Vector3 = -_active_car.global_transform.basis.z
		var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
		if flat_fwd.length_squared() > 0.001:
			flat_fwd = flat_fwd.normalized()
			base_yaw_deg = rad_to_deg(atan2(-flat_fwd.x, -flat_fwd.z))

	var total_yaw_rad: float = deg_to_rad(base_yaw_deg + _cam_yaw_offset)
	var pitch_rad: float = deg_to_rad(_cam_pitch_deg)

	# При total_yaw_rad = 0 камера находится позади машины (+Z) и смотрит вперёд (-Z)
	var horiz_r: float = cos(pitch_rad) * _cam_dist
	var offset := Vector3(
		sin(total_yaw_rad) * horiz_r,
		sin(pitch_rad) * _cam_dist,
		cos(total_yaw_rad) * horiz_r
	)

	var desired_pos: Vector3 = _cam_focus_pos + offset
	# Не даём камере уходить под пол полигона при низких углах обзора подвески
	desired_pos.y = maxf(desired_pos.y, 0.22)
	_orbit_cam.look_at_from_position(desired_pos, _cam_focus_pos, Vector3.UP)

func _switch_car(step: int) -> void:
	var pos: Vector3 = SPAWN_POS
	var yaw: float = 0.0
	if is_instance_valid(_active_car):
		pos = Vector3(_active_car.global_position.x, maxf(_active_car.global_position.y + 0.35, 0.55), _active_car.global_position.z)
		var fwd: Vector3 = -_active_car.global_transform.basis.z
		yaw = atan2(-fwd.x, -fwd.z)
	_spawn_vehicle(_current_car_idx + step, pos, yaw)

func _reset_car_to_start() -> void:
	_spawn_vehicle(_current_car_idx, SPAWN_POS, 0.0)

func _unflip_car_in_place() -> void:
	if not is_instance_valid(_active_car):
		return
	var pos: Vector3 = _active_car.global_position
	var fwd: Vector3 = -_active_car.global_transform.basis.z
	var yaw: float = atan2(-fwd.x, -fwd.z)
	_active_car.linear_velocity = Vector3.ZERO
	_active_car.angular_velocity = Vector3.ZERO
	_active_car.global_position = Vector3(pos.x, maxf(pos.y + 0.85, 0.85), pos.z)
	_active_car.global_rotation = Vector3(0.0, yaw, 0.0)

func _cycle_kit_mode() -> void:
	_kit_mode = (_kit_mode + 1) % 3
	_apply_current_kit_mode()

func _reset_camera_behind() -> void:
	_cam_yaw_offset = 0.0
	_cam_pitch_deg = 16.0
	_cam_target_dist = 5.4

func _toggle_camera_follow_heading() -> void:
	if is_instance_valid(_active_car):
		var fwd: Vector3 = -_active_car.global_transform.basis.z
		var car_yaw_deg: float = rad_to_deg(atan2(-fwd.x, -fwd.z))
		if _cam_follow_heading:
			_cam_yaw_offset = car_yaw_deg + _cam_yaw_offset
		else:
			_cam_yaw_offset = _cam_yaw_offset - car_yaw_deg
	_cam_follow_heading = not _cam_follow_heading
	_update_header_labels()

func _toggle_free_mouse() -> void:
	_cam_free_mouse = not _cam_free_mouse
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _cam_free_mouse else Input.MOUSE_MODE_VISIBLE)
	_update_header_labels()

func _return_to_main_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	SceneTransition.transition_to_scene("res://ui/menu.tscn")

func _make_stylebox(bg: Color, border: Color, bw_left: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.border_width_left = bw_left
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb

func _make_toolbar_btn(caption: String, callback: Callable, accent: Color = Color(0.92, 0.48, 0.18)) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT_RUSSO)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", Color(0.94, 0.95, 0.96))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.92, 0.82))
	b.add_theme_stylebox_override("normal", _make_stylebox(Color(0.09, 0.11, 0.14, 0.88), Color(0.32, 0.36, 0.40, 0.75), 3))
	b.add_theme_stylebox_override("hover", _make_stylebox(Color(0.16, 0.15, 0.16, 0.96), accent, 4))
	b.add_theme_stylebox_override("pressed", _make_stylebox(Color(0.22, 0.14, 0.10, 0.98), accent, 5))
	b.pressed.connect(callback)
	return b

func _build_polygon_hud() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "PolygonHUD"
	_ui_layer.layer = 5
	add_child(_ui_layer)

	# 1. Верхняя панель управления полигоном
	var top_panel := PanelContainer.new()
	top_panel.anchor_left = 0.0
	top_panel.anchor_right = 1.0
	top_panel.offset_left = 12.0
	top_panel.offset_top = 10.0
	top_panel.offset_right = -12.0
	top_panel.offset_bottom = 80.0
	top_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.06, 0.08, 0.88), Color(0.36, 0.40, 0.45, 0.72), 4))
	_ui_layer.add_child(top_panel)

	var top_vbox := VBoxContainer.new()
	top_vbox.add_theme_constant_override("separation", 5)
	top_panel.add_child(top_vbox)

	var row_btns := HBoxContainer.new()
	row_btns.add_theme_constant_override("separation", 6)
	top_vbox.add_child(row_btns)

	var btn_menu := _make_toolbar_btn("◀ В МЕНЮ", Callable(self, "_return_to_main_menu"), Color(0.95, 0.35, 0.25))
	row_btns.add_child(btn_menu)

	var btn_prev := _make_toolbar_btn("◀ [1]", func() -> void: _switch_car(-1))
	row_btns.add_child(btn_prev)

	_lbl_car_title = Label.new()
	_lbl_car_title.custom_minimum_size = Vector2(180.0, 0.0)
	_lbl_car_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_car_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_car_title.add_theme_font_override("font", FONT_RUSSO)
	_lbl_car_title.add_theme_font_size_override("font_size", 13)
	_lbl_car_title.add_theme_color_override("font_color", Color(0.98, 0.78, 0.32))
	row_btns.add_child(_lbl_car_title)

	var btn_next := _make_toolbar_btn("[2] ▶", func() -> void: _switch_car(1))
	row_btns.add_child(btn_next)

	_btn_kit_mode = _make_toolbar_btn("[T] ОБВЕС: ГАРАЖ", Callable(self, "_cycle_kit_mode"))
	row_btns.add_child(_btn_kit_mode)

	var btn_reset := _make_toolbar_btn("[R] СТАРТ", Callable(self, "_reset_car_to_start"))
	row_btns.add_child(btn_reset)

	var btn_unflip := _make_toolbar_btn("[E] НА КОЛЁСА", Callable(self, "_unflip_car_in_place"))
	row_btns.add_child(btn_unflip)

	var btn_cam_rst := _make_toolbar_btn("[C] СЗАДИ", Callable(self, "_reset_camera_behind"))
	row_btns.add_child(btn_cam_rst)

	_btn_cam_mode = _make_toolbar_btn("[F] ЗА КУРСОМ", Callable(self, "_toggle_camera_follow_heading"))
	row_btns.add_child(_btn_cam_mode)

	_btn_free_mouse = _make_toolbar_btn("[V] МЫШЬ: ЗАЖАТИЕ", Callable(self, "_toggle_free_mouse"))
	row_btns.add_child(_btn_free_mouse)

	var hint_lbl := Label.new()
	hint_lbl.text = "КАМЕРА 360°: Зажми ЛКМ или ПКМ + двигай мышь (или нажми [V] / СКМ для обзора без зажатия)  •  Колёсико: Зум к подвеске  •  [1]/[2]: Сменить машину  •  [T]: Обвес  •  [R]: Старт"
	hint_lbl.add_theme_font_override("font", FONT_JURA)
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.76, 0.82, 0.88))
	top_vbox.add_child(hint_lbl)

	# 2. Нижняя левая панель живой телеметрии подвески (Ход каждого колеса FL/FR/RL/RR, крен, тангаж)
	var tele_panel := PanelContainer.new()
	tele_panel.anchor_left = 0.0
	tele_panel.anchor_top = 1.0
	tele_panel.anchor_right = 0.0
	tele_panel.anchor_bottom = 1.0
	tele_panel.offset_left = 14.0
	tele_panel.offset_top = -205.0
	tele_panel.offset_right = 338.0
	tele_panel.offset_bottom = -14.0
	tele_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_panel.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.06, 0.08, 0.82), Color(0.34, 0.38, 0.44, 0.68), 4))
	_ui_layer.add_child(tele_panel)

	var tele_vbox := VBoxContainer.new()
	tele_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_vbox.add_theme_constant_override("separation", 5)
	tele_panel.add_child(tele_vbox)

	var tele_hdr := Label.new()
	tele_hdr.text = "ТЕЛЕМЕТРИЯ ПОДВЕСКИ И КУЗОВА"
	tele_hdr.add_theme_font_override("font", FONT_RUSSO)
	tele_hdr.add_theme_font_size_override("font_size", 13)
	tele_hdr.add_theme_color_override("font_color", Color(0.95, 0.62, 0.24))
	tele_vbox.add_child(tele_hdr)

	_lbl_telemetry = Label.new()
	_lbl_telemetry.add_theme_font_override("font", FONT_JURA)
	_lbl_telemetry.add_theme_font_size_override("font_size", 13)
	_lbl_telemetry.add_theme_color_override("font_color", Color(0.88, 0.91, 0.94))
	tele_vbox.add_child(_lbl_telemetry)

	var wheel_titles: Array[String] = ["ПЛ (FL)", "ПП (FR)", "ЗЛ (RL)", "ЗП (RR)"]
	_wheel_bars.clear()
	_wheel_pct_labels.clear()

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.16, 0.20, 0.95)
	bar_bg.set_corner_radius_all(3)

	for w_title in wheel_titles:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 8)
		tele_vbox.add_child(row)

		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(64.0, 0.0)
		name_lbl.text = w_title
		name_lbl.add_theme_font_override("font", FONT_RUSSO)
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.90))
		row.add_child(name_lbl)

		var pb := ProgressBar.new()
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.custom_minimum_size = Vector2(140.0, 14.0)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.max_value = 100.0
		pb.value = 50.0
		pb.show_percentage = false
		pb.add_theme_stylebox_override("background", bar_bg)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.32, 0.82, 0.48)
		bar_fill.set_corner_radius_all(3)
		pb.add_theme_stylebox_override("fill", bar_fill)
		row.add_child(pb)
		_wheel_bars.append(pb)

		var pct_lbl := Label.new()
		pct_lbl.custom_minimum_size = Vector2(82.0, 0.0)
		pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pct_lbl.text = "50% (ОК)"
		pct_lbl.add_theme_font_override("font", FONT_JURA)
		pct_lbl.add_theme_font_size_override("font_size", 12)
		pct_lbl.add_theme_color_override("font_color", Color(0.86, 0.90, 0.94))
		row.add_child(pct_lbl)
		_wheel_pct_labels.append(pct_lbl)

func _update_header_labels() -> void:
	var g: Node = get_node_or_null("/root/Game")
	var car_name: String = "МАШИНА"
	var total_cars: int = 11
	if g != null:
		var data_v: Variant = g.get("car_data")
		if data_v is Array and not (data_v as Array).is_empty():
			var data: Array = data_v as Array
			total_cars = data.size()
			var info: Dictionary = data[_current_car_idx] as Dictionary
			car_name = str(info.get("name", car_name)).to_upper()
	if is_instance_valid(_lbl_car_title):
		_lbl_car_title.text = "%s (%d/%d)" % [car_name, _current_car_idx + 1, total_cars]
	if is_instance_valid(_btn_kit_mode):
		var kit_names: Array[String] = ["[T] ОБВЕС: ГАРАЖ", "[T] ОБВЕС: ПОЛНЫЙ 3/3", "[T] ОБВЕС: СТОК 0/3"]
		_btn_kit_mode.text = kit_names[_kit_mode % kit_names.size()]
	if is_instance_valid(_btn_cam_mode):
		_btn_cam_mode.text = "[F] ЗА КУРСОМ" if _cam_follow_heading else "[F] МИРОВАЯ 360°"
	if is_instance_valid(_btn_free_mouse):
		_btn_free_mouse.text = "[V] МЫШЬ: СВОБОДНО" if _cam_free_mouse else "[V] МЫШЬ: ЗАЖАТИЕ"

func _update_telemetry_hud() -> void:
	if not is_instance_valid(_active_car) or not is_instance_valid(_lbl_telemetry):
		return

	var vel: Vector3 = _active_car.linear_velocity
	var spd_kmh: int = roundi(vel.length() * 3.6)
	var basis: Basis = _active_car.global_transform.basis
	var roll_deg: float = rad_to_deg(asin(clampf(basis.x.y, -1.0, 1.0)))
	var pitch_deg: float = rad_to_deg(asin(clampf(-basis.z.y, -1.0, 1.0)))

	var firm_v: Variant = _active_car.get("suspension_firmness")
	var firm_val: float = float(firm_v) if firm_v != null else 1.25
	var dc_v: Variant = _active_car.get("compression_damping_ratio")
	var damp_c: float = float(dc_v) if dc_v != null else 0.60
	var dr_v: Variant = _active_car.get("rebound_damping_ratio")
	var damp_r: float = float(dr_v) if dr_v != null else 0.60
	var arb_v: Variant = _active_car.get("anti_roll_stiffness")
	var arb_val: int = roundi(float(arb_v)) if arb_v != null else 7800

	var wheels_v: Variant = _active_car.get("_wheels")
	var wheels: Array = wheels_v as Array if (wheels_v is Array) else []
	var grounded_cnt: int = 0

	for idx in range(mini(wheels.size(), 4)):
		var w := wheels[idx] as RayCast3D
		if not is_instance_valid(w):
			continue
		var hit_v: Variant = w.get("is_grounded")
		var hit: bool = bool(hit_v) if hit_v != null else w.is_colliding()
		var cr_v: Variant = w.get("compression_ratio")
		var comp_ratio: float = clampf(float(cr_v), 0.0, 1.0) if cr_v != null else 0.0
		if hit:
			grounded_cnt += 1

		var pct: int = roundi(comp_ratio * 100.0)
		var pb := _wheel_bars[idx]
		var lbl := _wheel_pct_labels[idx]
		pb.value = float(pct)
		var fill_sb := pb.get_theme_stylebox("fill") as StyleBoxFlat
		if fill_sb != null:
			if not hit:
				fill_sb.bg_color = Color(0.38, 0.44, 0.52)
			elif pct >= 85:
				fill_sb.bg_color = Color(0.95, 0.30, 0.22)
			elif pct >= 68:
				fill_sb.bg_color = Color(0.95, 0.72, 0.22)
			else:
				fill_sb.bg_color = Color(0.30, 0.84, 0.48)
		lbl.text = "%d%% %s" % [pct, ("В ВОЗДУХЕ" if not hit else ("ПРОБОЙ!" if pct >= 88 else "НОРМА"))]

	var surf_prof: Dictionary = get_surface_grip_profile(_active_car.global_position)
	var surf_str: String = "ЛЁД (0.52x)" if bool(surf_prof.get("is_ice", false)) else "АСФАЛЬТ-СЕТКА (1.0x)"

	_lbl_telemetry.text = (
		"Скорость: %d км/ч  |  Колёс на земле: %d/4\n" % [spd_kmh, grounded_cnt]
		+ "Крен (Roll): %+.1f°  |  Тангаж (Pitch): %+.1f°\n" % [roll_deg, pitch_deg]
		+ "Жёсткость: %.2f  |  Сжатие/Отбой: %.2f/%.2f  |  Стаб: %d\n" % [firm_val, damp_c, damp_r, arb_val]
		+ "Покрытие: %s" % surf_str
	)
