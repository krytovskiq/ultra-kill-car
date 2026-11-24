extends RefCounted

const ROAD_SURFACE_SHADER: Shader = preload("res://environment/shaders/road_surface.gdshader")
const BIOME_TERRAIN_SHADER: Shader = preload("res://environment/shaders/biome_terrain.gdshader")
const RUINED_BUILDING_SHADER: Shader = preload("res://environment/shaders/ruined_building.gdshader")
const WORLD_PROP_HEADLIGHT_SHADER: Shader = preload("res://environment/shaders/world_prop_headlight.gdshader")
const OCEAN_WATER_SHADER: Shader = preload("res://environment/shaders/ocean_water.gdshader")
const WORLD_FIRE_SHADER: Shader = preload("res://environment/shaders/world_fire.gdshader")
const WORLD_SMOKE_SHADER: Shader = preload("res://environment/shaders/world_smoke.gdshader")

static var _materials: Dictionary = {}
static var _converted_mats: Dictionary = {}
static var _meshes: Dictionary = {}

static var _hl_left_pos: Vector3 = Vector3(0.0, -1000.0, 0.0)
static var _hl_right_pos: Vector3 = Vector3(0.0, -1000.0, 0.0)
static var _hl_dir: Vector3 = Vector3(0.0, -0.05, 1.0)
static var _hl_intensity: float = 0.0
static var _hl_color: Color = Color(1.0, 0.94, 0.78, 1.0)
static var _hl_range: float = 68.0
static var _night_window_boost: float = 0.0

static func get_material(key: String) -> Material:
	if _materials.has(key):
		return _materials[key] as Material

	var mat: Material = null
	match key:
		"asphalt":
			mat = _make_road_shader_mat(0.0)
		"asphalt_ice":
			mat = _make_road_shader_mat(1.0)
		"asphalt_wet":
			mat = _make_road_shader_mat(0.0, 0.72, 0.68, Color(0.76, 0.80, 0.75, 1.0))
		"asphalt_scorched":
			mat = _make_road_shader_mat(0.0, 0.05, 0.96, Color(0.84, 0.76, 0.70, 1.0))
		"asphalt_overgrown":
			mat = _make_road_shader_mat(0.0, 0.22, 0.94, Color(0.86, 0.90, 0.80, 1.0), 0.94)
		"desert":
			mat = _make_terrain_shader_mat(
				"gravelly_sand", "dry_ground_rocks",
				Color(0.95, 0.87, 0.76, 1.0), Color(0.86, 0.79, 0.69, 1.0),
				0.075, 0.135, 1.35, 17.0, 0.08
			)
		"city_concrete":
			mat = _make_terrain_shader_mat(
				"concrete_floor_worn_001", "cracked_concrete_wall",
				Color(0.82, 0.82, 0.84, 1.0), Color(0.72, 0.72, 0.75, 1.0),
				0.085, 0.145, 1.20, 20.0, 0.30
			)
		"burnt_city_concrete":
			mat = _make_terrain_shader_mat(
				"concrete_floor_worn_001", "cracked_concrete_wall",
				Color(0.32, 0.28, 0.27, 1.0), Color(0.20, 0.16, 0.15, 1.0),
				0.085, 0.145, 1.32, 20.0, 0.06
			)
		"forest_ground":
			mat = _make_terrain_shader_mat(
				"forest_ground_04", "brown_mud_leaves_01",
				Color(0.84, 0.90, 0.80, 1.0), Color(0.76, 0.70, 0.62, 1.0),
				0.085, 0.15, 1.35, 15.0, 0.42
			)
		"burnt_forest_ground":
			mat = _make_terrain_shader_mat(
				"forest_ground_04", "dry_ground_rocks",
				Color(0.24, 0.21, 0.20, 1.0), Color(0.16, 0.14, 0.13, 1.0),
				0.085, 0.145, 1.40, 15.0, 0.04
			)
		"overgrown_ground":
			mat = _make_terrain_shader_mat(
				"forest_ground_04", "mossy_rock",
				Color(0.56, 0.74, 0.38, 1.0), Color(0.46, 0.62, 0.30, 1.0),
				0.085, 0.15, 1.30, 16.0, 0.25
			)
		"snow_ground":
			mat = _make_terrain_shader_mat(
				"dry_ground_rocks", "gravelly_sand",
				Color(0.86, 0.90, 0.95, 1.0), Color(0.70, 0.75, 0.82, 1.0),
				0.080, 0.140, 1.20, 17.0, 0.10, 1.0
			)
		"toxic_ground":
			mat = _make_terrain_shader_mat(
				"brown_mud_leaves_01", "forest_ground_04",
				Color(0.56, 0.68, 0.42, 1.0), Color(0.46, 0.54, 0.34, 1.0),
				0.080, 0.145, 1.35, 16.0, 0.74, 0.0
			)
		"scorched_ground":
			mat = _make_terrain_shader_mat(
				"dry_ground_rocks", "gravelly_sand",
				Color(0.72, 0.42, 0.30, 1.0), Color(0.42, 0.30, 0.25, 1.0),
				0.075, 0.140, 1.45, 17.0, 0.04, 0.0
			)
		"building_factory":
			mat = _make_building_shader_mat("factory_wall", "cracked_concrete_wall", Color(0.86, 0.86, 0.88, 1.0), 0.14, 0.08, 0.82)
		"building_brick":
			mat = _make_building_shader_mat("brick_wall_001", "cracked_concrete_wall", Color(0.85, 0.79, 0.75, 1.0), 0.17, 0.02, 0.74)
		"building_burnt_factory":
			mat = _make_building_shader_mat("factory_wall", "cracked_concrete_wall", Color(0.62, 0.54, 0.50, 1.0), 0.14, 0.08, 0.82, 0.88)
		"building_burnt_brick":
			mat = _make_building_shader_mat("brick_wall_001", "cracked_concrete_wall", Color(0.58, 0.48, 0.44, 1.0), 0.17, 0.02, 0.74, 0.90)
		"rock":
			mat = _make_pbr("aerial_rocks_02", Vector3(0.14, 0.14, 0.14), true, true, 1.5, Color(0.85, 0.82, 0.78, 1.0), 0.0, 0.95)
		"mossy_rock":
			mat = _make_pbr("mossy_rock", Vector3(0.18, 0.18, 0.18), true, true, 1.5, Color(0.86, 0.90, 0.82, 1.0), 0.0, 0.92)
		"snow_rock":
			mat = _make_pbr("aerial_rocks_02", Vector3(0.14, 0.14, 0.14), true, true, 1.45, Color(0.76, 0.82, 0.88, 1.0), 0.0, 0.72)
		"toxic_rock":
			mat = _make_pbr("mossy_rock", Vector3(0.16, 0.16, 0.16), true, true, 1.5, Color(0.58, 0.72, 0.44, 1.0), 0.0, 0.78)
		"scorched_rock":
			mat = _make_pbr("aerial_rocks_02", Vector3(0.14, 0.14, 0.14), true, true, 1.55, Color(0.46, 0.34, 0.30, 1.0), 0.0, 0.94)
		"snow_bank":
			mat = _make_flat_prop_mat(Color(0.79, 0.85, 0.91, 1.0), 0.62, 0.0)
		"bark":
			mat = _make_pbr("bark_brown_02", Vector3(0.65, 0.65, 0.65), true, false, 1.35, Color(0.82, 0.76, 0.70, 1.0), 0.0, 0.96)
		"charred_bark":
			mat = _make_pbr("bark_brown_02", Vector3(0.65, 0.65, 0.65), true, false, 1.45, Color(0.22, 0.19, 0.18, 1.0), 0.0, 0.98)
		"charred_ember":
			mat = _make_flat_prop_mat(Color(0.18, 0.10, 0.08, 1.0), 0.92, 0.0, Color(1.0, 0.32, 0.04, 1.0), 2.4)
		"concrete_rubble":
			mat = _make_pbr("cracked_concrete_wall", Vector3(0.22, 0.22, 0.22), true, true, 1.35, Color(0.78, 0.78, 0.80, 1.0), 0.0, 0.94)
		"shrub_foliage":
			mat = _make_shrub_foliage_mat()
		"tall_grass_mat":
			mat = _make_tall_grass_mat()
		"world_fire_mat":
			var wf := ShaderMaterial.new()
			wf.shader = WORLD_FIRE_SHADER
			var fire_tex := load("res://assets/textures/vfx/fire_flipbook_8x8.png") as Texture2D
			if fire_tex:
				wf.set_shader_parameter("fire_sheet", fire_tex)
			mat = wf
		"world_smoke_mat":
			var ws := ShaderMaterial.new()
			ws.shader = WORLD_SMOKE_SHADER
			var smoke_tex := load("res://assets/textures/vfx/smoke_flipbook_8x8.png") as Texture2D
			if smoke_tex:
				ws.set_shader_parameter("smoke_sheet", smoke_tex)
			mat = ws
		"stop_sign_metal":
			mat = _make_stop_sign_mat()
		"barbed_wire_steel":
			mat = _make_flat_prop_mat(Color(0.36, 0.38, 0.40, 1.0), 0.38, 0.82)
		"rusty_metal":
			mat = _make_pbr("rusty_corrugated_iron", Vector3(0.22, 0.22, 0.22), true, true, 1.2, Color(0.92, 0.88, 0.84, 1.0), 0.55, 0.75)
		"gate_steel":
			mat = _make_pbr("rusty_corrugated_iron", Vector3(0.28, 0.28, 0.28), true, false, 1.25, Color(0.56, 0.58, 0.60, 1.0), 0.68, 0.56)
		"hazard_stripe":
			mat = _make_hazard_stripe_mat()
		"flare_beacon":
			mat = _make_flat_prop_mat(Color(1.0, 0.52, 0.14, 1.0), 0.25, 0.0, Color(1.0, 0.48, 0.10, 1.0), 4.6)
		"stripe_yellow":
			mat = _make_flat_prop_mat(Color(0.88, 0.68, 0.16, 1.0), 0.82, 0.0)
		"stripe_white":
			mat = _make_flat_prop_mat(Color(0.82, 0.82, 0.80, 1.0), 0.85, 0.0)
		"pole_steel":
			mat = _make_flat_prop_mat(Color(0.28, 0.30, 0.33, 1.0), 0.42, 0.75)
		"road_sign_warn":
			mat = _make_sign_mat("warn")
		"road_sign_hazard":
			mat = _make_sign_mat("hazard")
		"gantry_sign":
			mat = _make_sign_mat("gantry")
		"billboard_0":
			mat = _make_billboard_poster_mat(0)
		"billboard_1":
			mat = _make_billboard_poster_mat(1)
		"billboard_2":
			mat = _make_billboard_poster_mat(2)
		"billboard_3":
			mat = _make_billboard_poster_mat(3)
		"lamp_glow":
			mat = _make_flat_prop_mat(Color(1.0, 0.88, 0.66, 1.0), 0.35, 0.0, Color(1.0, 0.82, 0.52, 1.0), 3.2)
		"ocean_water":
			var ow_mat := ShaderMaterial.new()
			ow_mat.shader = OCEAN_WATER_SHADER
			mat = ow_mat
		_:
			mat = _make_flat_prop_mat(Color.WHITE, 0.85, 0.0)

	if mat is ShaderMaterial:
		_apply_hl_to_mat(mat as ShaderMaterial)
	_materials[key] = mat
	return mat

