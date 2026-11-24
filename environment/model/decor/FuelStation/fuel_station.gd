extends Node3D

const ProceduralMaterials = preload("res://levels/procedural_materials.gd")

const GAS_CANISTER_SCENE: PackedScene = preload("res://environment/model/decor/gas/Gas.tscn")
const TANKER_WRECK_SCENE: PackedScene = preload("res://environment/model/decor/wrekers_car/tanker_001a_reference_smd_1.tscn")

const GLTF_GENERATOR: PackedScene = preload("res://environment/model/decor/FuelStation/models/portable_generator/portable_generator_1k.gltf")
const GLTF_PROPANE: PackedScene = preload("res://environment/model/decor/FuelStation/models/propane_tank/propane_tank_1k.gltf")
const GLTF_IBC: PackedScene = preload("res://environment/model/decor/FuelStation/models/industrial_pastic_container/industrial_pastic_container_1k.gltf")
const GLTF_BARRIER: PackedScene = preload("res://environment/model/decor/FuelStation/models/concrete_road_barrier/concrete_road_barrier_opt.scn")
const GLTF_CRATE: PackedScene = preload("res://environment/model/decor/FuelStation/models/old_military_crate/old_military_crate_1k.gltf")
const GLTF_JERRYCAN: PackedScene = preload("res://environment/model/decor/FuelStation/models/metal_jerrycan/metal_jerrycan_1k.gltf")

const FONT_RUSSO: FontFile = preload("res://assets/fonts/RussoOne-Regular.ttf")

const TEX_CONCRETE_FLOOR_DIFF: Texture2D = preload("res://environment/textures/procedural/concrete_floor_worn_001/diff.jpg")
const TEX_CONCRETE_FLOOR_NOR: Texture2D = preload("res://environment/textures/procedural/concrete_floor_worn_001/nor_gl.jpg")
const TEX_CONCRETE_FLOOR_RGH: Texture2D = preload("res://environment/textures/procedural/concrete_floor_worn_001/rough.jpg")

const TEX_CONCRETE_WALL_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/concrete_wall_006/concrete_wall_006_diff_1k.jpg")
const TEX_CONCRETE_WALL_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/concrete_wall_006/concrete_wall_006_nor_gl_1k.jpg")
const TEX_CONCRETE_WALL_RGH: Texture2D = preload("res://environment/model/decor/FuelStation/textures/concrete_wall_006/concrete_wall_006_rough_1k.jpg")

const TEX_CORR_IRON_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/corrugated_iron_02/corrugated_iron_02_diff_1k.jpg")
const TEX_CORR_IRON_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/corrugated_iron_02/corrugated_iron_02_nor_gl_1k.jpg")
const TEX_CORR_IRON_RGH: Texture2D = preload("res://environment/model/decor/FuelStation/textures/corrugated_iron_02/corrugated_iron_02_rough_1k.jpg")

const TEX_RUST_STEEL_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_STEEL_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")
const TEX_RUST_STEEL_RGH: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_rough_1k.jpg")

static var _cached_mats: Dictionary = {}

var _built: bool = false

func _ready() -> void:
	if not _built:
		build_outpost()

