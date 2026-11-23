extends Node3D

const ProceduralChunkScript = preload("res://levels/procedural_chunk.gd")
const ProceduralMaterials = preload("res://levels/procedural_materials.gd")
const TornadoVortexScript = preload("res://levels/tornado_vortex.gd")

enum WeatherAnomaly { NONE, BLOOD_NIGHT, ACID_STORM, THUNDERSTORM, TORNADO_OUTBREAK }

@export var world_environment: WorldEnvironment
@export var car: RigidBody3D

@export_group("World Generation")
@export var use_procedural_generation: bool = true
@export var world_seed: int = 0
@export var barn_interval_meters: float = 1500.0
@export var chunk_scenes_list: Array[PackedScene] = []
@export var bridge_scene: PackedScene

@export var chunks_ahead: int = 2
@export var chunks_behind: int = 1
@export var chunk_width: float = 560.0
@export var chunk_length: float = 500.0
@export var chunk_thickness: float = 800.0
@export var road_y: float = 0.0
@export var world_origin: Vector3 = Vector3.ZERO
@export var forward_axis: Vector3 = Vector3.BACK

@export_group("Bridge Settings")
@export var bridge_interval_meters: float = 3000.0
@export var bridge_shortfall_meters: float = 45.0

@export_group("Динамический Спавн Зомби")
@export var base_spawn_cooldown: float = 1.05
@export var min_spawn_cooldown: float = 0.30
@export var spawn_distance_ahead: float = 175.0
@export var road_spawn_width: float = 150.0
@export var max_active_zombies: int = 135

@export_group("Смена дня и ночи и Аномалии")
@export var day_night_cycle_seconds: float = 150.0
## -1 = случайная аномалия по отрезкам, 0 = чисто, 1 = Кровавая ночь, 2 = Кислотный шторм, 3 = Гроза, 4 = Смерч
@export var debug_weather_override: int = -1
## -1.0 = авто-цикл, 0.0..1.0 = фиксированное время суток (0.25 = полдень, 0.50 = закат, 0.75 = полночь)
@export var debug_tod_override: float = -1.0

@export_group("Debug")
@export var verbose_logs: bool = false
## Для быстрого теста биома: -1 = без повторов (9 биомов), 0 = Пустошь, 1 = Город, 2 = Лес, 3 = Зимний гололёд, 4 = Токсичное болото, 5 = Опалённый каньон, 6 = Пылающий город, 7 = Сгоревший лес, 8 = Заросшая трасса
@export var debug_start_biome: int = -1

var normal_fog_color: Color = Color("0d1117")
var scary_red_fog_color: Color = Color("6c1717ff")
var current_fog_tween: Tween
var is_fog_red: bool = false

var _forward: Vector3 = Vector3.BACK
var _chunk_step: float = 500.0
var _chunks_per_bridge: int = 6
var _chunk_nodes: Dictionary = {}
var _last_checked_chunk: int = -999999

var _active_world_seed: int = 1
var _biome_rng := RandomNumberGenerator.new()
var _biome_order: Array[int] = []
var _current_biome: int = -1
var _dir_light: DirectionalLight3D = null
var _ash_particles: CPUParticles3D = null
var _ash_mat: StandardMaterial3D = null
var _rain_particles: CPUParticles3D = null
var _rain_mat: StandardMaterial3D = null

const _TOD_PRESETS: Array[Dictionary] = [
	{"tod": 0.04, "label": "РАССВЕТ"},
	{"tod": 0.16, "label": "УТРО"},
	{"tod": 0.28, "label": "ДЕНЬ"},
	{"tod": 0.45, "label": "ЗАКАТ"},
	{"tod": 0.56, "label": "СУМЕРКИ"},
	{"tod": 0.78, "label": "НОЧЬ"},
]

var _time_of_day: float = 0.16
var _tod_preset_idx: int = 1
var _target_time_of_day: float = 0.16
var _tod_blending: bool = false
var _active_anomaly: int = WeatherAnomaly.NONE
var _anomaly_segment: int = -999
var _blood_blend: float = 0.0
var _acid_blend: float = 0.0
var _acid_fog_blend: float = 0.0
var _storm_blend: float = 0.0
var _tornado_blend: float = 0.0
var _lightning_flash: float = 0.0
var _lightning_timer: float = 3.2
var _lightning_bolt: MeshInstance3D = null
var _lightning_bolt_timer: float = 0.0
var _thunder_delay_timer: float = -1.0
var _tornado_node: Node3D = null
var _biome_cur_profile: Dictionary = {}
var _headlight_boost: float = 1.0
var _base_fog_density: float = 1.0
var _base_fog_begin: float = 16.0
var _base_fog_end: float = 148.0

var spawn_timer: float = 0.0
var current_spawn_cooldown: float = 1.05

func _ready() -> void:
	if world_environment and world_environment.environment and not world_environment.environment.resource_local_to_scene:
		world_environment.environment = world_environment.environment.duplicate()
		if world_environment.environment.sky:
			world_environment.environment.sky = world_environment.environment.sky.duplicate()
			if world_environment.environment.sky.sky_material:
				world_environment.environment.sky.sky_material = world_environment.environment.sky.sky_material.duplicate()

	_dir_light = get_node_or_null("DirectionalLight3D") as DirectionalLight3D

	if world_seed != 0:
		_active_world_seed = world_seed
	else:
		var generated_seed: int = int(randi() & 0x7FFFFFFF)
		_active_world_seed = generated_seed if generated_seed != 0 else 1
	_init_biome_sequence()

	_forward = forward_axis.normalized()
	if _forward.length_squared() < 0.001:
		_forward = Vector3.BACK
	_chunk_step = maxf(chunk_length, 1.0)
	_chunks_per_bridge = maxi(floori(bridge_interval_meters / _chunk_step), 2)

	if Game.car_data.is_empty():
		push_error("Main: Game.car_data пуст!")
		return

	var car_idx := clampi(Game.selected_car_index, 0, Game.car_data.size() - 1)
	var car_path: String = Game.car_data[car_idx].path
	var car_scene: PackedScene = load(car_path)
	if car_scene:
		car = car_scene.instantiate() as RigidBody3D
		add_child(car)
		var spawn_basis: Basis = Basis.looking_at(_forward, Vector3.UP)
		car.global_transform = Transform3D(spawn_basis, Vector3(0.0, 0.25, 0.0))
		car.add_to_group("player")
		var rolling_start_mps: float = 32.0 / 3.6
		if car.has_method("set_initial_rolling_start"):
			car.call("set_initial_rolling_start", rolling_start_mps, _forward)
		else:
			car.linear_velocity = _forward * rolling_start_mps

	var WorldChunkScript = load("res://levels/world_chunk.gd")
	WorldChunkScript.global_distance_counter = 0.0

	var quality_cap: int = SettingsManager.get_max_zombies() if SettingsManager.has_method("get_max_zombies") else max_active_zombies
	ZombiePool.prewarm_zombies(mini(quality_cap, 150), self)
	current_spawn_cooldown = base_spawn_cooldown

	if (not use_procedural_generation and chunk_scenes_list.is_empty()) or bridge_scene == null or car == null:
		push_error("Main: Критические ресурсы не назначены в Инспекторе!")
		return

	if not SettingsManager.quality_changed.is_connected(_on_quality_changed):
		SettingsManager.quality_changed.connect(_on_quality_changed)
	SettingsManager.apply_settings(self)
	if world_environment and world_environment.environment:
		_base_fog_density = 1.0
		_base_fog_begin = clampf(world_environment.environment.fog_depth_begin, 8.0, 26.0)
		_base_fog_end = clampf(world_environment.environment.fog_depth_end, 105.0, 190.0)

	_cleanup_preplaced_chunks()
	_setup_ash_emitter()
	_setup_rain_emitter()
	var car_index: int = _get_chunk_index(_distance_along_forward(car.global_position))
	_current_biome = _get_biome_for_index(car_index)
	_active_anomaly = _sanitize_anomaly_for_biome(_get_anomaly_for_segment(0), _current_biome)
	_anomaly_segment = 0
	if debug_tod_override < 0.0:
		var init_rng := RandomNumberGenerator.new()
		init_rng.seed = hash(_active_world_seed) ^ 0x5A17
		_tod_preset_idx = init_rng.randi_range(0, _TOD_PRESETS.size() - 1)
		var init_tod_val: float = float(_TOD_PRESETS[_tod_preset_idx]["tod"])
		_time_of_day = init_tod_val
		_target_time_of_day = init_tod_val
	is_fog_red = (_active_anomaly == WeatherAnomaly.BLOOD_NIGHT)
	_sync_anomaly_effects(false)
	_update_dynamic_atmosphere(0.0, true)

	_ensure_chunks_for_index(car_index)
	_last_checked_chunk = car_index

func _exit_tree() -> void:
	if SettingsManager and SettingsManager.quality_changed.is_connected(_on_quality_changed):
		SettingsManager.quality_changed.disconnect(_on_quality_changed)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_weather_audio"):
		sm.call("set_weather_audio", 0.0, 0.0)
	if is_instance_valid(_tornado_node):
		_tornado_node.queue_free()
		_tornado_node = null
	if is_instance_valid(_lightning_bolt):
		_lightning_bolt.queue_free()
		_lightning_bolt = null

