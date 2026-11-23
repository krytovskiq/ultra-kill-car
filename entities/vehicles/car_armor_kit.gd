extends RefCounted
class_name CarArmorKit

const KMF = preload("res://entities/vehicles/kit_mesh_factory.gd")

## Поэтапная установка визуальных комплектов улучшения на все 11 машин:
## - `engine`: V8 Roots нагнетатель со шкивом и дросселями / твин-турбо блок / дизель-интеркулер + спойлеры и выхлоп
## - `armor`: скульптурный силовой таран / Baja-бампер, решётка радиатора, болтовая бортовая броня
## - `chassis`: бронежалюзи, трубчатые пороги, дуги безопасности и тактическая LED-балка
## - `fuel`: только увеличение ёмкости бака (без визуальной бочки) + открывает боевую патину при 50/50.

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

	# Улучшение топливного бака больше не спавнит визуальных моделей на кузове
	if not (st_engine or st_armor or st_chassis):
		return

	var kit := Node3D.new()
	kit.name = "FullUpgradeArmorKit"
	vehicle.add_child(kit)

	match engine_id:
		"pikap":
			_build_pikap_kit(kit, st_engine, st_armor, st_chassis)
		"doge2":
			_build_doge2_kit(kit, st_engine, st_armor, st_chassis)
		"mustang", "barracuda":
			_build_barracuda_kit(kit, st_engine, st_armor, st_chassis)
		"buhanka":
			_build_buhanka_kit(kit, st_engine, st_armor, st_chassis)
		"vandura":
			_build_vandura_kit(kit, st_engine, st_armor, st_chassis)
		"carson":
			_build_carson_kit(kit, st_engine, st_armor, st_chassis)
		"delorean":
			_build_delorean_kit(kit, st_engine, st_armor, st_chassis)
		"k2500":
			_build_k2500_kit(kit, st_engine, st_armor, st_chassis)
		"paz3205":
			_build_paz3205_kit(kit, st_engine, st_armor, st_chassis)
		"raptor":
			_build_raptor_kit(kit, st_engine, st_armor, st_chassis)
		"btr":
			_build_btr_kit(vehicle, kit, st_engine, st_armor, st_chassis)
		_:
			_build_pikap_kit(kit, st_engine, st_armor, st_chassis)

	if vehicle.has_method("refresh_armor_kit_refs"):
		vehicle.call("refresh_armor_kit_refs")

static func _apply_body_war_patina(vehicle: Node3D) -> void:
	KMF.ensure_textures()
	var saved: Dictionary = {}
	_scan_and_patch_materials(vehicle, saved)
	if not saved.is_empty():
		vehicle.set_meta("_max_patina_originals", saved)

static func _scan_and_patch_materials(node: Node, saved: Dictionary) -> void:
	if node is RaycastWheel or node is CPUParticles3D:
		return
	if node.name == "FullUpgradeArmorKit" or node.name == "VisualLightsRig" or node.name == "TurretArmorMount":
		return
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.material_override != null:
			for child in node.get_children():
				_scan_and_patch_materials(child, saved)
			return
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
				pat.detail_albedo = KMF.get_war_detail_tex()
				pat.detail_normal = KMF.get_diamond_nor_tex()
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

static func _build_pikap_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var steel := KMF.get_mat("forged_steel")
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.37, 0.30, 0.76, 0.94, 0.34, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 1.00, -2.36), Vector2(0.96, 0.36))
		for sx: float in [-1.015, 1.015]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.74, -0.18), 0.34, 1.06, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.34, -1.56), 1.02, -4.0)
		for sx: float in [-0.88, 0.88]:
			KMF.add_exhaust_stack(kit, Vector3(sx, 1.08, 0.44), Vector3(sx, 2.02, 0.48), 0.045)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.60, -0.78), 1.24, 0.42, -48.0, 4, 24.0)
		for sx: float in [-0.78, 0.78]:
			KMF._add_tube(kit, Vector3(sx, 1.08, 0.50), Vector3(sx * 0.90, 1.94, 0.52), 0.040, steel)
			KMF._add_tube(kit, Vector3(sx * 0.90, 1.94, 0.52), Vector3(sx, 1.08, 2.02), 0.036, steel)
			KMF._add_tube(kit, Vector3(sx, 1.08, 0.50), Vector3(sx, 1.08, 2.08), 0.034, steel)
		KMF._add_tube(kit, Vector3(-0.70, 1.94, 0.52), Vector3(0.70, 1.94, 0.52), 0.040, steel)
		for sx: float in [-1.02, 1.02]:
			KMF.add_rock_slider(kit, sx, 0.34, -0.88, 0.92, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.84, -0.28), 1.18, 4)

