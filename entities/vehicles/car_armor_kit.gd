extends RefCounted
class_name CarArmorKit

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")
const TEX_RUST_RGH: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_rough_1k.jpg")

static var _mats: Dictionary = {}
static var _tex_diamond_diff: ImageTexture = null
static var _tex_diamond_nor: ImageTexture = null
static var _tex_grille_alpha: ImageTexture = null
static var _tex_hazard_diff: ImageTexture = null
static var _tex_war_detail: ImageTexture = null

static func apply_or_clear_max_kit(vehicle: Node3D, engine_id: String, enabled: bool) -> void:
	apply_staged_kits(vehicle, engine_id, {
		"fuel": enabled,
		"engine": enabled,
		"armor": enabled,
		"chassis": enabled,
	})

static func apply_staged_kits(vehicle: Node3D, engine_id: String, stages: Dictionary) -> void:
	if vehicle == null or not is_instance_valid(vehicle):
		return

	var existing := vehicle.get_node_or_null("FullUpgradeArmorKit") as Node3D
	if is_instance_valid(existing):
		vehicle.remove_child(existing)
		existing.queue_free()

	var base_gun := vehicle.get_node_or_null("Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun") as Node3D
	if is_instance_valid(base_gun):
		var old_turret_kit := base_gun.get_node_or_null("TurretArmorMount") as Node3D
		if is_instance_valid(old_turret_kit):
			base_gun.remove_child(old_turret_kit)
			old_turret_kit.queue_free()

	var st_fuel: bool = bool(stages.get("fuel", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_armor: bool = bool(stages.get("armor", false))
	var st_chassis: bool = bool(stages.get("chassis", false))

	var all_maxed: bool = st_fuel and st_engine and st_armor and st_chassis
	if all_maxed:
		_restore_body_patina(vehicle)
		_apply_body_war_patina(vehicle)
	else:
		_restore_body_patina(vehicle)

	if not (st_fuel or st_engine or st_armor or st_chassis):
		return

	var kit := Node3D.new()
	kit.name = "FullUpgradeArmorKit"
	vehicle.add_child(kit)

	match engine_id:
		"pikap":
			_build_pikap_kit(kit, stages)
		"doge2":
			_build_doge2_kit(kit, stages)
		"mustang", "barracuda":
			_build_barracuda_kit(kit, stages)
		"buhanka":
			_build_buhanka_kit(kit, stages)
		"vandura":
			_build_vandura_kit(kit, stages)
		"carson":
			_build_carson_kit(kit, stages)
		"delorean":
			_build_delorean_kit(kit, stages)
		"k2500":
			_build_k2500_kit(kit, stages)
		"paz3205":
			_build_paz3205_kit(kit, stages)
		"raptor":
			_build_raptor_kit(kit, stages)
		"btr":
			_build_btr_kit(vehicle, kit, stages)
		_:
			_build_pikap_kit(kit, stages)

static func _ensure_procedural_textures() -> void:
	if _tex_diamond_diff != null:
		return

	var sz := 128
	var d_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var g_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var h_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var w_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)

	var rng := RandomNumberGenerator.new()
	rng.seed = 40771
	for y in range(sz):
		for x in range(sz):
			var u := float(x) / float(sz)
			var v := float(y) / float(sz)
			var noise := rng.randf_range(-0.04, 0.04)

			# 1. Diamond plate + rivets + edge panel seams
			var gx := fmod(u * 8.0, 1.0) - 0.5
			var gy := fmod(v * 8.0, 1.0) - 0.5
			var diag1 := absf(gx + gy)
			var diag2 := absf(gx - gy)
			var cell := int(floor(u * 8.0) + floor(v * 8.0)) % 2
			var ridge := maxf(0.0, 1.0 - (diag1 if cell == 0 else diag2) * 5.2) * (1.0 - maxf(absf(gx), absf(gy)) * 1.4)
			ridge = clampf(ridge, 0.0, 1.0)
			var border := 1.0 if (x < 3 or x >= sz - 3 or y < 3 or y >= sz - 3) else 0.0
			var corner_d := minf(
				minf(Vector2(x - 10, y - 10).length(), Vector2(x - (sz - 11), y - 10).length()),
				minf(Vector2(x - 10, y - (sz - 11)).length(), Vector2(x - (sz - 11), y - (sz - 11)).length())
			)
			var rivet := clampf(1.0 - corner_d / 4.2, 0.0, 1.0)
			var base_v := clampf(0.46 + ridge * 0.22 + rivet * 0.28 - border * 0.14 + noise, 0.22, 0.90)
			d_img.set_pixel(x, y, Color(base_v * 0.98, base_v * 0.99, base_v * 1.02, 1.0))

			var nx := clampf(0.5 + (gx if cell == 0 else -gx) * ridge * 0.45, 0.1, 0.9)
			var ny := clampf(0.5 + gy * ridge * 0.45, 0.1, 0.9)
			n_img.set_pixel(x, y, Color(nx, ny, 0.92, 1.0))

			# 2. Perforated steel grille grate (diamond holes with solid thick steel bars)
			var mg1 := absf(fmod(u * 10.0 + v * 10.0, 1.0) - 0.5)
			var mg2 := absf(fmod(u * 10.0 - v * 10.0 + 10.0, 1.0) - 0.5)
			var is_bar := (mg1 < 0.20 or mg2 < 0.20) or (x < 6 or x >= sz - 6 or y < 6 or y >= sz - 6)
			var gc := clampf(0.44 + noise * 0.4, 0.28, 0.62)
			g_img.set_pixel(x, y, Color(gc, gc, gc * 1.04, 1.0 if is_bar else 0.0))

			# 3. Scuffed industrial yellow-black hazard chevrons
			var stripe := sin((u + v) * TAU * 4.0)
			var yellow := Color(0.92, 0.64, 0.16)
			var dark := Color(0.18, 0.18, 0.20)
			var hcol := yellow.lerp(dark, clampf(0.5 - stripe * 6.0, 0.0, 1.0))
			var wear := clampf(noise * 2.2 + 0.06, -0.12, 0.15)
			h_img.set_pixel(x, y, Color(clampf(hcol.r + wear, 0.08, 0.96), clampf(hcol.g + wear, 0.08, 0.92), clampf(hcol.b + wear, 0.08, 0.88), 1.0))

			# 4. Tactical war-rig battle-patina overlay (weld lines & steel scratches without crushing dark tones)
			var scratch := 1.0 if (absf(sin(u * 31.0 + v * 7.0) * cos(v * 53.0 - u * 11.0)) > 0.955 and absf(u - 0.5) > 0.08) else 0.0
			var seam := 1.0 if ((x % 32 == 0) or (y % 64 == 0)) else 0.0
			var pat := clampf(0.90 - seam * 0.26 + scratch * 0.12 + noise * 1.1, 0.56, 1.0)
			w_img.set_pixel(x, y, Color(pat, pat * 0.99, pat * 0.97, 1.0))

	_tex_diamond_diff = ImageTexture.create_from_image(d_img)
	_tex_diamond_nor = ImageTexture.create_from_image(n_img)
	_tex_grille_alpha = ImageTexture.create_from_image(g_img)
	_tex_hazard_diff = ImageTexture.create_from_image(h_img)
	_tex_war_detail = ImageTexture.create_from_image(w_img)

static func _get_mat(key: String) -> StandardMaterial3D:
	_ensure_procedural_textures()
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D

	var m := StandardMaterial3D.new()
	match key:
		"armor_plate":
			m.albedo_color = Color(0.68, 0.70, 0.73)
			m.albedo_texture = _tex_diamond_diff
			m.normal_enabled = true
			m.normal_texture = TEX_RUST_NOR if TEX_RUST_NOR != null else _tex_diamond_nor
			m.normal_scale = 0.75
			m.metallic = 0.48
			m.roughness = 0.44
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"cage_pipe":
			m.albedo_color = Color(0.54, 0.56, 0.60)
			m.albedo_texture = _tex_diamond_diff
			m.normal_enabled = true
			m.normal_texture = _tex_diamond_nor
			m.normal_scale = 0.55
			m.metallic = 0.52
			m.roughness = 0.36
		"grille":
			m.albedo_color = Color(0.76, 0.78, 0.80)
			m.albedo_texture = _tex_grille_alpha
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.4
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic = 0.52
			m.roughness = 0.42
			m.uv1_scale = Vector3(1.5, 1.5, 1.0)
		"hazard":
			m.albedo_texture = _tex_hazard_diff
			m.metallic = 0.36
			m.roughness = 0.48
			m.normal_enabled = true
			m.normal_texture = _tex_diamond_nor
			m.normal_scale = 0.55
		"fuel_tank":
			m.albedo_color = Color(0.72, 0.22, 0.14)
			m.albedo_texture = _tex_diamond_diff
			m.normal_enabled = true
			m.normal_texture = TEX_RUST_NOR if TEX_RUST_NOR != null else _tex_diamond_nor
			m.normal_scale = 0.65
			m.metallic = 0.34
			m.roughness = 0.52
		"floodlamp_lens":
			m.albedo_color = Color(1.0, 0.94, 0.80)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.88, 0.62)
			m.emission_energy_multiplier = 2.6
			m.roughness = 0.15
	_mats[key] = m
	return m

