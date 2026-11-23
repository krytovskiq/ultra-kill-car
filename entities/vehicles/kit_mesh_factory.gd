class_name KitMeshFactory
extends RefCounted

## Фабрика высокодетализированных 3D-деталей обвеса и двигателей (нагнетатель V8 Roots,
## твин-турбо, силовые отвалы, болтовая броня, жалюзи, спойлеры, выхлоп и LED-балки).

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")
const TEX_RUST_RGH: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_rough_1k.jpg")

static var _mats: Dictionary = {}
static var _tex_diamond_diff: ImageTexture = null
static var _tex_diamond_nor: ImageTexture = null
static var _tex_grille_alpha: ImageTexture = null
static var _tex_hazard_diff: ImageTexture = null
static var _tex_war_detail: ImageTexture = null
static var _tex_metal_grain_nor: ImageTexture = null

static func ensure_textures() -> void:
	if _tex_diamond_diff != null:
		return
	var sz := 128
	var d_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var n_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var g_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var h_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var w_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var gn_img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)

	var rng := RandomNumberGenerator.new()
	rng.seed = 40771
	for y in range(sz):
		for x in range(sz):
			var u := float(x) / float(sz)
			var v := float(y) / float(sz)
			var noise := rng.randf_range(-0.04, 0.04)

			# Diamond plate + perimeter bevel + corner rivets
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
			var base_v := clampf(0.48 + ridge * 0.22 + rivet * 0.28 - border * 0.14 + noise, 0.24, 0.92)
			d_img.set_pixel(x, y, Color(base_v * 0.98, base_v * 0.99, base_v * 1.02, 1.0))

			var nx := clampf(0.5 + (gx if cell == 0 else -gx) * ridge * 0.45, 0.1, 0.9)
			var ny := clampf(0.5 + gy * ridge * 0.45, 0.1, 0.9)
			n_img.set_pixel(x, y, Color(nx, ny, 0.92, 1.0))

			# Expanded-metal steel grille grate
			var mg1 := absf(fmod(u * 10.0 + v * 10.0, 1.0) - 0.5)
			var mg2 := absf(fmod(u * 10.0 - v * 10.0 + 10.0, 1.0) - 0.5)
			var is_bar := (mg1 < 0.21 or mg2 < 0.21) or (x < 6 or x >= sz - 6 or y < 6 or y >= sz - 6)
			var gc := clampf(0.48 + noise * 0.4, 0.30, 0.68)
			g_img.set_pixel(x, y, Color(gc, gc, gc * 1.04, 1.0 if is_bar else 0.0))

			# Industrial yellow-black hazard chevrons
			var stripe := sin((u + v) * TAU * 4.0)
			var yellow := Color(0.92, 0.64, 0.14)
			var dark := Color(0.15, 0.15, 0.17)
			var hcol := yellow.lerp(dark, clampf(0.5 - stripe * 6.0, 0.0, 1.0))
			var wear := clampf(noise * 2.0 + 0.04, -0.12, 0.14)
			h_img.set_pixel(x, y, Color(clampf(hcol.r + wear, 0.08, 0.96), clampf(hcol.g + wear, 0.08, 0.92), clampf(hcol.b + wear, 0.08, 0.88), 1.0))

			# War-rig patina detail
			var scratch := 1.0 if (absf(sin(u * 31.0 + v * 7.0) * cos(v * 53.0 - u * 11.0)) > 0.955 and absf(u - 0.5) > 0.08) else 0.0
			var seam := 1.0 if ((x % 32 == 0) or (y % 64 == 0)) else 0.0
			var pat := clampf(0.90 - seam * 0.24 + scratch * 0.12 + noise * 1.1, 0.56, 1.0)
			w_img.set_pixel(x, y, Color(pat, pat * 0.99, pat * 0.97, 1.0))

			# Fine brushed / cast alloy grain normal
			var gx_n := 0.5 + rng.randf_range(-0.14, 0.14)
			var gy_n := 0.5 + rng.randf_range(-0.14, 0.14)
			gn_img.set_pixel(x, y, Color(gx_n, gy_n, 0.96, 1.0))

	_tex_diamond_diff = ImageTexture.create_from_image(d_img)
	_tex_diamond_nor = ImageTexture.create_from_image(n_img)
	_tex_grille_alpha = ImageTexture.create_from_image(g_img)
	_tex_hazard_diff = ImageTexture.create_from_image(h_img)
	_tex_war_detail = ImageTexture.create_from_image(w_img)
	_tex_metal_grain_nor = ImageTexture.create_from_image(gn_img)

static func get_war_detail_tex() -> ImageTexture:
	ensure_textures()
	return _tex_war_detail

static func get_diamond_nor_tex() -> ImageTexture:
	ensure_textures()
	return _tex_diamond_nor