static func _build_doge2_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.63, 0.22, 0.60, 1.00, 0.34, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.70, -2.63), Vector2(1.14, 0.26))
		for sx: float in [-1.075, 1.075]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.62, 0.0), 0.30, 1.68, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.005, -1.62), 1.10, -2.0)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 1.105, 2.40), 1.84, 0.28, -10.0, 0.16, 1.02)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.21, -0.56), 1.42, 0.56, -32.0, 4, 22.0)
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.22, 1.18), 1.38, 0.86, 16.0, 6, -16.0)
		for sx: float in [-1.08, 1.08]:
			KMF.add_rock_slider(kit, sx, 0.28, -1.10, 1.10, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.425, 0.02), 1.26, 4)

static func _build_barracuda_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.37, 0.26, 0.58, 0.90, 0.30, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.66, -2.33), Vector2(1.08, 0.22))
		for sx: float in [-1.045, 1.045]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.62, 0.0), 0.28, 1.46, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.00, -1.36), 1.08, -1.5)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 0.96, 2.18), 1.76, 0.28, -10.0, 0.21, 0.96)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.14, -0.42), 1.22, 0.52, -31.0, 4, 22.0)
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.15, 1.16), 1.16, 0.74, 18.0, 5, -18.0)
		for sx: float in [-1.04, 1.04]:
			KMF.add_rock_slider(kit, sx, 0.30, -0.88, 0.88, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.33, 0.10), 1.14, 4)

static func _build_buhanka_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var steel := KMF.get_mat("forged_steel")
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.12, 0.28, 0.74, 0.98, 0.32, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.95, -2.13), Vector2(1.16, 0.38))
		for sx: float in [-1.00, 1.00]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.78, 0.02), 0.42, 1.24, signf(sx))

	if st_engine:
		KMF.add_diesel_turbo_unit(kit, Vector3(0.0, 2.09, -0.15), 1.0)
		for sx: float in [-0.96, 0.96]:
			KMF.add_exhaust_stack(kit, Vector3(sx, 0.90, 2.04), Vector3(sx, 2.26, 2.04), 0.044)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.48, -1.98), 1.44, 0.50, -70.0, 4, 24.0)
		for sx: float in [-0.70, 0.70]:
			KMF._add_tube(kit, Vector3(sx, 2.12, -1.50), Vector3(sx, 2.12, 1.72), 0.032, steel)
		KMF._add_tube(kit, Vector3(-0.70, 2.12, 1.72), Vector3(0.70, 2.12, 1.72), 0.032, steel)
		for sx: float in [-1.00, 1.00]:
			KMF.add_rock_slider(kit, sx, 0.36, -0.68, 0.72, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 2.11, -1.25), 1.36, 4)

static func _build_vandura_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.57, 0.30, 0.72, 1.00, 0.32, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.90, -2.56), Vector2(1.16, 0.32))
		for sx: float in [-1.02, 1.02]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.84, -0.20), 0.44, 1.96, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.34, -2.18), 0.80, -14.0)
		for sx: float in [-1.02, 1.02]:
			KMF.add_exhaust_stack(kit, Vector3(sx, 0.92, 2.42), Vector3(sx, 2.30, 2.42), 0.046)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 2.12, 2.05), 1.72, 0.28, -9.0, 0.16, 1.08)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.74, -1.68), 1.42, 0.54, -42.0, 4, 24.0)
		for sx: float in [-1.02, 1.02]:
			KMF.add_rock_slider(kit, sx, 0.36, -1.26, 0.90, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 2.12, -0.72), 1.38, 4)

static func _build_carson_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var ex_mat := KMF.get_mat("exhaust_steel")
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.45, 0.24, 0.58, 0.78, 0.28, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.72, -2.14), Vector2(0.68, 0.40), false)
		for sx: float in [-0.785, 0.785]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.84, 0.12), 0.28, 1.65, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.275, -1.16), 1.12, 0.0)
		for sx: float in [-0.82, 0.82]:
			KMF._add_tube(kit, Vector3(sx * 0.90, 0.82, -1.35), Vector3(sx, 0.42, -1.05), 0.036, ex_mat)
			KMF._add_tube(kit, Vector3(sx, 0.42, -1.05), Vector3(sx, 0.36, 0.58), 0.040, ex_mat)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.40, -0.18), 1.06, 0.36, -70.0, 4, 24.0)
		for sx: float in [-0.95, 0.95]:
			KMF.add_rock_slider(kit, sx, 0.28, -0.96, 1.06, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.56, 0.32), 1.10, 4)

