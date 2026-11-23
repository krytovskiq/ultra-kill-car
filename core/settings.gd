extends Node

enum GraphicsQuality { LOW, MEDIUM, HIGH, ULTRA }

signal quality_changed(new_quality: GraphicsQuality)
signal volume_changed()

var current_quality: GraphicsQuality = GraphicsQuality.HIGH

var master_volume: float = 0.85
var vehicles_volume: float = 0.85
var sfx_volume: float = 0.90
var ambience_volume: float = 0.80

const SAVE_PATH := "user://settings.dat"
const SAVE_MAGIC_0 := 0x53 # 'S'
const SAVE_VERSION := 3

const QUALITY_NAMES: Dictionary = {
	GraphicsQuality.LOW: "Низкое",
	GraphicsQuality.MEDIUM: "Среднее",
	GraphicsQuality.HIGH: "Высокое",
	GraphicsQuality.ULTRA: "Ультра",
}

const QUALITY_DESCRIPTIONS: Dictionary = {
	GraphicsQuality.LOW: "Масштаб 75%, без сглаживания и пост-эффектов, текстурные фары и быстрый туман",
	GraphicsQuality.MEDIUM: "Масштаб 90%, MSAA 2x, текстурные фары, шейдерное небо и умеренный эффект скорости",
	GraphicsQuality.HIGH: "Масштаб 100%, MSAA 2x, Filmic, атмосферное небо-шейдер, текстурный свет фар и эффект скорости",
	GraphicsQuality.ULTRA: "Масштаб 100%, MSAA 4x, Filmic, glow, полный шейдер скорости и максимум деталей",
}

func _ready() -> void:
	load_settings()
	apply_audio_settings()
	var tree := get_tree()
	if tree and tree.has_signal("scene_changed"):
		tree.scene_changed.connect(apply_settings)
	call_deferred("apply_settings")

func set_quality(q: GraphicsQuality) -> void:
	current_quality = clampi(int(q), GraphicsQuality.LOW, GraphicsQuality.ULTRA) as GraphicsQuality
	apply_settings()
	save_settings()
	quality_changed.emit(current_quality)

func cycle_quality() -> GraphicsQuality:
	var next_q: GraphicsQuality = ((int(current_quality) + 1) % 4) as GraphicsQuality
	set_quality(next_q)
	return current_quality

func set_volume(channel: String, value: float, persist: bool = true) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	match channel:
		"master":
			master_volume = clamped
		"vehicles":
			vehicles_volume = clamped
		"sfx":
			sfx_volume = clamped
		"ambience":
			ambience_volume = clamped
	apply_audio_settings()
	volume_changed.emit()
	if persist:
		save_settings()

func get_volume(channel: String) -> float:
	match channel:
		"master":
			return master_volume
		"vehicles":
			return vehicles_volume
		"sfx":
			return sfx_volume
		"ambience":
			return ambience_volume
	return 1.0

func apply_audio_settings() -> void:
	var bus_map: Dictionary = {
		&"Master": master_volume,
		&"Vehicles": vehicles_volume,
		&"SFX": sfx_volume,
		&"Ambience": ambience_volume,
	}
	for bus_name in bus_map.keys():
		var idx := AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			var val := float(bus_map[bus_name])
			if val <= 0.001:
				AudioServer.set_bus_mute(idx, true)
			else:
				AudioServer.set_bus_mute(idx, false)
				AudioServer.set_bus_volume_db(idx, linear_to_db(val))

func get_quality_name(q: int = -1) -> String:
	var target: int = current_quality if q < 0 else clampi(q, GraphicsQuality.LOW, GraphicsQuality.ULTRA)
	return str(QUALITY_NAMES.get(target, "Высокое"))

func get_quality_description(q: int = -1) -> String:
	var target: int = current_quality if q < 0 else clampi(q, GraphicsQuality.LOW, GraphicsQuality.ULTRA)
	return str(QUALITY_DESCRIPTIONS.get(target, ""))

func get_prop_density() -> float:
	match current_quality:
		GraphicsQuality.LOW:
			return 0.35
		GraphicsQuality.MEDIUM:
			return 0.65
		GraphicsQuality.HIGH:
			return 1.0
		GraphicsQuality.ULTRA:
			return 1.25
	return 1.0

func is_fog_allowed() -> bool:
	return true

func are_car_lights_enabled() -> bool:
	return true

func get_speed_effect_scale() -> float:
	match current_quality:
		GraphicsQuality.LOW:
			return 0.0
		GraphicsQuality.MEDIUM:
			return 0.55
		GraphicsQuality.HIGH:
			return 0.85
		GraphicsQuality.ULTRA:
			return 1.0
	return 0.85