static func _make_road_shader_mat(ice_amt: float = 0.0, puddle_override: float = -1.0, rough_override: float = -1.0, tint_override: Variant = null, overgrown_amt: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SURFACE_SHADER
	var base := "res://environment/textures/procedural/worn_asphalt/"
	var diff_tex := load(base + "diff.jpg") as Texture2D
	var nor_tex := load(base + "nor_gl.jpg") as Texture2D
	var rough_tex := load(base + "rough.jpg") as Texture2D
	if diff_tex:
		mat.set_shader_parameter("albedo_tex", diff_tex)
	if nor_tex:
		mat.set_shader_parameter("normal_tex", nor_tex)
	if rough_tex:
		mat.set_shader_parameter("roughness_tex", rough_tex)
	var default_tint := Color(0.84, 0.88, 0.94, 1.0) if ice_amt > 0.5 else Color(0.92, 0.92, 0.94, 1.0)
	mat.set_shader_parameter("tint_color", tint_override if tint_override is Color else default_tint)
	mat.set_shader_parameter("uv_tile_u", 1.0)
	mat.set_shader_parameter("uv_tile_v", 1.0)
	mat.set_shader_parameter("normal_strength", 1.22)
	mat.set_shader_parameter("roughness_mult", rough_override if rough_override >= 0.0 else 0.90)
	mat.set_shader_parameter("tire_track_strength", 0.36)
	mat.set_shader_parameter("road_half_width", 17.0)
	mat.set_shader_parameter("puddle_strength", puddle_override if puddle_override >= 0.0 else 0.36)
	mat.set_shader_parameter("ice_amount", ice_amt)
	mat.set_shader_parameter("overgrown_amount", overgrown_amt)
	return mat

static func _make_hazard_stripe_mat() -> ShaderMaterial:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		for x in range(sz):
			var band := int(floor((float(x) + float(y)) / 8.0)) % 2
			var g := 0.88 + 0.12 * _tex_hash(x, y, 31)
			var col := Color(0.88 * g, 0.64 * g, 0.10 * g, 1.0) if band == 0 else Color(0.11 * g, 0.11 * g, 0.12 * g, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color.WHITE)
	mat.set_shader_parameter("roughness_val", 0.62)
	mat.set_shader_parameter("metallic_val", 0.25)
	mat.set_shader_parameter("uv_scale", Vector3(2.0, 2.0, 2.0))
	return mat

static func _make_terrain_shader_mat(
	folder_a: String,
	folder_b: String,
	tint_a: Color,
	tint_b: Color,
	uv_a: float,
	uv_b: float,
	norm_str: float,
	road_half: float,
	puddle_amt: float,
	snow_amt: float = 0.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BIOME_TERRAIN_SHADER
	var base_a := "res://environment/textures/procedural/" + folder_a + "/"
	var base_b := "res://environment/textures/procedural/" + folder_b + "/"
	if load(base_a + "diff.jpg"):
		mat.set_shader_parameter("albedo_primary", load(base_a + "diff.jpg"))
	if load(base_a + "nor_gl.jpg"):
		mat.set_shader_parameter("normal_primary", load(base_a + "nor_gl.jpg"))
	if load(base_a + "rough.jpg"):
		mat.set_shader_parameter("rough_primary", load(base_a + "rough.jpg"))
	if load(base_b + "diff.jpg"):
		mat.set_shader_parameter("albedo_detail", load(base_b + "diff.jpg"))
	if load(base_b + "nor_gl.jpg"):
		mat.set_shader_parameter("normal_detail", load(base_b + "nor_gl.jpg"))
	if load(base_b + "rough.jpg"):
		mat.set_shader_parameter("rough_detail", load(base_b + "rough.jpg"))
	mat.set_shader_parameter("tint_primary", tint_a)
	mat.set_shader_parameter("tint_detail", tint_b)
	mat.set_shader_parameter("uv_scale_primary", uv_a)
	mat.set_shader_parameter("uv_scale_detail", uv_b)
	mat.set_shader_parameter("normal_strength", norm_str)
	mat.set_shader_parameter("road_half_width", road_half)
	mat.set_shader_parameter("puddle_amount", puddle_amt)
	mat.set_shader_parameter("snow_amount", snow_amt)
	return mat

static func _make_building_shader_mat(
	folder_wall: String,
	folder_crack: String,
	tint: Color,
	uv_scale: float,
	metal: float,
	win_dens: float,
	burn_amt: float = 0.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = RUINED_BUILDING_SHADER
	var bw := "res://environment/textures/procedural/" + folder_wall + "/"
	var bc := "res://environment/textures/procedural/" + folder_crack + "/"
	if load(bw + "diff.jpg"):
		mat.set_shader_parameter("albedo_wall", load(bw + "diff.jpg"))
	if load(bw + "nor_gl.jpg"):
		mat.set_shader_parameter("normal_wall", load(bw + "nor_gl.jpg"))
	if load(bw + "rough.jpg"):
		mat.set_shader_parameter("rough_wall", load(bw + "rough.jpg"))
	if load(bc + "diff.jpg"):
		mat.set_shader_parameter("albedo_crack", load(bc + "diff.jpg"))
	if load(bc + "nor_gl.jpg"):
		mat.set_shader_parameter("normal_crack", load(bc + "nor_gl.jpg"))
	mat.set_shader_parameter("tint_color", tint)
	mat.set_shader_parameter("world_uv_scale", uv_scale)
	mat.set_shader_parameter("metallic_val", metal)
	mat.set_shader_parameter("window_density", win_dens)
	mat.set_shader_parameter("night_window_boost", _night_window_boost)
	mat.set_shader_parameter("burn_amount", burn_amt)
	return mat

static func _make_pbr(folder: String, uv_scale: Vector3, triplanar: bool, world_triplanar: bool, normal_strength: float, tint: Color, metallic_val: float, rough_mult: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	var base := "res://environment/textures/procedural/" + folder + "/"
	var diff_tex := load(base + "diff.jpg") as Texture2D
	var nor_tex := load(base + "nor_gl.jpg") as Texture2D
	var rough_tex := load(base + "rough.jpg") as Texture2D

	mat.set_shader_parameter("has_albedo_tex", diff_tex != null)
	if diff_tex:
		mat.set_shader_parameter("albedo_tex", diff_tex)
	mat.set_shader_parameter("albedo_tint", tint)
	mat.set_shader_parameter("has_normal_tex", nor_tex != null)
	if nor_tex:
		mat.set_shader_parameter("normal_tex", nor_tex)
	mat.set_shader_parameter("normal_strength", normal_strength)
	mat.set_shader_parameter("has_rough_tex", rough_tex != null)
	if rough_tex:
		mat.set_shader_parameter("rough_tex", rough_tex)
	mat.set_shader_parameter("roughness_val", rough_mult)
	mat.set_shader_parameter("metallic_val", metallic_val)
	mat.set_shader_parameter("uv_scale", uv_scale)
	mat.set_shader_parameter("use_triplanar", triplanar)
	mat.set_shader_parameter("world_triplanar", world_triplanar)
	return mat

static func _make_flat_prop_mat(
	albedo: Color,
	rough: float,
	metal: float,
	em_col: Color = Color.BLACK,
	em_energy: float = 0.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", false)
	mat.set_shader_parameter("has_normal_tex", false)
	mat.set_shader_parameter("has_rough_tex", false)
	mat.set_shader_parameter("albedo_tint", albedo)
	mat.set_shader_parameter("roughness_val", rough)
	mat.set_shader_parameter("metallic_val", metal)
	mat.set_shader_parameter("base_emission", em_col)
	mat.set_shader_parameter("base_emission_energy", em_energy)
	return mat

static func _make_shrub_foliage_mat() -> ShaderMaterial:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var v := float(y) / float(sz - 1)
		for x in range(sz):
			var u := (float(x) / float(sz - 1)) * 2.0 - 1.0
			var h := 1.0 - v
			var spread := lerpf(0.18, 0.95, pow(clampf(h, 0.0, 1.0), 0.55))
			var radial := absf(u) / maxf(spread, 0.05)
			var ang := atan2(h - 0.1, u)
			var twigs := 0.72 + 0.28 * sin(ang * 13.0 + h * 18.0) * cos(ang * 7.0 - u * 15.0)
			var holes := sin(u * 24.0 + h * 19.0) * cos(u * 17.0 - h * 23.0)
			var mask := (1.0 - smoothstep(twigs * 0.65, twigs, radial)) * smoothstep(0.0, 0.14, h) * (1.0 - smoothstep(0.84, 1.0, h))
			if holes > 0.52 and h > 0.35:
				mask = 0.0
			var alpha := 1.0 if mask > 0.28 else 0.0
			var shade := clampf(0.55 + h * 0.45 + 0.12 * sin(u * 19.0 + h * 13.0), 0.42, 1.05)
			var col := Color(0.24 * shade, 0.28 * shade, 0.16 * shade, alpha)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color(0.95, 0.92, 0.85, 1.0))
	mat.set_shader_parameter("roughness_val", 0.94)
	mat.set_shader_parameter("metallic_val", 0.0)
	return mat

static func get_lit_prop_material(orig_mat: Material) -> ShaderMaterial:
	if orig_mat is ShaderMaterial:
		return orig_mat as ShaderMaterial
	var key := "default_prop"
	var sm := orig_mat as StandardMaterial3D
	if sm != null:
		key = "mat_" + str(sm.get_instance_id())
	if _converted_mats.has(key):
		return _converted_mats[key] as ShaderMaterial

	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	if sm != null:
		mat.set_shader_parameter("has_albedo_tex", sm.albedo_texture != null)
		if sm.albedo_texture:
			mat.set_shader_parameter("albedo_tex", sm.albedo_texture)
		mat.set_shader_parameter("albedo_tint", sm.albedo_color)
		mat.set_shader_parameter("has_normal_tex", sm.normal_enabled and sm.normal_texture != null)
		if sm.normal_enabled and sm.normal_texture:
			mat.set_shader_parameter("normal_tex", sm.normal_texture)
			mat.set_shader_parameter("normal_strength", sm.normal_scale)
		mat.set_shader_parameter("has_rough_tex", sm.roughness_texture != null)
		if sm.roughness_texture:
			mat.set_shader_parameter("rough_tex", sm.roughness_texture)
		mat.set_shader_parameter("roughness_val", clampf(sm.roughness, 0.2, 0.98))
		mat.set_shader_parameter("metallic_val", clampf(sm.metallic, 0.0, 0.85))
		mat.set_shader_parameter("uv_scale", sm.uv1_scale)
		mat.set_shader_parameter("use_triplanar", sm.uv1_triplanar)
		mat.set_shader_parameter("world_triplanar", sm.uv1_world_triplanar)
		if sm.emission_enabled:
			mat.set_shader_parameter("base_emission", sm.emission)
			mat.set_shader_parameter("base_emission_energy", sm.emission_energy_multiplier)
	_apply_hl_to_mat(mat)
	_converted_mats[key] = mat
	return mat

static func apply_headlight_materials_to_node(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override and not (mi.material_override is ShaderMaterial):
			mi.material_override = get_lit_prop_material(mi.material_override)
		elif mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var active_m := mi.get_active_material(s)
				if active_m and not (active_m is ShaderMaterial):
					mi.set_surface_override_material(s, get_lit_prop_material(active_m))
	for child in node.get_children():
		apply_headlight_materials_to_node(child)

static func _apply_hl_to_mat(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("hl_left_pos", _hl_left_pos)
	mat.set_shader_parameter("hl_right_pos", _hl_right_pos)
	mat.set_shader_parameter("hl_dir", _hl_dir)
	mat.set_shader_parameter("hl_intensity", _hl_intensity)
	mat.set_shader_parameter("hl_color", _hl_color)
	mat.set_shader_parameter("hl_range", _hl_range)

static func update_headlight_uniforms(
	left_pos: Vector3,
	right_pos: Vector3,
	dir: Vector3,
	intensity: float,
	hl_color: Color = Color(1.0, 0.94, 0.78, 1.0),
	hl_range: float = 68.0
) -> void:
	_hl_left_pos = left_pos
	_hl_right_pos = right_pos
	_hl_dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	_hl_intensity = intensity
	_hl_color = hl_color
	_hl_range = hl_range
	for m in _materials.values():
		if m is ShaderMaterial:
			_apply_hl_to_mat(m as ShaderMaterial)
	for cm in _converted_mats.values():
		if cm is ShaderMaterial:
			_apply_hl_to_mat(cm as ShaderMaterial)

static func _make_tall_grass_mat() -> ShaderMaterial:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var v := float(y) / float(sz - 1)
		var h := 1.0 - v
		for x in range(sz):
			var u := float(x) / float(sz - 1)
			var alpha := 0.0
			var blade_tint := 0.72 + 0.30 * h
			for b_i in range(7):
				var bx := 0.10 + float(b_i) * 0.132 + 0.04 * sin(float(b_i) * 2.1)
				var lean := sin(float(b_i) * 1.7 + 0.4) * 0.14
				var cx := bx + lean * h * h
				var half_w := lerpf(0.068, 0.008, clampf(h, 0.0, 1.0))
				var max_h := 0.68 + 0.28 * _tex_hash(b_i, 3, 41)
				if h <= max_h and absf(u - cx) <= half_w:
					alpha = 1.0
					blade_tint = lerpf(0.62, 1.06, clampf(h / max_h, 0.0, 1.0))
			var col := Color(0.22 * blade_tint, 0.42 * blade_tint, 0.14 * blade_tint, alpha)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color(0.95, 0.98, 0.88, 1.0))
	mat.set_shader_parameter("roughness_val", 0.88)
	mat.set_shader_parameter("metallic_val", 0.0)
	return mat

static func _make_stop_sign_mat() -> ShaderMaterial:
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var v := float(y) / float(sz - 1)
		var dy := absf(v - 0.5)
		for x in range(sz):
			var u := float(x) / float(sz - 1)
			var dx := absf(u - 0.5)
			var oct_r := maxf(maxf(dx, dy), (dx + dy) * 0.7071)
			var col := Color(0.68, 0.11, 0.09, 1.0)
			if oct_r > 0.47:
				col = Color(0.22, 0.22, 0.24, 1.0)
			elif oct_r > 0.415:
				col = Color(0.86, 0.85, 0.80, 1.0)
			else:
				# Белые буквы STOP в центре красного октагона
				var in_letter := false
				if v >= 0.36 and v <= 0.64:
					# S
					if u >= 0.14 and u <= 0.28:
						if v <= 0.41 or v >= 0.59 or absf(v - 0.50) <= 0.025 or (v < 0.50 and u <= 0.19) or (v > 0.50 and u >= 0.23):
							in_letter = true
					# T
					elif u >= 0.32 and u <= 0.48:
						if v <= 0.41 or absf(u - 0.40) <= 0.03:
							in_letter = true
					# O
					elif u >= 0.52 and u <= 0.68:
						if v <= 0.41 or v >= 0.59 or u <= 0.56 or u >= 0.64:
							in_letter = true
					# P
					elif u >= 0.72 and u <= 0.86:
						if u <= 0.765 or (v <= 0.52 and (v <= 0.41 or v >= 0.47 or u >= 0.815)):
							in_letter = true
				if in_letter:
					col = Color(0.92, 0.91, 0.86, 1.0)
			var rust := _tex_hash(floori(float(x) / 4.0), floori(float(y) / 4.0), 89)
			if rust > 0.75:
				col = col.lerp(Color(0.26, 0.16, 0.10, 1.0), (rust - 0.75) * 2.4)
			var grit := 0.86 + 0.14 * _tex_hash(x, y, 53)
			img.set_pixel(x, y, Color(col.r * grit, col.g * grit, col.b * grit, 1.0))
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color.WHITE)
	mat.set_shader_parameter("roughness_val", 0.52)
	mat.set_shader_parameter("metallic_val", 0.32)
	return mat

static func set_night_window_boost(boost: float) -> void:
	_night_window_boost = clampf(boost, 0.0, 1.5)
	for key: String in ["building_factory", "building_brick", "building_burnt_factory", "building_burnt_brick"]:
		if _materials.has(key):
			var sm: ShaderMaterial = _materials[key] as ShaderMaterial
			if sm:
				sm.set_shader_parameter("night_window_boost", _night_window_boost)

static func get_unit_box_mesh(mat_key: String) -> BoxMesh:
	var cache_key := "box_" + mat_key
	if _meshes.has(cache_key):
		return _meshes[cache_key] as BoxMesh
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = get_material(mat_key)
	_meshes[cache_key] = box
	return box

static func get_boulder_mesh() -> ArrayMesh:
	if _meshes.has("boulder"):
		return _meshes["boulder"] as ArrayMesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings := 7
	var segs := 10
	for r in range(rings):
		var v0 := float(r) / float(rings)
		var v1 := float(r + 1) / float(rings)
		var phi0 := v0 * PI
		var phi1 := v1 * PI
		for s in range(segs):
			var u0 := float(s) / float(segs)
			var u1 := float(s + 1) / float(segs)
			var th0 := u0 * TAU
			var th1 := u1 * TAU

			var p00 := _boulder_point(phi0, th0)
			var p10 := _boulder_point(phi0, th1)
			var p11 := _boulder_point(phi1, th1)
			var p01 := _boulder_point(phi1, th0)

			if r > 0:
				st.set_uv(Vector2(u0, v0))
				st.add_vertex(p00)
				st.set_uv(Vector2(u1, v1))
				st.add_vertex(p11)
				st.set_uv(Vector2(u1, v0))
				st.add_vertex(p10)
			if r < rings - 1:
				st.set_uv(Vector2(u0, v0))
				st.add_vertex(p00)
				st.set_uv(Vector2(u0, v1))
				st.add_vertex(p01)
				st.set_uv(Vector2(u1, v1))
				st.add_vertex(p11)

	st.generate_normals()
	var mesh := st.commit()
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, get_material("rock"))
	_meshes["boulder"] = mesh
	return mesh

static func _boulder_point(phi: float, theta: float) -> Vector3:
	var sin_p := sin(phi)
	var dir := Vector3(sin_p * cos(theta), cos(phi), sin_p * sin(theta))
	var disp := 1.0 + 0.18 * sin(dir.x * 4.3 + 0.7) * cos(dir.z * 3.7 - 0.4) + 0.12 * cos(dir.y * 5.1 + dir.x * 2.9)
	var p := dir * disp
	p.y *= 0.72
	return p

static func get_pine_tree_mesh() -> Mesh:
	if _meshes.has("pine_tree"):
		return _meshes["pine_tree"] as Mesh
	var gen_scene := load("res://levels/chunks/Generator.tscn") as PackedScene
	if gen_scene:
		var inst := gen_scene.instantiate()
		var mm_node := inst.get_node_or_null("MultiMeshInstance3D") as MultiMeshInstance3D
		if mm_node and mm_node.multimesh and mm_node.multimesh.mesh:
			var mesh_copy := mm_node.multimesh.mesh.duplicate() as Mesh
			if mesh_copy:
				for s in range(mesh_copy.get_surface_count()):
					var sm := mesh_copy.surface_get_material(s)
					if sm:
						mesh_copy.surface_set_material(s, get_lit_prop_material(sm))
			_meshes["pine_tree"] = mesh_copy
			inst.free()
			return mesh_copy
		inst.free()
	return null

static func get_mossy_boulder_mesh() -> ArrayMesh:
	if _meshes.has("mossy_boulder"):
		return _meshes["mossy_boulder"] as ArrayMesh
	var base := get_boulder_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as ArrayMesh
	if dup and dup.get_surface_count() > 0:
		dup.surface_set_material(0, get_material("mossy_rock"))
	_meshes["mossy_boulder"] = dup
	return dup

static func get_log_mesh() -> CylinderMesh:
	if _meshes.has("fallen_log"):
		return _meshes["fallen_log"] as CylinderMesh
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.34
	cyl.bottom_radius = 0.44
	cyl.height = 5.2
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.material = get_material("bark")
	_meshes["fallen_log"] = cyl
	return cyl

static func get_shrub_mesh() -> ArrayMesh:
	if _meshes.has("shrub"):
		return _meshes["shrub"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes := 3
	for i in range(planes):
		var ang := float(i) * (PI / float(planes))
		var dx := cos(ang) * 0.85
		var dz := sin(ang) * 0.85
		var p0 := Vector3(-dx, 0.0, -dz)
		var p1 := Vector3(dx, 0.0, dz)
		var p2 := Vector3(dx * 0.78, 1.15, dz * 0.78)
		var p3 := Vector3(-dx * 0.78, 1.15, -dz * 0.78)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 0)); st.add_vertex(p1)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 0)); st.add_vertex(p0)
		st.set_uv(Vector2(1, 1)); st.add_vertex(p2)
		st.set_uv(Vector2(0, 1)); st.add_vertex(p3)
	st.generate_normals()
	var mesh := st.commit()
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, get_material("shrub_foliage"))
	_meshes["shrub"] = mesh
	return mesh