static func get_mat(key: String) -> StandardMaterial3D:
	ensure_textures()
	if _mats.has(key):
		return _mats[key] as StandardMaterial3D

	var m := StandardMaterial3D.new()
	match key:
		"chrome":
			m.albedo_color = Color(0.92, 0.94, 0.97)
			m.metallic = 0.96
			m.roughness = 0.14
			m.clearcoat = 0.35
			m.clearcoat_roughness = 0.08
		"cast_alu":
			m.albedo_color = Color(0.74, 0.76, 0.79)
			m.metallic = 0.82
			m.roughness = 0.36
			m.normal_enabled = true
			m.normal_texture = _tex_metal_grain_nor
			m.normal_scale = 0.35
		"billet_alu":
			m.albedo_color = Color(0.84, 0.86, 0.89)
			m.metallic = 0.90
			m.roughness = 0.22
		"anodized_red":
			m.albedo_color = Color(0.92, 0.14, 0.10)
			m.metallic = 0.62
			m.roughness = 0.22
			m.clearcoat = 0.30
		"dark_cavity":
			m.albedo_color = Color(0.035, 0.035, 0.045)
			m.metallic = 0.10
			m.roughness = 0.92
		"rubber_belt":
			m.albedo_color = Color(0.10, 0.10, 0.11)
			m.metallic = 0.04
			m.roughness = 0.88
		"gunmetal_armor":
			m.albedo_color = Color(0.48, 0.51, 0.55)
			m.albedo_texture = _tex_diamond_diff
			m.normal_enabled = true
			m.normal_texture = TEX_RUST_NOR if TEX_RUST_NOR != null else _tex_diamond_nor
			m.normal_scale = 0.72
			m.metallic = 0.62
			m.roughness = 0.42
			m.uv1_scale = Vector3(2.0, 2.0, 1.0)
		"forged_steel":
			m.albedo_color = Color(0.32, 0.35, 0.39)
			m.albedo_texture = _tex_diamond_diff
			m.normal_enabled = true
			m.normal_texture = _tex_diamond_nor
			m.normal_scale = 0.52
			m.metallic = 0.68
			m.roughness = 0.38
		"exhaust_steel":
			m.albedo_color = Color(0.64, 0.58, 0.53)
			m.metallic = 0.84
			m.roughness = 0.30
			m.normal_enabled = true
			m.normal_texture = _tex_metal_grain_nor
			m.normal_scale = 0.28
		"grille_mesh":
			m.albedo_color = Color(0.76, 0.78, 0.82)
			m.albedo_texture = _tex_grille_alpha
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.42
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.metallic = 0.60
			m.roughness = 0.40
			m.uv1_scale = Vector3(1.6, 1.6, 1.0)
		"hazard_steel":
			m.albedo_texture = _tex_hazard_diff
			m.metallic = 0.42
			m.roughness = 0.46
			m.normal_enabled = true
			m.normal_texture = _tex_diamond_nor
			m.normal_scale = 0.55
		"led_lens":
			m.albedo_color = Color(1.0, 0.94, 0.80)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.90, 0.68)
			m.emission_energy_multiplier = 3.2
			m.roughness = 0.14
	_mats[key] = m
	return m

# ==============================================================================
# УТИЛИТЫ БАЗОВОЙ ГЕОМЕТРИИ
# ==============================================================================

static func _add_box(parent: Node3D, pos: Vector3, size: Vector3, rot_deg: Vector3, mat: Material, node_name: String = "Part") -> MeshInstance3D:
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

static func _add_cyl(parent: Node3D, pos: Vector3, r_top: float, r_bot: float, height: float, rot_deg: Vector3, mat: Material, segs: int = 16, node_name: String = "CylPart") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi

static func _add_tube(parent: Node3D, p0: Vector3, p1: Vector3, radius: float, mat: Material, with_caps: bool = true, segs: int = 10) -> void:
	var diff := p1 - p0
	var dist := diff.length()
	if dist < 0.008:
		return
	var mid := (p0 + p1) * 0.5
	var dir := diff / dist

	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = dist
	cyl.radial_segments = segs

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
		for end_pt: Vector3 in [p0, p1]:
			var ci := MeshInstance3D.new()
			ci.mesh = cap
			ci.material_override = mat
			ci.position = end_pt
			ci.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(ci)

static func _make_loft_mesh(stations: Array[Dictionary], closed_back: bool = true, closed_front: bool = true) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_st: int = stations.size()
	if n_st < 2:
		return ArrayMesh.new()
	var n_ring: int = (stations[0]["pts"] as PackedVector2Array).size()

	for si in range(n_st - 1):
		var a: Dictionary = stations[si]
		var b: Dictionary = stations[si + 1]
		var za: float = float(a["z"])
		var zb: float = float(b["z"])
		var pa := a["pts"] as PackedVector2Array
		var pb := b["pts"] as PackedVector2Array
		var ua := float(si) / float(n_st - 1)
		var ub := float(si + 1) / float(n_st - 1)
		for ri in range(n_ring):
			var r_next := (ri + 1) % n_ring
			var va := float(ri) / float(n_ring)
			var vb := float(ri + 1) / float(n_ring)
			var v00 := Vector3(pa[ri].x, pa[ri].y, za)
			var v01 := Vector3(pa[r_next].x, pa[r_next].y, za)
			var v10 := Vector3(pb[ri].x, pb[ri].y, zb)
			var v11 := Vector3(pb[r_next].x, pb[r_next].y, zb)

			st.set_uv(Vector2(ua, va)); st.add_vertex(v00)
			st.set_uv(Vector2(ub, va)); st.add_vertex(v10)
			st.set_uv(Vector2(ub, vb)); st.add_vertex(v11)

			st.set_uv(Vector2(ua, va)); st.add_vertex(v00)
			st.set_uv(Vector2(ub, vb)); st.add_vertex(v11)
			st.set_uv(Vector2(ua, vb)); st.add_vertex(v01)

	if closed_front:
		var f0: Dictionary = stations[0]
		var zf: float = float(f0["z"])
		var pf := f0["pts"] as PackedVector2Array
		var cf := Vector3(0.0, 0.0, zf)
		var y_avg: float = 0.0
		for pt: Vector2 in pf:
			y_avg += pt.y
		cf.y = y_avg / float(maxi(pf.size(), 1))
		for ri in range(n_ring):
			var r_next := (ri + 1) % n_ring
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(cf)
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(pf[ri].x, pf[ri].y, zf))
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(pf[r_next].x, pf[r_next].y, zf))

	if closed_back:
		var b0: Dictionary = stations[n_st - 1]
		var zb: float = float(b0["z"])
		var pb := b0["pts"] as PackedVector2Array
		var cb := Vector3(0.0, 0.0, zb)
		var y_avg_b: float = 0.0
		for pt: Vector2 in pb:
			y_avg_b += pt.y
		cb.y = y_avg_b / float(maxi(pb.size(), 1))
		for ri in range(n_ring):
			var r_next := (ri + 1) % n_ring
			st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(cb)
			st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(pb[r_next].x, pb[r_next].y, zb))
			st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(pb[ri].x, pb[ri].y, zb))

	st.generate_normals()
	return st.commit()