static func _apply_body_war_patina(vehicle: Node3D) -> void:
	_ensure_procedural_textures()
	var saved: Dictionary = {}
	_scan_and_patch_materials(vehicle, saved)
	if not saved.is_empty():
		vehicle.set_meta("_max_patina_originals", saved)

static func _scan_and_patch_materials(node: Node, saved: Dictionary) -> void:
	if node.name == "FullUpgradeArmorKit" or node.name == "VisualLightsRig":
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null and not mi.name.contains("Gun_Effect"):
			for s in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(s) as StandardMaterial3D
				if mat == null:
					continue
				if mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or mat.emission_enabled:
					continue
				var rn := mat.resource_name.to_lower()
				if rn.contains("glass") or rn.contains("window") or rn.contains("windshield") or rn.contains("tire") or rn.contains("wheel") or rn.contains("light") or rn.contains("lamp"):
					continue
				var key := "%d_%d" % [mi.get_instance_id(), s]
				saved[key] = [mi, s, mi.get_surface_override_material(s)]
				var pat := mat.duplicate() as StandardMaterial3D
				pat.albedo_color = pat.albedo_color.lerp(Color(0.72, 0.70, 0.66), 0.14)
				pat.metallic = clampf(pat.metallic, 0.14, 0.36)
				pat.roughness = clampf(lerpf(pat.roughness, 0.48, 0.45), 0.24, 0.85)
				pat.clearcoat = minf(pat.clearcoat, 0.28)
				pat.detail_enabled = true
				pat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
				pat.detail_albedo = _tex_war_detail
				pat.detail_normal = _tex_diamond_nor
				mi.set_surface_override_material(s, pat)
	for child in node.get_children():
		_scan_and_patch_materials(child, saved)

static func _restore_body_patina(vehicle: Node3D) -> void:
	if not vehicle.has_meta("_max_patina_originals"):
		return
	var saved = vehicle.get_meta("_max_patina_originals")
	if typeof(saved) == TYPE_DICTIONARY:
		for k in (saved as Dictionary).keys():
			var rec: Array = (saved as Dictionary)[k]
			var mi: MeshInstance3D = rec[0] as MeshInstance3D
			var s: int = int(rec[1])
			var orig_m: Material = rec[2] as Material
			if is_instance_valid(mi):
				mi.set_surface_override_material(s, orig_m)
	vehicle.remove_meta("_max_patina_originals")

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, rot_deg: Vector3, mat: Material, node_name: String = "ArmorPart") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _add_tube(parent: Node3D, p0: Vector3, p1: Vector3, radius: float, mat: Material, with_caps: bool = true) -> void:
	var diff := p1 - p0
	var dist := diff.length()
	if dist < 0.01:
		return
	var mid := (p0 + p1) * 0.5
	var dir := diff / dist

	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = dist
	cyl.radial_segments = 10

	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var up_ref := Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var x_ax := up_ref.cross(dir).normalized()
	var z_ax := dir.cross(x_ax).normalized()
	mi.transform = Transform3D(Basis(x_ax, dir, z_ax), mid)
	parent.add_child(mi)

	if with_caps:
		var cap := SphereMesh.new()
		cap.radius = radius * 1.04
		cap.height = radius * 2.08
		cap.radial_segments = 8
		cap.rings = 4
		for end_pt in [p0, p1]:
			var ci := MeshInstance3D.new()
			ci.mesh = cap
			ci.material_override = mat
			ci.position = end_pt
			ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(ci)