static func get_pylon_mesh() -> ArrayMesh:
	if _meshes.has("pylon"):
		return _meshes["pylon"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Vertical pole box + horizontal crossarm
	_append_box(st, Vector3(0.0, 3.6, 0.0), Vector3(0.24, 7.2, 0.24))
	_append_box(st, Vector3(0.0, 6.7, 0.0), Vector3(2.4, 0.16, 0.16))
	st.generate_normals()
	var mesh := st.commit()
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, get_material("bark"))
	_meshes["pylon"] = mesh
	return mesh

static func _append_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var c := center
	var corners := [
		c + Vector3(-h.x, -h.y, -h.z), c + Vector3(h.x, -h.y, -h.z),
		c + Vector3(h.x, h.y, -h.z), c + Vector3(-h.x, h.y, -h.z),
		c + Vector3(-h.x, -h.y, h.z), c + Vector3(h.x, -h.y, h.z),
		c + Vector3(h.x, h.y, h.z), c + Vector3(-h.x, h.y, h.z)
	]
	var faces := [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7],
		[1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]
	]
	for f in faces:
		st.set_uv(Vector2(0, 0)); st.add_vertex(corners[f[0]])
		st.set_uv(Vector2(1, 0)); st.add_vertex(corners[f[1]])
		st.set_uv(Vector2(1, 1)); st.add_vertex(corners[f[2]])
		st.set_uv(Vector2(0, 0)); st.add_vertex(corners[f[0]])
		st.set_uv(Vector2(1, 1)); st.add_vertex(corners[f[2]])
		st.set_uv(Vector2(0, 1)); st.add_vertex(corners[f[3]])


static func _append_box_xform(st: SurfaceTool, center: Vector3, size: Vector3, euler_rot: Vector3) -> void:
	var h := size * 0.5
	var b := Basis.from_euler(euler_rot)
	var corners := [
		center + b * Vector3(-h.x, -h.y, -h.z), center + b * Vector3(h.x, -h.y, -h.z),
		center + b * Vector3(h.x, h.y, -h.z), center + b * Vector3(-h.x, h.y, -h.z),
		center + b * Vector3(-h.x, -h.y, h.z), center + b * Vector3(h.x, -h.y, h.z),
		center + b * Vector3(h.x, h.y, h.z), center + b * Vector3(-h.x, h.y, h.z)
	]
	var faces := [
		[0, 1, 2, 3], [5, 4, 7, 6], [4, 0, 3, 7],
		[1, 5, 6, 2], [3, 2, 6, 7], [4, 5, 1, 0]
	]
	for f in faces:
		st.set_uv(Vector2(0, 0)); st.add_vertex(corners[f[0]])
		st.set_uv(Vector2(1, 0)); st.add_vertex(corners[f[1]])
		st.set_uv(Vector2(1, 1)); st.add_vertex(corners[f[2]])
		st.set_uv(Vector2(0, 0)); st.add_vertex(corners[f[0]])
		st.set_uv(Vector2(1, 1)); st.add_vertex(corners[f[2]])
		st.set_uv(Vector2(0, 1)); st.add_vertex(corners[f[3]])


static func _commit_surface(arr: ArrayMesh, st: SurfaceTool, mat_key: String) -> void:
	st.generate_normals()
	var res := st.commit()
	if res and res.get_surface_count() > 0:
		var idx: int = arr.get_surface_count()
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res.surface_get_arrays(0))
		arr.surface_set_material(idx, get_material(mat_key))


static func _tex_hash(x: int, y: int, seed_val: int) -> float:
	var n := sin(float(x) * 12.9898 + float(y) * 78.233 + float(seed_val) * 37.719) * 43758.5453
	return n - floorf(n)


static func _make_billboard_poster_mat(variant: int) -> ShaderMaterial:
	var w := 256
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v := float(y) / float(h - 1)
		for x in range(w):
			var u := float(x) / float(w - 1)
			var n := _tex_hash(x, y, variant * 17 + 3)
			var rust_n := _tex_hash(floori(float(x) / 6.0), floori(float(y) / 6.0), variant * 29 + 11)
			var grime := 0.82 + 0.18 * n
			var col := Color(0.55, 0.50, 0.44, 1.0)

			match variant % 4:
				0:
					# Заброшенная ретро-вывеска топлива: выцветший красный + кремовые полосы
					col = Color(0.54, 0.16, 0.13) if v < 0.56 else Color(0.72, 0.65, 0.52)
					if absf(v - 0.56) < 0.045:
						col = Color(0.14, 0.13, 0.12)
					# Стилизованные блоки текста (контрастные строчки без искажений шрифта)
					if u > 0.10 and u < 0.68 and v > 0.18 and v < 0.36 and (int(u * 32.0) % 5 != 0):
						col = Color(0.84, 0.78, 0.66)
					if u > 0.10 and u < 0.52 and v > 0.68 and v < 0.82 and (int(u * 26.0) % 4 != 0):
						col = Color(0.24, 0.18, 0.14)
					if Vector2((u - 0.83) * 2.0, v - 0.38).length() < 0.24:
						col = Color(0.84, 0.62, 0.16)
				1:
					# Карантинная охра-жёлтая лента с предупреждающим знаком
					col = Color(0.70, 0.54, 0.16)
					if v < 0.16 or v > 0.84:
						var diag := int((u * 16.0 + v * 4.0) * 1.4) % 2
						col = Color(0.12, 0.12, 0.12) if diag == 0 else Color(0.74, 0.56, 0.14)
					var tri_y := 1.0 - v
					if absf(u - 0.22) < (0.16 - absf(tri_y - 0.48) * 0.26) and tri_y > 0.25 and tri_y < 0.76:
						col = Color(0.14, 0.14, 0.14)
					if u > 0.44 and u < 0.90 and ((v > 0.28 and v < 0.44) or (v > 0.52 and v < 0.66)) and (int(u * 28.0) % 6 != 0):
						col = Color(0.16, 0.15, 0.13)
				2:
					# Военный щит комендантского пункта: оливково-серый + армейский шеврон
					col = Color(0.22, 0.25, 0.20)
					if u > 0.04 and u < 0.96 and (absf(v - 0.08) < 0.025 or absf(v - 0.92) < 0.025):
						col = Color(0.68, 0.64, 0.56)
					var dv := absf(v - 0.50)
					if u > 0.72 and u < 0.90 and (absf(u - 0.81 - dv * 0.30) < 0.03 or absf(u - 0.81 + dv * 0.30) < 0.03):
						col = Color(0.76, 0.34, 0.14)
					if u > 0.10 and u < 0.66 and ((v > 0.26 and v < 0.42) or (v > 0.54 and v < 0.68)) and (int(u * 24.0) % 5 != 0):
						col = Color(0.72, 0.70, 0.62)
				_:
					# Потрёпанный придорожный мотель / перевал: выцветший сине-серо-бирюзовый
					col = Color(0.18, 0.27, 0.32) if v < 0.62 else Color(0.42, 0.32, 0.22)
					if u > 0.12 and u < 0.88 and v > 0.22 and v < 0.40 and (int(u * 30.0) % 6 != 0):
						col = Color(0.84, 0.68, 0.38)
					if v > 0.62 and v < 0.66:
						col = Color(0.78, 0.74, 0.64)

			# Выцветание, ржавчина по краям и ободранные полосы бумаги
			var edge_dist := minf(minf(u, 1.0 - u), minf(v, 1.0 - v))
			var rust_mask := clampf((0.12 - edge_dist) * 6.5 + (rust_n - 0.55) * 0.8, 0.0, 0.85)
			col = col.lerp(Color(0.28, 0.18, 0.12), rust_mask * 0.75)
			# Потёки грязи сверху вниз
			var streak := _tex_hash(floori(float(x) / 3.0), 1, variant * 41 + 9)
			if streak > 0.84 and v < (streak - 0.35):
				col = col.lerp(Color(0.14, 0.12, 0.10), 0.48)
			col = Color(col.r * grime, col.g * grime, col.b * grime, 1.0)
			img.set_pixel(x, y, col)

	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color(0.95, 0.94, 0.92, 1.0))
	mat.set_shader_parameter("roughness_val", 0.86)
	mat.set_shader_parameter("metallic_val", 0.12)
	return mat


static func _make_sign_mat(kind: String) -> ShaderMaterial:
	var w := 128
	var h := 128 if kind != "gantry" else 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v := float(y) / float(h - 1)
		for x in range(w):
			var u := float(x) / float(w - 1)
			var n := _tex_hash(x, y, 71)
			var col := Color(0.75, 0.62, 0.18)
			if kind == "warn":
				col = Color(0.84, 0.62, 0.14)
				if minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) < 0.09:
					col = Color(0.12, 0.12, 0.12)
				if absf(u - 0.5) < 0.06 and ((v > 0.22 and v < 0.58) or (v > 0.68 and v < 0.80)):
					col = Color(0.12, 0.11, 0.10)
			elif kind == "hazard":
				col = Color(0.68, 0.16, 0.14)
				if minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) < 0.10:
					col = Color(0.78, 0.76, 0.72)
				if absf(v - 0.5) < 0.12 and u > 0.18 and u < 0.82:
					col = Color(0.82, 0.80, 0.76)
			else:
				# "gantry" highway shield sign (muted green-teal + white arrow & frame)
				col = Color(0.13, 0.30, 0.22)
				if minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) < 0.08:
					col = Color(0.76, 0.78, 0.74)
				if u > 0.14 and u < 0.70 and ((v > 0.24 and v < 0.42) or (v > 0.54 and v < 0.68)) and (int(u * 22.0) % 5 != 0):
					col = Color(0.80, 0.82, 0.78)
				if u > 0.76 and u < 0.90 and absf(v - 0.5) < (0.28 - (u - 0.76) * 1.6):
					col = Color(0.84, 0.84, 0.78)

			var rust := _tex_hash(floori(float(x) / 5.0), floori(float(y) / 5.0), 19)
			if rust > 0.74:
				col = col.lerp(Color(0.28, 0.18, 0.12), (rust - 0.74) * 2.2)
			var g := 0.84 + 0.16 * n
			img.set_pixel(x, y, Color(col.r * g, col.g * g, col.b * g, 1.0))

	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", tex)
	mat.set_shader_parameter("albedo_tint", Color.WHITE)
	mat.set_shader_parameter("roughness_val", 0.58)
	mat.set_shader_parameter("metallic_val", 0.35)
	return mat