static func _stadium_ring(half_w: float, half_h: float, y_center: float, segs_per_arc: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var r := minf(half_h, half_w * 0.45)
	var dx := maxf(half_w - r, 0.0)
	# Right semicircle (top -> bottom) + Left semicircle (bottom -> top) in CCW
	for i in range(segs_per_arc + 1):
		var ang := lerpf(PI * 0.5, -PI * 0.5, float(i) / float(segs_per_arc))
		pts.append(Vector2(dx + cos(ang) * r, y_center + sin(ang) * half_h))
	for i in range(segs_per_arc + 1):
		var ang := lerpf(-PI * 0.5, -PI * 1.5, float(i) / float(segs_per_arc))
		pts.append(Vector2(-dx + cos(ang) * r, y_center + sin(ang) * half_h))
	return pts

# ==============================================================================
# 1. НАГНЕТАТЕЛЬ V8 ROOTS SUPERCHARGER BLOWER (АНИМИРОВАННЫЙ ШКИВ И ЗАСЛОНКИ)
# ==============================================================================

static func add_supercharger_blower(parent: Node3D, pos: Vector3, scale_v: float = 1.0, pitch_deg: float = 0.0) -> void:
	var chrome := get_mat("chrome")
	var cast_alu := get_mat("cast_alu")
	var billet := get_mat("billet_alu")
	var red_anod := get_mat("anodized_red")
	var dark := get_mat("dark_cavity")
	var belt_mat := get_mat("rubber_belt")
	var steel := get_mat("forged_steel")

	var rig := Node3D.new()
	rig.name = "SuperchargerRig"
	rig.position = pos
	rig.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)
	rig.scale = Vector3.ONE * scale_v
	parent.add_child(rig)

	# 1. Впускной коллектор / постамент, глубоко уходящий в капот (y = -0.14 .. +0.05) — без зазоров даже на наклонных капотах
	var base_st: Array[Dictionary] = [
		{"z": -0.25, "pts": _stadium_ring(0.225, 0.095, -0.045)},
		{"z":  0.25, "pts": _stadium_ring(0.225, 0.095, -0.045)},
	]
	var mi_manifold := MeshInstance3D.new()
	mi_manifold.mesh = _make_loft_mesh(base_st, true, true)
	mi_manifold.material_override = cast_alu
	mi_manifold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rig.add_child(mi_manifold)

	# Фланец посадки с болтами крепления
	_add_box(rig, Vector3(0.0, 0.050, 0.0), Vector3(0.42, 0.022, 0.48), Vector3.ZERO, billet, "BlowerFlange")
	for bx: float in [-0.185, 0.185]:
		for bz: float in [-0.20, -0.07, 0.07, 0.20]:
			_add_cyl(rig, Vector3(bx, 0.064, bz), 0.011, 0.011, 0.014, Vector3.ZERO, chrome, 6, "FlangeBolt")

	# 2. Скульптурный оребрённый корпус 8-71 Roots Blower (лофтинг с закруглёнными стенками)
	var blower_st: Array[Dictionary] = [
		{"z": -0.22, "pts": _stadium_ring(0.185, 0.088, 0.145)},
		{"z":  0.22, "pts": _stadium_ring(0.185, 0.088, 0.145)},
	]
	var mi_housing := MeshInstance3D.new()
	mi_housing.name = "BlowerHousing"
	mi_housing.mesh = _make_loft_mesh(blower_st, true, true)
	mi_housing.material_override = cast_alu
	mi_housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rig.add_child(mi_housing)

	# Машинная фрезеровка: 7 горизонтальных рёбер охлаждения слева и справа
	for side: float in [-1.0, 1.0]:
		for fi in range(6):
			var fy := 0.088 + float(fi) * 0.022
			_add_box(rig, Vector3(side * 0.182, fy, 0.0), Vector3(0.020, 0.008, 0.40), Vector3.ZERO, billet, "BlowerFin")

	# Передняя и задняя фрезерованные крышки подшипников нагнетателя
	_add_box(rig, Vector3(0.0, 0.145, -0.232), Vector3(0.35, 0.165, 0.024), Vector3.ZERO, billet, "BlowerFrontPlate")
	_add_box(rig, Vector3(0.0, 0.145,  0.232), Vector3(0.35, 0.165, 0.024), Vector3.ZERO, billet, "BlowerRearPlate")
	_add_cyl(rig, Vector3(0.0, 0.145,  0.252), 0.036, 0.042, 0.030, Vector3(90.0, 0.0, 0.0), chrome, 12, "BlowOffValve")

	# 3. Выносной приводной нос (Snout), нижний шкив коленвала, зубчатый ремень и вращающийся шкив
	_add_cyl(rig, Vector3(0.0, 0.145, -0.320), 0.048, 0.062, 0.175, Vector3(90.0, 0.0, 0.0), billet, 16, "BlowerSnout")
	_add_cyl(rig, Vector3(0.0, 0.145, -0.395), 0.056, 0.056, 0.022, Vector3(90.0, 0.0, 0.0), chrome, 16, "SnoutCollar")

	# Верхний вращающийся шкив (VehicleBase вращает узел "SuperchargerPulley" по оси Z)
	var upper_pulley := Node3D.new()
	upper_pulley.name = "SuperchargerPulley"
	upper_pulley.position = Vector3(0.0, 0.145, -0.435)
	rig.add_child(upper_pulley)
	_add_cyl(upper_pulley, Vector3.ZERO, 0.082, 0.082, 0.042, Vector3(90.0, 0.0, 0.0), billet, 20, "PulleyWheel")
	_add_cyl(upper_pulley, Vector3(0.0, 0.0, -0.016), 0.056, 0.056, 0.014, Vector3(90.0, 0.0, 0.0), steel, 16, "PulleyDish")
	_add_cyl(upper_pulley, Vector3(0.0, 0.0, -0.024), 0.020, 0.020, 0.018, Vector3(90.0, 0.0, 0.0), chrome, 6, "PulleyHubNut")
	for bi in range(6):
		var ang := float(bi) * TAU / 6.0
		_add_cyl(upper_pulley, Vector3(cos(ang) * 0.040, sin(ang) * 0.040, -0.022), 0.007, 0.007, 0.012, Vector3(90.0, 0.0, 0.0), red_anod, 6, "PulleyBolt")

	# Нижний шкив на капоте + натяжной ролик + зубчатый приводной ремень Гилмера
	_add_cyl(rig, Vector3(0.0, -0.045, -0.435), 0.072, 0.072, 0.042, Vector3(90.0, 0.0, 0.0), steel, 18, "LowerCrankPulley")
	_add_cyl(rig, Vector3(0.088, 0.055, -0.435), 0.026, 0.026, 0.042, Vector3(90.0, 0.0, 0.0), chrome, 14, "TensionerPulley")
	# Две плотные ветви зубчатого ремня от верхнего к нижнему шкиву
	_add_box(rig, Vector3(-0.074, 0.050, -0.435), Vector3(0.014, 0.215, 0.044), Vector3(0.0, 0.0, 3.0), belt_mat, "BeltLeft")
	_add_box(rig, Vector3(0.074, 0.050, -0.435), Vector3(0.014, 0.215, 0.044), Vector3(0.0, 0.0, -3.0), belt_mat, "BeltRight")
	_add_cyl(rig, Vector3(0.0, 0.145, -0.435), 0.087, 0.087, 0.044, Vector3(90.0, 0.0, 0.0), belt_mat, 18, "BeltWrapTop")

	# 4. Хромированный аэродинамический ковш 3-Barrel "Bug Catcher" (плавный многоступенчатый лофт)
	_add_box(rig, Vector3(0.0, 0.240, 0.0), Vector3(0.28, 0.024, 0.34), Vector3.ZERO, chrome, "ScoopNeckPlate")
	var scoop_stations: Array[Dictionary] = [
		{"z": -0.295, "pts": _stadium_ring(0.215, 0.084, 0.340)},
		{"z": -0.255, "pts": _stadium_ring(0.205, 0.078, 0.338)},
		{"z": -0.140, "pts": _stadium_ring(0.188, 0.072, 0.330)},
		{"z":  0.020, "pts": _stadium_ring(0.165, 0.064, 0.318)},
		{"z":  0.160, "pts": _stadium_ring(0.125, 0.052, 0.302)},
		{"z":  0.245, "pts": _stadium_ring(0.068, 0.036, 0.286)},
	]
	var mi_scoop := MeshInstance3D.new()
	mi_scoop.name = "ChromeBugCatcher"
	mi_scoop.mesh = _make_loft_mesh(scoop_stations, true, false)
	mi_scoop.material_override = chrome
	mi_scoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	rig.add_child(mi_scoop)

	# Развальцованный хромированный обод переднего раструба + тёмная впускная камера внутри
	_add_box(rig, Vector3(0.0, 0.340, -0.258), Vector3(0.37, 0.128, 0.025), Vector3.ZERO, dark, "ScoopCavity")
	for bx: float in [-0.112, 0.0, 0.112]:
		_add_cyl(rig, Vector3(bx, 0.340, -0.286), 0.048, 0.050, 0.024, Vector3(90.0, 0.0, 0.0), chrome, 16, "InjectorBarrelRing")
		_add_cyl(rig, Vector3(bx, 0.340, -0.274), 0.042, 0.042, 0.018, Vector3(90.0, 0.0, 0.0), dark, 16, "InjectorBarrelBore")

	# Верхний и нижний хромированные козырьки раструба
	_add_box(rig, Vector3(0.0, 0.422, -0.285), Vector3(0.41, 0.016, 0.040), Vector3(-6.0, 0.0, 0.0), chrome, "ScoopLipTop")
	_add_box(rig, Vector3(0.0, 0.258, -0.285), Vector3(0.41, 0.016, 0.040), Vector3(6.0, 0.0, 0.0), chrome, "ScoopLipBot")

	# 5. Подвижная ось с тремя ярко-красными дроссельными заслонками ("SuperchargerButterflies")
	var bfly_shaft := Node3D.new()
	bfly_shaft.name = "SuperchargerButterflies"
	bfly_shaft.position = Vector3(0.0, 0.340, -0.292)
	bfly_shaft.rotation.x = deg_to_rad(14.0)
	rig.add_child(bfly_shaft)
	_add_cyl(bfly_shaft, Vector3.ZERO, 0.008, 0.008, 0.38, Vector3(0.0, 0.0, 90.0), chrome, 10, "ThrottleShaft")
	for bx: float in [-0.112, 0.0, 0.112]:
		_add_cyl(bfly_shaft, Vector3(bx, 0.0, -0.004), 0.041, 0.041, 0.009, Vector3(90.0, 0.0, 0.0), red_anod, 16, "ThrottlePlate")

	# Топливная рампа с 3 форсуночными трубками на боку нагнетателя
	_add_box(rig, Vector3(-0.18, 0.255, -0.05), Vector3(0.028, 0.026, 0.24), Vector3.ZERO, red_anod, "FuelDistBlock")
	for fz: float in [-0.13, -0.04, 0.05]:
		_add_tube(rig, Vector3(-0.18, 0.268, fz), Vector3(-0.14, 0.305, fz - 0.02), 0.007, chrome, true, 8)