static func _get_pbr_mat(key: String) -> Material:
	if _cached_mats.has(key):
		return _cached_mats[key] as Material

	var mat: Material = null
	match key:
		"apron":
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.56, 0.55, 0.53)
			sm.albedo_texture = TEX_CONCRETE_FLOOR_DIFF
			sm.normal_enabled = true
			sm.normal_texture = TEX_CONCRETE_FLOOR_NOR
			sm.normal_scale = 1.2
			sm.roughness_texture = TEX_CONCRETE_FLOOR_RGH
			sm.roughness = 0.92
			sm.uv1_scale = Vector3(5.0, 9.0, 1.0)
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"island":
			var sm := StandardMaterial3D.new()
			sm.albedo_texture = TEX_CONCRETE_WALL_DIFF
			sm.normal_enabled = true
			sm.normal_texture = TEX_CONCRETE_WALL_NOR
			sm.normal_scale = 1.2
			sm.roughness_texture = TEX_CONCRETE_WALL_RGH
			sm.roughness = 0.88
			sm.uv1_triplanar = true
			sm.uv1_scale = Vector3(0.45, 0.45, 0.45)
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"corrugated_roof":
			var sm := StandardMaterial3D.new()
			sm.albedo_texture = TEX_CORR_IRON_DIFF
			sm.normal_enabled = true
			sm.normal_texture = TEX_CORR_IRON_NOR
			sm.normal_scale = 1.4
			sm.roughness_texture = TEX_CORR_IRON_RGH
			sm.roughness = 0.78
			sm.metallic = 0.45
			sm.uv1_scale = Vector3(4.0, 6.0, 1.0)
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"rusty_steel":
			var sm := StandardMaterial3D.new()
			sm.albedo_texture = TEX_RUST_STEEL_DIFF
			sm.normal_enabled = true
			sm.normal_texture = TEX_RUST_STEEL_NOR
			sm.normal_scale = 1.3
			sm.roughness_texture = TEX_RUST_STEEL_RGH
			sm.roughness = 0.74
			sm.metallic = 0.55
			sm.uv1_triplanar = true
			sm.uv1_scale = Vector3(0.55, 0.55, 0.55)
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"hazard_amber":
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.86, 0.56, 0.14)
			sm.roughness = 0.55
			sm.metallic = 0.20
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"hose_rubber":
			var sm := StandardMaterial3D.new()
			sm.albedo_color = Color(0.10, 0.10, 0.11)
			sm.roughness = 0.82
			mat = ProceduralMaterials.get_lit_prop_material(sm)
		"pump_screen":
			var um := StandardMaterial3D.new()
			um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			um.albedo_color = Color(0.98, 0.66, 0.18)
			mat = um
		"sign_glow":
			var um := StandardMaterial3D.new()
			um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			um.albedo_color = Color(1.0, 0.44, 0.12)
			mat = um
		"canopy_tube_dim":
			var um := StandardMaterial3D.new()
			um.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			um.albedo_color = Color(0.88, 0.86, 0.74)
			mat = um

	_cached_mats[key] = mat
	return mat