static func _add_wedge_ram(parent: Node3D, base_z: float, y_bot: float, y_top: float, half_w: float, tip_ext: float, center_x: float = 0.0) -> void:
	var plate_mat := _get_mat("armor_plate")
	var hazard_mat := _get_mat("hazard")
	var pipe_mat := _get_mat("cage_pipe")

	# Two angled heavy steel plow wings sweeping into a sharp central V-nose + hazard edge teeth
	var nose_z := base_z - tip_ext
	for side: float in [-1.0, 1.0]:
		var wing_center := Vector3(center_x + side * half_w * 0.50, (y_bot + y_top) * 0.5, base_z - tip_ext * 0.44)
		var yaw := -side * 16.0
		_add_box(parent, wing_center, Vector3(half_w * 1.02, y_top - y_bot, 0.08), Vector3(14.0, yaw, 0.0), plate_mat, "RamWing")
		var tip_pos := Vector3(center_x + side * half_w * 0.88, y_bot + (y_top - y_bot) * 0.45, base_z - tip_ext * 0.18)
		_add_box(parent, tip_pos, Vector3(0.24, (y_top - y_bot) * 0.85, 0.11), Vector3(14.0, yaw, 0.0), hazard_mat, "RamTip")

	# Central armored spine wedge & gusset braces
	_add_box(parent, Vector3(center_x, (y_bot + y_top) * 0.5, nose_z + 0.06), Vector3(0.18, (y_top - y_bot) * 1.05, 0.24), Vector3(12.0, 0.0, 0.0), hazard_mat, "RamNoseSpine")
	_add_tube(parent, Vector3(center_x - half_w * 0.85, y_top + 0.04, base_z - tip_ext * 0.12), Vector3(center_x, y_top + 0.06, nose_z), 0.038, pipe_mat)
	_add_tube(parent, Vector3(center_x + half_w * 0.85, y_top + 0.04, base_z - tip_ext * 0.12), Vector3(center_x, y_top + 0.06, nose_z), 0.038, pipe_mat)

static func _add_louver_rack(parent: Node3D, center: Vector3, width: float, span: float, tilt_deg_x: float, slat_count: int, slat_pitch_deg: float = -18.0) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var rack := Node3D.new()
	rack.position = center
	rack.rotation_degrees.x = tilt_deg_x
	parent.add_child(rack)

	for side: float in [-1.0, 1.0]:
		_add_box(rack, Vector3(side * width * 0.5, 0.0, 0.0), Vector3(0.036, 0.045, span), Vector3.ZERO, pipe_mat, "LouverRail")
	for i in range(slat_count):
		var t := (float(i) / float(maxi(slat_count - 1, 1))) - 0.5
		_add_box(rack, Vector3(0.0, 0.008, t * span * 0.86), Vector3(width - 0.03, 0.018, 0.075), Vector3(slat_pitch_deg, 0.0, 0.0), plate_mat, "LouverSlat")

static func _add_roof_lightbar(parent: Node3D, pos: Vector3, width: float, lamp_count: int = 4) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var lens_mat := _get_mat("floodlamp_lens")
	_add_tube(parent, pos + Vector3(-width * 0.5, 0.0, 0.0), pos + Vector3(width * 0.5, 0.0, 0.0), 0.032, pipe_mat)
	for i in range(lamp_count):
		var t := (float(i) / float(maxi(lamp_count - 1, 1))) - 0.5
		var lx := pos.x + t * (width * 0.78)
		_add_box(parent, Vector3(lx, pos.y + 0.065, pos.z), Vector3(0.18, 0.10, 0.11), Vector3.ZERO, pipe_mat, "AuxLampBody")
		_add_box(parent, Vector3(lx, pos.y + 0.065, pos.z - 0.056), Vector3(0.14, 0.07, 0.015), Vector3.ZERO, lens_mat, "AuxLampLens")

static func _add_aux_fuel_tanks(parent: Node3D, spots: Array, drum_radius: float = 0.16, drum_len: float = 0.56, rot_deg: Vector3 = Vector3(90.0, 0.0, 0.0)) -> void:
	var fuel_mat := _get_mat("fuel_tank")
	var pipe_mat := _get_mat("cage_pipe")
	var cyl := CylinderMesh.new()
	cyl.top_radius = drum_radius
	cyl.bottom_radius = drum_radius
	cyl.height = drum_len
	cyl.radial_segments = 12
	var band := CylinderMesh.new()
	band.top_radius = drum_radius * 1.07
	band.bottom_radius = drum_radius * 1.07
	band.height = 0.055
	band.radial_segments = 12

	for spot: Vector3 in spots:
		var holder := Node3D.new()
		holder.name = "AuxFuelDrum"
		holder.position = spot
		holder.rotation_degrees = rot_deg
		parent.add_child(holder)

		var dm := MeshInstance3D.new()
		dm.mesh = cyl
		dm.material_override = fuel_mat
		dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		holder.add_child(dm)

		for by: float in [-drum_len * 0.28, drum_len * 0.28]:
			var bm := MeshInstance3D.new()
			bm.mesh = band
			bm.position = Vector3(0.0, by, 0.0)
			bm.material_override = pipe_mat
			bm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(bm)