# ==============================================================================
# 2. ТВИН-ТУРБО МОТОРНЫЙ БЛОК ДЛЯ ЗАДНЕМОТОРНОЙ КОРМЫ (DELOREAN V6 TURBO)
# ==============================================================================

static func add_twin_turbo_rig(parent: Node3D, pos: Vector3, scale_v: float = 1.0, pitch_deg: float = -4.0) -> void:
	var chrome := get_mat("chrome")
	var cast_alu := get_mat("cast_alu")
	var billet := get_mat("billet_alu")
	var red_anod := get_mat("anodized_red")
	var steel := get_mat("forged_steel")
	var ex_mat := get_mat("exhaust_steel")
	var grille := get_mat("grille_mesh")

	var rig := Node3D.new()
	rig.name = "TwinTurboRig"
	rig.position = pos
	rig.rotation_degrees = Vector3(pitch_deg, 0.0, 0.0)
	rig.scale = Vector3.ONE * scale_v
	parent.add_child(rig)

	# Опорная плита-коллектор и центральный ребристый интеркулер
	_add_box(rig, Vector3(0.0, -0.03, 0.0), Vector3(0.86, 0.09, 0.68), Vector3.ZERO, steel, "TurboDeckFrame")
	_add_box(rig, Vector3(0.0, 0.08, -0.10), Vector3(0.46, 0.13, 0.30), Vector3.ZERO, cast_alu, "IntercoolerCore")
	for i in range(6):
		var fz := -0.22 + float(i) * 0.048
		_add_box(rig, Vector3(0.0, 0.148, fz), Vector3(0.42, 0.012, 0.016), Vector3.ZERO, billet, "IntercoolerFin")
	_add_box(rig, Vector3(0.0, 0.08, -0.26), Vector3(0.44, 0.11, 0.02), Vector3.ZERO, grille, "IntercoolerGrate")

	# Левая и правая турбины-"улитки" с конусными фильтрами и сбросом газов
	for side: float in [-1.0, 1.0]:
		var tx := side * 0.30
		_add_cyl(rig, Vector3(tx, 0.11, 0.04), 0.105, 0.105, 0.082, Vector3(90.0, 0.0, 0.0), cast_alu, 16, "CompressorScroll")
		_add_cyl(rig, Vector3(tx, 0.11, 0.12), 0.086, 0.086, 0.075, Vector3(90.0, 0.0, 0.0), ex_mat, 14, "TurbineHousing")
		_add_cyl(rig, Vector3(tx, 0.11, -0.02), 0.052, 0.068, 0.040, Vector3(90.0, 0.0, 0.0), billet, 14, "CompressorInlet")
		_add_cyl(rig, Vector3(tx, 0.11, -0.085), 0.066, 0.084, 0.11, Vector3(90.0, 0.0, 0.0), red_anod, 14, "ConeAirFilter")
		_add_cyl(rig, Vector3(tx, 0.11, -0.025), 0.046, 0.046, 0.018, Vector3(90.0, 0.0, 0.0), chrome, 12, "CompressorNose")
		# Патрубки наддува в интеркулер с красными силиконовыми муфтами
		_add_tube(rig, Vector3(tx, 0.16, 0.02), Vector3(side * 0.21, 0.14, -0.06), 0.032, chrome, true, 10)
		_add_cyl(rig, Vector3(side * 0.23, 0.14, -0.04), 0.037, 0.037, 0.036, Vector3(0.0, 0.0, 90.0), red_anod, 10, "SiliconeCoupler")
		# Внешние трубы вестгейта назад
		_add_tube(rig, Vector3(tx, 0.11, 0.16), Vector3(tx * 1.06, 0.16, 0.34), 0.030, ex_mat, false, 10)