static func _make_tinted_headlight_mat(orig_mat: Material, tint_mul: Color, fallback_col: Color) -> ShaderMaterial:
	var base := get_lit_prop_material(orig_mat)
	var dup := base.duplicate() as ShaderMaterial
	var cur: Variant = dup.get_shader_parameter("albedo_tint")
	if cur is Color:
		var c: Color = cur
		# Подкрашиваем ветви холодным инеем
		dup.set_shader_parameter("albedo_tint", Color(
			lerpf(c.r * tint_mul.r, fallback_col.r, 0.42),
			lerpf(c.g * tint_mul.g, fallback_col.g, 0.42),
			lerpf(c.b * tint_mul.b, fallback_col.b, 0.48),
			c.a
		))
	else:
		dup.set_shader_parameter("albedo_tint", fallback_col)
	_apply_hl_to_mat(dup)
	_converted_mats["tinted_" + str(dup.get_instance_id())] = dup
	return dup


static func get_snow_pine_tree_mesh() -> Mesh:
	if _meshes.has("snow_pine_tree"):
		return _meshes["snow_pine_tree"] as Mesh
	var base := get_pine_tree_mesh()
	if base == null:
		return null
	var snow_mesh := base.duplicate() as Mesh
	if snow_mesh:
		for s in range(snow_mesh.get_surface_count()):
			var sm := snow_mesh.surface_get_material(s)
			if sm:
				var frost_col := Color(0.72, 0.79, 0.85, 1.0) if s > 0 else Color(0.58, 0.60, 0.64, 1.0)
				snow_mesh.surface_set_material(s, _make_tinted_headlight_mat(sm, Color(0.82, 0.92, 1.08), frost_col))
	_meshes["snow_pine_tree"] = snow_mesh
	return snow_mesh


static func get_snow_boulder_mesh() -> ArrayMesh:
	if _meshes.has("snow_boulder"):
		return _meshes["snow_boulder"] as ArrayMesh
	var base := get_boulder_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as ArrayMesh
	if dup and dup.get_surface_count() > 0:
		dup.surface_set_material(0, get_material("snow_rock"))
	_meshes["snow_boulder"] = dup
	return dup


static func get_snow_bank_mesh() -> ArrayMesh:
	if _meshes.has("snow_bank"):
		return _meshes["snow_bank"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 6
	var segs := 10
	for r in range(rings):
		var v0 := float(r) / float(rings)
		var v1 := float(r + 1) / float(rings)
		var phi0 := v0 * PI * 0.55
		var phi1 := v1 * PI * 0.55
		for s in range(segs):
			var u0 := float(s) / float(segs)
			var u1 := float(s + 1) / float(segs)
			var th0 := u0 * TAU
			var th1 := u1 * TAU
			var p00 := Vector3(sin(phi0) * cos(th0) * 2.4, cos(phi0) * 0.72, sin(phi0) * sin(th0) * 1.25)
			var p10 := Vector3(sin(phi0) * cos(th1) * 2.4, cos(phi0) * 0.72, sin(phi0) * sin(th1) * 1.25)
			var p11 := Vector3(sin(phi1) * cos(th1) * 2.4, cos(phi1) * 0.72, sin(phi1) * sin(th1) * 1.25)
			var p01 := Vector3(sin(phi1) * cos(th0) * 2.4, cos(phi1) * 0.72, sin(phi1) * sin(th0) * 1.25)
			if r > 0:
				st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
				st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
				st.set_uv(Vector2(u1, v0)); st.add_vertex(p10)
			if r < rings - 1:
				st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
				st.set_uv(Vector2(u0, v1)); st.add_vertex(p01)
				st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
	st.generate_normals()
	var mesh := st.commit()
	if mesh and mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, get_material("snow_bank"))
	_meshes["snow_bank"] = mesh
	return mesh


static func get_billboard_frame_mesh(variant: int = 0) -> ArrayMesh:
	var v_idx := clampi(variant, 0, 3)
	var key := "billboard_%d" % v_idx
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh

	# Поверхность 0: металлический каркас + подложка; Поверхность 1: выцветший постер
	var arr_mesh := ArrayMesh.new()
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_frame, Vector3(-2.35, 3.6, -0.14), Vector3(0.24, 7.2, 0.24))
	_append_box(st_frame, Vector3(2.35, 3.6, -0.14), Vector3(0.24, 7.2, 0.24))
	_append_box(st_frame, Vector3(0.0, 4.15, 0.0), Vector3(6.9, 3.35, 0.14))
	_append_box(st_frame, Vector3(0.0, 2.30, 0.34), Vector3(6.6, 0.12, 0.55))
	st_frame.generate_normals()
	var frame_res := st_frame.commit()
	if frame_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, frame_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(0, get_material("pole_steel"))

	var st_poster := SurfaceTool.new()
	st_poster.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 3.32
	var y_lo := 2.58
	var y_hi := 5.72
	var z_f := 0.09
	# Передняя грань обращена к +Z (в сторону приближающейся машины/камеры)
	var v0 := Vector3(-hw, y_lo, z_f)
	var v1 := Vector3(hw, y_lo, z_f)
	var v2 := Vector3(hw, y_hi, z_f)
	var v3 := Vector3(-hw, y_hi, z_f)
	st_poster.set_uv(Vector2(0, 1)); st_poster.add_vertex(v0)
	st_poster.set_uv(Vector2(1, 1)); st_poster.add_vertex(v1)
	st_poster.set_uv(Vector2(1, 0)); st_poster.add_vertex(v2)
	st_poster.set_uv(Vector2(0, 1)); st_poster.add_vertex(v0)
	st_poster.set_uv(Vector2(1, 0)); st_poster.add_vertex(v2)
	st_poster.set_uv(Vector2(0, 0)); st_poster.add_vertex(v3)
	st_poster.generate_normals()
	var post_res := st_poster.commit()
	if post_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, post_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(1, get_material("billboard_%d" % v_idx))

	_meshes[key] = arr_mesh
	return arr_mesh


static func get_overhead_gantry_mesh() -> ArrayMesh:
	if _meshes.has("overhead_gantry"):
		return _meshes["overhead_gantry"] as ArrayMesh
	var arr_mesh := ArrayMesh.new()
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Две мощные стальные фермы на обочинах X = ±19.0 и двойная поперечная балка
	_append_box(st_steel, Vector3(-19.0, 4.7, 0.0), Vector3(0.74, 9.4, 0.74))
	_append_box(st_steel, Vector3(19.0, 4.7, 0.0), Vector3(0.74, 9.4, 0.74))
	_append_box(st_steel, Vector3(0.0, 8.95, 0.0), Vector3(38.8, 0.70, 0.65))
	_append_box(st_steel, Vector3(0.0, 7.35, 0.0), Vector3(38.8, 0.45, 0.50))
	for sx in [-12.0, -4.0, 4.0, 12.0]:
		_append_box(st_steel, Vector3(sx, 8.15, 0.0), Vector3(0.26, 1.65, 0.36))
	st_steel.generate_normals()
	var steel_res := st_steel.commit()
	if steel_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, steel_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(0, get_material("pole_steel"))

	var st_signs := SurfaceTool.new()
	st_signs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cx in [-7.2, 7.2]:
		var sw := 5.0
		var y_lo := 6.35
		var y_hi := 9.05
		var z_f := 0.38
		var p0 := Vector3(cx - sw, y_lo, z_f)
		var p1 := Vector3(cx + sw, y_lo, z_f)
		var p2 := Vector3(cx + sw, y_hi, z_f)
		var p3 := Vector3(cx - sw, y_hi, z_f)
		st_signs.set_uv(Vector2(0, 1)); st_signs.add_vertex(p0)
		st_signs.set_uv(Vector2(1, 1)); st_signs.add_vertex(p1)
		st_signs.set_uv(Vector2(1, 0)); st_signs.add_vertex(p2)
		st_signs.set_uv(Vector2(0, 1)); st_signs.add_vertex(p0)
		st_signs.set_uv(Vector2(1, 0)); st_signs.add_vertex(p2)
		st_signs.set_uv(Vector2(0, 0)); st_signs.add_vertex(p3)
	st_signs.generate_normals()
	var sign_res := st_signs.commit()
	if sign_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sign_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(1, get_material("gantry_sign"))

	_meshes["overhead_gantry"] = arr_mesh
	return arr_mesh


static func get_road_sign_mesh(is_hazard: bool = false) -> ArrayMesh:
	var key := "road_sign_hazard" if is_hazard else "road_sign_warn"
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr_mesh := ArrayMesh.new()
	var st_post := SurfaceTool.new()
	st_post.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_post, Vector3(0.0, 1.35, 0.0), Vector3(0.10, 2.70, 0.10))
	_append_box(st_post, Vector3(0.0, 2.45, 0.05), Vector3(0.98, 0.98, 0.03))
	st_post.generate_normals()
	var post_res := st_post.commit()
	if post_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, post_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(0, get_material("pole_steel"))

	var st_plate := SurfaceTool.new()
	st_plate.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.48
	var yc := 2.45
	var zf := 0.075
	var v0 := Vector3(-hw, yc - hw, zf)
	var v1 := Vector3(hw, yc - hw, zf)
	var v2 := Vector3(hw, yc + hw, zf)
	var v3 := Vector3(-hw, yc + hw, zf)
	st_plate.set_uv(Vector2(0, 1)); st_plate.add_vertex(v0)
	st_plate.set_uv(Vector2(1, 1)); st_plate.add_vertex(v1)
	st_plate.set_uv(Vector2(1, 0)); st_plate.add_vertex(v2)
	st_plate.set_uv(Vector2(0, 1)); st_plate.add_vertex(v0)
	st_plate.set_uv(Vector2(1, 0)); st_plate.add_vertex(v2)
	st_plate.set_uv(Vector2(0, 0)); st_plate.add_vertex(v3)
	st_plate.generate_normals()
	var plate_res := st_plate.commit()
	if plate_res:
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plate_res.surface_get_arrays(0))
		arr_mesh.surface_set_material(1, get_material("road_sign_hazard" if is_hazard else "road_sign_warn"))

	_meshes[key] = arr_mesh
	return arr_mesh


static func get_toxic_pine_tree_mesh() -> Mesh:
	if _meshes.has("toxic_pine_tree"):
		return _meshes["toxic_pine_tree"] as Mesh
	var base := get_pine_tree_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as Mesh
	if dup:
		for s in range(dup.get_surface_count()):
			var sm := dup.surface_get_material(s)
			if sm:
				var col := Color(0.46, 0.62, 0.24, 1.0) if s > 0 else Color(0.32, 0.36, 0.26, 1.0)
				dup.surface_set_material(s, _make_tinted_headlight_mat(sm, Color(0.75, 0.98, 0.45), col))
	_meshes["toxic_pine_tree"] = dup
	return dup


static func get_scorched_pine_tree_mesh() -> Mesh:
	if _meshes.has("scorched_pine_tree"):
		return _meshes["scorched_pine_tree"] as Mesh
	var base := get_pine_tree_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as Mesh
	if dup:
		for s in range(dup.get_surface_count()):
			var sm := dup.surface_get_material(s)
			if sm:
				var col := Color(0.26, 0.22, 0.20, 1.0) if s > 0 else Color(0.20, 0.16, 0.14, 1.0)
				dup.surface_set_material(s, _make_tinted_headlight_mat(sm, Color(0.45, 0.36, 0.30), col))
	_meshes["scorched_pine_tree"] = dup
	return dup


static func get_toxic_boulder_mesh() -> ArrayMesh:
	if _meshes.has("toxic_boulder"):
		return _meshes["toxic_boulder"] as ArrayMesh
	var base := get_boulder_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as ArrayMesh
	if dup and dup.get_surface_count() > 0:
		dup.surface_set_material(0, get_material("toxic_rock"))
	_meshes["toxic_boulder"] = dup
	return dup


static func get_scorched_boulder_mesh() -> ArrayMesh:
	if _meshes.has("scorched_boulder"):
		return _meshes["scorched_boulder"] as ArrayMesh
	var base := get_boulder_mesh()
	if base == null:
		return null
	var dup := base.duplicate() as ArrayMesh
	if dup and dup.get_surface_count() > 0:
		dup.surface_set_material(0, get_material("scorched_rock"))
	_meshes["scorched_boulder"] = dup
	return dup


static func _append_ramp_side_curb(
	st: SurfaceTool,
	x_in: float,
	x_out: float,
	z_top: float,
	z_bot: float,
	y_top: float,
	y_bot: float,
	curb_h: float
) -> void:
	var xa := minf(x_in, x_out)
	var xb := maxf(x_in, x_out)
	var bt_l := Vector3(xa, y_top, z_top)
	var bt_r := Vector3(xb, y_top, z_top)
	var bb_l := Vector3(xa, y_bot, z_bot)
	var bb_r := Vector3(xb, y_bot, z_bot)
	var tt_l := Vector3(xa, y_top + curb_h, z_top)
	var tt_r := Vector3(xb, y_top + curb_h, z_top)
	var tb_l := Vector3(xa, y_bot + curb_h * 0.72, z_bot)
	var tb_r := Vector3(xb, y_bot + curb_h * 0.72, z_bot)
	var quads := [
		[tt_l, tt_r, tb_r, tb_l],
		[bt_l, bb_l, tb_l, tt_l],
		[bb_r, bt_r, tt_r, tb_r],
		[bt_l, bt_r, tt_r, tt_l],
		[bb_r, bb_l, tb_l, tb_r],
	]
	for q: Array in quads:
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(q[0] as Vector3)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(q[1] as Vector3)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(q[2] as Vector3)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(q[0] as Vector3)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(q[2] as Vector3)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(q[3] as Vector3)