static func _build_pikap_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")

	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		# Передний V-таран, кенгурятник, решётка радиатора и бронелисты дверей
		_add_wedge_ram(kit, -2.35, 0.28, 0.72, 0.96, 0.30, 0.0)
		_add_tube(kit, Vector3(-0.92, 0.72, -2.38), Vector3(-0.92, 1.12, -2.30), 0.038, pipe_mat)
		_add_tube(kit, Vector3(0.92, 0.72, -2.38), Vector3(0.92, 1.12, -2.30), 0.038, pipe_mat)
		_add_tube(kit, Vector3(-0.92, 1.12, -2.30), Vector3(0.92, 1.12, -2.30), 0.036, pipe_mat)
		_add_box(kit, Vector3(0.0, 0.88, -2.36), Vector3(0.96, 0.38, 0.03), Vector3.ZERO, grille_mat, "RadiatorGrille")
		for sx: float in [-1.04, 1.04]:
			_add_box(kit, Vector3(sx, 0.66, 0.02), Vector3(0.05, 0.34, 1.32), Vector3.ZERO, plate_mat, "DoorArmor")

	if st_engine:
		# Воздухозаборник на капот и вертикальные выхлопные трубы за кабиной
		_add_box(kit, Vector3(0.0, 1.29, -1.28), Vector3(0.56, 0.14, 0.68), Vector3.ZERO, plate_mat, "HoodIntake")
		_add_box(kit, Vector3(0.0, 1.29, -1.62), Vector3(0.48, 0.10, 0.03), Vector3.ZERO, grille_mat, "HoodIntakeGrille")
		for sx: float in [-0.88, 0.88]:
			_add_tube(kit, Vector3(sx, 1.12, 0.44), Vector3(sx, 2.02, 0.48), 0.046, pipe_mat)
			_add_box(kit, Vector3(sx, 2.02, 0.50), Vector3(0.11, 0.08, 0.14), Vector3(24.0, 0.0, 0.0), plate_mat, "ExhaustStackTip")

	if st_chassis:
		# Бронежалюзи лобового стекла, дуги кузова и боковые силовые пороги
		_add_louver_rack(kit, Vector3(0.0, 1.48, -0.49), 1.24, 0.44, -50.0, 4, 24.0)
		for sx: float in [-0.80, 0.80]:
			_add_tube(kit, Vector3(sx, 1.14, 0.56), Vector3(sx * 0.92, 1.96, 0.56), 0.042, pipe_mat)
			_add_tube(kit, Vector3(sx * 0.92, 1.96, 0.56), Vector3(sx, 1.14, 2.08), 0.038, pipe_mat)
			_add_tube(kit, Vector3(sx, 1.14, 0.56), Vector3(sx, 1.14, 2.18), 0.034, pipe_mat)
		for sx: float in [-1.06, 1.06]:
			_add_tube(kit, Vector3(sx, 0.36, -0.82), Vector3(sx, 0.36, 0.84), 0.044, pipe_mat)

	if st_fuel:
		# Дополнительные топливные баки-бочки в кузове и люстра на крышу/дугу
		_add_aux_fuel_tanks(kit, [Vector3(-0.46, 0.98, 1.28), Vector3(0.46, 0.98, 1.28)], 0.19, 0.84, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 1.96, 0.56 if st_chassis else 0.12), 1.48, 4)

static func _build_doge2_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")

	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		# Штурмовой таран, решётка перехватчика и броненакладки дверей
		_add_wedge_ram(kit, -2.62, 0.22, 0.58, 1.02, 0.32, 0.0)
		_add_box(kit, Vector3(0.0, 0.70, -2.65), Vector3(1.16, 0.28, 0.03), Vector3.ZERO, grille_mat, "ChargerGrille")
		_add_tube(kit, Vector3(-1.04, 0.56, -2.66), Vector3(-0.94, 0.88, -2.60), 0.035, pipe_mat)
		_add_tube(kit, Vector3(1.04, 0.56, -2.66), Vector3(0.94, 0.88, -2.60), 0.035, pipe_mat)
		_add_tube(kit, Vector3(-0.94, 0.88, -2.60), Vector3(0.94, 0.88, -2.60), 0.034, pipe_mat)
		for sx: float in [-1.11, 1.11]:
			_add_box(kit, Vector3(sx, 0.56, 0.0), Vector3(0.05, 0.30, 1.46), Vector3.ZERO, plate_mat, "SideDoorArmor")

	if st_engine:
		# Компрессор-нагнетатель на капоте + массивный задний боевой спойлер
		_add_box(kit, Vector3(0.0, 1.03, -1.52), Vector3(0.62, 0.16, 0.86), Vector3.ZERO, plate_mat, "BlowerCowl")
		_add_box(kit, Vector3(0.0, 1.03, -1.96), Vector3(0.54, 0.12, 0.02), Vector3.ZERO, grille_mat, "BlowerGrille")
		_add_box(kit, Vector3(0.0, 1.18, 2.48), Vector3(1.86, 0.05, 0.30), Vector3(-9.0, 0.0, 0.0), plate_mat, "DodgeWing")
		for wx: float in [-0.52, 0.52]:
			_add_box(kit, Vector3(wx, 1.04, 2.44), Vector3(0.05, 0.24, 0.22), Vector3.ZERO, pipe_mat, "DodgeWingStrut")

	if st_chassis:
		# Жалюзи лобового/заднего стекла и силовые пороги
		_add_louver_rack(kit, Vector3(0.0, 1.20, -0.48), 1.46, 0.62, -32.0, 4, 22.0)
		_add_louver_rack(kit, Vector3(0.0, 1.21, 1.12), 1.40, 0.92, 16.0, 6, -16.0)
		for sx: float in [-1.14, 1.14]:
			_add_tube(kit, Vector3(sx, 0.28, -0.96), Vector3(sx, 0.28, 0.96), 0.042, pipe_mat)

	if st_fuel:
		# Выносные баки на багажнике и тактическая люстра на крыше
		_add_aux_fuel_tanks(kit, [Vector3(-0.58, 1.02, 2.02), Vector3(0.58, 1.02, 2.02)], 0.15, 0.58, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 1.42, 0.05), 1.26, 4)

static func _build_mustang_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var cx := -0.02

	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		# Аэродинамический клин-таран, защитная сетка и боковые броненакладки
		_add_wedge_ram(kit, -2.22, 0.30, 0.62, 0.88, 0.28, cx)
		_add_box(kit, Vector3(cx, 0.72, -2.24), Vector3(0.96, 0.24, 0.03), Vector3.ZERO, grille_mat, "MustangGrille")
		_add_tube(kit, Vector3(cx - 0.84, 0.58, -2.24), Vector3(cx - 0.84, 0.88, -2.18), 0.032, pipe_mat)
		_add_tube(kit, Vector3(cx + 0.84, 0.58, -2.24), Vector3(cx + 0.84, 0.88, -2.18), 0.032, pipe_mat)
		_add_tube(kit, Vector3(cx - 0.84, 0.88, -2.18), Vector3(cx + 0.84, 0.88, -2.18), 0.030, pipe_mat)
		for sx: float in [-0.93, 0.93]:
			_add_box(kit, Vector3(cx + sx, 0.56, 0.02), Vector3(0.04, 0.24, 1.32), Vector3.ZERO, plate_mat, "MustangSideSkirt")

	if st_engine:
		# Сдвоенный воздухозаборник на капот и боевое антикрыло сзади
		_add_box(kit, Vector3(cx, 1.02, -1.26), Vector3(0.58, 0.12, 0.68), Vector3.ZERO, plate_mat, "MustangScoop")
		_add_box(kit, Vector3(cx, 1.02, -1.61), Vector3(0.50, 0.09, 0.03), Vector3.ZERO, grille_mat, "MustangScoopMesh")
		_add_box(kit, Vector3(cx, 1.18, 2.22), Vector3(1.74, 0.05, 0.28), Vector3(-10.0, 0.0, 0.0), plate_mat, "CombatWing")
		for wx: float in [-0.46, 0.46]:
			_add_box(kit, Vector3(cx + wx, 1.07, 2.18), Vector3(0.05, 0.22, 0.20), Vector3.ZERO, pipe_mat, "WingStrut")

	if st_chassis:
		# Внешний трубчатый каркас, боковые рейки и жалюзи на стёкла
		for sx: float in [-0.58, 0.58]:
			_add_tube(kit, Vector3(cx + sx * 1.16, 1.00, -0.74), Vector3(cx + sx, 1.43, -0.10), 0.028, pipe_mat)
			_add_tube(kit, Vector3(cx + sx, 1.43, -0.10), Vector3(cx + sx, 1.43, 0.60), 0.028, pipe_mat)
			_add_tube(kit, Vector3(cx + sx, 1.43, 0.60), Vector3(cx + sx * 1.18, 1.04, 1.62), 0.028, pipe_mat)
		_add_tube(kit, Vector3(cx - 0.58, 1.43, -0.06), Vector3(cx + 0.58, 1.43, -0.06), 0.028, pipe_mat)
		_add_louver_rack(kit, Vector3(cx, 1.22, -0.43), 1.16, 0.56, -29.0, 4, 22.0)
		_add_louver_rack(kit, Vector3(cx, 1.22, 1.04), 1.14, 0.82, 20.0, 5, -18.0)
		for sx: float in [-0.94, 0.94]:
			_add_tube(kit, Vector3(cx + sx, 0.40, -0.78), Vector3(cx + sx, 0.40, 0.82), 0.038, pipe_mat)

	if st_fuel:
		# Бронированные доп. баки на задних крыльях и прожекторная планка на крыше
		_add_aux_fuel_tanks(kit, [Vector3(cx - 0.56, 1.03, 1.72), Vector3(cx + 0.56, 1.03, 1.72)], 0.14, 0.54, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(cx, 1.45, -0.04), 1.10, 4)