# ==============================================================================
# 3. ДИЗЕЛЬНЫЙ ТУРБО-ИНТЕРКУЛЕР НА КРЫШУ (ДЛЯ БУХАНКИ И ПАЗ-3205)
# ==============================================================================

static func add_diesel_turbo_unit(parent: Node3D, pos: Vector3, scale_v: float = 1.0) -> void:
	var billet := get_mat("billet_alu")
	var cast_alu := get_mat("cast_alu")
	var steel := get_mat("forged_steel")
	var grille := get_mat("grille_mesh")
	var red_anod := get_mat("anodized_red")
	var chrome := get_mat("chrome")

	var rig := Node3D.new()
	rig.name = "DieselTurboUnit"
	rig.position = pos
	rig.scale = Vector3.ONE * scale_v
	parent.add_child(rig)

	_add_box(rig, Vector3(0.0, -0.02, 0.0), Vector3(0.84, 0.08, 0.72), Vector3.ZERO, steel, "CoolerMountTray")
	_add_box(rig, Vector3(0.0, 0.09, -0.05), Vector3(0.76, 0.14, 0.56), Vector3.ZERO, cast_alu, "IntercoolerShroud")
	_add_box(rig, Vector3(0.0, 0.09, -0.335), Vector3(0.68, 0.11, 0.02), Vector3.ZERO, grille, "CoolerFrontGrille")
	for side: float in [-1.0, 1.0]:
		_add_cyl(rig, Vector3(side * 0.22, 0.175, 0.02), 0.135, 0.145, 0.045, Vector3.ZERO, billet, 16, "FanRing")
		_add_cyl(rig, Vector3(side * 0.22, 0.190, 0.02), 0.042, 0.042, 0.032, Vector3.ZERO, red_anod, 12, "FanHub")
		_add_cyl(rig, Vector3(side * 0.44, 0.09, 0.04), 0.075, 0.075, 0.34, Vector3(90.0, 0.0, 0.0), steel, 12, "AirFilterDrum")
		_add_tube(rig, Vector3(side * 0.44, 0.10, -0.14), Vector3(side * 0.34, 0.10, -0.22), 0.032, chrome, true, 10)

# ==============================================================================
# 4. СКУЛЬПТУРНЫЙ СИЛОВОЙ ТАРАН, BAJA-БАМПЕР, БРОНЯ, ЖАЛЮЗИ И КРЫЛЬЯ
# ==============================================================================