static func get_stunt_ramp_mesh(width: float = 8.4, height: float = 2.6, length: float = 11.5) -> ArrayMesh:
	var key := "stunt_ramp_%.1f_%.1f_%.1f" % [width, height, length]
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr := ArrayMesh.new()
	var hw := width * 0.5
	var hl := length * 0.5
	# Wedge approaching from +Z (y=0) climbing toward -Z (y=height)
	var b_fl := Vector3(-hw, 0.0, -hl)
	var b_fr := Vector3(hw, 0.0, -hl)
	var b_bl := Vector3(-hw, 0.0, hl)
	var b_br := Vector3(hw, 0.0, hl)
	var t_fl := Vector3(-hw, height, -hl)
	var t_fr := Vector3(hw, height, -hl)

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Back wall at -Z (normal points -Z)
	st_body.set_uv(Vector2(0, 0)); st_body.add_vertex(b_fl)
	st_body.set_uv(Vector2(1, 0)); st_body.add_vertex(b_fr)
	st_body.set_uv(Vector2(1, 1)); st_body.add_vertex(t_fr)
	st_body.set_uv(Vector2(0, 0)); st_body.add_vertex(b_fl)
	st_body.set_uv(Vector2(1, 1)); st_body.add_vertex(t_fr)
	st_body.set_uv(Vector2(0, 1)); st_body.add_vertex(t_fl)
	# Left & Right triangle sides
	st_body.set_uv(Vector2(0, 0)); st_body.add_vertex(b_bl)
	st_body.set_uv(Vector2(1, 0)); st_body.add_vertex(b_fl)
	st_body.set_uv(Vector2(1, 1)); st_body.add_vertex(t_fl)
	st_body.set_uv(Vector2(0, 0)); st_body.add_vertex(b_fr)
	st_body.set_uv(Vector2(1, 0)); st_body.add_vertex(b_br)
	st_body.set_uv(Vector2(0, 1)); st_body.add_vertex(t_fr)
	# Stepped concrete flank buttresses along exterior sides
	for sgn: float in [-1.0, 1.0]:
		_append_box(st_body, Vector3(sgn * (hw + 0.14), height * 0.22, hl * 0.05), Vector3(0.28, height * 0.44, length * 0.72))
		_append_box(st_body, Vector3(sgn * (hw + 0.14), height * 0.46, -hl * 0.42), Vector3(0.30, height * 0.92, length * 0.28))
	st_body.generate_normals()
	var res_body := st_body.commit()
	if res_body:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res_body.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("concrete_rubble"))

	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	st_deck.set_uv(Vector2(0, 0)); st_deck.add_vertex(t_fl + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 0)); st_deck.add_vertex(t_fr + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 1)); st_deck.add_vertex(b_br + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(0, 0)); st_deck.add_vertex(t_fl + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 1)); st_deck.add_vertex(b_br + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(0, 1)); st_deck.add_vertex(b_bl + Vector3(0, 0.02, 0))
	# Beveled entry apron at +Z
	var ap_l := Vector3(-hw, 0.002, hl + 0.42)
	var ap_r := Vector3(hw, 0.002, hl + 0.42)
	st_deck.set_uv(Vector2(0, 0)); st_deck.add_vertex(b_bl + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 0)); st_deck.add_vertex(b_br + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 0.12)); st_deck.add_vertex(ap_r)
	st_deck.set_uv(Vector2(0, 0)); st_deck.add_vertex(b_bl + Vector3(0, 0.02, 0))
	st_deck.set_uv(Vector2(1, 0.12)); st_deck.add_vertex(ap_r)
	st_deck.set_uv(Vector2(0, 0.12)); st_deck.add_vertex(ap_l)
	# Rear lip warning strip
	_append_box(st_deck, Vector3(0.0, height - 0.18, -hl - 0.02), Vector3(width * 0.96, 0.34, 0.08))
	st_deck.generate_normals()
	var res_deck := st_deck.commit()
	if res_deck:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res_deck.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("hazard_stripe"))

	var st_curbs := SurfaceTool.new()
	st_curbs.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_ramp_side_curb(st_curbs, -hw - 0.16, -hw + 0.04, -hl, hl, height, 0.02, 0.24)
	_append_ramp_side_curb(st_curbs, hw - 0.04, hw + 0.16, -hl, hl, height, 0.02, 0.24)
	for px: float in [-hw + 0.45, 0.0, hw - 0.45]:
		_append_box(st_curbs, Vector3(px, height * 0.5, -hl - 0.10), Vector3(0.24, height * 0.94, 0.22))
	_append_box(st_curbs, Vector3(0.0, height * 0.72, -hl - 0.12), Vector3(width * 0.92, 0.22, 0.20))
	st_curbs.generate_normals()
	var res_curbs := st_curbs.commit()
	if res_curbs:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, res_curbs.surface_get_arrays(0))
		arr.surface_set_material(2, get_material("pole_steel"))

	_meshes[key] = arr
	return arr


static func get_smash_gate_mesh() -> ArrayMesh:
	if _meshes.has("smash_gate"):
		return _meshes["smash_gate"] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_frame := SurfaceTool.new()
	st_frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_frame, Vector3(-3.8, 1.15, 0.0), Vector3(0.24, 2.30, 0.24))
	_append_box(st_frame, Vector3(3.8, 1.15, 0.0), Vector3(0.24, 2.30, 0.24))
	_append_box(st_frame, Vector3(0.0, 2.20, 0.0), Vector3(8.0, 0.24, 0.26))
	st_frame.generate_normals()
	var rf := st_frame.commit()
	if rf:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rf.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("pole_steel"))

	var st_bars := SurfaceTool.new()
	st_bars.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_bars, Vector3(0.0, 1.35, 0.0), Vector3(8.2, 0.56, 0.16))
	_append_box(st_bars, Vector3(0.0, 0.62, 0.0), Vector3(8.2, 0.32, 0.16))
	st_bars.generate_normals()
	var rb := st_bars.commit()
	if rb:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rb.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("hazard_stripe"))

	_meshes["smash_gate"] = arr
	return arr


static func _collect_gltf_meshes(
	node: Node,
	parent_xf: Transform3D,
	is_root: bool,
	prefix: String,
	excludes: PackedStringArray,
	out_list: Array[Dictionary]
) -> void:
	var cur_xf: Transform3D = parent_xf
	if is_root:
		cur_xf = Transform3D.IDENTITY
	elif node is Node3D:
		cur_xf = parent_xf * (node as Node3D).transform

	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var n_str: String = String(mi.name)
			var ok: bool = (prefix.is_empty() or n_str.begins_with(prefix))
			if ok:
				for tok: String in excludes:
					if n_str.contains(tok):
						ok = false
						break
			if ok:
				out_list.append({"xf": cur_xf, "mi": mi})

	for ch in node.get_children():
		_collect_gltf_meshes(ch, cur_xf, false, prefix, excludes, out_list)


static func _append_mesh_to_buckets(
	src_mesh: Mesh,
	src_mi: MeshInstance3D,
	xf: Transform3D,
	shift: Vector3,
	scale_mul: float,
	extra_offset: Vector3,
	st_by_mat: Dictionary,
	mat_by_id: Dictionary
) -> void:
	var xf_basis: Basis = xf.basis
	var det: float = xf_basis.determinant()
	if absf(det) < 1e-8:
		return
	var nrm_basis: Basis = xf_basis.inverse().transposed()
	var flip_wind: bool = det < 0.0

	for s in range(src_mesh.get_surface_count()):
		if src_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var raw_mat: Material = src_mi.get_active_material(s) if src_mi != null else src_mesh.surface_get_material(s)
		var lit_mat: Material = get_lit_prop_material(raw_mat)
		if lit_mat == null:
			continue
		var m_id: int = lit_mat.get_instance_id()
		var st: SurfaceTool = null
		if st_by_mat.has(m_id):
			st = st_by_mat[m_id] as SurfaceTool
		else:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st_by_mat[m_id] = st
			mat_by_id[m_id] = lit_mat

		var arrays: Array = src_mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var raw_verts: Variant = arrays[Mesh.ARRAY_VERTEX]
		if not (raw_verts is PackedVector3Array):
			continue
		var verts := raw_verts as PackedVector3Array
		if verts.is_empty():
			continue

		var raw_nrms: Variant = arrays[Mesh.ARRAY_NORMAL]
		var has_nrm: bool = (raw_nrms is PackedVector3Array) and (raw_nrms as PackedVector3Array).size() == verts.size()
		var norms: PackedVector3Array = raw_nrms as PackedVector3Array if has_nrm else PackedVector3Array()

		var raw_uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
		var has_uv: bool = (raw_uvs is PackedVector2Array) and (raw_uvs as PackedVector2Array).size() == verts.size()
		var uvs: PackedVector2Array = raw_uvs as PackedVector2Array if has_uv else PackedVector2Array()

		var raw_idx: Variant = arrays[Mesh.ARRAY_INDEX]
		var idx_arr: PackedInt32Array = raw_idx as PackedInt32Array if (raw_idx is PackedInt32Array) else PackedInt32Array()

		var tri_count: int = floori(float(verts.size()) / 3.0) if idx_arr.is_empty() else floori(float(idx_arr.size()) / 3.0)
		for t_i in range(tri_count):
			var base_i: int = t_i * 3
			var i0: int = base_i if idx_arr.is_empty() else idx_arr[base_i]
			var i1: int = (base_i + 1) if idx_arr.is_empty() else idx_arr[base_i + 1]
			var i2: int = (base_i + 2) if idx_arr.is_empty() else idx_arr[base_i + 2]
			if flip_wind:
				var tmp: int = i1
				i1 = i2
				i2 = tmp
			var p0: Vector3 = ((xf * verts[i0]) + shift) * scale_mul + extra_offset
			var p1: Vector3 = ((xf * verts[i1]) + shift) * scale_mul + extra_offset
			var p2: Vector3 = ((xf * verts[i2]) + shift) * scale_mul + extra_offset

			var face_n: Vector3 = (p2 - p0).cross(p1 - p0)
			face_n = face_n.normalized() if face_n.length_squared() > 1e-8 else Vector3.UP

			var n0: Vector3 = (nrm_basis * norms[i0]).normalized() if has_nrm else face_n
			var n1: Vector3 = (nrm_basis * norms[i1]).normalized() if has_nrm else face_n
			var n2: Vector3 = (nrm_basis * norms[i2]).normalized() if has_nrm else face_n

			var uv0: Vector2 = uvs[i0] if has_uv else Vector2.ZERO
			var uv1: Vector2 = uvs[i1] if has_uv else Vector2.ZERO
			var uv2: Vector2 = uvs[i2] if has_uv else Vector2.ZERO

			st.set_uv(uv0); st.set_normal(n0); st.add_vertex(p0)
			st.set_uv(uv1); st.set_normal(n1); st.add_vertex(p1)
			st.set_uv(uv2); st.set_normal(n2); st.add_vertex(p2)


static func _commit_buckets_to_array_mesh(st_by_mat: Dictionary, mat_by_id: Dictionary) -> ArrayMesh:
	var arr := ArrayMesh.new()
	for m_id in st_by_mat.keys():
		var st := st_by_mat[m_id] as SurfaceTool
		var lit_mat := mat_by_id[m_id] as Material
		if st == null:
			continue
		st.index()
		var sub_mesh: ArrayMesh = st.commit()
		if sub_mesh and sub_mesh.get_surface_count() > 0:
			var surf_idx: int = arr.get_surface_count()
			arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sub_mesh.surface_get_arrays(0))
			if lit_mat:
				arr.surface_set_material(surf_idx, lit_mat)
	return arr


static func _extract_merged_gltf_mesh(
	cache_key: String,
	gltf_path: String,
	scale_mul: float = 1.0,
	name_include_prefix: String = "",
	name_exclude_tokens: PackedStringArray = PackedStringArray(),
	recenter_xz: bool = true,
	ground_min_y: bool = true,
	extra_offset: Vector3 = Vector3.ZERO
) -> ArrayMesh:
	if _meshes.has(cache_key):
		return _meshes[cache_key] as ArrayMesh
	if not ResourceLoader.exists(gltf_path):
		return null
	var packed := ResourceLoader.load(gltf_path, "PackedScene") as PackedScene
	if packed == null:
		return null
	var root: Node = packed.instantiate()
	if root == null:
		return null

	var collected: Array[Dictionary] = []
	_collect_gltf_meshes(root, Transform3D.IDENTITY, true, name_include_prefix, name_exclude_tokens, collected)
	if collected.is_empty():
		root.free()
		return null

	var min_pt := Vector3(INF, INF, INF)
	var max_pt := Vector3(-INF, -INF, -INF)
	var has_pts := false
	for item: Dictionary in collected:
		var xf: Transform3D = item["xf"] as Transform3D
		var mi: MeshInstance3D = item["mi"] as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			if mi.mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			if arrays.is_empty() or not (arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array):
				continue
			var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			for v: Vector3 in verts:
				var p: Vector3 = xf * v
				min_pt = min_pt.min(p)
				max_pt = max_pt.max(p)
				has_pts = true

	if not has_pts:
		root.free()
		return null

	var shift := Vector3(
		-0.5 * (min_pt.x + max_pt.x) if recenter_xz else 0.0,
		-min_pt.y if ground_min_y else 0.0,
		-0.5 * (min_pt.z + max_pt.z) if recenter_xz else 0.0
	)

	var st_by_mat: Dictionary = {}
	var mat_by_id: Dictionary = {}
	for item: Dictionary in collected:
		var xf: Transform3D = item["xf"] as Transform3D
		var mi: MeshInstance3D = item["mi"] as MeshInstance3D
		if mi and mi.mesh:
			_append_mesh_to_buckets(mi.mesh, mi, xf, shift, scale_mul, extra_offset, st_by_mat, mat_by_id)

	var arr := _commit_buckets_to_array_mesh(st_by_mat, mat_by_id)
	root.free()
	if arr.get_surface_count() == 0:
		return null
	_meshes[cache_key] = arr
	return arr