func get_difficulty(distance_m: float) -> float:
	return maxf(absf(distance_m) / 11000.0, 0.0)

func _process(delta: float) -> void:
	if not is_instance_valid(car) or (not use_procedural_generation and chunk_scenes_list.is_empty()):
		return

	if is_instance_valid(_ash_particles):
		_ash_particles.global_position = car.global_position + _forward * 16.0 + Vector3(0.0, 4.2, 0.0)
	if is_instance_valid(_rain_particles) and _rain_particles.visible:
		_rain_particles.global_position = car.global_position + _forward * 18.0 + Vector3(0.0, 13.5, 0.0)

	var distance: float = _distance_along_forward(car.global_position)
	var current_chunk_index: int = _get_chunk_index(distance)
	var diff: float = get_difficulty(distance)
	var diff01: float = clampf(diff, 0.0, 1.0)

	current_spawn_cooldown = lerpf(base_spawn_cooldown, min_spawn_cooldown, pow(diff01, 0.85))
	if is_fog_red:
		current_spawn_cooldown *= 0.85

	var cap_max: int = mini(max_active_zombies, SettingsManager.get_max_zombies() if SettingsManager.has_method("get_max_zombies") else max_active_zombies)
	var dynamic_max_zombies: int = roundi(lerpf(minf(50.0, float(cap_max)), float(cap_max), diff01))
	spawn_timer += delta
	if spawn_timer >= current_spawn_cooldown:
		spawn_timer = 0.0
		_spawn_single_zombie_ahead(diff, dynamic_max_zombies)

	var weather_seg: int = maxi(floori(float(maxi(current_chunk_index, 0)) / float(_chunks_per_bridge)), 0)
	var target_biome: int = _get_biome_for_index(current_chunk_index)
	var target_anomaly: int = _sanitize_anomaly_for_biome(_get_anomaly_for_segment(weather_seg), target_biome)

	if target_biome != _current_biome or target_anomaly != _active_anomaly:
		var prev_biome: int = _current_biome
		var biome_changed: bool = (target_biome != _current_biome)
		var anomaly_changed: bool = (target_anomaly != _active_anomaly)
		_current_biome = target_biome
		_active_anomaly = target_anomaly
		_anomaly_segment = weather_seg
		is_fog_red = (_active_anomaly == WeatherAnomaly.BLOOD_NIGHT)
		var tod_label := ""
		if biome_changed and prev_biome >= 0 and debug_tod_override < 0.0:
			var step_idx: int = _biome_rng.randi_range(1, _TOD_PRESETS.size() - 1)
			_tod_preset_idx = (_tod_preset_idx + step_idx) % _TOD_PRESETS.size()
			_target_time_of_day = float(_TOD_PRESETS[_tod_preset_idx]["tod"])
			_tod_blending = true
			tod_label = String(_TOD_PRESETS[_tod_preset_idx]["label"])
		_sync_anomaly_effects(anomaly_changed)
		if biome_changed and prev_biome >= 0 and (not anomaly_changed or _active_anomaly == WeatherAnomaly.NONE):
			if is_instance_valid(car) and car.has_method("show_hud_notice"):
				var notice_str := "СЕКТОР: %s // %s" % [_get_biome_title(target_biome), tod_label if not tod_label.is_empty() else "ТРАССА"]
				var notice_col := Color(0.62, 0.88, 1.0) if target_biome == ProceduralChunkScript.Biome.WINTER_ICE else Color(0.95, 0.68, 0.30)
				car.call("show_hud_notice", notice_str, notice_col, 3.2)

	_update_thunderstorm_fx(delta)
	_update_tornado_disaster(delta)
	_update_weather_audio()
	_update_dynamic_atmosphere(delta, false)

	if current_chunk_index == _last_checked_chunk:
		return

	_last_checked_chunk = current_chunk_index
	_ensure_chunks_for_index(current_chunk_index)

func _ensure_chunks_for_index(current_index: int) -> void:
	var min_index: int = current_index - maxi(chunks_behind, 1)
	var max_index: int = current_index + maxi(chunks_ahead, 2)

	for index in range(min_index, max_index + 1):
		if not _chunk_nodes.has(index):
			_spawn_chunk(index)

	var remove_list: Array[int] = []
	for key in _chunk_nodes.keys():
		var index := int(key)
		var chunk = _chunk_nodes[index]
		if not is_instance_valid(chunk) or index < min_index or index > max_index:
			remove_list.append(index)

	for index in remove_list:
		var chunk = _chunk_nodes[index]
		_despawn_chunk_safely(chunk)
		_chunk_nodes.erase(index)


func _despawn_chunk_safely(chunk: Variant) -> void:
	if not is_instance_valid(chunk):
		return
	var chunk_node := chunk as Node
	if chunk_node == null:
		return
	# Перед удалением чанка гасим и замораживаем все физические тела внутри него —
	# исключает катапультирование машин/бочек/барьеров вперёд в небо при смене пола
	_quiesce_chunk_physics(chunk_node)
	if chunk_node.get_parent():
		chunk_node.get_parent().remove_child(chunk_node)
	chunk_node.queue_free()


func _quiesce_chunk_physics(node: Node) -> void:
	if node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.set_physics_process(false)
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
		rb.sleeping = true
		rb.linear_velocity = Vector3.ZERO
		rb.angular_velocity = Vector3.ZERO
		rb.collision_layer = 0
		rb.collision_mask = 0
	elif node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child in node.get_children():
		_quiesce_chunk_physics(child)

func _is_bridge_index(index: int) -> bool:
	return index > 0 and (index % _chunks_per_bridge == 0)

func _get_chunk_center_z(index: int) -> float:
	if index <= 0:
		return _chunk_step * float(index)
	var how_many_bridges_passed: int = floori(float(index) / float(_chunks_per_bridge))
	if index % _chunks_per_bridge == 0:
		how_many_bridges_passed -= 1
	return _chunk_step * float(index) - float(how_many_bridges_passed) * bridge_shortfall_meters

func _spawn_chunk(index: int) -> void:
	var chunk: Node3D = null
	var is_bridge: bool = _is_bridge_index(index)
	var using_proc_chunk: bool = use_procedural_generation and not is_bridge

	if is_bridge:
		if bridge_scene != null:
			chunk = bridge_scene.instantiate() as Node3D
		else:
			push_error("Main: bridge_scene is null!")
			return
	elif using_proc_chunk:
		chunk = ProceduralChunkScript.new() as Node3D
		chunk.name = "ProceduralChunk_%d" % index
	else:
		var list_size: int = chunk_scenes_list.size()
		if list_size == 0:
			push_error("Main: chunk_scenes_list is empty!")
			return

		var abs_index: int = abs(index)
		var calculated_biome: int = posmod(floori(float(abs_index) / float(_chunks_per_bridge)), list_size)
		var scene_to_spawn: PackedScene = chunk_scenes_list[calculated_biome]

		if scene_to_spawn == null:
			for s in chunk_scenes_list:
				if s != null:
					scene_to_spawn = s
					break

		if scene_to_spawn != null:
			chunk = scene_to_spawn.instantiate() as Node3D
		else:
			push_error("Main: Не удалось найти валидную сцену чанка для спавна.")
			return

	if chunk == null:
		return

	var chunk_z_pos: float = _get_chunk_center_z(index)
	var chunk_origin: Vector3 = world_origin + _forward * chunk_z_pos
	var chunk_basis: Basis = Basis.looking_at(_forward, Vector3.UP)

	add_child(chunk)
	chunk.global_transform = Transform3D(chunk_basis, Vector3(chunk_origin.x, road_y, chunk_origin.z))

	var skip_landing_zone: bool = index > 1 and _is_bridge_index(index - 1)
	if using_proc_chunk:
		var biome_id: int = _get_biome_for_index(index)
		var skip_takeoff_zone: bool = index >= 0 and _is_bridge_index(index + 1)
		var bridges_before: int = maxi(floori(float(index) / float(_chunks_per_bridge)), 0)
		var normal_ordinal: int = index - bridges_before
		var barn_stride: int = maxi(roundi(barn_interval_meters / _chunk_step), 2)
		var spawn_barn_here: bool = index >= 2 and (normal_ordinal % barn_stride == 2)
		chunk.call(
			"setup_procedural",
			index,
			biome_id,
			_active_world_seed,
			chunk_width,
			chunk_length,
			chunk_thickness,
			road_y,
			skip_landing_zone,
			skip_takeoff_zone,
			spawn_barn_here,
			_chunks_per_bridge,
			bridge_shortfall_meters
		)
	elif chunk.has_method("configure_chunk"):
		chunk.call("configure_chunk", chunk_width, chunk_length, chunk_thickness, road_y, skip_landing_zone)

	if chunk.has_method("init_chunk_zombies"):
		chunk.call("init_chunk_zombies")

	_chunk_nodes[index] = chunk