static func _build_raptor_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var hazard_mat := _get_mat("hazard")

	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		# Силовой Baja-бампер, защита картера, сетка и боковые бронелисты дверей
		_add_box(kit, Vector3(0.0, 0.56, -2.76), Vector3(1.88, 0.44, 0.08), Vector3(32.0, 0.0, 0.0), plate_mat, "BajaSkidPlate")
		_add_box(kit, Vector3(0.0, 0.72, -2.90), Vector3(1.94, 0.14, 0.12), Vector3.ZERO, hazard_mat, "BajaRamEdge")
		_add_tube(kit, Vector3(-1.02, 0.78, -2.72), Vector3(-0.96, 1.18, -2.74), 0.046, pipe_mat)
		_add_tube(kit, Vector3(1.02, 0.78, -2.72), Vector3(0.96, 1.18, -2.74), 0.046, pipe_mat)
		_add_tube(kit, Vector3(-0.96, 1.18, -2.74), Vector3(0.96, 1.18, -2.74), 0.046, pipe_mat)
		_add_tube(kit, Vector3(-0.62, 1.18, -2.74), Vector3(-0.46, 1.38, -2.62), 0.036, pipe_mat)
		_add_tube(kit, Vector3(0.62, 1.18, -2.74), Vector3(0.46, 1.38, -2.62), 0.036, pipe_mat)
		_add_box(kit, Vector3(0.0, 1.02, -2.72), Vector3(1.12, 0.34, 0.03), Vector3.ZERO, grille_mat, "RaptorGrilleMesh")
		for sx: float in [-1.08, 1.08]:
			_add_box(kit, Vector3(sx, 0.80, 0.0), Vector3(0.05, 0.32, 1.72), Vector3.ZERO, plate_mat, "RaptorDoorPlate")

	if st_engine:
		# Усиленный турбо-воздухозаборник на капоте и задний бортовой спойлер
		_add_box(kit, Vector3(0.0, 1.46, -1.62), Vector3(0.76, 0.13, 0.84), Vector3.ZERO, plate_mat, "RaptorHoodScoop")
		_add_box(kit, Vector3(0.0, 1.46, -2.05), Vector3(0.66, 0.10, 0.03), Vector3.ZERO, grille_mat, "RaptorScoopGrille")
		_add_box(kit, Vector3(0.0, 1.56, 2.74), Vector3(1.88, 0.06, 0.28), Vector3(-10.0, 0.0, 0.0), plate_mat, "RaptorTailWing")
		for wx: float in [-0.62, 0.62]:
			_add_box(kit, Vector3(wx, 1.46, 2.70), Vector3(0.06, 0.18, 0.20), Vector3.ZERO, pipe_mat, "RaptorWingStrut")

	if st_chassis:
		# Бронежалюзи лобового стекла, дуга кузова Trophy-Truck и силовые пороги
		_add_louver_rack(kit, Vector3(0.0, 1.64, -0.92), 1.54, 0.64, -40.0, 4, 24.0)
		for sx: float in [-0.90, 0.90]:
			_add_tube(kit, Vector3(sx, 1.44, 0.42), Vector3(sx, 1.96, 0.46), 0.044, pipe_mat)
			_add_tube(kit, Vector3(sx, 1.96, 0.46), Vector3(sx, 1.45, 2.66), 0.042, pipe_mat)
			_add_tube(kit, Vector3(sx, 1.45, 0.42), Vector3(sx, 1.45, 2.72), 0.036, pipe_mat)
		_add_tube(kit, Vector3(-0.90, 1.96, 0.46), Vector3(0.90, 1.96, 0.46), 0.044, pipe_mat)
		for sx: float in [-1.10, 1.10]:
			_add_tube(kit, Vector3(sx, 0.44, -1.06), Vector3(sx, 0.44, 1.06), 0.048, pipe_mat)

	if st_fuel:
		# Экспедиционные бочки топлива в кузове, багажник крыши и 4 LED-прожектора
		_add_aux_fuel_tanks(kit, [Vector3(-0.52, 1.52, 1.42), Vector3(0.52, 1.52, 1.42)], 0.19, 0.88, Vector3(90.0, 0.0, 0.0))
		for sx: float in [-0.74, 0.74]:
			_add_tube(kit, Vector3(sx, 1.97, -0.52), Vector3(sx, 1.97, 0.24), 0.032, pipe_mat)
		_add_roof_lightbar(kit, Vector3(0.0, 1.98, -0.50), 1.54, 4)