static func get_ph_street_lamp_mesh() -> ArrayMesh:
	if _meshes.has("ph_street_lamp"):
		return _meshes["ph_street_lamp"] as ArrayMesh
	var base := _extract_merged_gltf_mesh(
		"ph_street_lamp_base",
		"res://environment/model/polyhaven/street_lamp_01/street_lamp_01_1k.gltf",
		1.55
	)
	if base == null:
		return null
	var arr := base.duplicate() as ArrayMesh
	if arr:
		var st_glow := SurfaceTool.new()
		st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)
		_append_box(st_glow, Vector3(0.0, 5.42, 0.0), Vector3(0.32, 0.44, 0.32))
		st_glow.generate_normals()
		var g_res := st_glow.commit()
		if g_res and g_res.get_surface_count() > 0:
			var idx: int = arr.get_surface_count()
			arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, g_res.surface_get_arrays(0))
			arr.surface_set_material(idx, get_material("lamp_glow"))
	_meshes["ph_street_lamp"] = arr
	return arr


static func get_ph_concrete_barrier_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_concrete_barrier",
		"res://environment/model/polyhaven/concrete_road_barrier_02/concrete_road_barrier_02_1k.gltf",
		1.45
	)


static func get_ph_barrel_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_barrel",
		"res://environment/model/polyhaven/Barrel_01/Barrel_01_1k.gltf",
		1.35
	)


static func get_ph_blue_barrel_mesh() -> ArrayMesh:
	if _meshes.has("ph_blue_barrel"):
		return _meshes["ph_blue_barrel"] as ArrayMesh
	var base_mesh := get_ph_barrel_mesh()
	if base_mesh == null:
		return null
	var blue_mesh := base_mesh.duplicate() as ArrayMesh
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in range(sz):
		var v := float(y) / float(sz)
		for x in range(sz):
			var u := float(x) / float(sz)
			var grime := sin(u * 23.0 + v * 17.0) * cos(u * 13.0 - v * 29.0)
			var rust_mask := clampf((sin(u * 37.0 - v * 19.0) * cos(v * 31.0 + u * 11.0) - 0.35) * 2.2, 0.0, 1.0)
			var streak := clampf(absf(sin(u * 41.0 + sin(v * 9.0) * 1.4)) * 0.16, 0.0, 0.16)
			var blue_col := Color(0.22, 0.39, 0.60).lerp(Color(0.14, 0.24, 0.38), clampf(grime * 0.5 + 0.5, 0.0, 1.0))
			blue_col = blue_col.lerp(Color(0.32, 0.19, 0.12), rust_mask * 0.68)
			blue_col = blue_col.darkened(streak * 0.8)
			img.set_pixel(x, y, Color(blue_col.r, blue_col.g, blue_col.b, 1.0))
	var blue_albedo := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = WORLD_PROP_HEADLIGHT_SHADER
	mat.set_shader_parameter("has_albedo_tex", true)
	mat.set_shader_parameter("albedo_tex", blue_albedo)
	mat.set_shader_parameter("albedo_tint", Color(1.0, 1.0, 1.0, 1.0))
	var nor_path := "res://environment/model/polyhaven/Barrel_01/textures/Barrel_01_explosive_nor_gl_1k.jpg"
	if ResourceLoader.exists(nor_path):
		mat.set_shader_parameter("has_normal_tex", true)
		mat.set_shader_parameter("normal_tex", ResourceLoader.load(nor_path))
		mat.set_shader_parameter("normal_strength", 1.15)
	var arm_path := "res://environment/model/polyhaven/Barrel_01/textures/Barrel_01_explosive_arm_1k.jpg"
	if ResourceLoader.exists(arm_path):
		mat.set_shader_parameter("has_rough_tex", true)
		mat.set_shader_parameter("rough_tex", ResourceLoader.load(arm_path))
	mat.set_shader_parameter("roughness_val", 0.62)
	mat.set_shader_parameter("metallic_val", 0.34)
	_apply_hl_to_mat(mat)
	for s in range(blue_mesh.get_surface_count()):
		blue_mesh.surface_set_material(s, mat)
	_meshes["ph_blue_barrel"] = blue_mesh
	return blue_mesh


static func get_ph_utility_pole_mesh() -> ArrayMesh:
	var pole := _extract_merged_gltf_mesh(
		"ph_utility_pole",
		"res://environment/model/polyhaven/modular_electricity_poles/modular_electricity_poles_opt.scn",
		1.15,
		"preset_01_",
		PackedStringArray(["_bolt_", "_nail_", "_fastener_"]),
		true,
		true
	)
	return pole if pole != null else get_pylon_mesh()


static func get_ph_chainlink_fence_mesh() -> ArrayMesh:
	if _meshes.has("ph_chainlink_fence"):
		return _meshes["ph_chainlink_fence"] as ArrayMesh
	var panel := _extract_merged_gltf_mesh(
		"ph_chainlink_panel_unit",
		"res://environment/model/polyhaven/modular_chainlink_fence/modular_chainlink_fence_opt.scn",
		1.0,
		"modular_chainlink_fence_double",
		PackedStringArray(),
		true,
		true
	)
	var st_by_mat: Dictionary = {}
	var mat_by_id: Dictionary = {}
	if panel:
		for x_off: float in [-0.96, 0.96]:
			_append_mesh_to_buckets(
				panel,
				null,
				Transform3D(Basis.IDENTITY, Vector3(x_off, 0.0, 0.0)),
				Vector3.ZERO,
				1.0,
				Vector3.ZERO,
				st_by_mat,
				mat_by_id
			)
	var arr := _commit_buckets_to_array_mesh(st_by_mat, mat_by_id)
	var st_posts := SurfaceTool.new()
	st_posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for px: float in [-1.92, 0.0, 1.92]:
		_append_box(st_posts, Vector3(px, 1.22, 0.0), Vector3(0.11, 2.44, 0.11))
	_append_box(st_posts, Vector3(0.0, 2.40, 0.0), Vector3(3.96, 0.09, 0.09))
	_append_box(st_posts, Vector3(0.0, 0.10, 0.0), Vector3(3.96, 0.12, 0.10))
	st_posts.generate_normals()
	var p_res := st_posts.commit()
	if p_res and p_res.get_surface_count() > 0:
		var idx: int = arr.get_surface_count()
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p_res.surface_get_arrays(0))
		arr.surface_set_material(idx, get_material("pole_steel"))
	if arr.get_surface_count() == 0:
		return null
	_meshes["ph_chainlink_fence"] = arr
	return arr


static func get_ph_fire_hydrant_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_fire_hydrant",
		"res://environment/model/polyhaven/fire_hydrant/fire_hydrant_opt.scn",
		1.25
	)


static func get_ph_power_box_mesh() -> ArrayMesh:
	if _meshes.has("ph_power_box"):
		return _meshes["ph_power_box"] as ArrayMesh
	var base := _extract_merged_gltf_mesh(
		"ph_power_box_upper",
		"res://environment/model/polyhaven/power_box_01/power_box_01_1k.gltf",
		1.35,
		"",
		PackedStringArray(),
		true,
		true,
		Vector3(0.0, 0.72, 0.0)
	)
	var arr := base.duplicate() as ArrayMesh if base else ArrayMesh.new()
	var st_plinth := SurfaceTool.new()
	st_plinth.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_plinth, Vector3(0.0, 0.37, 0.0), Vector3(0.68, 0.74, 0.56))
	st_plinth.generate_normals()
	var p_res := st_plinth.commit()
	if p_res and p_res.get_surface_count() > 0:
		var idx: int = arr.get_surface_count()
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, p_res.surface_get_arrays(0))
		arr.surface_set_material(idx, get_material("concrete_rubble"))
	_meshes["ph_power_box"] = arr
	return arr


static func get_ph_trash_can_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_trash_can",
		"res://environment/model/polyhaven/metal_trash_can/metal_trash_can_1k.gltf",
		1.15
	)


static func get_ph_dead_log_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_dead_log",
		"res://environment/model/polyhaven/dead_tree_trunk/dead_tree_trunk_opt.scn",
		1.45
	)


static func get_ph_boulder_desert_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_boulder_desert",
		"res://environment/model/polyhaven/namaqualand_boulder_02/namaqualand_boulder_02_opt.scn",
		1.6
	)


static func get_ph_moss_rock_mesh(idx: int = 0) -> ArrayMesh:
	var r_i: int = clampi(idx, 0, 5)
	var rock := _extract_merged_gltf_mesh(
		"ph_moss_rock_%d" % r_i,
		"res://environment/model/polyhaven/rock_moss_set_01/rock_moss_set_01_opt.scn",
		1.8,
		"rock_moss_set_01_rock0%d" % (r_i + 1)
	)
	return rock if rock != null else get_mossy_boulder_mesh()


static func get_ph_wooden_crate_mesh() -> ArrayMesh:
	return _extract_merged_gltf_mesh(
		"ph_wooden_crate",
		"res://environment/model/polyhaven/wooden_crate_01/wooden_crate_01_1k.gltf",
		2.2
	)


static func get_city_tower_mesh(variant: int = 0) -> ArrayMesh:
	var v: int = clampi(variant, 0, 2)
	var key := "city_tower_%d" % v
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_wall := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rust := SurfaceTool.new()
	st_rust.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)

	match v:
		0:
			# Podium + setback industrial loft + 4 corner pilasters + recessed roof parapet
			_append_box(st_wall, Vector3(0.0, 0.09, 0.0), Vector3(0.98, 0.18, 0.98))
			_append_box(st_wall, Vector3(0.0, 0.45, 0.0), Vector3(0.84, 0.54, 0.84))
			_append_box(st_wall, Vector3(0.0, 0.49, 0.0), Vector3(0.91, 0.04, 0.91))
			for sx: float in [-0.41, 0.41]:
				for sz: float in [-0.41, 0.41]:
					_append_box(st_wall, Vector3(sx, 0.54, sz), Vector3(0.14, 0.74, 0.14))
			_append_box(st_wall, Vector3(0.0, 0.84, 0.0), Vector3(0.68, 0.24, 0.68))
			_append_box(st_wall, Vector3(0.0, 0.98, -0.32), Vector3(0.70, 0.05, 0.06))
			_append_box(st_wall, Vector3(0.0, 0.98, 0.32), Vector3(0.70, 0.05, 0.06))
			_append_box(st_wall, Vector3(-0.32, 0.98, 0.0), Vector3(0.06, 0.05, 0.64))
			_append_box(st_wall, Vector3(0.32, 0.98, 0.0), Vector3(0.06, 0.05, 0.64))
			_append_box(st_rust, Vector3(-0.10, 1.00, 0.05), Vector3(0.24, 0.09, 0.22))
			_append_box(st_rust, Vector3(0.18, 0.98, -0.14), Vector3(0.14, 0.06, 0.14))
			_append_box(st_steel, Vector3(-0.10, 1.11, 0.05), Vector3(0.025, 0.14, 0.025))
		1:
			# Brutalist finned slab + upper mechanical level
			_append_box(st_wall, Vector3(0.0, 0.11, 0.0), Vector3(1.00, 0.22, 0.96))
			_append_box(st_wall, Vector3(0.0, 0.55, 0.0), Vector3(0.78, 0.66, 0.78))
			for fx: float in [-0.41, -0.15, 0.15, 0.41]:
				_append_box(st_wall, Vector3(fx, 0.54, 0.40), Vector3(0.08, 0.66, 0.09))
				_append_box(st_wall, Vector3(fx, 0.54, -0.40), Vector3(0.08, 0.66, 0.09))
			_append_box(st_wall, Vector3(0.0, 0.92, 0.0), Vector3(0.84, 0.10, 0.84))
			_append_box(st_wall, Vector3(0.0, 0.99, 0.39), Vector3(0.84, 0.05, 0.06))
			_append_box(st_wall, Vector3(0.0, 0.99, -0.39), Vector3(0.84, 0.05, 0.06))
			_append_box(st_rust, Vector3(0.12, 1.02, 0.0), Vector3(0.32, 0.10, 0.26))
			_append_box(st_rust, Vector3(-0.22, 1.01, -0.16), Vector3(0.14, 0.09, 0.14))
			_append_box(st_steel, Vector3(0.22, 1.12, -0.12), Vector3(0.02, 0.16, 0.02))
			_append_box(st_steel, Vector3(0.22, 1.15, -0.12), Vector3(0.12, 0.015, 0.015))
		_:
			# Asymmetric twin-wing high-rise
			_append_box(st_wall, Vector3(0.0, 0.08, 0.0), Vector3(1.00, 0.16, 0.98))
			_append_box(st_wall, Vector3(-0.17, 0.57, 0.0), Vector3(0.56, 0.82, 0.86))
			_append_box(st_wall, Vector3(0.22, 0.40, 0.04), Vector3(0.42, 0.48, 0.78))
			_append_box(st_wall, Vector3(-0.17, 0.58, 0.0), Vector3(0.61, 0.04, 0.91))
			_append_box(st_wall, Vector3(-0.17, 1.00, 0.40), Vector3(0.56, 0.05, 0.06))
			_append_box(st_wall, Vector3(-0.17, 1.00, -0.40), Vector3(0.56, 0.05, 0.06))
			_append_box(st_rust, Vector3(0.22, 0.68, 0.04), Vector3(0.22, 0.08, 0.24))
			_append_box(st_rust, Vector3(-0.18, 1.03, -0.10), Vector3(0.22, 0.09, 0.26))
			_append_box(st_steel, Vector3(-0.22, 1.13, -0.14), Vector3(0.025, 0.16, 0.025))

	st_wall.generate_normals()
	var rw := st_wall.commit()
	if rw and rw.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rw.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("building_factory"))

	st_rust.generate_normals()
	var rr := st_rust.commit()
	if rr and rr.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rr.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("rusty_metal"))

	st_steel.generate_normals()
	var rs := st_steel.commit()
	if rs and rs.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rs.surface_get_arrays(0))
		arr.surface_set_material(2, get_material("pole_steel"))

	_meshes[key] = arr
	return arr