func _spawn_single_zombie_ahead(diff: float = 0.0, dynamic_max: int = -1) -> void:
	var effective_max: int = dynamic_max if dynamic_max > 0 else max_active_zombies
	if ZombiePool.active_zombies.size() >= effective_max:
		return

	var diff01: float = clampf(diff, 0.0, 1.0)
	var safe_fog_distance: float = spawn_distance_ahead
	var base_ahead_dist: float = _distance_along_forward(car.global_position) + safe_fog_distance
	var target_chunk: int = _get_chunk_index(base_ahead_dist)
	var on_bridge: bool = _is_bridge_index(target_chunk)

	var cluster_size: int = 1
	if on_bridge:
		cluster_size = randi_range(1, 2)
		var bridge_start: float = _get_chunk_center_z(target_chunk) - _chunk_step * 0.5
		if base_ahead_dist - bridge_start > (_chunk_step - bridge_shortfall_meters - 45.0):
			return # Не спавним зомби в разрыве за трамплином моста
	elif diff < 0.14:
		cluster_size = randi_range(1, 2)
	else:
		var min_c: int = roundi(lerpf(1.0, 3.0, diff01))
		var max_c: int = roundi(lerpf(2.0, 5.0, diff01))
		cluster_size = randi_range(min_c, maxi(max_c, min_c))

	var z_biome: int = _get_biome_for_index(target_chunk)
	var x_half: float = 7.0 if on_bridge else (ProceduralChunkScript.get_playable_half_width(z_biome) - 5.0 if use_procedural_generation else road_spawn_width * 0.5)
	var run_chance: float = 1.0 if is_fog_red else lerpf(0.28, 0.78, diff01)

	for i in range(cluster_size):
		if ZombiePool.active_zombies.size() >= effective_max:
			break
		var spawn_z: float = car.global_position.z + _forward.z * safe_fog_distance + randf_range(-18.0, 18.0)
		var road_cx: float = 0.0
		if use_procedural_generation and not on_bridge:
			road_cx = ProceduralChunkScript.sample_road_center_x(spawn_z, _active_world_seed, _chunk_step, _chunks_per_bridge, bridge_shortfall_meters)
		var spawn_pos: Vector3 = Vector3(road_cx, road_y, spawn_z)
		if on_bridge:
			spawn_pos.x = randf_range(-x_half, x_half)
		elif randf() < 0.65:
			var car_lat: float = car.global_position.x - road_cx
			spawn_pos.x = road_cx + clampf(car_lat + randf_range(-20.0, 20.0), -x_half, x_half)
		else:
			spawn_pos.x = road_cx + randf_range(-x_half, x_half)
		if use_procedural_generation and not on_bridge:
			spawn_pos.y = road_y + ProceduralChunkScript.sample_terrain_height(spawn_pos.x, spawn_pos.z, z_biome, _active_world_seed)
		var z_node: Node3D = ZombiePool.spawn_zombie_at(spawn_pos, diff, randf() < run_chance)
		if z_node and z_biome == ProceduralChunkScript.Biome.BURNING_CITY and z_node.has_method("set_burning"):
			z_node.call("set_burning", true)

func advance_to_next_biome() -> void:
	pass

func get_biome_at_position(world_pos: Vector3) -> int:
	var dist := _distance_along_forward(world_pos)
	return _get_biome_for_index(_get_chunk_index(dist))


func get_surface_grip_profile(world_pos: Vector3) -> Dictionary:
	var dist := _distance_along_forward(world_pos)
	var idx := _get_chunk_index(dist)
	var b := _get_biome_for_index(idx)
	if b == ProceduralChunkScript.Biome.WINTER_ICE and not _is_bridge_index(idx):
		return {
			"biome": b,
			"is_ice": true,
			"grip_scale": 0.34,
			"brake_scale": 0.38,
			"yaw_assist_scale": 0.85,
		}
	return {
		"biome": b,
		"is_ice": false,
		"grip_scale": 1.0,
		"brake_scale": 1.0,
		"yaw_assist_scale": 1.0,
	}


func get_headlight_boost() -> float:
	return _headlight_boost


func _get_anomaly_for_segment(segment: int) -> int:
	if debug_weather_override >= 0 and debug_weather_override <= 4:
		return debug_weather_override
	if segment <= 0:
		return WeatherAnomaly.NONE
	var a_rng := RandomNumberGenerator.new()
	a_rng.seed = hash(Vector3i(_active_world_seed, segment, 4421))
	var r: float = a_rng.randf()
	if r < 0.22:
		return WeatherAnomaly.BLOOD_NIGHT
	if r < 0.42:
		return WeatherAnomaly.ACID_STORM
	if r < 0.60:
		return WeatherAnomaly.THUNDERSTORM
	if r < 0.76:
		return WeatherAnomaly.TORNADO_OUTBREAK
	return WeatherAnomaly.NONE


func _sanitize_anomaly_for_biome(anomaly: int, biome: int) -> int:
	if biome == ProceduralChunkScript.Biome.BURNING_CITY and anomaly == WeatherAnomaly.ACID_STORM and debug_weather_override != WeatherAnomaly.ACID_STORM:
		return WeatherAnomaly.NONE
	return anomaly


func _init_biome_sequence() -> void:
	_biome_rng.seed = hash(Vector2i(_active_world_seed, 9137))
	_biome_order.clear()
	_biome_order.append(ProceduralChunkScript.Biome.WASTELAND)
	var rest: Array[int] = [
		ProceduralChunkScript.Biome.WINTER_ICE,
		ProceduralChunkScript.Biome.RUINED_CITY,
		ProceduralChunkScript.Biome.DARK_FOREST,
		ProceduralChunkScript.Biome.TOXIC_MARSH,
		ProceduralChunkScript.Biome.SCORCHED_CANYON,
		ProceduralChunkScript.Biome.BURNING_CITY,
		ProceduralChunkScript.Biome.BURNT_FOREST,
		ProceduralChunkScript.Biome.OVERGROWN_HIGHWAY,
	]
	for i in range(rest.size() - 1, 0, -1):
		var j := _biome_rng.randi_range(0, i)
		var tmp := rest[i]
		rest[i] = rest[j]
		rest[j] = tmp
	for b_id in rest:
		_biome_order.append(b_id)


func _get_biome_for_index(index: int) -> int:
	if debug_start_biome >= 0 and debug_start_biome <= 8:
		return debug_start_biome
	if index < 0:
		return ProceduralChunkScript.Biome.WASTELAND
	if _biome_order.is_empty():
		_init_biome_sequence()
	var segment: int = floori(float(index) / float(_chunks_per_bridge))
	while _biome_order.size() <= segment:
		var bag: Array[int] = [0, 1, 2, 3, 4, 5, 6, 7, 8]
		for i in range(bag.size() - 1, 0, -1):
			var j := _biome_rng.randi_range(0, i)
			var tmp := bag[i]
			bag[i] = bag[j]
			bag[j] = tmp
		if not _biome_order.is_empty() and bag[0] == _biome_order.back():
			var swap_idx := 1 + _biome_rng.randi_range(0, bag.size() - 2)
			var t2 := bag[0]
			bag[0] = bag[swap_idx]
			bag[swap_idx] = t2
		for b_id in bag:
			_biome_order.append(b_id)
	return _biome_order[segment]