func build_outpost() -> void:
	if _built:
		return
	_built = true

	var apron_mat := _get_pbr_mat("apron")
	var island_mat := _get_pbr_mat("island")
	var roof_mat := _get_pbr_mat("corrugated_roof")
	var steel_mat := _get_pbr_mat("rusty_steel")
	var hazard_mat := _get_pbr_mat("hazard_amber")
	var screen_mat := _get_pbr_mat("pump_screen")
	var sign_mat := _get_pbr_mat("sign_glow")
	var tube_mat := _get_pbr_mat("canopy_tube_dim")
	var hose_mat := _get_pbr_mat("hose_rubber")

	# 1. Weathered concrete fueling pad + gentle drive-on ramps (NO sudden curb bump!)
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(20.0, 0.09, 34.0)
	_add_mesh_child(self, "ConcreteApron", pad_mesh, apron_mat, Vector3(2.0, 0.025, 0.0), Vector3.ZERO, false)

	var stripe_mat := ProceduralMaterials.get_material("stripe_yellow")
	for sx: float in [-5.8, -0.9]:
		var lane_mark := BoxMesh.new()
		lane_mark.size = Vector3(0.32, 0.02, 28.0)
		_add_mesh_child(self, "FuelLaneStripe", lane_mark, stripe_mat, Vector3(sx, 0.075, 0.0), Vector3.ZERO, false)

	# 2. Central raised concrete pump island (x_local = +1.0, out of highway main traffic)
	var island_body := StaticBody3D.new()
	island_body.name = "PumpIslandBody"
	island_body.collision_layer = 9
	island_body.collision_mask = 525
	island_body.position = Vector3(1.1, 0.16, 0.0)
	add_child(island_body)

	var island_box := BoxMesh.new()
	island_box.size = Vector3(2.2, 0.24, 15.6)
	_add_mesh_child(island_body, "IslandCurbMesh", island_box, island_mat, Vector3.ZERO, Vector3.ZERO, true)

	var island_col := CollisionShape3D.new()
	var island_shape := BoxShape3D.new()
	island_shape.size = Vector3(2.2, 0.45, 15.6)
	island_col.shape = island_shape
	island_body.add_child(island_col)

	# 3. Industrial Diesel Fuel Dispensers + Emergency Generator Pumps on the Island
	for pz: float in [-4.0, 4.0]:
		var disp := Node3D.new()
		disp.name = "FuelDispenser"
		disp.position = Vector3(1.1, 0.28, pz)
		add_child(disp)

		var cab_mesh := BoxMesh.new()
		cab_mesh.size = Vector3(0.92, 1.85, 1.15)
		_add_mesh_child(disp, "DispenserBody", cab_mesh, steel_mat, Vector3(0.0, 0.92, 0.0), Vector3.ZERO, true)

		var trim_mesh := BoxMesh.new()
		trim_mesh.size = Vector3(0.98, 0.22, 1.22)
		_add_mesh_child(disp, "DispenserTopTrim", trim_mesh, hazard_mat, Vector3(0.0, 1.80, 0.0), Vector3.ZERO, false)

		var screen_mesh := BoxMesh.new()
		screen_mesh.size = Vector3(0.96, 0.26, 0.68)
		_add_mesh_child(disp, "DispenserMeter", screen_mesh, screen_mat, Vector3(0.0, 1.38, 0.0), Vector3.ZERO, false)

		var nozzle_box := BoxMesh.new()
		nozzle_box.size = Vector3(0.10, 0.85, 0.12)
		_add_mesh_child(disp, "FuelHose", nozzle_box, hose_mat, Vector3(-0.48, 0.98, 0.35), Vector3(0.0, 0.0, 0.18), false)

	_spawn_gltf(self, GLTF_GENERATOR, Vector3(1.1, 0.28, 0.0), Vector3(0.0, PI * 0.5, 0.0), 1.55)
	_spawn_gltf(self, GLTF_JERRYCAN, Vector3(0.7, 0.28, -6.2), Vector3(0.0, 0.35, 0.0), 1.65)
	_spawn_gltf(self, GLTF_JERRYCAN, Vector3(1.5, 0.28, 6.2), Vector3(0.0, -0.45, 0.0), 1.65)

	# 4. Cantilevered Corrugated Steel Canopy (supports ONLY on island + outer pad so fueling lane is wide open!)
	var canopy_body := StaticBody3D.new()
	canopy_body.name = "CanopyStructure"
	canopy_body.collision_layer = 9
	canopy_body.collision_mask = 525
	add_child(canopy_body)

	var col_mesh := BoxMesh.new()
	col_mesh.size = Vector3(0.42, 5.4, 0.42)
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.75, 0.65, 0.75)

	var pillar_coords: Array[Vector2] = [
		Vector2(1.1, -6.2),
		Vector2(1.1, 6.2),
		Vector2(8.4, -6.2),
		Vector2(8.4, 6.2),
	]
	for pt: Vector2 in pillar_coords:
		_add_mesh_child(canopy_body, "SteelColumn", col_mesh, steel_mat, Vector3(pt.x, 2.75, pt.y), Vector3.ZERO, true)
		_add_mesh_child(canopy_body, "ColumnFooting", base_mesh, island_mat, Vector3(pt.x, 0.36, pt.y), Vector3.ZERO, false)
		var p_col := CollisionShape3D.new()
		var p_shape := BoxShape3D.new()
		p_shape.size = Vector3(0.55, 5.4, 0.55)
		p_col.shape = p_shape
		p_col.position = Vector3(pt.x, 2.75, pt.y)
		canopy_body.add_child(p_col)

	# Cantilevered roof spans from x = -6.0 (over fueling lane) to x = +9.4 (over service yard)
	var fascia_mesh := BoxMesh.new()
	fascia_mesh.size = Vector3(15.4, 0.55, 19.6)
	_add_mesh_child(canopy_body, "CanopyFascia", fascia_mesh, steel_mat, Vector3(1.7, 5.65, 0.0), Vector3.ZERO, true)

	var roof_deck_mesh := BoxMesh.new()
	roof_deck_mesh.size = Vector3(15.0, 0.14, 19.2)
	_add_mesh_child(canopy_body, "CanopyRoofSheet", roof_deck_mesh, roof_mat, Vector3(1.7, 5.98, 0.0), Vector3.ZERO, true)

	var trim_band := BoxMesh.new()
	trim_band.size = Vector3(15.55, 0.16, 19.75)
	_add_mesh_child(canopy_body, "CanopyHazardBand", trim_band, hazard_mat, Vector3(1.7, 5.46, 0.0), Vector3.ZERO, false)

	# Canopy front & rear approach signs
	var sign_back_mesh := BoxMesh.new()
	sign_back_mesh.size = Vector3(6.2, 0.85, 0.14)
	for z_face: Dictionary in [
		{"board_z": 9.95, "lbl_z": 10.04, "ry": 0.0},
		{"board_z": -9.95, "lbl_z": -10.04, "ry": PI},
	]:
		_add_mesh_child(
			canopy_body,
			"CanopySignBack",
			sign_back_mesh,
			steel_mat,
			Vector3(-1.4, 5.76, float(z_face["board_z"])),
			Vector3.ZERO,
			false
		)
		var clbl := Label3D.new()
		clbl.text = "АЗС  //  ТОПЛИВО"
		clbl.font = FONT_RUSSO
		clbl.font_size = 76
		clbl.pixel_size = 0.0085
		clbl.modulate = Color(0.98, 0.78, 0.34, 0.96)
		clbl.outline_modulate = Color(0.06, 0.05, 0.04, 1.0)
		clbl.outline_size = 14
		clbl.position = Vector3(-1.4, 5.76, float(z_face["lbl_z"]))
		clbl.rotation = Vector3(0.0, float(z_face["ry"]), 0.0)
		canopy_body.add_child(clbl)

	# Subtle underside fluorescent strips along fueling lane ceiling
	var tube_mesh := BoxMesh.new()
	tube_mesh.size = Vector3(0.24, 0.08, 3.2)
	for tz: float in [-4.5, 4.5]:
		_add_mesh_child(canopy_body, "CanopyLightStrip", tube_mesh, tube_mat, Vector3(-2.8, 5.34, tz), Vector3.ZERO, false)

	# 5. High-Visibility Roadside Fuel Pylon Sign at station entrance (visible at long fog distance!)
	var sign_pole := BoxMesh.new()
	sign_pole.size = Vector3(0.32, 7.2, 0.32)
	_add_mesh_child(canopy_body, "FuelPylonPost", sign_pole, steel_mat, Vector3(-0.2, 3.6, 14.5), Vector3.ZERO, true)
	var s_col := CollisionShape3D.new()
	var s_shape := BoxShape3D.new()
	s_shape.size = Vector3(0.45, 7.2, 0.45)
	s_col.shape = s_shape
	s_col.position = Vector3(-0.2, 3.6, 14.5)
	canopy_body.add_child(s_col)

	var sign_board := BoxMesh.new()
	sign_board.size = Vector3(3.1, 1.55, 0.34)
	_add_mesh_child(canopy_body, "FuelSignFrame", sign_board, steel_mat, Vector3(-0.2, 6.7, 14.5), Vector3.ZERO, false)

	var sign_panel := BoxMesh.new()
	sign_panel.size = Vector3(2.75, 0.96, 0.38)
	_add_mesh_child(canopy_body, "FuelSignGlow", sign_panel, sign_mat, Vector3(-0.2, 6.7, 14.5), Vector3.ZERO, false)

	for sz_face: Dictionary in [
		{"z": 14.72, "ry": 0.0},
		{"z": 14.28, "ry": PI},
	]:
		var plbl := Label3D.new()
		plbl.text = "FUEL 24"
		plbl.font = FONT_RUSSO
		plbl.font_size = 86
		plbl.pixel_size = 0.0072
		plbl.modulate = Color(0.10, 0.07, 0.04, 1.0)
		plbl.outline_modulate = Color(1.0, 0.85, 0.42, 0.9)
		plbl.outline_size = 6
		plbl.position = Vector3(-0.2, 6.7, float(sz_face["z"]))
		plbl.rotation = Vector3(0.0, float(sz_face["ry"]), 0.0)
		canopy_body.add_child(plbl)

	# 5b. Weathered Concrete & Corrugated-Iron Operator Kiosk on outer station pad
	var kiosk := StaticBody3D.new()
	kiosk.name = "StationKiosk"
	kiosk.collision_layer = 9
	kiosk.collision_mask = 525
	kiosk.position = Vector3(6.8, 0.08, 0.8)
	add_child(kiosk)

	var kiosk_walls := BoxMesh.new()
	kiosk_walls.size = Vector3(4.2, 3.1, 5.8)
	_add_mesh_child(kiosk, "KioskWalls", kiosk_walls, island_mat, Vector3(0.0, 1.55, 0.0), Vector3.ZERO, true)

	var kiosk_col := CollisionShape3D.new()
	var kiosk_box := BoxShape3D.new()
	kiosk_box.size = Vector3(4.3, 3.2, 5.9)
	kiosk_col.shape = kiosk_box
	kiosk_col.position = Vector3(0.0, 1.6, 0.0)
	kiosk.add_child(kiosk_col)

	var kiosk_roof := BoxMesh.new()
	kiosk_roof.size = Vector3(5.0, 0.24, 6.4)
	_add_mesh_child(kiosk, "KioskCorrugatedRoof", kiosk_roof, roof_mat, Vector3(-0.25, 3.18, 0.0), Vector3(0.0, 0.0, 0.06), true)

	var shutter := BoxMesh.new()
	shutter.size = Vector3(0.14, 1.35, 3.0)
	_add_mesh_child(kiosk, "KioskWindowShutter", shutter, steel_mat, Vector3(-2.12, 1.75, 0.0), Vector3.ZERO, false)

	var win_glow := BoxMesh.new()
	win_glow.size = Vector3(0.12, 0.42, 1.8)
	_add_mesh_child(kiosk, "KioskSlitGlow", win_glow, screen_mat, Vector3(-2.14, 1.75, 0.0), Vector3.ZERO, false)

	_spawn_gltf(kiosk, GLTF_JERRYCAN, Vector3(-2.4, 0.0, -1.6), Vector3(0.0, 0.4, 0.0), 1.65)
	_spawn_gltf(kiosk, GLTF_JERRYCAN, Vector3(-2.4, 0.0, -2.1), Vector3(0.0, -0.3, 0.0), 1.65)

	# 6. Outer Fuel Yard: Tanker wreck + Propane tanks + IBC totes + Military crates
	if TANKER_WRECK_SCENE:
		var tanker := TANKER_WRECK_SCENE.instantiate() as Node3D
		if tanker:
			add_child(tanker)
			tanker.position = Vector3(13.8, 1.50, -3.0)
			tanker.rotation = Vector3(0.0, 0.26, 0.0)
			ProceduralMaterials.apply_headlight_materials_to_node(tanker)
			_freeze_sleeping_rigid(tanker)

	_spawn_static_gltf_with_box(GLTF_PROPANE, Vector3(6.2, 0.06, 9.8), Vector3(0.0, 0.4, 0.0), 2.4, Vector3(0.9, 1.4, 0.9))
	_spawn_static_gltf_with_box(GLTF_PROPANE, Vector3(7.4, 0.06, 11.2), Vector3(0.0, -0.2, 0.0), 2.4, Vector3(0.9, 1.4, 0.9))
	_spawn_static_gltf_with_box(GLTF_IBC, Vector3(5.2, 0.14, -9.6), Vector3(0.0, 0.15, 0.0), 2.1, Vector3(1.1, 1.1, 1.4))
	_spawn_static_gltf_with_box(GLTF_IBC, Vector3(7.2, 0.14, -9.8), Vector3(0.0, -0.25, 0.0), 2.1, Vector3(1.1, 1.1, 1.4))

	# 7. Smashable roadside barriers, crates & oil drums around service pad perimeter
	for bz: float in [-14.2, 14.2]:
		_spawn_knockable_gltf(GLTF_BARRIER, Vector3(3.4, 0.08, bz), rng_yaw(bz), 1.45, Vector3(2.2, 1.15, 0.92), "concrete", 320.0, 10.0)
	_spawn_knockable_gltf(GLTF_CRATE, Vector3(-0.6, 0.18, 10.4), 0.35, 1.45, Vector3(1.35, 0.56, 1.0), "wood", 85.0, 3.0)
	_spawn_knockable_gltf(GLTF_CRATE, Vector3(-0.6, 0.18, -10.2), -0.40, 1.45, Vector3(1.35, 0.56, 1.0), "wood", 85.0, 3.0)

	var barrel_spots: Array[Dictionary] = [
		{"pos": Vector3(4.0, 0.04, -3.5), "explosive": false, "yaw": 0.4},
		{"pos": Vector3(4.8, 0.04, 5.2), "explosive": true, "yaw": -0.7},
		{"pos": Vector3(-0.8, 0.04, 12.2), "explosive": false, "yaw": 1.2},
	]
	for b_sp: Dictionary in barrel_spots:
		var is_exp: bool = bool(b_sp["explosive"])
		var b_mesh: Mesh = ProceduralMaterials.get_ph_barrel_mesh() if is_exp else ProceduralMaterials.get_ph_blue_barrel_mesh()
		if b_mesh == null:
			continue
		var kp := KnockableProp.new()
		kp.name = "FuelStationRedBarrel" if is_exp else "FuelStationBlueBarrel"
		kp.is_barrel = true
		kp.is_explosive_barrel = is_exp
		kp.prop_material = "metal" if is_exp else "barrel_blue"
		kp.prop_mass = 65.0
		kp.damage_to_car = 2.0
		kp.speed_drag_factor = 0.024
		kp.prop_height = 1.18
		kp.position = b_sp["pos"] as Vector3
		kp.rotation = Vector3(0.0, float(b_sp["yaw"]), 0.0)
		var b_mi := MeshInstance3D.new()
		b_mi.mesh = b_mesh
		b_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b_mi.visibility_range_end = 195.0
		kp.add_child(b_mi)
		var b_col := CollisionShape3D.new()
		var b_bx := BoxShape3D.new()
		b_bx.size = Vector3(0.78, 1.16, 0.78)
		b_col.shape = b_bx
		b_col.position = Vector3(0.0, 0.58, 0.0)
		kp.add_child(b_col)
		add_child(kp)

	# 8. Grounded Drive-Through Fuel Canisters inside Fueling Lane (REFUEL ONLY — ZERO REPAIR!)
	if GAS_CANISTER_SCENE:
		var lane_spots: Array[Dictionary] = [
			{"pos": Vector3(-3.3, 0.38, -2.5), "frac": 1.0},
			{"pos": Vector3(-3.3, 0.38, 4.8), "frac": 1.0},
			{"pos": Vector3(-6.4, 0.38, 0.5), "frac": 0.65},
		]
		for sp: Dictionary in lane_spots:
			var gas_inst := GAS_CANISTER_SCENE.instantiate()
			if gas_inst:
				gas_inst.set("fuel_fraction", float(sp["frac"]))
				add_child(gas_inst)
				(gas_inst as Node3D).position = sp["pos"] as Vector3