static func get_city_ruin_mesh(variant: int = 0) -> ArrayMesh:
	var v: int = clampi(variant, 0, 1)
	var key := "city_ruin_%d" % v
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_brick := SurfaceTool.new()
	st_brick.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rust := SurfaceTool.new()
	st_rust.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Stepped ruined brick tenement with corner piers, cornice ledges & awning
	_append_box(st_brick, Vector3(0.0, 0.41, 0.0), Vector3(0.88, 0.82, 0.88))
	for sx: float in [-0.41, 0.41]:
		for sz: float in [-0.41, 0.41]:
			_append_box(st_brick, Vector3(sx, 0.46, sz), Vector3(0.16, 0.92, 0.16))
	_append_box(st_brick, Vector3(0.0, 0.34, 0.0), Vector3(0.95, 0.04, 0.95))
	_append_box(st_brick, Vector3(0.0, 0.67, 0.0), Vector3(0.95, 0.04, 0.95))
	if v == 0:
		_append_box(st_brick, Vector3(-0.18, 0.90, 0.0), Vector3(0.50, 0.18, 0.86))
		_append_box(st_brick, Vector3(0.24, 0.85, -0.18), Vector3(0.38, 0.09, 0.48))
		_append_box(st_rust, Vector3(0.0, 0.29, 0.48), Vector3(0.74, 0.035, 0.20))
		_append_box(st_rust, Vector3(0.0, 0.29, -0.48), Vector3(0.74, 0.035, 0.20))
		_append_box(st_rust, Vector3(0.16, 0.90, 0.18), Vector3(0.24, 0.09, 0.22))
	else:
		_append_box(st_brick, Vector3(0.26, 0.24, 0.0), Vector3(0.46, 0.48, 0.82))
		_append_box(st_brick, Vector3(-0.14, 0.90, 0.14), Vector3(0.54, 0.18, 0.56))
		_append_box(st_rust, Vector3(-0.48, 0.29, 0.0), Vector3(0.20, 0.035, 0.72))
		_append_box(st_rust, Vector3(0.48, 0.29, 0.0), Vector3(0.20, 0.035, 0.72))
		_append_box(st_rust, Vector3(-0.14, 1.02, 0.14), Vector3(0.24, 0.08, 0.20))

	st_brick.generate_normals()
	var rb := st_brick.commit()
	if rb and rb.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rb.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("building_brick"))

	st_rust.generate_normals()
	var rr := st_rust.commit()
	if rr and rr.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rr.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("rusty_metal"))

	_meshes[key] = arr
	return arr


static func get_guardrail_mesh() -> ArrayMesh:
	if _meshes.has("guardrail"):
		return _meshes["guardrail"] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pz: float in [-6.0, -3.0, 0.0, 3.0, 6.0]:
		_append_box(st_steel, Vector3(0.0, 0.43, pz), Vector3(0.11, 0.86, 0.14))
		_append_box(st_steel, Vector3(0.0, 0.02, pz), Vector3(0.22, 0.04, 0.24))
		_append_box(st_steel, Vector3(0.09, 0.57, pz), Vector3(0.10, 0.26, 0.14))
		_append_box(st_steel, Vector3(-0.09, 0.57, pz), Vector3(0.10, 0.26, 0.14))
	# Profiled twin-rib W-beam rails on both faces
	for sx: float in [-0.14, 0.14]:
		_append_box(st_steel, Vector3(sx, 0.67, 0.0), Vector3(0.05, 0.09, 14.0))
		_append_box(st_steel, Vector3(sx * 0.72, 0.57, 0.0), Vector3(0.04, 0.11, 14.0))
		_append_box(st_steel, Vector3(sx, 0.47, 0.0), Vector3(0.05, 0.09, 14.0))
	st_steel.generate_normals()
	var rs := st_steel.commit()
	if rs and rs.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rs.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("gate_steel"))

	var st_ref := SurfaceTool.new()
	st_ref.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pz: float in [-6.0, 0.0, 6.0]:
		_append_box(st_ref, Vector3(0.0, 0.80, pz), Vector3(0.12, 0.09, 0.10))
	st_ref.generate_normals()
	var rf := st_ref.commit()
	if rf and rf.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rf.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("lamp_glow"))

	_meshes["guardrail"] = arr
	return arr


static func get_bridge_stop_fence_mesh(with_stop_sign: bool = true) -> ArrayMesh:
	var key := "bridge_stop_fence_%d" % (1 if with_stop_sign else 0)
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var base := get_ph_chainlink_fence_mesh()
	var arr := base.duplicate() as ArrayMesh if base else ArrayMesh.new()

	# Кронштейны под углом 45 градусов + три ряда колючей проволоки сверху + жёлто-чёрный предупреждающий отбойник
	var st_wire := SurfaceTool.new()
	st_wire.begin(Mesh.PRIMITIVE_TRIANGLES)
	for px: float in [-1.92, 0.0, 1.92]:
		var arm_top := Vector3(px, 2.74, -0.22)
		var arm_bot := Vector3(px, 2.42, 0.0)
		var arm_c := (arm_top + arm_bot) * 0.5
		_append_box(st_wire, arm_c + Vector3(0.0, 0.0, 0.0), Vector3(0.08, 0.42, 0.08))
		# Опора бетонного башмака внизу
		_append_box(st_wire, Vector3(px, 0.07, 0.0), Vector3(0.28, 0.14, 0.28))
	for strand_i in range(3):
		var wy := 2.50 + float(strand_i) * 0.13
		var wz := -0.05 - float(strand_i) * 0.07
		_append_box(st_wire, Vector3(0.0, wy, wz), Vector3(3.92, 0.032, 0.032))
		# Шипы колючей проволоки через каждые ~0.35м
		var sx := -1.75
		while sx <= 1.76:
			_append_box(st_wire, Vector3(sx, wy, wz), Vector3(0.04, 0.095, 0.095))
			sx += 0.36
	st_wire.generate_normals()
	var w_res := st_wire.commit()
	if w_res and w_res.get_surface_count() > 0:
		var idx: int = arr.get_surface_count()
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, w_res.surface_get_arrays(0))
		arr.surface_set_material(idx, get_material("barbed_wire_steel"))

	var st_haz := SurfaceTool.new()
	st_haz.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_haz, Vector3(0.0, 1.05, 0.05), Vector3(3.86, 0.20, 0.05))
	st_haz.generate_normals()
	var h_res := st_haz.commit()
	if h_res and h_res.get_surface_count() > 0:
		var idx_h: int = arr.get_surface_count()
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, h_res.surface_get_arrays(0))
		arr.surface_set_material(idx_h, get_material("hazard_stripe"))

	if with_stop_sign:
		var st_sign := SurfaceTool.new()
		st_sign.begin(Mesh.PRIMITIVE_TRIANGLES)
		var sh := 0.44
		var cy := 1.62
		var sz_f := 0.08
		var sz_b := 0.04
		# Передняя табличка STOP обращена в сторону дороги (-Z к машине или +Z в зависимости от поворота; рисуем двусторонне)
		var f0 := Vector3(-sh, cy - sh, sz_f)
		var f1 := Vector3(sh, cy - sh, sz_f)
		var f2 := Vector3(sh, cy + sh, sz_f)
		var f3 := Vector3(-sh, cy + sh, sz_f)
		st_sign.set_uv(Vector2(0, 1)); st_sign.add_vertex(f0)
		st_sign.set_uv(Vector2(1, 1)); st_sign.add_vertex(f1)
		st_sign.set_uv(Vector2(1, 0)); st_sign.add_vertex(f2)
		st_sign.set_uv(Vector2(0, 1)); st_sign.add_vertex(f0)
		st_sign.set_uv(Vector2(1, 0)); st_sign.add_vertex(f2)
		st_sign.set_uv(Vector2(0, 0)); st_sign.add_vertex(f3)

		var b0 := Vector3(-sh, cy - sh, -sz_b)
		var b1 := Vector3(sh, cy - sh, -sz_b)
		var b2 := Vector3(sh, cy + sh, -sz_b)
		var b3 := Vector3(-sh, cy + sh, -sz_b)
		st_sign.set_uv(Vector2(0, 1)); st_sign.add_vertex(b1)
		st_sign.set_uv(Vector2(1, 1)); st_sign.add_vertex(b0)
		st_sign.set_uv(Vector2(1, 0)); st_sign.add_vertex(b3)
		st_sign.set_uv(Vector2(0, 1)); st_sign.add_vertex(b1)
		st_sign.set_uv(Vector2(1, 0)); st_sign.add_vertex(b3)
		st_sign.set_uv(Vector2(0, 0)); st_sign.add_vertex(b2)
		st_sign.generate_normals()
		var s_res := st_sign.commit()
		if s_res and s_res.get_surface_count() > 0:
			var idx_s: int = arr.get_surface_count()
			arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, s_res.surface_get_arrays(0))
			arr.surface_set_material(idx_s, get_material("stop_sign_metal"))

	_meshes[key] = arr
	return arr


static func get_fire_cluster_mesh() -> ArrayMesh:
	if _meshes.has("fire_cluster"):
		return _meshes["fire_cluster"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes := [
		{"yaw": 0.0, "w": 2.4, "h": 3.4, "off": Vector3.ZERO},
		{"yaw": PI / 3.0, "w": 2.2, "h": 3.2, "off": Vector3(0.18, 0.0, -0.10)},
		{"yaw": -PI / 3.0, "w": 2.1, "h": 2.9, "off": Vector3(-0.18, 0.0, 0.14)},
	]
	for p: Dictionary in planes:
		var yaw: float = float(p["yaw"])
		var hw: float = float(p["w"]) * 0.5
		var hh: float = float(p["h"])
		var off: Vector3 = p["off"] as Vector3
		var b := Basis(Vector3.UP, yaw)
		var v0 := off + b * Vector3(-hw, 0.0, 0.0)
		var v1 := off + b * Vector3(hw, 0.0, 0.0)
		var v2 := off + b * Vector3(hw, hh, 0.0)
		var v3 := off + b * Vector3(-hw, hh, 0.0)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)
	st.generate_normals()
	var arr := st.commit()
	if arr and arr.get_surface_count() > 0:
		arr.surface_set_material(0, get_material("world_fire_mat"))
	_meshes["fire_cluster"] = arr
	return arr


static func get_fire_smoke_plume_mesh() -> ArrayMesh:
	if _meshes.has("fire_smoke_plume"):
		return _meshes["fire_smoke_plume"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planes := [
		{"yaw": 0.0, "w": 4.6, "y0": 1.6, "y1": 11.8, "off": Vector3.ZERO},
		{"yaw": PI / 3.0, "w": 4.4, "y0": 1.8, "y1": 11.4, "off": Vector3(0.24, 0.0, -0.18)},
		{"yaw": -PI / 3.0, "w": 4.2, "y0": 1.7, "y1": 10.9, "off": Vector3(-0.22, 0.0, 0.20)},
	]
	for p: Dictionary in planes:
		var yaw: float = float(p["yaw"])
		var hw: float = float(p["w"]) * 0.5
		var y0: float = float(p["y0"])
		var y1: float = float(p["y1"])
		var off: Vector3 = p["off"] as Vector3
		var b := Basis(Vector3.UP, yaw)
		var v0 := off + b * Vector3(-hw, y0, 0.0)
		var v1 := off + b * Vector3(hw, y0, 0.0)
		var v2 := off + b * Vector3(hw, y1, 0.0)
		var v3 := off + b * Vector3(-hw, y1, 0.0)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)
	st.generate_normals()
	var arr := st.commit()
	if arr and arr.get_surface_count() > 0:
		arr.surface_set_material(0, get_material("world_smoke_mat"))
	_meshes["fire_smoke_plume"] = arr
	return arr


static func get_burnt_tree_mesh() -> ArrayMesh:
	if _meshes.has("burnt_tree"):
		return _meshes["burnt_tree"] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Обугленный ствол, корневой наплыв и обломанные ветви
	_append_box(st_trunk, Vector3(0.0, 3.6, 0.0), Vector3(0.46, 7.2, 0.46))
	_append_box(st_trunk, Vector3(0.0, 0.36, 0.0), Vector3(0.68, 0.72, 0.68))
	_append_box(st_trunk, Vector3(0.18, 7.6, -0.08), Vector3(0.26, 2.2, 0.24))
	_append_box(st_trunk, Vector3(0.85, 3.8, 0.12), Vector3(1.5, 0.16, 0.16))
	_append_box(st_trunk, Vector3(-0.78, 5.1, -0.18), Vector3(1.3, 0.14, 0.14))
	_append_box(st_trunk, Vector3(0.12, 5.9, 0.72), Vector3(0.14, 0.14, 1.2))
	_append_box(st_trunk, Vector3(-0.22, 2.5, -0.62), Vector3(0.16, 0.16, 1.05))
	st_trunk.generate_normals()
	var rt := st_trunk.commit()
	if rt and rt.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rt.surface_get_arrays(0))
		arr.surface_set_material(0, get_material("charred_bark"))

	var st_emb := SurfaceTool.new()
	st_emb.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_box(st_emb, Vector3(0.0, 0.09, 0.0), Vector3(0.40, 0.18, 0.40))
	st_emb.generate_normals()
	var re := st_emb.commit()
	if re and re.get_surface_count() > 0:
		arr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, re.surface_get_arrays(0))
		arr.surface_set_material(1, get_material("charred_ember"))

	_meshes["burnt_tree"] = arr
	return arr