static func _build_delorean_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.11, 0.18, 0.48, 0.88, 0.28, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 0.54, -2.10), Vector2(1.10, 0.18), false)
		for sx: float in [-0.985, 0.985]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.50, -0.02), 0.22, 1.26, signf(sx))

	if st_engine:
		KMF.add_twin_turbo_rig(kit, Vector3(0.0, 1.045, 1.48), 1.00, -4.0)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 1.07, 1.96), 1.72, 0.26, -11.0, 0.22, 0.94)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 0.96, -0.50), 1.20, 0.50, -23.0, 4, 22.0)
		for sx: float in [-0.98, 0.98]:
			KMF.add_rock_slider(kit, sx, 0.24, -0.76, 0.74, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.14, 0.14), 1.06, 4)

static func _build_k2500_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var steel := KMF.get_mat("forged_steel")
	if st_armor:
		KMF.add_baja_prerunner_bumper(kit, -2.92, 0.56, 1.24, 1.04, 0.0)
		for sx: float in [-1.045, 1.045]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.92, -0.45), 0.34, 1.30, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.44, -2.05), 1.12, -4.0)
		for sx: float in [-0.94, 0.94]:
			KMF.add_exhaust_stack(kit, Vector3(sx, 1.42, 0.38), Vector3(sx, 2.48, 0.40), 0.048)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 1.45, 2.74), 1.92, 0.28, -10.0, 0.18, 1.18)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.82, -1.02), 1.54, 0.56, -42.0, 4, 24.0)
		for sx: float in [-0.90, 0.90]:
			KMF._add_tube(kit, Vector3(sx, 1.45, 0.44), Vector3(sx, 2.24, 0.44), 0.044, steel)
			KMF._add_tube(kit, Vector3(sx, 2.24, 0.44), Vector3(sx, 1.46, 2.66), 0.042, steel)
		KMF._add_tube(kit, Vector3(-0.90, 2.24, 0.44), Vector3(0.90, 2.24, 0.44), 0.044, steel)
		for sx: float in [-1.04, 1.04]:
			KMF.add_rock_slider(kit, sx, 0.50, -1.24, 0.98, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 2.22, -0.30), 1.48, 4)

static func _build_raptor_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var steel := KMF.get_mat("forged_steel")
	if st_armor:
		KMF.add_baja_prerunner_bumper(kit, -2.72, 0.54, 1.22, 1.02, 0.0)
		for sx: float in [-1.085, 1.085]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.84, 0.0), 0.32, 1.80, signf(sx))

	if st_engine:
		KMF.add_supercharger_blower(kit, Vector3(0.0, 1.445, -1.82), 1.10, -5.0)
		KMF.add_sculpted_airfoil_wing(kit, Vector3(0.0, 1.41, 2.82), 1.88, 0.28, -10.0, 0.19, 1.22)

	if st_chassis:
		KMF.add_armored_louver_shield(kit, Vector3(0.0, 1.68, -0.98), 1.52, 0.58, -39.0, 4, 24.0)
		for sx: float in [-0.88, 0.88]:
			KMF._add_tube(kit, Vector3(sx, 1.42, 0.52), Vector3(sx, 1.96, 0.56), 0.044, steel)
			KMF._add_tube(kit, Vector3(sx, 1.96, 0.56), Vector3(sx, 1.42, 2.68), 0.042, steel)
			KMF._add_tube(kit, Vector3(sx, 1.42, 0.52), Vector3(sx, 1.42, 2.72), 0.036, steel)
		KMF._add_tube(kit, Vector3(-0.88, 1.96, 0.56), Vector3(0.88, 1.96, 0.56), 0.044, steel)
		for sx: float in [-1.08, 1.08]:
			KMF.add_rock_slider(kit, sx, 0.44, -1.12, 1.12, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 1.99, -0.48), 1.50, 4)