static func _build_btr_kit(vehicle: Node3D, kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var hazard_mat := _get_mat("hazard")
	var cx := -0.02

	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		# Плотный носовой V-отвал (по контуру бампера z=-2.84) и бортовая броня корпуса
		_add_wedge_ram(kit, -2.84, 0.24, 0.78, 0.94, 0.34, cx)
		for sx: float in [-0.54, 0.54]:
			_add_tube(kit, Vector3(cx + sx, 0.74, -2.62), Vector3(cx + sx * 0.92, 0.52, -3.02), 0.048, pipe_mat)
		for side: float in [-1.0, 1.0]:
			_add_box(kit, Vector3(cx + side * 1.18, 0.72, -0.25), Vector3(0.05, 0.26, 1.38), Vector3(0.0, 0.0, side * -8.0), plate_mat, "SideRockerArmor")

		# Компактная лобовая и бортовая броня башни/турели, повторяющая наклон купола
		var base_gun := vehicle.get_node_or_null("Sketchfab_model/5828856774f842698fde4b89440fa649_fbx/RootNode/Object007/Object_4/Base/base_gun") as Node3D
		if is_instance_valid(base_gun):
			var t_kit := Node3D.new()
			t_kit.name = "TurretArmorMount"
			base_gun.add_child(t_kit)
			var wr_t: WeakRef = weakref(t_kit)
			kit.tree_exiting.connect(func():
				var n := wr_t.get_ref() as Node3D
				if n and is_instance_valid(n):
					n.queue_free()
			)
			_add_box(t_kit, Vector3(-5.8, 2.5, -0.6), Vector3(0.55, 2.3, 5.0), Vector3(0.0, 14.0, -22.0), plate_mat, "TurretLeftCheek")
			_add_box(t_kit, Vector3(5.8, 2.5, -0.6), Vector3(0.55, 2.3, 5.0), Vector3(0.0, -14.0, 22.0), plate_mat, "TurretRightCheek")
			_add_box(t_kit, Vector3(0.0, 2.7, -4.8), Vector3(6.2, 1.5, 0.45), Vector3(-22.0, 0.0, 0.0), grille_mat, "TurretMantletScreen")
			_add_box(t_kit, Vector3(-3.4, 2.9, -4.1), Vector3(2.0, 0.65, 0.42), Vector3(-22.0, 10.0, 0.0), hazard_mat, "TurretTrimL")
			_add_box(t_kit, Vector3(3.4, 2.9, -4.1), Vector3(2.0, 0.65, 0.42), Vector3(-22.0, -10.0, 0.0), hazard_mat, "TurretTrimR")

	if st_engine:
		# Плотно прилегающий экран ВЛД, защита передних фар и компактные теплоэкраны выхлопа на суженной корме
		_add_box(kit, Vector3(cx, 1.06, -2.32), Vector3(1.18, 0.24, 0.05), Vector3(-34.0, 0.0, 0.0), grille_mat, "GlacisCage")
		_add_box(kit, Vector3(-0.73, 0.92, -2.62), Vector3(0.24, 0.16, 0.18), Vector3.ZERO, grille_mat, "HeadlampCageL")
		_add_box(kit, Vector3(0.73, 0.92, -2.62), Vector3(0.24, 0.16, 0.18), Vector3.ZERO, grille_mat, "HeadlampCageR")
		for sx: float in [-0.62, 0.62]:
			_add_box(kit, Vector3(cx + sx, 0.88, 2.26), Vector3(0.16, 0.18, 0.44), Vector3(12.0, sx * -10.0, 0.0), plate_mat, "DieselMufflerBox")

	if st_chassis:
		# Противокумулятивные решётки наклонных бортов (строго по реальной ширине и наклону отсека z=-0.05) и нижние рельсы
		for side: float in [-1.0, 1.0]:
			_add_box(kit, Vector3(cx + side * 1.06, 1.56, -0.05), Vector3(0.04, 0.22, 0.96), Vector3(0.0, 0.0, side * 30.0), grille_mat, "UpperPortCage")
			_add_tube(kit, Vector3(cx + side * 1.24, 0.48, -1.05), Vector3(cx + side * 1.24, 0.48, 0.65), 0.040, pipe_mat)

	if st_fuel:
		# Бронированные дизельные баки-бочки на плоской кормовой палубе (внутри ширины корпуса) и люстра прямо на крыше рубки (y=2.03, z=-0.35)
		_add_aux_fuel_tanks(kit, [Vector3(cx - 0.40, 1.44, 1.56), Vector3(cx + 0.40, 1.44, 1.56)], 0.15, 0.64, Vector3(106.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(cx, 2.02, -0.35), 0.92, 3)

static func _build_barracuda_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -2.36, 0.28, 0.60, 0.90, 0.30, 0.0)
		_add_box(kit, Vector3(0.0, 0.66, -2.32), Vector3(1.10, 0.24, 0.03), Vector3.ZERO, grille_mat, "BarracudaGrille")
		_add_tube(kit, Vector3(-0.88, 0.56, -2.34), Vector3(-0.88, 0.84, -2.28), 0.034, pipe_mat)
		_add_tube(kit, Vector3(0.88, 0.56, -2.34), Vector3(0.88, 0.84, -2.28), 0.034, pipe_mat)
		_add_tube(kit, Vector3(-0.88, 0.84, -2.28), Vector3(0.88, 0.84, -2.28), 0.032, pipe_mat)
		for sx: float in [-1.02, 1.02]:
			_add_box(kit, Vector3(sx, 0.58, 0.04), Vector3(0.05, 0.28, 1.38), Vector3.ZERO, plate_mat, "BarracudaDoorPlate")

	if st_engine:
		_add_box(kit, Vector3(0.0, 0.98, -1.35), Vector3(0.58, 0.14, 0.72), Vector3.ZERO, plate_mat, "HemiScoop")
		_add_box(kit, Vector3(0.0, 0.98, -1.72), Vector3(0.50, 0.10, 0.03), Vector3.ZERO, grille_mat, "HemiScoopGrille")
		_add_box(kit, Vector3(0.0, 1.15, 2.24), Vector3(1.76, 0.05, 0.28), Vector3(-10.0, 0.0, 0.0), plate_mat, "BarracudaWing")
		for wx: float in [-0.48, 0.48]:
			_add_box(kit, Vector3(wx, 1.04, 2.20), Vector3(0.05, 0.22, 0.20), Vector3.ZERO, pipe_mat, "BarracudaWingStrut")

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 1.13, -0.45), 1.24, 0.56, -30.0, 4, 22.0)
		_add_louver_rack(kit, Vector3(0.0, 1.16, 1.08), 1.18, 0.84, 18.0, 5, -18.0)
		for sx: float in [-0.98, 0.98]:
			_add_tube(kit, Vector3(sx, 0.30, -0.82), Vector3(sx, 0.30, 0.86), 0.040, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.52, 1.04, 1.92), Vector3(0.52, 1.04, 1.92)], 0.14, 0.54, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 1.36, 0.08), 1.14, 4)