func get_max_zombies() -> int:
	match current_quality:
		GraphicsQuality.LOW:
			return 55
		GraphicsQuality.MEDIUM:
			return 80
		GraphicsQuality.HIGH:
			return 105
		GraphicsQuality.ULTRA:
			return 130
	return 105

func get_vfx_scale() -> float:
	match current_quality:
		GraphicsQuality.LOW:
			return 0.55
		GraphicsQuality.MEDIUM:
			return 0.75
		GraphicsQuality.HIGH:
			return 1.0
		GraphicsQuality.ULTRA:
			return 1.0
	return 1.0

func apply_settings(target_scene: Node = null) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return

	var tree := get_tree()
	var scene: Node = target_scene if target_scene != null else (tree.current_scene if tree else null)
	if scene and scene.get_node_or_null("WorldEnvironment") == null and tree and tree.current_scene:
		scene = tree.current_scene

	var is_shop: bool = (scene != null and scene.name == "Shop")
	var is_menu: bool = (scene != null and (scene.name == "MainMenu" or scene.scene_file_path.ends_with("menu.tscn")))

	match current_quality:
		GraphicsQuality.LOW:
			viewport.scaling_3d_scale = 0.75
			viewport.msaa_3d = Viewport.MSAA_DISABLED
		GraphicsQuality.MEDIUM:
			viewport.scaling_3d_scale = 0.90
			viewport.msaa_3d = Viewport.MSAA_2X
		GraphicsQuality.HIGH:
			viewport.scaling_3d_scale = 1.00
			viewport.msaa_3d = Viewport.MSAA_2X
		GraphicsQuality.ULTRA:
			viewport.scaling_3d_scale = 1.00
			viewport.msaa_3d = Viewport.MSAA_4X

	var dir_light: DirectionalLight3D = null
	var envs: Array[Environment] = []
	var cam: Camera3D = viewport.get_camera_3d()

	if scene:
		var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we == null:
			we = scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we and we.environment:
			envs.append(we.environment)

		dir_light = scene.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
		if dir_light == null:
			dir_light = scene.find_child("DirectionalLight3D", true, false) as DirectionalLight3D

		if cam == null:
			cam = scene.find_child("*Camera*", true, false) as Camera3D

	if cam and cam.environment and not envs.has(cam.environment):
		envs.append(cam.environment)

	if dir_light:
		# No real-time shadow maps; vehicles use additive/multiplicative texture overlays instead.
		dir_light.shadow_enabled = false

	for env in envs:
		match current_quality:
			GraphicsQuality.LOW:
				env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
				env.tonemap_exposure = 1.0
				env.tonemap_white = 1.0
				env.ambient_light_energy = 0.72 if is_shop else 0.65
				env.glow_enabled = false
				env.glow_intensity = 0.0
				env.glow_bloom = 0.0
				env.glow_hdr_threshold = 1.35
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
				env.adjustment_enabled = false
				env.adjustment_brightness = 1.0
				env.adjustment_contrast = 1.0
				env.adjustment_saturation = 1.0
				env.fog_enabled = not is_shop
				env.fog_sun_scatter = 0.0
				env.fog_sky_affect = 0.94
				if not is_shop:
					env.fog_mode = Environment.FOG_MODE_DEPTH
					env.fog_density = 1.0
					env.fog_depth_curve = 1.08
					env.fog_depth_begin = 16.0
					env.fog_depth_end = 138.0
			GraphicsQuality.MEDIUM:
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				env.tonemap_exposure = 1.0
				env.tonemap_white = 6.0
				env.ambient_light_energy = 0.72 if is_shop else 0.64
				env.glow_enabled = false
				env.glow_intensity = 0.0
				env.glow_bloom = 0.0
				env.glow_hdr_threshold = 1.35
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
				env.adjustment_enabled = false
				env.adjustment_brightness = 1.0
				env.adjustment_contrast = 1.0
				env.adjustment_saturation = 1.0
				env.fog_enabled = true
				env.fog_sun_scatter = 0.05
				env.fog_sky_affect = 0.96
				if is_shop:
					env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
					env.fog_density = 0.0025
				else:
					env.fog_mode = Environment.FOG_MODE_DEPTH
					env.fog_density = 1.0
					env.fog_depth_curve = 1.10
					env.fog_depth_begin = 19.0
					env.fog_depth_end = 152.0
			GraphicsQuality.HIGH:
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				env.tonemap_exposure = 1.0
				env.tonemap_white = 6.0
				env.ambient_light_energy = 0.72 if is_shop else 0.62
				env.glow_enabled = true
				env.glow_intensity = 0.28
				env.glow_bloom = 0.02
				env.glow_hdr_threshold = 1.35
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
				env.adjustment_enabled = not is_shop
				env.adjustment_brightness = 1.0
				env.adjustment_contrast = 1.06
				env.adjustment_saturation = 0.90
				env.fog_enabled = true
				env.fog_sun_scatter = 0.08
				env.fog_sky_affect = 0.96
				if is_shop:
					env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
					env.fog_density = 0.0025
				else:
					env.fog_mode = Environment.FOG_MODE_DEPTH
					env.fog_density = 1.0
					env.fog_depth_curve = 1.10
					env.fog_depth_begin = 21.0
					env.fog_depth_end = 166.0
			GraphicsQuality.ULTRA:
				env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
				env.tonemap_exposure = 1.0
				env.tonemap_white = 6.0
				env.ambient_light_energy = 0.72 if is_shop else 0.60
				env.glow_enabled = true
				env.glow_intensity = 0.36
				env.glow_bloom = 0.03
				env.glow_hdr_threshold = 1.30
				env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
				env.adjustment_enabled = not is_shop
				env.adjustment_brightness = 1.0
				env.adjustment_contrast = 1.08
				env.adjustment_saturation = 0.88
				env.fog_enabled = true
				env.fog_sun_scatter = 0.10
				env.fog_sky_affect = 0.98
				if is_shop:
					env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
					env.fog_density = 0.0025
				else:
					env.fog_mode = Environment.FOG_MODE_DEPTH
					env.fog_density = 1.0
					env.fog_depth_curve = 1.10
					env.fog_depth_begin = 23.0
					env.fog_depth_end = 178.0

		if is_menu:
			# Preserve atmospheric apocalyptic menu fog on all graphics presets
			env.ambient_light_energy = 0.44
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_density = 0.94
			env.fog_depth_curve = 1.25
			env.fog_depth_begin = 11.0
			env.fog_light_color = Color(0.32, 0.35, 0.36, 1.0)
			env.fog_light_energy = 0.72
			env.fog_sky_affect = 0.85
			match current_quality:
				GraphicsQuality.LOW:
					env.fog_depth_end = 82.0
				GraphicsQuality.MEDIUM:
					env.fog_depth_end = 92.0
				GraphicsQuality.HIGH:
					env.fog_depth_end = 98.0
				GraphicsQuality.ULTRA:
					env.fog_depth_end = 104.0
		elif is_shop:
			# Тёпло-дымчатый ангар с плавной видимостью выезда на внешнюю трассу
			env.ambient_light_color = Color(0.28, 0.32, 0.35, 1.0)
			env.ambient_light_energy = 0.44
			env.fog_enabled = true
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_density = 0.82
			env.fog_depth_curve = 1.15
			env.fog_depth_begin = 28.0
			env.fog_light_color = Color(0.24, 0.22, 0.19, 1.0)
			env.fog_light_energy = 0.76
			env.fog_sky_affect = 0.85
			env.fog_depth_end = 175.0

	if cam:
		if is_shop:
			cam.far = 260.0
		elif is_menu:
			cam.far = 160.0
		else:
			match current_quality:
				GraphicsQuality.LOW:
					cam.far = 290.0
				GraphicsQuality.MEDIUM:
					cam.far = 320.0
				GraphicsQuality.HIGH:
					cam.far = 350.0
				GraphicsQuality.ULTRA:
					cam.far = 380.0