func _update_ash_atmosphere(anomaly: int) -> void:
	if _ash_particles == null or _ash_mat == null:
		return
	var is_winter: bool = (_current_biome == ProceduralChunkScript.Biome.WINTER_ICE)
	var is_toxic: bool = (_current_biome == ProceduralChunkScript.Biome.TOXIC_MARSH)
	var is_scorched: bool = (_current_biome == ProceduralChunkScript.Biome.SCORCHED_CANYON)
	var is_burning_city: bool = (_current_biome == ProceduralChunkScript.Biome.BURNING_CITY)
	var is_burnt_forest: bool = (_current_biome == ProceduralChunkScript.Biome.BURNT_FOREST)
	var is_overgrown: bool = (_current_biome == ProceduralChunkScript.Biome.OVERGROWN_HIGHWAY)
	if anomaly == WeatherAnomaly.ACID_STORM:
		_ash_particles.amount = 220
		_ash_particles.direction = Vector3(-0.24, -0.88, -0.38).normalized()
		_ash_particles.spread = 18.0
		_ash_particles.gravity = Vector3(0.0, -3.5, 0.0)
		_ash_particles.initial_velocity_min = 9.0
		_ash_particles.initial_velocity_max = 15.0
		_ash_particles.scale_amount_min = 0.75
		_ash_particles.scale_amount_max = 1.65
		_ash_particles.color = Color(0.55, 1.0, 0.24, 0.65)
		_ash_mat.emission_enabled = true
		_ash_mat.emission = Color(0.45, 0.96, 0.18, 1.0)
		_ash_mat.emission_energy_multiplier = 1.4
	elif anomaly == WeatherAnomaly.BLOOD_NIGHT:
		_ash_particles.amount = 185
		_ash_particles.direction = Vector3(-0.30, 0.14, -0.86).normalized()
		_ash_particles.spread = 34.0
		_ash_particles.gravity = Vector3(0.0, 0.12, 0.0)
		_ash_particles.initial_velocity_min = 2.0
		_ash_particles.initial_velocity_max = 5.4
		_ash_particles.scale_amount_min = 0.75
		_ash_particles.scale_amount_max = 1.65
		_ash_particles.color = Color(1.0, 0.22, 0.14, 0.90)
		_ash_mat.emission_enabled = true
		_ash_mat.emission = Color(1.0, 0.16, 0.08, 1.0)
		_ash_mat.emission_energy_multiplier = 3.2
	elif anomaly == WeatherAnomaly.TORNADO_OUTBREAK:
		_ash_particles.amount = 240
		_ash_particles.direction = Vector3(-0.78, 0.18, -0.60).normalized()
		_ash_particles.spread = 46.0
		_ash_particles.gravity = Vector3(0.0, 0.25, 0.0)
		_ash_particles.initial_velocity_min = 6.0
		_ash_particles.initial_velocity_max = 14.0
		_ash_particles.scale_amount_min = 0.75
		_ash_particles.scale_amount_max = 1.75
		_ash_particles.color = Color(0.58, 0.50, 0.40, 0.62)
		_ash_mat.emission_enabled = false
	elif anomaly == WeatherAnomaly.THUNDERSTORM:
		_ash_particles.amount = 160
		_ash_particles.direction = Vector3(-0.42, -0.58, -0.70).normalized()
		_ash_particles.spread = 28.0
		_ash_particles.gravity = Vector3(0.0, -2.5, 0.0)
		_ash_particles.initial_velocity_min = 5.0
		_ash_particles.initial_velocity_max = 10.0
		_ash_particles.scale_amount_min = 0.60
		_ash_particles.scale_amount_max = 1.25
		_ash_particles.color = Color(0.68, 0.76, 0.88, 0.45)
		_ash_mat.emission_enabled = false
	elif is_burning_city:
		_ash_particles.amount = 210
		_ash_particles.direction = Vector3(-0.22, 0.42, -0.82).normalized()
		_ash_particles.spread = 36.0
		_ash_particles.gravity = Vector3(0.0, 0.85, 0.0)
		_ash_particles.initial_velocity_min = 2.4
		_ash_particles.initial_velocity_max = 6.2
		_ash_particles.scale_amount_min = 0.65
		_ash_particles.scale_amount_max = 1.55
		_ash_particles.color = Color(1.0, 0.44, 0.12, 0.92)
		_ash_mat.emission_enabled = true
		_ash_mat.emission = Color(1.0, 0.36, 0.08, 1.0)
		_ash_mat.emission_energy_multiplier = 3.4
	elif is_burnt_forest:
		_ash_particles.amount = 175
		_ash_particles.direction = Vector3(-0.28, 0.22, -0.86).normalized()
		_ash_particles.spread = 38.0
		_ash_particles.gravity = Vector3(0.0, 0.18, 0.0)
		_ash_particles.initial_velocity_min = 1.4
		_ash_particles.initial_velocity_max = 4.2
		_ash_particles.scale_amount_min = 0.60
		_ash_particles.scale_amount_max = 1.40
		_ash_particles.color = Color(0.95, 0.36, 0.10, 0.76)
		_ash_mat.emission_enabled = true
		_ash_mat.emission = Color(1.0, 0.30, 0.06, 1.0)
		_ash_mat.emission_energy_multiplier = 2.0
	elif is_overgrown:
		_ash_particles.amount = 120
		_ash_particles.direction = Vector3(-0.18, 0.05, -0.92).normalized()
		_ash_particles.spread = 40.0
		_ash_particles.gravity = Vector3(0.0, -0.10, 0.0)
		_ash_particles.initial_velocity_min = 0.9
		_ash_particles.initial_velocity_max = 2.8
		_ash_particles.scale_amount_min = 0.55
		_ash_particles.scale_amount_max = 1.20
		_ash_particles.color = Color(0.84, 0.92, 0.56, 0.45)
		_ash_mat.emission_enabled = false
	elif is_winter:
		_ash_particles.amount = 220
		_ash_particles.direction = Vector3(-0.48, -0.52, -0.70).normalized()
		_ash_particles.spread = 38.0
		_ash_particles.gravity = Vector3(0.0, -0.85, 0.0)
		_ash_particles.initial_velocity_min = 3.2
		_ash_particles.initial_velocity_max = 7.4
		_ash_particles.scale_amount_min = 0.85
		_ash_particles.scale_amount_max = 1.85
		_ash_particles.color = Color(0.92, 0.96, 1.0, 0.78)
		_ash_mat.emission_enabled = false
	elif is_toxic:
		_ash_particles.amount = 150
		_ash_particles.direction = Vector3(-0.20, 0.18, -0.85).normalized()
		_ash_particles.spread = 42.0
		_ash_particles.gravity = Vector3(0.0, 0.12, 0.0)
		_ash_particles.initial_velocity_min = 0.9
		_ash_particles.initial_velocity_max = 2.6
		_ash_particles.scale_amount_min = 0.75
		_ash_particles.scale_amount_max = 1.65
		_ash_particles.color = Color(0.68, 0.88, 0.36, 0.65)
		_ash_mat.emission_enabled = false
	elif is_scorched:
		_ash_particles.amount = 145
		_ash_particles.direction = Vector3(-0.32, 0.16, -0.86).normalized()
		_ash_particles.spread = 32.0
		_ash_particles.gravity = Vector3(0.0, 0.25, 0.0)
		_ash_particles.initial_velocity_min = 1.8
		_ash_particles.initial_velocity_max = 4.6
		_ash_particles.scale_amount_min = 0.65
		_ash_particles.scale_amount_max = 1.48
		_ash_particles.color = Color(1.0, 0.50, 0.16, 0.88)
		_ash_mat.emission_enabled = true
		_ash_mat.emission = Color(1.0, 0.40, 0.12, 1.0)
		_ash_mat.emission_energy_multiplier = 2.4
	else:
		_ash_particles.amount = 110
		_ash_particles.direction = Vector3(-0.32, -0.38, -0.86)
		_ash_particles.spread = 28.0
		_ash_particles.gravity = Vector3(0.0, -0.35, 0.0)
		_ash_particles.initial_velocity_min = 1.6
		_ash_particles.initial_velocity_max = 4.2
		_ash_particles.scale_amount_min = 0.65
		_ash_particles.scale_amount_max = 1.45
		_ash_particles.color = Color(0.76, 0.74, 0.72, 0.42)
		_ash_mat.emission_enabled = false

func _setup_ash_emitter() -> void:
	if _ash_particles != null:
		return
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.18)
	_ash_mat = StandardMaterial3D.new()
	_ash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_ash_mat.vertex_color_use_as_albedo = true
	_ash_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_ash_mat.no_depth_test = false
	var vfx_node: Node = get_node_or_null("/root/CarVFX")
	if vfx_node:
		var ash_tex: Variant = vfx_node.get("tex_ash_flake")
		if ash_tex == null:
			ash_tex = vfx_node.get("tex_smoke_puff")
		if ash_tex == null:
			ash_tex = vfx_node.get("tex_smoke")
		if ash_tex is Texture2D:
			_ash_mat.albedo_texture = ash_tex as Texture2D
	qm.material = _ash_mat

	_ash_particles = CPUParticles3D.new()
	_ash_particles.name = "AtmosphereAshParticles"
	_ash_particles.mesh = qm
	_ash_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ash_particles.amount = 110
	_ash_particles.lifetime = 2.4
	_ash_particles.local_coords = false
	_ash_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_ash_particles.emission_box_extents = Vector3(18.0, 5.5, 24.0)
	_ash_particles.direction = Vector3(-0.32, -0.38, -0.86)
	_ash_particles.spread = 28.0
	_ash_particles.gravity = Vector3(0.0, -0.35, 0.0)
	_ash_particles.initial_velocity_min = 1.6
	_ash_particles.initial_velocity_max = 4.2
	_ash_particles.scale_amount_min = 0.65
	_ash_particles.scale_amount_max = 1.45
	add_child(_ash_particles)
	_update_ash_atmosphere(_active_anomaly)

func _setup_rain_emitter() -> void:
	if _rain_particles != null:
		return
	var qm := QuadMesh.new()
	qm.size = Vector2(0.055, 1.35)
	_rain_mat = StandardMaterial3D.new()
	_rain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rain_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rain_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_rain_mat.billboard_keep_scale = true
	_rain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rain_mat.vertex_color_use_as_albedo = true
	_rain_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_rain_mat.no_depth_test = false
	var vfx_node: Node = get_node_or_null("/root/CarVFX")
	if vfx_node:
		var rain_tex: Variant = vfx_node.get("tex_rain_streak")
		if rain_tex is Texture2D:
			_rain_mat.albedo_texture = rain_tex as Texture2D
	qm.material = _rain_mat

	_rain_particles = CPUParticles3D.new()
	_rain_particles.name = "AtmosphereRainParticles"
	_rain_particles.mesh = qm
	_rain_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_particles.amount = 340
	_rain_particles.lifetime = 0.75
	_rain_particles.local_coords = false
	_rain_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain_particles.emission_box_extents = Vector3(24.0, 6.0, 32.0)
	_rain_particles.direction = Vector3(-0.14, -1.0, -0.22).normalized()
	_rain_particles.spread = 6.0
	_rain_particles.gravity = Vector3(0.0, -9.8, 0.0)
	_rain_particles.initial_velocity_min = 24.0
	_rain_particles.initial_velocity_max = 32.0
	_rain_particles.emitting = false
	_rain_particles.visible = false
	add_child(_rain_particles)
	_update_rain_atmosphere()