static func _build_buhanka_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -2.18, 0.28, 0.72, 1.02, 0.30, 0.0)
		_add_box(kit, Vector3(0.0, 0.92, -2.18), Vector3(1.18, 0.42, 0.04), Vector3.ZERO, grille_mat, "BuhankaGrille")
		_add_tube(kit, Vector3(-0.98, 0.72, -2.22), Vector3(-0.98, 1.22, -2.18), 0.040, pipe_mat)
		_add_tube(kit, Vector3(0.98, 0.72, -2.22), Vector3(0.98, 1.22, -2.18), 0.040, pipe_mat)
		_add_tube(kit, Vector3(-0.98, 1.22, -2.18), Vector3(0.98, 1.22, -2.18), 0.038, pipe_mat)
		for sx: float in [-1.14, 1.14]:
			_add_box(kit, Vector3(sx, 0.86, -0.35), Vector3(0.05, 0.52, 2.20), Vector3.ZERO, plate_mat, "BuhankaSideArmor")

	if st_engine:
		_add_tube(kit, Vector3(-0.98, 0.90, 2.08), Vector3(-0.98, 2.28, 2.08), 0.046, pipe_mat)
		_add_tube(kit, Vector3(0.98, 0.90, 2.08), Vector3(0.98, 2.28, 2.08), 0.046, pipe_mat)
		_add_box(kit, Vector3(0.0, 2.18, -0.35), Vector3(0.70, 0.14, 0.76), Vector3.ZERO, plate_mat, "BuhankaRoofIntake")
		_add_box(kit, Vector3(0.0, 2.18, -0.74), Vector3(0.58, 0.10, 0.03), Vector3.ZERO, grille_mat, "BuhankaIntakeMesh")

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 1.50, -2.06), 1.48, 0.52, -78.0, 4, 24.0)
		for sx: float in [-1.10, 1.10]:
			_add_tube(kit, Vector3(sx, 0.36, -0.90), Vector3(sx, 0.36, 0.90), 0.046, pipe_mat)
			_add_tube(kit, Vector3(sx * 0.72, 2.16, -1.55), Vector3(sx * 0.72, 2.16, 1.75), 0.034, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.48, 2.24, 0.75), Vector3(0.48, 2.24, 0.75)], 0.18, 0.82, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 2.22, -1.25), 1.48, 4)

static func _build_vandura_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -2.56, 0.28, 0.68, 1.02, 0.30, 0.0)
		_add_box(kit, Vector3(0.0, 0.85, -2.56), Vector3(1.18, 0.34, 0.04), Vector3.ZERO, grille_mat, "VanduraGrille")
		_add_tube(kit, Vector3(-1.00, 0.68, -2.58), Vector3(-0.94, 1.08, -2.52), 0.040, pipe_mat)
		_add_tube(kit, Vector3(1.00, 0.68, -2.58), Vector3(0.94, 1.08, -2.52), 0.040, pipe_mat)
		_add_tube(kit, Vector3(-0.94, 1.08, -2.52), Vector3(0.94, 1.08, -2.52), 0.038, pipe_mat)
		for sx: float in [-1.14, 1.14]:
			_add_box(kit, Vector3(sx, 0.88, -0.35), Vector3(0.05, 0.48, 2.60), Vector3.ZERO, plate_mat, "VanduraSideArmor")

	if st_engine:
		_add_box(kit, Vector3(0.0, 1.24, -2.06), Vector3(0.66, 0.14, 0.70), Vector3.ZERO, plate_mat, "VanduraScoop")
		for sx: float in [-1.04, 1.04]:
			_add_tube(kit, Vector3(sx, 0.90, 2.45), Vector3(sx, 2.34, 2.45), 0.048, pipe_mat)
		_add_box(kit, Vector3(0.0, 2.22, 2.42), Vector3(1.88, 0.06, 0.30), Vector3(-9.0, 0.0, 0.0), plate_mat, "VanduraRoofWing")

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 1.54, -1.38), 1.48, 0.56, -42.0, 4, 24.0)
		for sx: float in [-1.12, 1.12]:
			_add_tube(kit, Vector3(sx, 0.36, -1.10), Vector3(sx, 0.36, 1.10), 0.046, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.48, 2.28, 0.90), Vector3(0.48, 2.28, 0.90)], 0.19, 0.88, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 2.24, -0.75), 1.52, 4)

static func _build_carson_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -2.36, 0.26, 0.58, 0.82, 0.28, 0.0)
		_add_box(kit, Vector3(0.0, 0.78, -2.26), Vector3(0.76, 0.42, 0.04), Vector3.ZERO, grille_mat, "CarsonRadiatorGrille")
		for sx: float in [-0.94, 0.94]:
			_add_box(kit, Vector3(sx, 0.62, 0.15), Vector3(0.05, 0.30, 1.48), Vector3.ZERO, plate_mat, "CarsonDoorArmor")

	if st_engine:
		_add_box(kit, Vector3(0.0, 1.16, -1.15), Vector3(0.50, 0.16, 0.82), Vector3.ZERO, plate_mat, "CarsonSupercharger")
		_add_box(kit, Vector3(0.0, 1.16, -1.57), Vector3(0.44, 0.12, 0.03), Vector3.ZERO, grille_mat, "CarsonBlowerMesh")
		for sx: float in [-0.90, 0.90]:
			_add_tube(kit, Vector3(sx, 0.46, -1.45), Vector3(sx, 0.34, 0.45), 0.040, pipe_mat)

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 1.28, -0.02), 1.10, 0.42, -72.0, 4, 24.0)
		for sx: float in [-0.92, 0.92]:
			_add_tube(kit, Vector3(sx, 0.28, -0.88), Vector3(sx, 0.28, 0.88), 0.040, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.44, 1.05, 1.98), Vector3(0.44, 1.05, 1.98)], 0.14, 0.54, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 1.56, 0.45), 1.04, 4)