func save_settings() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_8(SAVE_MAGIC_0)
		file.store_8(SAVE_VERSION)
		file.store_8(int(current_quality))
		file.store_float(master_volume)
		file.store_float(vehicles_volume)
		file.store_float(sfx_volume)
		file.store_float(ambience_volume)
		file.close()

func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var size := file.get_length()
	if size >= 3:
		var m0 := file.get_8()
		var ver := file.get_8()
		var val := file.get_8()
		if m0 == SAVE_MAGIC_0 and ver == SAVE_VERSION:
			current_quality = clampi(val, GraphicsQuality.LOW, GraphicsQuality.ULTRA) as GraphicsQuality
			if size >= 19:
				master_volume = clampf(file.get_float(), 0.0, 1.0)
				vehicles_volume = clampf(file.get_float(), 0.0, 1.0)
				sfx_volume = clampf(file.get_float(), 0.0, 1.0)
				ambience_volume = clampf(file.get_float(), 0.0, 1.0)
		elif m0 == SAVE_MAGIC_0 and ver == 2:
			current_quality = clampi(val, GraphicsQuality.LOW, GraphicsQuality.ULTRA) as GraphicsQuality
		else:
			current_quality = _migrate_legacy_quality(m0)
	elif size >= 1:
		var legacy_val := file.get_8()
		current_quality = _migrate_legacy_quality(legacy_val)

	file.close()

func _migrate_legacy_quality(legacy_val: int) -> GraphicsQuality:
	match legacy_val:
		0, 1:
			return GraphicsQuality.LOW
		2:
			return GraphicsQuality.MEDIUM
		3:
			return GraphicsQuality.HIGH
		4, 5:
			return GraphicsQuality.ULTRA
	return GraphicsQuality.HIGH