func _update_rain_atmosphere() -> void:
	if _rain_particles == null or _rain_mat == null:
		return
	var is_thunder: bool = (_active_anomaly == WeatherAnomaly.THUNDERSTORM)
	var is_acid_storm: bool = (_active_anomaly == WeatherAnomaly.ACID_STORM)
	var is_toxic_biome: bool = (_current_biome == ProceduralChunkScript.Biome.TOXIC_MARSH)
	if is_thunder:
		_rain_particles.amount = 340
		_rain_particles.color = Color(0.74, 0.84, 0.98, 0.66)
		_rain_mat.emission_enabled = false
		_rain_particles.visible = true
		_rain_particles.emitting = true
	elif is_acid_storm:
		_rain_particles.amount = 340
		_rain_particles.color = Color(0.56, 1.0, 0.28, 0.76)
		_rain_mat.emission_enabled = true
		_rain_mat.emission = Color(0.45, 0.98, 0.20, 1.0)
		_rain_mat.emission_energy_multiplier = 1.4
		_rain_particles.visible = true
		_rain_particles.emitting = true
	elif is_toxic_biome:
		_rain_particles.amount = 220
		_rain_particles.color = Color(0.54, 0.95, 0.30, 0.56)
		_rain_mat.emission_enabled = true
		_rain_mat.emission = Color(0.40, 0.86, 0.18, 1.0)
		_rain_mat.emission_energy_multiplier = 1.0
		_rain_particles.visible = true
		_rain_particles.emitting = true
	else:
		_rain_mat.emission_enabled = false
		_rain_particles.emitting = false
		_rain_particles.visible = false

func _update_thunderstorm_fx(delta: float) -> void:
	_lightning_flash = maxf(_lightning_flash - delta * 3.8, 0.0)
	if _lightning_bolt_timer > 0.0:
		_lightning_bolt_timer -= delta
		if _lightning_bolt_timer <= 0.0 and is_instance_valid(_lightning_bolt):
			_lightning_bolt.visible = false
	if _thunder_delay_timer > 0.0:
		_thunder_delay_timer -= delta
		if _thunder_delay_timer <= 0.0:
			_thunder_delay_timer = -1.0
			var sm: Node = get_node_or_null("/root/SoundManager")
			if sm and sm.has_method("play_thunder"):
				sm.call("play_thunder", -2.2)

	if _active_anomaly != WeatherAnomaly.THUNDERSTORM:
		return

	_lightning_timer -= delta
	if _lightning_timer <= 0.0:
		_lightning_timer = randf_range(3.0, 6.8)
		_trigger_lightning_strike()
		_lightning_flash = 1.0
		_lightning_bolt_timer = 0.22
		_thunder_delay_timer = randf_range(0.18, 0.52)