static func add_sculpted_v_ram(parent: Node3D, base_z: float, y_bot: float, y_top: float, half_w: float, tip_ext: float, center_x: float = 0.0) -> void:
	var armor := get_mat("gunmetal_armor")
	var steel := get_mat("forged_steel")
	var hazard := get_mat("hazard_steel")
	var red_anod := get_mat("anodized_red")

	var ram := Node3D.new()
	ram.name = "SculptedVRam"
	parent.add_child(ram)

	var h := maxf(y_top - y_bot, 0.24)
	var mid_y := (y_bot + y_top) * 0.5
	var nose_z := base_z - tip_ext

	# Вогнутый 2-ярусный отвал с каждой стороны (верхняя и нижняя секции под разными углами для эффекта ковша)
	for side: float in [-1.0, 1.0]:
		var yaw := -side * 18.0
		var wing_x := center_x + side * half_w * 0.49
		var wing_z := base_z - tip_ext * 0.45
		_add_box(ram, Vector3(wing_x, y_bot + h * 0.28, wing_z - 0.03), Vector3(half_w * 1.02, h * 0.56, 0.065), Vector3(22.0, yaw, 0.0), armor, "RamLowerBlade")
		_add_box(ram, Vector3(wing_x, y_bot + h * 0.78, wing_z + 0.03), Vector3(half_w * 1.00, h * 0.48, 0.060), Vector3(6.0, yaw, 0.0), steel, "RamUpperShield")
		# Нижняя режущая кромка с желто-чёрной разметкой
		_add_box(ram, Vector3(wing_x, y_bot + 0.05, wing_z - 0.06), Vector3(half_w * 1.04, 0.11, 0.075), Vector3(24.0, yaw, 0.0), hazard, "RamCuttingEdge")
		# Вертикальные сварные косынки жёсткости
		for frac: float in [0.35, 0.72, 0.94]:
			var gx := center_x + side * half_w * frac
			var gz := lerpf(nose_z + 0.08, base_z - 0.02, frac)
			_add_box(ram, Vector3(gx, mid_y, gz + 0.04), Vector3(0.038, h * 0.88, 0.12), Vector3(12.0, yaw, 0.0), steel, "RamGusset")
		# Буксирная проушина
		_add_cyl(ram, Vector3(center_x + side * half_w * 0.46, y_bot + h * 0.65, wing_z - 0.05), 0.038, 0.038, 0.024, Vector3(0.0, 0.0, 90.0), red_anod, 10, "TowShackle")

	# Центральный бронированный клин-ребро
	_add_box(ram, Vector3(center_x, mid_y, nose_z + 0.07), Vector3(0.16, h * 1.04, 0.24), Vector3(14.0, 0.0, 0.0), hazard, "RamNoseWedge")
	# Силовые трубчатые упоры сверху
	_add_tube(ram, Vector3(center_x - half_w * 0.90, y_top + 0.04, base_z - tip_ext * 0.10), Vector3(center_x, y_top + 0.05, nose_z + 0.02), 0.034, steel)
	_add_tube(ram, Vector3(center_x + half_w * 0.90, y_top + 0.04, base_z - tip_ext * 0.10), Vector3(center_x, y_top + 0.05, nose_z + 0.02), 0.034, steel)

static func add_baja_prerunner_bumper(parent: Node3D, base_z: float, y_bot: float, y_top: float, half_w: float, center_x: float = 0.0) -> void:
	var steel := get_mat("forged_steel")
	var hazard := get_mat("hazard_steel")
	var grille := get_mat("grille_mesh")
	var red_anod := get_mat("anodized_red")

	var bm := Node3D.new()
	bm.name = "BajaPreRunnerBumper"
	parent.add_child(bm)

	var r := 0.044
	var y_mid := (y_bot + y_top) * 0.5
	# Нижняя защита картера (броневая сталь) и передняя труба-отбойник
	_add_box(bm, Vector3(center_x, y_bot + 0.14, base_z - 0.05), Vector3(half_w * 1.42, 0.30, 0.055), Vector3(40.0, 0.0, 0.0), steel, "SkidPlate")
	_add_box(bm, Vector3(center_x, y_bot + 0.18, base_z - 0.14), Vector3(half_w * 1.56, 0.11, 0.085), Vector3.ZERO, hazard, "BajaImpactBar")
	_add_tube(bm, Vector3(center_x - half_w * 0.82, y_mid - 0.02, base_z - 0.16), Vector3(center_x + half_w * 0.82, y_mid - 0.02, base_z - 0.16), r, steel)
	_add_tube(bm, Vector3(center_x - half_w * 0.98, y_mid - 0.02, base_z - 0.02), Vector3(center_x - half_w * 0.82, y_mid - 0.02, base_z - 0.16), r, steel)
	_add_tube(bm, Vector3(center_x + half_w * 0.98, y_mid - 0.02, base_z - 0.02), Vector3(center_x + half_w * 0.82, y_mid - 0.02, base_z - 0.16), r, steel)
	# Верхняя трапециевидная дуга защиты фар и радиатора
	_add_tube(bm, Vector3(center_x - half_w * 0.86, y_mid - 0.02, base_z - 0.14), Vector3(center_x - half_w * 0.54, y_top, base_z - 0.10), r * 0.88, steel)
	_add_tube(bm, Vector3(center_x + half_w * 0.86, y_mid - 0.02, base_z - 0.14), Vector3(center_x + half_w * 0.54, y_top, base_z - 0.10), r * 0.88, steel)
	_add_tube(bm, Vector3(center_x - half_w * 0.54, y_top, base_z - 0.10), Vector3(center_x + half_w * 0.54, y_top, base_z - 0.10), r * 0.88, steel)
	_add_box(bm, Vector3(center_x, (y_mid + y_top) * 0.5, base_z - 0.04), Vector3(half_w * 1.10, (y_top - y_mid) * 0.86, 0.03), Vector3.ZERO, grille, "BajaGrilleGuard")
	for sx: float in [-0.46, 0.46]:
		_add_cyl(bm, Vector3(center_x + sx, y_bot + 0.18, base_z - 0.20), 0.032, 0.032, 0.024, Vector3(0.0, 0.0, 90.0), red_anod, 10, "TowHook")