static func _build_paz3205_kit(kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var armor := KMF.get_mat("gunmetal_armor")
	if st_armor:
		KMF.add_sculpted_v_ram(kit, -3.30, 0.34, 0.96, 1.22, 0.36, 0.0)
		KMF.add_radiator_guard(kit, Vector3(0.0, 1.08, -3.28), Vector2(1.86, 0.44))
		for sx: float in [-1.23, 1.23]:
			KMF.add_bolted_side_armor(kit, Vector3(sx, 0.92, -0.41), 0.48, 1.88, signf(sx))

	if st_engine:
		KMF.add_diesel_turbo_unit(kit, Vector3(0.0, 0.99, 1.85), 1.15)
		for sx: float in [-1.06, 1.06]:
			KMF.add_exhaust_stack(kit, Vector3(sx, 0.90, 3.22), Vector3(sx, 3.28, 3.22), 0.052)

	if st_chassis:
		KMF._add_box(kit, Vector3(0.0, 2.66, -3.12), Vector3(2.22, 0.22, 0.14), Vector3(18.0, 0.0, 0.0), armor, "PAZCabBrowArmor")
		for sx: float in [-1.23, 1.23]:
			KMF.add_rock_slider(kit, sx, 0.48, -1.46, 0.65, signf(sx))
		KMF.add_tactical_lightbar(kit, Vector3(0.0, 2.96, -2.72), 1.84, 4)

static func _build_btr_kit(vehicle: Node3D, kit: Node3D, st_engine: bool, st_armor: bool, st_chassis: bool) -> void:
	var armor := KMF.get_mat("gunmetal_armor")
	var steel := KMF.get_mat("forged_steel")
	var grille := KMF.get_mat("grille_mesh")
	var hazard := KMF.get_mat("hazard_steel")
	var cx := -0.02

	if st_armor:
		KMF.add_sculpted_v_ram(kit, -2.84, 0.24, 0.78, 0.94, 0.34, cx)
		for sx: float in [-0.54, 0.54]:
			KMF._add_tube(kit, Vector3(cx + sx, 0.74, -2.62), Vector3(cx + sx * 0.92, 0.52, -3.02), 0.048, steel)
		for side: float in [-1.0, 1.0]:
			KMF.add_bolted_side_armor(kit, Vector3(cx + side * 1.18, 0.72, -0.25), 0.26, 1.38, side, side * -8.0)

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
			KMF._add_box(t_kit, Vector3(-5.8, 2.5, -0.6), Vector3(0.55, 2.3, 5.0), Vector3(0.0, 14.0, -22.0), armor, "TurretLeftCheek")
			KMF._add_box(t_kit, Vector3(5.8, 2.5, -0.6), Vector3(0.55, 2.3, 5.0), Vector3(0.0, -14.0, 22.0), armor, "TurretRightCheek")
			KMF._add_box(t_kit, Vector3(0.0, 2.7, -4.8), Vector3(6.2, 1.5, 0.45), Vector3(-22.0, 0.0, 0.0), grille, "TurretMantletScreen")
			KMF._add_box(t_kit, Vector3(-3.4, 2.9, -4.1), Vector3(2.0, 0.65, 0.42), Vector3(-22.0, 10.0, 0.0), hazard, "TurretTrimL")
			KMF._add_box(t_kit, Vector3(3.4, 2.9, -4.1), Vector3(2.0, 0.65, 0.42), Vector3(-22.0, -10.0, 0.0), hazard, "TurretTrimR")

	if st_engine:
		KMF._add_box(kit, Vector3(cx, 1.06, -2.32), Vector3(1.18, 0.24, 0.05), Vector3(-34.0, 0.0, 0.0), grille, "GlacisCage")
		KMF._add_box(kit, Vector3(-0.73, 0.92, -2.62), Vector3(0.24, 0.16, 0.18), Vector3.ZERO, grille, "HeadlampCageL")
		KMF._add_box(kit, Vector3(0.73, 0.92, -2.62), Vector3(0.24, 0.16, 0.18), Vector3.ZERO, grille, "HeadlampCageR")
		for sx: float in [-0.62, 0.62]:
			KMF._add_box(kit, Vector3(cx + sx, 0.88, 2.26), Vector3(0.18, 0.18, 0.46), Vector3(12.0, sx * -10.0, 0.0), armor, "DieselMufflerBox")

	if st_chassis:
		for side: float in [-1.0, 1.0]:
			KMF._add_box(kit, Vector3(cx + side * 1.06, 1.56, -0.05), Vector3(0.04, 0.22, 0.96), Vector3(0.0, 0.0, side * 30.0), grille, "UpperPortCage")
			KMF.add_rock_slider(kit, cx + side * 1.24, 0.48, -1.05, 0.65, side)
		KMF.add_tactical_lightbar(kit, Vector3(cx, 2.02, -0.35), 0.92, 3)