func _trigger_lightning_strike() -> void:
	if not is_instance_valid(car):
		return
	if _lightning_bolt == null:
		_lightning_bolt = MeshInstance3D.new()
		_lightning_bolt.name = "ThunderLightningBolt"
		_lightning_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lightning_bolt.visibility_range_end = 360.0
		var b_mat := StandardMaterial3D.new()
		b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		b_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		b_mat.albedo_color = Color(0.86, 0.94, 1.0, 0.96)
		_lightning_bolt.material_override = b_mat
		add_child(_lightning_bolt)

	var side_vec := Vector3(-_forward.z, 0.0, _forward.x).normalized()
	var strike_pos: Vector3 = car.global_position + _forward * randf_range(85.0, 155.0) + side_vec * randf_range(-52.0, 52.0)
	strike_pos.y = road_y
	_lightning_bolt.global_position = strike_pos
	_lightning_bolt.basis = Basis.looking_at(-_forward, Vector3.UP)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev_pt := Vector3(randf_range(-6.0, 6.0), 140.0, 0.0)
	var steps := 16
	for s_i in range(steps):
		var t_next := float(s_i + 1) / float(steps)
		var next_y: float = lerpf(140.0, 0.0, t_next)
		var next_x: float = clampf(prev_pt.x + randf_range(-7.5, 7.5), -22.0, 22.0)
		var next_pt := Vector3(next_x, next_y, 0.0)
		var hw: float = lerpf(0.55, 0.16, t_next)
		var v0 := prev_pt + Vector3(-hw, 0.0, 0.0)
		var v1 := prev_pt + Vector3(hw, 0.0, 0.0)
		var v2 := next_pt + Vector3(hw, 0.0, 0.0)
		var v3 := next_pt + Vector3(-hw, 0.0, 0.0)
		st.add_vertex(v0); st.add_vertex(v1); st.add_vertex(v2)
		st.add_vertex(v0); st.add_vertex(v2); st.add_vertex(v3)
		if s_i == 3 or s_i == 7 or s_i == 11:
			var side_s := -1.0 if (s_i % 2 == 1) else 1.0
			var f_mid := next_pt + Vector3(side_s * randf_range(5.0, 10.5), -11.0, 0.0)
			var f_end := f_mid + Vector3(side_s * randf_range(4.0, 9.5) + randf_range(-3.0, 3.0), -13.0, 0.0)
			var fhw := 0.24
			var fmw := 0.13
			var few := 0.06
			st.add_vertex(next_pt + Vector3(-fhw, 0.0, 0.0))
			st.add_vertex(next_pt + Vector3(fhw, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(fmw, 0.0, 0.0))
			st.add_vertex(next_pt + Vector3(-fhw, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(fmw, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(-fmw, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(-fmw, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(fmw, 0.0, 0.0))
			st.add_vertex(f_end + Vector3(few, 0.0, 0.0))
			st.add_vertex(f_mid + Vector3(-fmw, 0.0, 0.0))
			st.add_vertex(f_end + Vector3(few, 0.0, 0.0))
			st.add_vertex(f_end + Vector3(-few, 0.0, 0.0))
		prev_pt = next_pt
	st.generate_normals()
	_lightning_bolt.mesh = st.commit()
	_lightning_bolt.visible = true

func _update_tornado_disaster(_delta: float) -> void:
	if _active_anomaly != WeatherAnomaly.TORNADO_OUTBREAK:
		if is_instance_valid(_tornado_node):
			_tornado_node.queue_free()
			_tornado_node = null
		return
	if not is_instance_valid(car):
		return

	var car_dist: float = _distance_along_forward(car.global_position)
	var side_vec := Vector3(-_forward.z, 0.0, _forward.x).normalized()

	if not is_instance_valid(_tornado_node):
		var t_node := TornadoVortexScript.new() as Node3D
		if t_node == null:
			return
		t_node.name = "ActiveTornadoVortex"
		if t_node.has_method("setup_tornado"):
			t_node.call("setup_tornado", _forward, _active_world_seed, _chunk_step, _chunks_per_bridge, bridge_shortfall_meters, randf() * TAU)
		add_child(t_node)
		var spawn_d: float = car_dist + 125.0
		while _is_bridge_index(_get_chunk_index(spawn_d)):
			spawn_d += 120.0
		var tgt := world_origin + _forward * spawn_d
		var cx: float = ProceduralChunkScript.sample_road_center_x(tgt.z, _active_world_seed, _chunk_step, _chunks_per_bridge, bridge_shortfall_meters)
		t_node.global_position = Vector3(cx, road_y, tgt.z) + side_vec * randf_range(-14.0, 14.0)
		_tornado_node = t_node
	else:
		var t_dist: float = _distance_along_forward(_tornado_node.global_position)
		if t_dist - car_dist < -85.0:
			var next_d: float = car_dist + 155.0
			while _is_bridge_index(_get_chunk_index(next_d)):
				next_d += 120.0
			var tgt := world_origin + _forward * next_d
			var cx: float = ProceduralChunkScript.sample_road_center_x(tgt.z, _active_world_seed, _chunk_step, _chunks_per_bridge, bridge_shortfall_meters)
			_tornado_node.global_position = Vector3(cx, road_y, tgt.z) + side_vec * randf_range(-16.0, 16.0)

func _update_weather_audio() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm == null or not sm.has_method("set_weather_audio"):
		return
	var rain_lvl: float = 0.0
	if _active_anomaly == WeatherAnomaly.THUNDERSTORM:
		rain_lvl = 1.0
	elif _active_anomaly == WeatherAnomaly.ACID_STORM:
		rain_lvl = 0.85
	elif _current_biome == ProceduralChunkScript.Biome.TOXIC_MARSH:
		rain_lvl = 0.55

	var tornado_lvl: float = 0.0
	if _active_anomaly == WeatherAnomaly.TORNADO_OUTBREAK:
		if is_instance_valid(car) and bool(car.get("destroyed")):
			tornado_lvl = 0.0
		elif is_instance_valid(_tornado_node) and is_instance_valid(car):
			var d: float = _tornado_node.global_position.distance_to(car.global_position)
			tornado_lvl = clampf(1.0 - (d - 18.0) / 160.0, 0.25, 1.0)
		else:
			tornado_lvl = 0.35
	sm.call("set_weather_audio", rain_lvl, tornado_lvl)

func _on_quality_changed(_new_quality: int) -> void:
	if _current_biome < 0:
		_current_biome = ProceduralChunkScript.Biome.WASTELAND
	if world_environment and world_environment.environment:
		_base_fog_density = 1.0
		_base_fog_begin = clampf(world_environment.environment.fog_depth_begin, 8.0, 26.0)
		_base_fog_end = clampf(world_environment.environment.fog_depth_end, 105.0, 190.0)
	_update_dynamic_atmosphere(0.0, true)

func _sync_anomaly_effects(show_banner: bool) -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_biome_ambience"):
		var sound_biome: int = 4 if _active_anomaly == WeatherAnomaly.ACID_STORM else _current_biome
		sm.call("set_biome_ambience", sound_biome, _active_anomaly == WeatherAnomaly.BLOOD_NIGHT)
	_update_ash_atmosphere(_active_anomaly)
	_update_rain_atmosphere()
	if show_banner and is_instance_valid(car) and car.has_method("show_hud_notice"):
		if _active_anomaly == WeatherAnomaly.BLOOD_NIGHT:
			car.call("show_hud_notice", "АНОМАЛИЯ // КРОВАВАЯ НОЧЬ — ОРДА В БЕШЕНСТВЕ", Color(1.0, 0.24, 0.20), 4.0)
		elif _active_anomaly == WeatherAnomaly.ACID_STORM:
			car.call("show_hud_notice", "АНОМАЛИЯ // КИСЛОТНЫЙ ШТОРМ — КИСЛОТНЫЙ ЛИВЕНЬ", Color(0.62, 1.0, 0.24), 4.0)
		elif _active_anomaly == WeatherAnomaly.THUNDERSTORM:
			car.call("show_hud_notice", "АНОМАЛИЯ // ГРОЗОВОЙ ШТОРМ — ЛИВЕНЬ И МОЛНИИ", Color(0.58, 0.80, 1.0), 4.0)
		elif _active_anomaly == WeatherAnomaly.TORNADO_OUTBREAK:
			car.call("show_hud_notice", "АНОМАЛИЯ // СМЕРЧ НА ТРАССЕ — ОБЪЕЗЖАЙ ВОРОНКУ", Color(0.98, 0.72, 0.34), 4.0)

func _get_biome_title(biome_id: int) -> String:
	match biome_id:
		ProceduralChunkScript.Biome.WASTELAND:
			return "ПУСТОШЬ"
		ProceduralChunkScript.Biome.RUINED_CITY:
			return "МЁРТВЫЙ ГОРОД"
		ProceduralChunkScript.Biome.DARK_FOREST:
			return "МРАЧНЫЙ ЛЕС"
		ProceduralChunkScript.Biome.WINTER_ICE:
			return "ЛЕДЯНАЯ ТРАССА"
		ProceduralChunkScript.Biome.TOXIC_MARSH:
			return "ТОКСИЧНАЯ ЗОНА"
		ProceduralChunkScript.Biome.SCORCHED_CANYON:
			return "ВЫЖЖЕННЫЙ КАНЬОН"
		ProceduralChunkScript.Biome.BURNING_CITY:
			return "ПЫЛАЮЩИЙ ГОРОД"
		ProceduralChunkScript.Biome.BURNT_FOREST:
			return "СГОРЕВШИЙ ЛЕС"
		ProceduralChunkScript.Biome.OVERGROWN_HIGHWAY:
			return "ЗАРОСШАЯ ТРАССА"
		_:
			return "СЕКТОР"

func _get_biome_atmosphere(biome_id: int, red_zone: bool) -> Dictionary:
	var fog_color := Color(0.60, 0.59, 0.56)
	var fog_energy := 0.82
	var sky_top := Color(0.36, 0.45, 0.56)
	var sky_horizon := Color(0.62, 0.61, 0.58)
	var ground_horizon := Color(0.50, 0.48, 0.45)
	var ground_bottom := Color(0.24, 0.23, 0.21)
	var cloud_lit := Color(0.88, 0.86, 0.82)
	var cloud_shadow := Color(0.42, 0.46, 0.52)
	var sun_glow := Color(1.0, 0.88, 0.72)
	var cloud_coverage := 0.54
	var ambient_color := Color(0.54, 0.54, 0.55)
	var light_color := Color(0.98, 0.95, 0.90)

	match biome_id:
		ProceduralChunkScript.Biome.RUINED_CITY:
			fog_color = Color(0.53, 0.56, 0.61)
			fog_energy = 0.80
			sky_top = Color(0.30, 0.37, 0.46)
			sky_horizon = Color(0.54, 0.57, 0.62)
			ground_horizon = Color(0.42, 0.45, 0.49)
			ground_bottom = Color(0.20, 0.22, 0.25)
			cloud_lit = Color(0.76, 0.79, 0.84)
			cloud_shadow = Color(0.34, 0.38, 0.45)
			sun_glow = Color(0.94, 0.88, 0.82)
			cloud_coverage = 0.64
			ambient_color = Color(0.49, 0.52, 0.57)
			light_color = Color(0.93, 0.95, 0.98)
		ProceduralChunkScript.Biome.DARK_FOREST:
			fog_color = Color(0.44, 0.52, 0.53)
			fog_energy = 0.78
			sky_top = Color(0.24, 0.34, 0.38)
			sky_horizon = Color(0.45, 0.53, 0.54)
			ground_horizon = Color(0.32, 0.39, 0.38)
			ground_bottom = Color(0.16, 0.20, 0.19)
			cloud_lit = Color(0.68, 0.76, 0.76)
			cloud_shadow = Color(0.28, 0.34, 0.37)
			sun_glow = Color(0.86, 0.92, 0.88)
			cloud_coverage = 0.70
			ambient_color = Color(0.42, 0.49, 0.48)
			light_color = Color(0.90, 0.95, 0.94)
		ProceduralChunkScript.Biome.WINTER_ICE:
			fog_color = Color(0.66, 0.73, 0.80)
			fog_energy = 0.88
			sky_top = Color(0.36, 0.46, 0.58)
			sky_horizon = Color(0.68, 0.75, 0.82)
			ground_horizon = Color(0.56, 0.63, 0.70)
			ground_bottom = Color(0.28, 0.33, 0.39)
			cloud_lit = Color(0.92, 0.95, 0.99)
			cloud_shadow = Color(0.46, 0.53, 0.62)
			sun_glow = Color(0.90, 0.95, 1.0)
			cloud_coverage = 0.78
			ambient_color = Color(0.56, 0.63, 0.71)
			light_color = Color(0.92, 0.96, 1.0)
		ProceduralChunkScript.Biome.TOXIC_MARSH:
			fog_color = Color(0.42, 0.50, 0.36)
			fog_energy = 0.84
			sky_top = Color(0.24, 0.32, 0.22)
			sky_horizon = Color(0.45, 0.52, 0.38)
			ground_horizon = Color(0.32, 0.38, 0.26)
			ground_bottom = Color(0.16, 0.20, 0.14)
			cloud_lit = Color(0.68, 0.74, 0.56)
			cloud_shadow = Color(0.28, 0.34, 0.25)
			sun_glow = Color(0.84, 0.92, 0.54)
			cloud_coverage = 0.74
			ambient_color = Color(0.44, 0.52, 0.36)
			light_color = Color(0.88, 0.96, 0.78)
		ProceduralChunkScript.Biome.SCORCHED_CANYON:
			fog_color = Color(0.58, 0.42, 0.34)
			fog_energy = 0.86
			sky_top = Color(0.36, 0.24, 0.20)
			sky_horizon = Color(0.62, 0.44, 0.34)
			ground_horizon = Color(0.44, 0.30, 0.24)
			ground_bottom = Color(0.22, 0.14, 0.12)
			cloud_lit = Color(0.88, 0.66, 0.50)
			cloud_shadow = Color(0.38, 0.24, 0.20)
			sun_glow = Color(1.0, 0.68, 0.38)
			cloud_coverage = 0.62
			ambient_color = Color(0.56, 0.42, 0.34)
			light_color = Color(1.0, 0.84, 0.72)
		ProceduralChunkScript.Biome.BURNING_CITY:
			fog_color = Color(0.46, 0.24, 0.16)
			fog_energy = 0.82
			sky_top = Color(0.16, 0.09, 0.08)
			sky_horizon = Color(0.52, 0.25, 0.15)
			ground_horizon = Color(0.34, 0.17, 0.11)
			ground_bottom = Color(0.12, 0.07, 0.05)
			cloud_lit = Color(0.82, 0.40, 0.20)
			cloud_shadow = Color(0.20, 0.11, 0.09)
			sun_glow = Color(1.0, 0.50, 0.18)
			cloud_coverage = 0.76
			ambient_color = Color(0.44, 0.26, 0.19)
			light_color = Color(1.0, 0.72, 0.48)
		ProceduralChunkScript.Biome.BURNT_FOREST:
			fog_color = Color(0.34, 0.30, 0.27)
			fog_energy = 0.76
			sky_top = Color(0.16, 0.15, 0.15)
			sky_horizon = Color(0.36, 0.31, 0.27)
			ground_horizon = Color(0.24, 0.20, 0.18)
			ground_bottom = Color(0.10, 0.09, 0.08)
			cloud_lit = Color(0.56, 0.46, 0.40)
			cloud_shadow = Color(0.18, 0.16, 0.15)
			sun_glow = Color(0.95, 0.58, 0.34)
			cloud_coverage = 0.72
			ambient_color = Color(0.36, 0.31, 0.28)
			light_color = Color(0.90, 0.78, 0.68)
		ProceduralChunkScript.Biome.OVERGROWN_HIGHWAY:
			fog_color = Color(0.46, 0.54, 0.44)
			fog_energy = 0.84
			sky_top = Color(0.28, 0.38, 0.36)
			sky_horizon = Color(0.50, 0.58, 0.48)
			ground_horizon = Color(0.35, 0.43, 0.33)
			ground_bottom = Color(0.16, 0.21, 0.16)
			cloud_lit = Color(0.78, 0.84, 0.74)
			cloud_shadow = Color(0.34, 0.40, 0.36)
			sun_glow = Color(0.96, 0.94, 0.76)
			cloud_coverage = 0.64
			ambient_color = Color(0.46, 0.54, 0.42)
			light_color = Color(0.94, 0.96, 0.86)

	if red_zone:
		fog_color = fog_color.lerp(Color(0.58, 0.24, 0.22), 0.62)
		fog_energy = maxf(fog_energy * 0.88, 0.68)
		sky_top = sky_top.lerp(Color(0.42, 0.16, 0.16), 0.48)
		sky_horizon = sky_horizon.lerp(Color(0.58, 0.27, 0.24), 0.55)
		ground_horizon = ground_horizon.lerp(Color(0.40, 0.20, 0.18), 0.55)
		cloud_lit = cloud_lit.lerp(Color(0.86, 0.42, 0.35), 0.55)
		cloud_shadow = cloud_shadow.lerp(Color(0.38, 0.16, 0.16), 0.55)
		sun_glow = sun_glow.lerp(Color(1.0, 0.45, 0.32), 0.60)
		cloud_coverage = minf(cloud_coverage + 0.12, 0.85)
		light_color = light_color.lerp(Color(0.96, 0.78, 0.72), 0.35)

	return {
		"fog_color": fog_color,
		"fog_energy": fog_energy,
		"sky_top": sky_top,
		"sky_horizon": sky_horizon,
		"ground_horizon": ground_horizon,
		"ground_bottom": ground_bottom,
		"cloud_lit": cloud_lit,
		"cloud_shadow": cloud_shadow,
		"sun_glow": sun_glow,
		"cloud_coverage": cloud_coverage,
		"ambient_color": ambient_color,
		"light_color": light_color,
	}

func _update_biome_atmosphere(_biome_id: int, _red_zone: bool, immediate: bool = false) -> void:
	_update_dynamic_atmosphere(0.0, immediate)


func _update_dynamic_atmosphere(delta: float, immediate: bool = false) -> void:
	if world_environment == null or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment
	env.fog_enabled = SettingsManager.is_fog_allowed()

	if debug_tod_override >= 0.0:
		_time_of_day = fposmod(debug_tod_override, 1.0)
		_tod_blending = false
	elif not immediate:
		if _tod_blending:
			var diff_tod: float = fposmod(_target_time_of_day - _time_of_day + 1.5, 1.0) - 0.5
			var step_tod: float = delta * 0.085
			if absf(diff_tod) <= step_tod:
				_time_of_day = _target_time_of_day
				_tod_blending = false
			else:
				_time_of_day = fposmod(_time_of_day + signf(diff_tod) * step_tod, 1.0)

	var target_blood: float = 1.0 if _active_anomaly == WeatherAnomaly.BLOOD_NIGHT else 0.0
	var target_acid: float = 1.0 if _active_anomaly == WeatherAnomaly.ACID_STORM else 0.0
	var target_storm: float = 1.0 if _active_anomaly == WeatherAnomaly.THUNDERSTORM else 0.0
	var target_tornado: float = 1.0 if _active_anomaly == WeatherAnomaly.TORNADO_OUTBREAK else 0.0
	var is_toxic_biome: bool = (_current_biome == ProceduralChunkScript.Biome.TOXIC_MARSH)
	var target_acid_fog: float = maxf(target_acid, 0.68 if is_toxic_biome else 0.0)
	var force_snap: bool = immediate or (debug_weather_override >= 0) or (debug_tod_override >= 0.0)
	var k_an: float = 1.0 if force_snap else clampf(delta * 0.75, 0.0, 1.0)
	_blood_blend = lerpf(_blood_blend, target_blood, k_an)
	_acid_blend = lerpf(_acid_blend, target_acid, k_an)
	_acid_fog_blend = lerpf(_acid_fog_blend, target_acid_fog, k_an)
	_storm_blend = lerpf(_storm_blend, target_storm, k_an)
	_tornado_blend = lerpf(_tornado_blend, target_tornado, k_an)

	var target_prof: Dictionary = _get_biome_atmosphere(maxi(_current_biome, 0), false)
	if _biome_cur_profile.is_empty() or force_snap:
		_biome_cur_profile = target_prof.duplicate()
	else:
		var k_b: float = clampf(delta * 0.85, 0.0, 1.0)
		for k_var: Variant in target_prof.keys():
			var k: String = String(k_var)
			var dst: Variant = target_prof[k]
			var src: Variant = _biome_cur_profile.get(k, dst)
			if dst is Color and src is Color:
				_biome_cur_profile[k] = (src as Color).lerp(dst as Color, k_b)
			else:
				_biome_cur_profile[k] = lerpf(float(src), float(dst), k_b)

	var sun_sin: float = sin(_time_of_day * TAU)
	var raw_night: float = clampf((-sun_sin + 0.12) / 0.62, 0.0, 1.0)
	var night_factor: float = maxf(raw_night, _blood_blend * 0.94)
	var sunset_factor: float = clampf(1.0 - absf(sun_sin) / 0.34, 0.0, 1.0) * (1.0 - _blood_blend * 0.7) * (1.0 - _acid_blend * 0.8) * (1.0 - _storm_blend * 0.75)

	var fog_col: Color = _biome_cur_profile["fog_color"] as Color
	var fog_eng: float = float(_biome_cur_profile["fog_energy"])
	var amb_col: Color = _biome_cur_profile["ambient_color"] as Color
	var sky_top: Color = _biome_cur_profile["sky_top"] as Color
	var sky_horizon: Color = _biome_cur_profile["sky_horizon"] as Color
	var ground_horizon: Color = _biome_cur_profile["ground_horizon"] as Color
	var ground_bottom: Color = _biome_cur_profile["ground_bottom"] as Color
	var cloud_lit: Color = _biome_cur_profile["cloud_lit"] as Color
	var cloud_shadow: Color = _biome_cur_profile["cloud_shadow"] as Color
	var sun_glow: Color = _biome_cur_profile["sun_glow"] as Color
	var cloud_cov: float = float(_biome_cur_profile["cloud_coverage"])
	var dir_col: Color = _biome_cur_profile["light_color"] as Color

	if sunset_factor > 0.001:
		sky_top = sky_top.lerp(Color(0.28, 0.22, 0.36), sunset_factor * 0.62)
		sky_horizon = sky_horizon.lerp(Color(0.84, 0.44, 0.24), sunset_factor * 0.75)
		fog_col = fog_col.lerp(Color(0.68, 0.42, 0.30), sunset_factor * 0.58)
		sun_glow = sun_glow.lerp(Color(1.0, 0.54, 0.22), sunset_factor * 0.80)
		cloud_lit = cloud_lit.lerp(Color(0.95, 0.58, 0.36), sunset_factor * 0.68)
		dir_col = dir_col.lerp(Color(1.0, 0.62, 0.34), sunset_factor * 0.72)

	if night_factor > 0.001:
		sky_top = sky_top.lerp(Color(0.03, 0.05, 0.11), night_factor * 0.88)
		sky_horizon = sky_horizon.lerp(Color(0.07, 0.10, 0.18), night_factor * 0.86)
		ground_horizon = ground_horizon.lerp(Color(0.05, 0.07, 0.12), night_factor * 0.84)
		ground_bottom = ground_bottom.lerp(Color(0.02, 0.03, 0.05), night_factor * 0.85)
		cloud_lit = cloud_lit.lerp(Color(0.18, 0.24, 0.38), night_factor * 0.82)
		cloud_shadow = cloud_shadow.lerp(Color(0.05, 0.07, 0.13), night_factor * 0.84)
		fog_col = fog_col.lerp(Color(0.06, 0.08, 0.14), night_factor * 0.85)
		amb_col = amb_col.lerp(Color(0.14, 0.18, 0.28), night_factor * 0.80)
		fog_eng = lerpf(fog_eng, 0.44, night_factor * 0.70)

	if _blood_blend > 0.001:
		sky_top = sky_top.lerp(Color(0.11, 0.02, 0.03), _blood_blend * 0.90)
		sky_horizon = sky_horizon.lerp(Color(0.46, 0.07, 0.06), _blood_blend * 0.88)
		ground_horizon = ground_horizon.lerp(Color(0.24, 0.05, 0.05), _blood_blend * 0.86)
		cloud_lit = cloud_lit.lerp(Color(0.72, 0.16, 0.14), _blood_blend * 0.85)
		cloud_shadow = cloud_shadow.lerp(Color(0.18, 0.04, 0.04), _blood_blend * 0.86)
		fog_col = fog_col.lerp(Color(0.42, 0.07, 0.07), _blood_blend * 0.86)
		amb_col = amb_col.lerp(Color(0.32, 0.10, 0.10), _blood_blend * 0.78)
		fog_eng = lerpf(fog_eng, 0.72, _blood_blend * 0.80)

	if _acid_fog_blend > 0.001:
		sky_top = sky_top.lerp(Color(0.18, 0.24, 0.10), _acid_fog_blend * 0.88)
		sky_horizon = sky_horizon.lerp(Color(0.36, 0.48, 0.18), _acid_fog_blend * 0.88)
		ground_horizon = ground_horizon.lerp(Color(0.24, 0.32, 0.12), _acid_fog_blend * 0.84)
		cloud_lit = cloud_lit.lerp(Color(0.52, 0.68, 0.26), _acid_fog_blend * 0.86)
		cloud_shadow = cloud_shadow.lerp(Color(0.16, 0.22, 0.09), _acid_fog_blend * 0.86)
		fog_col = fog_col.lerp(Color(0.30, 0.44, 0.13), _acid_fog_blend * 0.90)
		amb_col = amb_col.lerp(Color(0.32, 0.44, 0.16), _acid_fog_blend * 0.84)
		cloud_cov = lerpf(cloud_cov, 0.92, _acid_fog_blend * 0.88)
		fog_eng = lerpf(fog_eng, 0.92, _acid_fog_blend * 0.75)

	if _storm_blend > 0.001:
		sky_top = sky_top.lerp(Color(0.08, 0.11, 0.17), _storm_blend * 0.88)
		sky_horizon = sky_horizon.lerp(Color(0.18, 0.23, 0.31), _storm_blend * 0.86)
		ground_horizon = ground_horizon.lerp(Color(0.12, 0.16, 0.22), _storm_blend * 0.82)
		cloud_lit = cloud_lit.lerp(Color(0.32, 0.38, 0.48), _storm_blend * 0.86)
		cloud_shadow = cloud_shadow.lerp(Color(0.08, 0.11, 0.16), _storm_blend * 0.88)
		fog_col = fog_col.lerp(Color(0.17, 0.22, 0.30), _storm_blend * 0.86)
		amb_col = amb_col.lerp(Color(0.22, 0.27, 0.35), _storm_blend * 0.78)
		cloud_cov = lerpf(cloud_cov, 0.94, _storm_blend * 0.90)
		fog_eng = lerpf(fog_eng, 0.62, _storm_blend * 0.72)

	if _tornado_blend > 0.001:
		sky_top = sky_top.lerp(Color(0.19, 0.19, 0.17), _tornado_blend * 0.82)
		sky_horizon = sky_horizon.lerp(Color(0.38, 0.35, 0.29), _tornado_blend * 0.84)
		ground_horizon = ground_horizon.lerp(Color(0.26, 0.24, 0.20), _tornado_blend * 0.82)
		cloud_lit = cloud_lit.lerp(Color(0.56, 0.52, 0.44), _tornado_blend * 0.84)
		cloud_shadow = cloud_shadow.lerp(Color(0.16, 0.15, 0.14), _tornado_blend * 0.86)
		fog_col = fog_col.lerp(Color(0.35, 0.33, 0.28), _tornado_blend * 0.84)
		amb_col = amb_col.lerp(Color(0.34, 0.32, 0.28), _tornado_blend * 0.76)
		cloud_cov = lerpf(cloud_cov, 0.90, _tornado_blend * 0.85)
		fog_eng = lerpf(fog_eng, 0.72, _tornado_blend * 0.65)

	if _lightning_flash > 0.001:
		var lf: float = _lightning_flash * _lightning_flash
		sky_top = sky_top.lerp(Color(0.55, 0.68, 0.88), lf * 0.72)
		sky_horizon = sky_horizon.lerp(Color(0.78, 0.86, 1.0), lf * 0.78)
		cloud_lit = cloud_lit.lerp(Color(0.95, 0.98, 1.0), lf * 0.85)
		fog_col = fog_col.lerp(Color(0.68, 0.78, 0.95), lf * 0.55)
		amb_col = amb_col.lerp(Color(0.65, 0.75, 0.92), lf * 0.55)
		fog_eng = minf(fog_eng + lf * 0.35, 1.15)

	var f_begin: float = lerpf(_base_fog_begin, 11.0, _acid_fog_blend)
	var f_end: float = lerpf(_base_fog_end, 80.0, _acid_fog_blend)
	f_begin = lerpf(f_begin, 12.5, _storm_blend * 0.65)
	f_end = lerpf(f_end, 112.0, _storm_blend * 0.75)
	f_end = lerpf(f_end, 118.0, _tornado_blend * 0.65)

	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = fog_col
	env.fog_light_energy = fog_eng
	env.ambient_light_color = amb_col
	env.fog_density = 1.0
	env.fog_depth_begin = f_begin
	env.fog_depth_end = f_end
	env.fog_depth_curve = lerpf(1.10, 0.98, _acid_fog_blend)
	env.fog_sky_affect = lerpf(0.88, 0.94, maxf(_acid_fog_blend, _storm_blend * 0.7))

	var sun_dir := Vector3(cos(_time_of_day * TAU) * 0.45, maxf(sun_sin, -0.25) * 0.78 + 0.14, 0.85).normalized()
	var moon_dir := Vector3(-0.14, 0.28, 0.95).normalized()
	var star_val := clampf(night_factor * 0.95 * (1.0 - _acid_blend * 0.8) * (1.0 - _storm_blend * 0.9), 0.0, 1.0)

	if env.sky and env.sky.sky_material is ShaderMaterial:
		var shader_sky := env.sky.sky_material as ShaderMaterial
		shader_sky.set_shader_parameter("sky_top_color", sky_top)
		shader_sky.set_shader_parameter("sky_horizon_color", sky_horizon)
		shader_sky.set_shader_parameter("ground_horizon_color", ground_horizon)
		shader_sky.set_shader_parameter("ground_bottom_color", ground_bottom)
		shader_sky.set_shader_parameter("cloud_lit_color", cloud_lit)
		shader_sky.set_shader_parameter("cloud_shadow_color", cloud_shadow)
		shader_sky.set_shader_parameter("sun_glow_color", sun_glow)
		shader_sky.set_shader_parameter("cloud_coverage", cloud_cov)
		shader_sky.set_shader_parameter("sun_direction", sun_dir)
		shader_sky.set_shader_parameter("moon_direction", moon_dir)
		shader_sky.set_shader_parameter("night_factor", night_factor)
		shader_sky.set_shader_parameter("blood_moon_factor", _blood_blend)
		shader_sky.set_shader_parameter("acid_factor", _acid_blend)
		shader_sky.set_shader_parameter("star_intensity", star_val)
	elif env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var proc_sky := env.sky.sky_material as ProceduralSkyMaterial
		proc_sky.sky_top_color = sky_top
		proc_sky.sky_horizon_color = sky_horizon
		proc_sky.ground_horizon_color = ground_horizon

	if _dir_light:
		var day_energy: float = lerpf(1.35, 0.52, sunset_factor) * (1.0 - _acid_blend * 0.42) * (1.0 - _storm_blend * 0.45)
		var moon_col: Color = Color(0.45, 0.58, 0.84).lerp(Color(0.95, 0.24, 0.18), _blood_blend)
		var moon_energy: float = lerpf(0.36, 0.58, _blood_blend) * (1.0 - _acid_blend * 0.35) * (1.0 - _storm_blend * 0.35)
		_dir_light.light_color = dir_col.lerp(moon_col, night_factor).lerp(Color(0.84, 0.92, 1.0), _lightning_flash * 0.75)
		_dir_light.light_energy = lerpf(day_energy, moon_energy, night_factor) + _lightning_flash * 2.4
		var day_pitch: float = -lerpf(14.0, 56.0, clampf(maxf(sun_sin, 0.0), 0.0, 1.0))
		var target_pitch: float = lerpf(day_pitch, -26.0, night_factor)
		var target_yaw: float = lerpf(28.0, 165.0, clampf(_time_of_day * 1.4, 0.0, 1.0))
		_dir_light.rotation_degrees = Vector3(target_pitch, target_yaw, 0.0)

	ProceduralMaterials.set_night_window_boost(clampf(night_factor * 1.25 + _blood_blend * 0.25 + _storm_blend * 0.45, 0.0, 1.5))
	_headlight_boost = lerpf(1.0, 1.65, clampf(night_factor + _acid_blend * 0.45 + _storm_blend * 0.55, 0.0, 1.0))

func _cleanup_preplaced_chunks() -> void:
	for child in get_children():
		if child == car:
			continue
		if child.name.to_lower().contains("chunk") or child.name.to_lower().contains("bridge"):
			child.queue_free()

func _distance_along_forward(world_position: Vector3) -> float:
	return (world_position - world_origin).dot(_forward)

func _get_chunk_index(distance_along_forward: float) -> int:
	var first_bridge_start := float(_chunks_per_bridge) * _chunk_step - _chunk_step * 0.5
	if distance_along_forward < first_bridge_start:
		return int(floor((distance_along_forward + _chunk_step * 0.5) / _chunk_step))

	var bridge_len := _chunk_step - bridge_shortfall_meters
	var period_len := float(_chunks_per_bridge) * _chunk_step - bridge_shortfall_meters
	var d_after := distance_along_forward - first_bridge_start
	var period := int(floor(d_after / period_len))
	var rem := d_after - float(period) * period_len

	if rem < bridge_len:
		return _chunks_per_bridge * (period + 1)

	var offset_in_normal := 1 + int(floor((rem - bridge_len) / _chunk_step))
	return _chunks_per_bridge * (period + 1) + offset_in_normal

func _transition_fog(target_energy: float) -> void:
	if world_environment == null or world_environment.environment == null:
		return

	var env: Environment = world_environment.environment
	env.fog_enabled = SettingsManager.is_fog_allowed()

	if current_fog_tween:
		current_fog_tween.kill()

	current_fog_tween = create_tween()
	current_fog_tween.tween_property(env, "fog_light_energy", target_energy, 1.5)