static func _build_delorean_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -2.10, 0.20, 0.50, 0.88, 0.26, 0.0)
		_add_box(kit, Vector3(0.0, 0.56, -2.10), Vector3(1.12, 0.20, 0.03), Vector3.ZERO, grille_mat, "DeLoreanGrille")
		for sx: float in [-0.99, 0.99]:
			_add_box(kit, Vector3(sx, 0.48, -0.10), Vector3(0.04, 0.22, 1.26), Vector3.ZERO, plate_mat, "DeLoreanSideSkirt")

	if st_engine:
		for sx: float in [-0.46, 0.46]:
			_add_box(kit, Vector3(sx, 1.04, 1.35), Vector3(0.32, 0.14, 0.72), Vector3(10.0, 0.0, 0.0), plate_mat, "TurboReactorPod")
		_add_box(kit, Vector3(0.0, 1.18, 1.98), Vector3(1.74, 0.05, 0.28), Vector3(-11.0, 0.0, 0.0), plate_mat, "DeLoreanWing")
		for wx: float in [-0.46, 0.46]:
			_add_box(kit, Vector3(wx, 1.04, 1.94), Vector3(0.05, 0.24, 0.20), Vector3.ZERO, pipe_mat, "DeLoreanWingStrut")

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 0.96, -0.45), 1.24, 0.52, -22.0, 4, 22.0)
		for sx: float in [-0.98, 0.98]:
			_add_tube(kit, Vector3(sx, 0.26, -0.78), Vector3(sx, 0.26, 0.78), 0.036, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.44, 0.98, 1.62), Vector3(0.44, 0.98, 1.62)], 0.13, 0.50, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 1.18, 0.10), 1.08, 4)

static func _build_k2500_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var hazard_mat := _get_mat("hazard")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_box(kit, Vector3(0.0, 0.58, -2.86), Vector3(1.94, 0.46, 0.08), Vector3(32.0, 0.0, 0.0), plate_mat, "K2500SkidPlate")
		_add_box(kit, Vector3(0.0, 0.74, -2.98), Vector3(2.00, 0.14, 0.12), Vector3.ZERO, hazard_mat, "K2500RamEdge")
		_add_tube(kit, Vector3(-1.02, 0.78, -2.84), Vector3(-0.98, 1.26, -2.84), 0.048, pipe_mat)
		_add_tube(kit, Vector3(1.02, 0.78, -2.84), Vector3(0.98, 1.26, -2.84), 0.048, pipe_mat)
		_add_tube(kit, Vector3(-0.98, 1.26, -2.84), Vector3(0.98, 1.26, -2.84), 0.046, pipe_mat)
		_add_box(kit, Vector3(0.0, 1.08, -2.84), Vector3(1.26, 0.38, 0.03), Vector3.ZERO, grille_mat, "K2500Grille")
		for sx: float in [-1.14, 1.14]:
			_add_box(kit, Vector3(sx, 0.92, -0.35), Vector3(0.05, 0.36, 1.60), Vector3.ZERO, plate_mat, "K2500DoorPlate")

	if st_engine:
		_add_box(kit, Vector3(0.0, 1.50, -1.85), Vector3(0.76, 0.14, 0.88), Vector3.ZERO, plate_mat, "K2500HoodScoop")
		for sx: float in [-0.94, 0.94]:
			_add_tube(kit, Vector3(sx, 1.40, 0.35), Vector3(sx, 2.48, 0.38), 0.050, pipe_mat)
		_add_box(kit, Vector3(0.0, 1.56, 2.75), Vector3(1.94, 0.06, 0.30), Vector3(-10.0, 0.0, 0.0), plate_mat, "K2500TailWing")

	if st_chassis:
		_add_louver_rack(kit, Vector3(0.0, 1.84, -0.95), 1.56, 0.60, -40.0, 4, 24.0)
		for sx: float in [-0.92, 0.92]:
			_add_tube(kit, Vector3(sx, 1.45, 0.42), Vector3(sx, 2.28, 0.42), 0.046, pipe_mat)
			_add_tube(kit, Vector3(sx, 2.28, 0.42), Vector3(sx, 1.46, 2.68), 0.044, pipe_mat)
		_add_tube(kit, Vector3(-0.92, 2.28, 0.42), Vector3(0.92, 2.28, 0.42), 0.046, pipe_mat)
		for sx: float in [-1.14, 1.14]:
			_add_tube(kit, Vector3(sx, 0.52, -1.05), Vector3(sx, 0.52, 0.95), 0.048, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-0.48, 1.38, 1.50), Vector3(0.48, 1.38, 1.50)], 0.20, 0.90, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 2.34, 0.25), 1.58, 4)

static func _build_paz3205_kit(kit: Node3D, stages: Dictionary) -> void:
	var pipe_mat := _get_mat("cage_pipe")
	var plate_mat := _get_mat("armor_plate")
	var grille_mat := _get_mat("grille")
	var st_armor: bool = bool(stages.get("armor", false))
	var st_engine: bool = bool(stages.get("engine", false))
	var st_chassis: bool = bool(stages.get("chassis", false))
	var st_fuel: bool = bool(stages.get("fuel", false))

	if st_armor:
		_add_wedge_ram(kit, -3.30, 0.34, 0.96, 1.22, 0.36, 0.0)
		_add_box(kit, Vector3(0.0, 1.06, -3.30), Vector3(1.90, 0.46, 0.05), Vector3.ZERO, grille_mat, "PAZRadiatorShield")
		for sx: float in [-1.32, 1.32]:
			_add_box(kit, Vector3(sx, 0.88, 0.0), Vector3(0.06, 0.54, 4.40), Vector3.ZERO, plate_mat, "PAZSideSkirtArmor")

	if st_engine:
		for sx: float in [-1.04, 1.04]:
			_add_tube(kit, Vector3(sx, 0.90, 3.22), Vector3(sx, 3.28, 3.22), 0.056, pipe_mat)
		_add_box(kit, Vector3(0.0, 3.04, 1.55), Vector3(1.18, 0.16, 1.24), Vector3.ZERO, plate_mat, "PAZRoofCooler")

	if st_chassis:
		_add_box(kit, Vector3(0.0, 2.74, -3.26), Vector3(2.26, 0.22, 0.14), Vector3(18.0, 0.0, 0.0), plate_mat, "PAZCabBrowArmor")
		for sx: float in [-1.34, 1.34]:
			_add_tube(kit, Vector3(sx, 0.48, -1.75), Vector3(sx, 0.48, 1.75), 0.052, pipe_mat)

	if st_fuel:
		_add_aux_fuel_tanks(kit, [Vector3(-1.32, 0.62, 0.35), Vector3(1.32, 0.62, 0.35)], 0.18, 0.92, Vector3(90.0, 0.0, 0.0))
		_add_roof_lightbar(kit, Vector3(0.0, 3.12, -2.75), 1.85, 4)