static func add_radiator_guard(parent: Node3D, pos: Vector3, size_xy: Vector2, with_bar: bool = true) -> void:
	var steel := get_mat("forged_steel")
	var grille := get_mat("grille_mesh")
	_add_box(parent, pos, Vector3(size_xy.x, size_xy.y, 0.030), Vector3.ZERO, grille, "RadiatorGrilleMesh")
	_add_box(parent, pos + Vector3(0.0, size_xy.y * 0.5, 0.0), Vector3(size_xy.x + 0.04, 0.042, 0.048), Vector3.ZERO, steel, "GrilleTopFrame")
	_add_box(parent, pos + Vector3(0.0, -size_xy.y * 0.5, 0.0), Vector3(size_xy.x + 0.04, 0.042, 0.048), Vector3.ZERO, steel, "GrilleBotFrame")
	if with_bar:
		_add_tube(parent, pos + Vector3(-size_xy.x * 0.52, -size_xy.y * 0.55, -0.04), pos + Vector3(-size_xy.x * 0.52, size_xy.y * 0.55, -0.01), 0.030, steel)
		_add_tube(parent, pos + Vector3(size_xy.x * 0.52, -size_xy.y * 0.55, -0.04), pos + Vector3(size_xy.x * 0.52, size_xy.y * 0.55, -0.01), 0.030, steel)
		_add_tube(parent, pos + Vector3(-size_xy.x * 0.52, size_xy.y * 0.55, -0.01), pos + Vector3(size_xy.x * 0.52, size_xy.y * 0.55, -0.01), 0.030, steel)

static func add_bolted_side_armor(parent: Node3D, pos: Vector3, height: float, length: float, side_sign: float, tilt_z_deg: float = 0.0) -> void:
	var armor := get_mat("gunmetal_armor")
	var steel := get_mat("forged_steel")
	var chrome := get_mat("chrome")

	var panel := Node3D.new()
	panel.name = "SideArmorPanel"
	panel.position = pos
	panel.rotation_degrees = Vector3(0.0, 0.0, tilt_z_deg)
	parent.add_child(panel)

	# Основной лист брони со скошенными кромками и выштампованными рёбрами жёсткости
	_add_box(panel, Vector3.ZERO, Vector3(0.044, height, length), Vector3.ZERO, armor, "MainDoorPlate")
	_add_box(panel, Vector3(side_sign * 0.018, height * 0.34, 0.0), Vector3(0.032, 0.050, length * 0.94), Vector3.ZERO, steel, "UpperRubRib")
	_add_box(panel, Vector3(side_sign * 0.018, -height * 0.34, 0.0), Vector3(0.032, 0.050, length * 0.94), Vector3.ZERO, steel, "LowerRubRib")
	# Заклёпки по периметру
	var n_bolts := clampi(roundi(length / 0.36), 3, 7)
	for bi in range(n_bolts):
		var bz := lerpf(-length * 0.42, length * 0.42, float(bi) / float(maxi(n_bolts - 1, 1)))
		_add_cyl(panel, Vector3(side_sign * 0.028, height * 0.34, bz), 0.012, 0.012, 0.018, Vector3(0.0, 0.0, 90.0), chrome, 6, "SideRivetTop")
		_add_cyl(panel, Vector3(side_sign * 0.028, -height * 0.34, bz), 0.012, 0.012, 0.018, Vector3(0.0, 0.0, 90.0), chrome, 6, "SideRivetBot")

static func add_armored_louver_shield(parent: Node3D, center: Vector3, width: float, span: float, tilt_deg_x: float, slat_count: int, slat_pitch_deg: float = 22.0) -> void:
	var steel := get_mat("forged_steel")
	var armor := get_mat("gunmetal_armor")
	var rack := Node3D.new()
	rack.name = "LouverShield"
	rack.position = center
	rack.rotation_degrees.x = tilt_deg_x
	parent.add_child(rack)

	# Сварная рама по периметру + центральная вертикальная стойка
	for sx: float in [-width * 0.5, 0.0, width * 0.5]:
		_add_box(rack, Vector3(sx, 0.0, 0.0), Vector3(0.036, 0.042, span), Vector3.ZERO, steel, "LouverRail")
	_add_box(rack, Vector3(0.0, 0.0, -span * 0.49), Vector3(width + 0.04, 0.042, 0.036), Vector3.ZERO, steel, "LouverHeader")
	_add_box(rack, Vector3(0.0, 0.0,  span * 0.49), Vector3(width + 0.04, 0.042, 0.036), Vector3.ZERO, steel, "LouverFooter")

	for i in range(slat_count):
		var t := (float(i) / float(maxi(slat_count - 1, 1))) - 0.5
		_add_box(rack, Vector3(0.0, 0.008, t * span * 0.80), Vector3(width - 0.04, 0.018, 0.072), Vector3(slat_pitch_deg, 0.0, 0.0), armor, "LouverSlat")