static func get_tall_grass_clump_mesh() -> ArrayMesh:
	if _meshes.has("tall_grass_clump"):
		return _meshes["tall_grass_clump"] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.68
	var hh := 0.92
	for ang: float in [0.0, PI / 3.0, -PI / 3.0]:
		var b := Basis(Vector3.UP, ang)
		var v0 := b * Vector3(-hw, -0.04, 0.0)
		var v1 := b * Vector3(hw, -0.04, 0.0)
		var v2 := b * Vector3(hw, hh, 0.0)
		var v3 := b * Vector3(-hw, hh, 0.0)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)
	st.generate_normals()
	var arr := st.commit()
	if arr and arr.get_surface_count() > 0:
		arr.surface_set_material(0, get_material("tall_grass_mat"))
	_meshes["tall_grass_clump"] = arr
	return arr


static func get_burnt_city_tower_mesh(variant: int = 0) -> ArrayMesh:
	var v: int = clampi(variant, 0, 2)
	var key := "burnt_city_tower_%d" % v
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_wall := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rubble := SurfaceTool.new()
	st_rubble.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)

	match v:
		0:
			# Бомбёный угловой небоскрёб: полая L-образная коробка со ступенчатым сколом, вырванным правым углом и наклонными плитами перекрытий
			_append_box(st_wall, Vector3(-0.39, 0.48, -0.04), Vector3(0.11, 0.96, 0.84))
			_append_box(st_wall, Vector3(-0.18, 0.41, -0.41), Vector3(0.50, 0.82, 0.11))
			_append_box(st_wall, Vector3(0.18, 0.28, -0.41), Vector3(0.24, 0.56, 0.10))
			_append_box(st_wall, Vector3(0.39, 0.16, -0.26), Vector3(0.11, 0.32, 0.38))
			_append_box(st_wall, Vector3(-0.26, 0.21, 0.41), Vector3(0.36, 0.42, 0.10))
			_append_box(st_wall, Vector3(0.26, 0.11, 0.34), Vector3(0.26, 0.22, 0.14))
			# Повреждённая шахта лифта в центре полости и обломанные межэтажные перекрытия
			_append_box(st_wall, Vector3(-0.12, 0.52, -0.10), Vector3(0.22, 1.04, 0.22))
			_append_box(st_wall, Vector3(-0.15, 0.32, 0.04), Vector3(0.46, 0.036, 0.54))
			_append_box(st_wall, Vector3(-0.18, 0.62, -0.12), Vector3(0.38, 0.036, 0.44))
			# Обрушившиеся наклонные бетонные плиты перекрытий
			_append_box_xform(st_wall, Vector3(0.12, 0.25, 0.08), Vector3(0.42, 0.038, 0.44), Vector3(0.36, 0.18, -0.48))
			_append_box_xform(st_wall, Vector3(0.06, 0.52, -0.18), Vector3(0.34, 0.034, 0.32), Vector3(0.22, -0.14, -0.56))
			# Торчащая арматура и покорёженные балки на гребне разлома
			for rx: float in [-0.41, -0.35, -0.22, -0.05, 0.16]:
				_append_box_xform(st_steel, Vector3(rx, 0.94 if rx < -0.1 else 0.64, -0.40 if rx > -0.3 else -0.12), Vector3(0.018, 0.18, 0.018), Vector3(rx * 0.6, 0.2, -rx * 0.4))
			_append_box_xform(st_steel, Vector3(-0.14, 0.88, -0.02), Vector3(0.42, 0.024, 0.024), Vector3(0.08, 0.15, -0.34))
			_append_box_xform(st_steel, Vector3(0.12, 0.46, 0.18), Vector3(0.32, 0.022, 0.022), Vector3(0.24, -0.22, 0.42))
			# Завалы бетонного щебня у основания пролома
			_append_box_xform(st_rubble, Vector3(0.22, 0.06, 0.16), Vector3(0.34, 0.12, 0.36), Vector3(0.18, 0.4, -0.14))
			_append_box_xform(st_rubble, Vector3(0.04, 0.05, 0.32), Vector3(0.28, 0.10, 0.26), Vector3(-0.22, 0.8, 0.16))
			_append_box_xform(st_rubble, Vector3(0.34, 0.08, -0.06), Vector3(0.24, 0.14, 0.28), Vector3(0.26, -0.5, 0.22))
		1:
			# Расколотый на две башни остов: два рваных стояка по краям, выбитый центр и свисающие балки
			_append_box(st_wall, Vector3(-0.34, 0.49, -0.12), Vector3(0.20, 0.98, 0.62))
			_append_box(st_wall, Vector3(-0.36, 0.26, 0.28), Vector3(0.14, 0.52, 0.24))
			_append_box(st_wall, Vector3(0.34, 0.38, 0.10), Vector3(0.20, 0.76, 0.66))
			_append_box(st_wall, Vector3(0.16, 0.18, 0.38), Vector3(0.32, 0.36, 0.12))
			_append_box(st_wall, Vector3(0.02, 0.31, -0.40), Vector3(0.56, 0.62, 0.11))
			# Разрушенные внутренние перекрытия с рваными краями
			_append_box(st_wall, Vector3(-0.18, 0.42, -0.14), Vector3(0.28, 0.036, 0.42))
			_append_box(st_wall, Vector3(0.18, 0.50, 0.08), Vector3(0.28, 0.036, 0.44))
			_append_box_xform(st_wall, Vector3(-0.02, 0.20, 0.12), Vector3(0.38, 0.036, 0.40), Vector3(-0.42, 0.24, 0.32))
			_append_box_xform(st_wall, Vector3(0.04, 0.68, -0.12), Vector3(0.44, 0.032, 0.26), Vector3(0.28, -0.12, -0.36))
			# Каркас вырванных ферм и арматура
			_append_box_xform(st_steel, Vector3(0.0, 0.84, -0.08), Vector3(0.54, 0.026, 0.026), Vector3(0.12, 0.08, -0.26))
			_append_box_xform(st_steel, Vector3(-0.04, 0.58, 0.14), Vector3(0.46, 0.022, 0.022), Vector3(-0.18, 0.22, 0.28))
			for i in range(5):
				var sx: float = -0.36 + float(i) * 0.18
				_append_box_xform(st_steel, Vector3(sx, 0.72 if absf(sx) > 0.2 else 0.56, -0.38 if absf(sx) < 0.2 else 0.0), Vector3(0.016, 0.20, 0.016), Vector3(0.25 - sx, 0.1, -0.15))
			_append_box_xform(st_rubble, Vector3(0.0, 0.07, 0.18), Vector3(0.46, 0.14, 0.42), Vector3(0.12, 0.35, 0.18))
			_append_box_xform(st_rubble, Vector3(-0.16, 0.05, 0.36), Vector3(0.28, 0.10, 0.22), Vector3(-0.18, 0.9, -0.14))
			_append_box_xform(st_rubble, Vector3(0.20, 0.06, -0.22), Vector3(0.26, 0.12, 0.26), Vector3(0.22, -0.6, 0.16))
		_:
			# Выжженный промышленный корпус со снесённым верхом и проломленным фасадом
			_append_box(st_wall, Vector3(-0.40, 0.44, 0.0), Vector3(0.10, 0.88, 0.88))
			_append_box(st_wall, Vector3(0.40, 0.30, -0.12), Vector3(0.10, 0.60, 0.64))
			_append_box(st_wall, Vector3(-0.14, 0.40, 0.41), Vector3(0.46, 0.80, 0.10))
			_append_box(st_wall, Vector3(0.26, 0.22, 0.41), Vector3(0.22, 0.44, 0.10))
			_append_box(st_wall, Vector3(-0.08, 0.24, -0.41), Vector3(0.68, 0.48, 0.10))
			_append_box(st_wall, Vector3(-0.28, 0.54, -0.41), Vector3(0.20, 0.36, 0.10))
			# Упавшая внутрь торцевая стена и покорёженное перекрытие
			_append_box_xform(st_wall, Vector3(0.14, 0.28, 0.04), Vector3(0.44, 0.04, 0.52), Vector3(-0.34, 0.14, 0.44))
			_append_box_xform(st_wall, Vector3(-0.06, 0.56, 0.08), Vector3(0.42, 0.034, 0.42), Vector3(0.24, -0.18, -0.28))
			_append_box_xform(st_steel, Vector3(-0.04, 0.88, 0.14), Vector3(0.64, 0.025, 0.025), Vector3(0.16, 0.2, 0.22))
			_append_box_xform(st_steel, Vector3(0.08, 0.72, -0.16), Vector3(0.52, 0.022, 0.022), Vector3(-0.22, 0.3, -0.34))
			for ax: float in [-0.38, -0.18, 0.06, 0.32]:
				_append_box_xform(st_steel, Vector3(ax, 0.82 if ax < 0.0 else 0.52, 0.38 if ax < 0.1 else -0.36), Vector3(0.016, 0.19, 0.016), Vector3(0.2, 0.4, ax * 0.8))
			_append_box_xform(st_rubble, Vector3(0.18, 0.07, -0.24), Vector3(0.38, 0.14, 0.32), Vector3(0.16, 0.5, -0.18))
			_append_box_xform(st_rubble, Vector3(0.28, 0.06, 0.24), Vector3(0.26, 0.12, 0.28), Vector3(-0.24, 0.2, 0.22))
			_append_box_xform(st_rubble, Vector3(-0.10, 0.05, -0.06), Vector3(0.30, 0.10, 0.28), Vector3(0.14, -0.7, 0.12))

	_commit_surface(arr, st_wall, "building_burnt_factory")
	_commit_surface(arr, st_rubble, "concrete_rubble")
	_commit_surface(arr, st_steel, "rusty_metal")
	_meshes[key] = arr
	return arr


static func get_burnt_city_ruin_mesh(variant: int = 0) -> ArrayMesh:
	var v: int = clampi(variant, 0, 1)
	var key := "burnt_city_ruin_%d" % v
	if _meshes.has(key):
		return _meshes[key] as ArrayMesh
	var arr := ArrayMesh.new()
	var st_wall := SurfaceTool.new()
	st_wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rubble := SurfaceTool.new()
	st_rubble.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_steel := SurfaceTool.new()
	st_steel.begin(Mesh.PRIMITIVE_TRIANGLES)

	match v:
		0:
			# Полуобрушенный кирпичный дом: рваный пролом спереди и провалившаяся кровля
			_append_box(st_wall, Vector3(-0.40, 0.38, 0.02), Vector3(0.11, 0.76, 0.82))
			_append_box(st_wall, Vector3(-0.08, 0.32, -0.40), Vector3(0.74, 0.64, 0.11))
			_append_box(st_wall, Vector3(0.38, 0.20, -0.14), Vector3(0.11, 0.40, 0.56))
			_append_box(st_wall, Vector3(-0.24, 0.24, 0.40), Vector3(0.38, 0.48, 0.11))
			_append_box(st_wall, Vector3(0.24, 0.12, 0.36), Vector3(0.24, 0.24, 0.11))
			# Проваленная внутрь крыша + деревянно-стальные стропила
			_append_box_xform(st_wall, Vector3(-0.02, 0.30, -0.02), Vector3(0.64, 0.045, 0.68), Vector3(0.42, 0.16, -0.36))
			_append_box_xform(st_steel, Vector3(-0.10, 0.58, 0.06), Vector3(0.56, 0.028, 0.028), Vector3(0.26, -0.18, -0.44))
			_append_box_xform(st_steel, Vector3(0.08, 0.50, -0.16), Vector3(0.48, 0.026, 0.026), Vector3(-0.20, 0.28, 0.38))
			_append_box_xform(st_steel, Vector3(-0.36, 0.78, -0.18), Vector3(0.020, 0.18, 0.020), Vector3(0.25, 0.1, -0.2))
			_append_box_xform(st_rubble, Vector3(0.14, 0.08, 0.20), Vector3(0.38, 0.16, 0.34), Vector3(0.22, 0.45, -0.16))
			_append_box_xform(st_rubble, Vector3(-0.08, 0.06, 0.32), Vector3(0.32, 0.12, 0.28), Vector3(-0.18, -0.35, 0.20))
		_:
			# Разбомбленный угловой склад / павильон со снесённым левым крылом и торчащими фермами
			_append_box(st_wall, Vector3(0.39, 0.42, -0.02), Vector3(0.11, 0.84, 0.84))
			_append_box(st_wall, Vector3(0.06, 0.36, -0.40), Vector3(0.68, 0.72, 0.11))
			_append_box(st_wall, Vector3(-0.36, 0.16, -0.22), Vector3(0.11, 0.32, 0.42))
			_append_box(st_wall, Vector3(0.22, 0.25, 0.40), Vector3(0.40, 0.50, 0.11))
			_append_box_xform(st_wall, Vector3(0.04, 0.26, 0.06), Vector3(0.56, 0.042, 0.54), Vector3(-0.38, -0.22, 0.46))
			_append_box_xform(st_steel, Vector3(0.08, 0.68, 0.04), Vector3(0.62, 0.026, 0.026), Vector3(0.18, 0.14, 0.42))
			_append_box_xform(st_steel, Vector3(-0.08, 0.54, -0.14), Vector3(0.50, 0.024, 0.024), Vector3(-0.28, -0.18, -0.36))
			_append_box_xform(st_steel, Vector3(0.34, 0.86, 0.16), Vector3(0.020, 0.18, 0.020), Vector3(-0.22, 0.3, 0.18))
			_append_box_xform(st_rubble, Vector3(-0.16, 0.07, 0.14), Vector3(0.42, 0.14, 0.38), Vector3(0.16, 0.6, 0.22))
			_append_box_xform(st_rubble, Vector3(-0.28, 0.06, -0.08), Vector3(0.28, 0.12, 0.28), Vector3(-0.22, 0.15, -0.18))

	_commit_surface(arr, st_wall, "building_burnt_brick")
	_commit_surface(arr, st_rubble, "concrete_rubble")
	_commit_surface(arr, st_steel, "rusty_metal")
	_meshes[key] = arr
	return arr