func rng_yaw(seed_f: float) -> float:
	return sin(seed_f * 1.73) * 0.18

func _freeze_sleeping_rigid(node: Node) -> void:
	if node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.can_sleep = true
		rb.sleeping = true
	for ch in node.get_children():
		_freeze_sleeping_rigid(ch)

func _spawn_gltf(parent: Node3D, ps: PackedScene, pos: Vector3, rot: Vector3, scale_factor: float) -> Node3D:
	if ps == null:
		return null
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return null
	inst.position = pos
	inst.rotation = rot
	inst.scale = Vector3.ONE * scale_factor
	parent.add_child(inst)
	ProceduralMaterials.apply_headlight_materials_to_node(inst)
	return inst

func _spawn_static_gltf_with_box(ps: PackedScene, pos: Vector3, rot: Vector3, scale_factor: float, col_size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 9
	body.collision_mask = 525
	body.position = pos
	body.rotation = rot
	add_child(body)
	var visual := _spawn_gltf(body, ps, Vector3.ZERO, Vector3.ZERO, scale_factor)
	if visual:
		var c := CollisionShape3D.new()
		var bx := BoxShape3D.new()
		bx.size = col_size
		c.shape = bx
		c.position = Vector3(0.0, col_size.y * 0.5, 0.0)
		body.add_child(c)

func _spawn_knockable_gltf(
	ps: PackedScene,
	pos: Vector3,
	yaw: float,
	scale_factor: float,
	col_size: Vector3,
	mat_kind: String,
	p_mass: float,
	p_dmg: float
) -> void:
	var kp := KnockableProp.new()
	kp.prop_material = mat_kind
	kp.prop_mass = p_mass
	kp.damage_to_car = p_dmg
	kp.speed_drag_factor = 0.10 if mat_kind == "concrete" else 0.05
	kp.prop_height = col_size.y
	kp.position = pos
	kp.rotation = Vector3(0.0, yaw, 0.0)
	add_child(kp)

	_spawn_gltf(kp, ps, Vector3.ZERO, Vector3.ZERO, scale_factor)
	var col := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = col_size
	col.shape = bx
	col.position = Vector3(0.0, col_size.y * 0.5 + 0.03, 0.0)
	kp.add_child(col)

func _add_mesh_child(
	parent: Node3D,
	node_name: String,
	mesh_res: Mesh,
	mat_res: Material,
	pos: Vector3,
	rot: Vector3,
	cast_shadow_on: bool
) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh_res
	mi.material_override = mat_res
	mi.position = pos
	mi.rotation = rot
	mi.visibility_range_end = 260.0
	if not cast_shadow_on:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