static func add_sculpted_airfoil_wing(parent: Node3D, base_pos: Vector3, width: float, chord: float = 0.28, tilt_deg: float = -10.0, strut_h: float = 0.20, strut_spacing: float = 0.92) -> void:
	var armor := get_mat("gunmetal_armor")
	var steel := get_mat("forged_steel")
	var hazard := get_mat("hazard_steel")

	var wing := Node3D.new()
	wing.name = "SculptedAirfoilWing"
	wing.position = base_pos
	parent.add_child(wing)

	# Опорные стойки с основаниями, прижатыми к крышке багажника/кузова (y = 0)
	var half_s := strut_spacing * 0.5
	for side: float in [-1.0, 1.0]:
		_add_box(wing, Vector3(side * half_s, 0.010, 0.0), Vector3(0.08, 0.022, chord * 0.72), Vector3.ZERO, steel, "WingFootPad")
		_add_box(wing, Vector3(side * half_s, strut_h * 0.5, 0.02), Vector3(0.038, strut_h, chord * 0.58), Vector3(8.0, 0.0, 0.0), steel, "WingStrut")

	# Аэродинамический профиль крыла (лофт вдоль X: широкое переднее крыло + закрылок Герни)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := width * 0.5
	var prof: Array[Vector2] = [
		Vector2(-chord * 0.50, 0.006),
		Vector2(-chord * 0.25, 0.026),
		Vector2( chord * 0.15, 0.022),
		Vector2( chord * 0.50, 0.008),
		Vector2( chord * 0.50, -0.010),
		Vector2( chord * 0.05, -0.008),
		Vector2(-chord * 0.35, -0.012),
	]
	var n_p := prof.size()
	for pi in range(n_p):
		var pn := (pi + 1) % n_p
		var a2: Vector2 = prof[pi]
		var b2: Vector2 = prof[pn]
		var la := Vector3(-hw, a2.y, a2.x)
		var lb := Vector3(-hw, b2.y, b2.x)
		var ra := Vector3(hw, a2.y, a2.x)
		var rb := Vector3(hw, b2.y, b2.x)
		st.set_uv(Vector2(0.0, float(pi) / float(n_p))); st.add_vertex(la)
		st.set_uv(Vector2(1.0, float(pi + 1) / float(n_p))); st.add_vertex(rb)
		st.set_uv(Vector2(1.0, float(pi) / float(n_p))); st.add_vertex(ra)
		st.set_uv(Vector2(0.0, float(pi) / float(n_p))); st.add_vertex(la)
		st.set_uv(Vector2(0.0, float(pi + 1) / float(n_p))); st.add_vertex(lb)
		st.set_uv(Vector2(1.0, float(pi + 1) / float(n_p))); st.add_vertex(rb)
	st.generate_normals()

	var blade := MeshInstance3D.new()
	blade.name = "AirfoilBlade"
	blade.mesh = st.commit()
	blade.material_override = armor
	blade.position = Vector3(0.0, strut_h + 0.01, 0.04)
	blade.rotation_degrees = Vector3(tilt_deg, 0.0, 0.0)
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	wing.add_child(blade)

	# Торцевые аэрошайбы
	for side: float in [-1.0, 1.0]:
		_add_box(blade, Vector3(side * (hw + 0.015), 0.01, 0.01), Vector3(0.026, 0.14, chord * 1.18), Vector3.ZERO, hazard, "WingEndplate")

static func add_exhaust_stack(parent: Node3D, base_pos: Vector3, top_pos: Vector3, radius: float = 0.046) -> void:
	var ex_mat := get_mat("exhaust_steel")
	var steel := get_mat("forged_steel")
	var dark := get_mat("dark_cavity")

	_add_tube(parent, base_pos, top_pos, radius, ex_mat, false, 12)
	# Перфорированный теплоэкран в средней части трубы
	var mid := base_pos.lerp(top_pos, 0.45)
	var shield_h := maxf((top_pos - base_pos).length() * 0.52, 0.25)
	_add_cyl(parent, mid, radius * 1.32, radius * 1.32, shield_h, Vector3.ZERO, steel, 12, "HeatShield")
	# Косой срез выхлопного сопла сверху + тёмное жерло
	var tip_dir := Vector3(0.0, 0.08, 0.11).normalized()
	_add_tube(parent, top_pos - Vector3(0.0, 0.02, 0.0), top_pos + tip_dir * 0.16, radius * 1.06, ex_mat, false, 12)
	_add_cyl(parent, top_pos + tip_dir * 0.155, radius * 0.85, radius * 0.85, 0.02, Vector3(54.0, 0.0, 0.0), dark, 10, "ExhaustBore")

static func add_rock_slider(parent: Node3D, x_pos: float, y_pos: float, z_front: float, z_rear: float, side_sign: float) -> void:
	var steel := get_mat("forged_steel")
	var inner_x := x_pos - side_sign * 0.05
	var outer_x := x_pos + side_sign * 0.03
	_add_tube(parent, Vector3(inner_x, y_pos, z_front), Vector3(inner_x, y_pos, z_rear), 0.034, steel)
	_add_tube(parent, Vector3(outer_x, y_pos + 0.015, z_front + 0.08), Vector3(outer_x, y_pos + 0.015, z_rear - 0.08), 0.040, steel)
	for frac: float in [0.18, 0.50, 0.82]:
		var bz := lerpf(z_front, z_rear, frac)
		_add_tube(parent, Vector3(inner_x, y_pos, bz), Vector3(outer_x, y_pos + 0.015, bz), 0.028, steel)

static func add_tactical_lightbar(parent: Node3D, pos: Vector3, width: float, pod_count: int = 4) -> void:
	var steel := get_mat("forged_steel")
	var lens := get_mat("led_lens")
	var chrome := get_mat("chrome")

	var bar := Node3D.new()
	bar.name = "TacticalLightbar"
	bar.position = pos
	parent.add_child(bar)

	# Установочные лапы на крышу + оребрённый корпус LED-балки + верхняя защитная дуга
	for sx: float in [-width * 0.44, width * 0.44]:
		_add_box(bar, Vector3(sx, 0.026, 0.0), Vector3(0.05, 0.058, 0.10), Vector3.ZERO, steel, "LightbarFoot")
	_add_box(bar, Vector3(0.0, 0.068, 0.0), Vector3(width * 0.90, 0.084, 0.115), Vector3.ZERO, steel, "LightbarHousing")
	_add_tube(bar, Vector3(-width * 0.48, 0.125, -0.02), Vector3(width * 0.48, 0.125, -0.02), 0.018, steel)
	_add_tube(bar, Vector3(-width * 0.48, 0.050, -0.02), Vector3(-width * 0.48, 0.125, -0.02), 0.018, steel)
	_add_tube(bar, Vector3(width * 0.48, 0.050, -0.02), Vector3(width * 0.48, 0.125, -0.02), 0.018, steel)

	for i in range(pod_count):
		var t := (float(i) / float(maxi(pod_count - 1, 1))) - 0.5
		var lx := t * (width * 0.72)
		_add_box(bar, Vector3(lx, 0.068, -0.052), Vector3(0.165, 0.068, 0.024), Vector3.ZERO, chrome, "LedBezel")
		_add_box(bar, Vector3(lx, 0.068, -0.064), Vector3(0.140, 0.050, 0.014), Vector3.ZERO, lens, "LedEmitter")
