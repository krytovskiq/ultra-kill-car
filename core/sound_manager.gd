extends Node

## Central Audio Manager (SoundManager autoload).
## Routes vehicles, SFX/UI, and biome/menu ambience through dedicated AudioServer buses.

const AUDIO_DIR := "res://assets/audio/"

const BUS_VEHICLES := &"Vehicles"
const BUS_SFX := &"SFX"
const BUS_AMBIENCE := &"Ambience"

var _streams: Dictionary = {}
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_idx: int = 0
var _user_hit_pool: Array[AudioStreamPlayer] = []
var _user_hit_idx: int = 0
var _last_user_hit_choice: int = -1
var _vox_pool: Array[AudioStreamPlayer3D] = []
var _vox_idx: int = 0

var _ambience_player: AudioStreamPlayer = null
var _wind_rush_player: AudioStreamPlayer = null
var _death_drone_player: AudioStreamPlayer = null
var _weather_rain_player: AudioStreamPlayer = null
var _weather_tornado_player: AudioStreamPlayer = null
var _muted: bool = false
var _last_zombie_vox_ms: int = 0
var _last_splat_ms: int = 0
var _last_thud_ms: int = 0
var _last_crash_ms: int = 0
var _last_ui_hover_ms: int = 0
var _last_thunder_ms: int = 0

var _target_amb_db: float = -16.0
var _target_amb_pitch: float = 1.0
var _target_death_drone_db: float = -60.0
var _target_rain_db: float = -60.0
var _target_tornado_db: float = -60.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	var cfg := get_node_or_null("/root/SettingsManager")
	if cfg and cfg.has_method("apply_audio_settings"):
		cfg.call("apply_audio_settings")
	_preload_all()
	_setup_pools()
	_setup_ambience()

func _setup_audio_buses() -> void:
	for bus_name: StringName in [BUS_VEHICLES, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, String(bus_name))
			AudioServer.set_bus_send(idx, &"Master")

	# Оптимизация микса: компрессоры на шинах SFX/Vehicles и лимитер на Master предотвращают перегрузку и «кашу» из звуков
	var master_idx := AudioServer.get_bus_index(&"Master")
	if master_idx >= 0 and AudioServer.get_bus_effect_count(master_idx) == 0:
		var lim := AudioEffectLimiter.new()
		lim.ceiling_db = -1.2
		lim.threshold_db = -4.0
		lim.soft_clip_db = 2.0
		AudioServer.add_bus_effect(master_idx, lim)

	var sfx_idx := AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx >= 0 and AudioServer.get_bus_effect_count(sfx_idx) == 0:
		var comp_sfx := AudioEffectCompressor.new()
		comp_sfx.threshold = -10.0
		comp_sfx.ratio = 3.2
		comp_sfx.attack_us = 2200.0
		comp_sfx.release_ms = 115.0
		comp_sfx.gain = -0.8
		AudioServer.add_bus_effect(sfx_idx, comp_sfx)

	var veh_idx := AudioServer.get_bus_index(BUS_VEHICLES)
	if veh_idx >= 0 and AudioServer.get_bus_effect_count(veh_idx) == 0:
		var comp_veh := AudioEffectCompressor.new()
		comp_veh.threshold = -10.5
		comp_veh.ratio = 2.8
		comp_veh.attack_us = 3000.0
		comp_veh.release_ms = 120.0
		comp_veh.gain = -2.2
		AudioServer.add_bus_effect(veh_idx, comp_veh)

func _load_audio(key: String) -> AudioStream:
	for ext: String in [".wav", ".ogg"]:
		var path: String = AUDIO_DIR + key + ext
		if ResourceLoader.exists(path):
			var st := load(path) as AudioStream
			if st != null:
				return st
	return null

func _preload_all() -> void:
	var loop_files: Array[String] = [
		"engine_pikap", "engine_pikap_idle", "engine_pikap_howl",
		"engine_doge2", "engine_doge2_idle", "engine_doge2_howl",
		"engine_mustang", "engine_mustang_idle", "engine_mustang_howl",
		"engine_barracuda", "engine_barracuda_idle", "engine_barracuda_howl",
		"engine_buhanka", "engine_buhanka_idle", "engine_buhanka_howl",
		"engine_vandura", "engine_vandura_idle", "engine_vandura_howl",
		"engine_carson", "engine_carson_idle", "engine_carson_howl",
		"engine_delorean", "engine_delorean_idle", "engine_delorean_howl",
		"engine_k2500", "engine_k2500_idle", "engine_k2500_howl",
		"engine_paz3205", "engine_paz3205_idle", "engine_paz3205_howl",
		"engine_raptor", "engine_raptor_idle", "engine_raptor_howl",
		"engine_btr", "engine_btr_idle", "engine_btr_howl",
		"engine_supercharger",
		"fire_crackle_loop", "weather_rain_loop", "weather_tornado_loop",
		"tire_skid_loop", "ambient_wind", "ambient_wind_rush", "death_drone",
		"music_wasteland", "music_city", "music_forest",
		"music_winter", "music_toxic", "music_scorched"
	]
	for car_id: String in ["pikap", "doge2", "mustang", "barracuda", "buhanka", "vandura", "carson", "delorean", "k2500", "paz3205", "raptor"]:
		for st_i: int in range(3):
			for layer_k: String in ["idle", "mid", "howl"]:
				loop_files.append("engine_%s_s%d_%s" % [car_id, st_i, layer_k])
	for k: String in loop_files:
		var st := _load_audio(k)
		if st is AudioStreamWAV:
			var dup := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
			var bps_frame: int = 2 * (2 if dup.stereo else 1)
			var total_frames: int = floori(float(dup.data.size()) / float(maxi(bps_frame, 1)))
			if total_frames > 32:
				dup.loop_mode = AudioStreamWAV.LOOP_FORWARD
				dup.loop_begin = 0
				dup.loop_end = total_frames if (k.begins_with("engine_") or k.begins_with("music_") or k.begins_with("weather_") or k == "fire_crackle_loop") else (total_frames - 16)
			_streams[k] = dup
		elif st is AudioStreamOggVorbis:
			var dup_ogg := (st as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			dup_ogg.loop = true
			_streams[k] = dup_ogg
		elif st != null:
			_streams[k] = st

	# Алиасы атмосферной музыки биомов
	for b_name: String in ["wasteland", "city", "forest", "winter", "toxic", "scorched"]:
		if _streams.has("music_" + b_name):
			_streams["ambient_" + b_name] = _streams["music_" + b_name]

	var oneshot_files: Array[String] = [
		"crash_metal", "crash_heavy", "crash_wreck_hit", "btr_gunshot",
		"car_landing_heavy", "car_landing_light",
		"prop_snap_wood", "prop_clang_metal", "prop_crumble_concrete",
		"zombie_splat", "zombie_bite_car", "fuel_pickup",
		"zombie_groan_1", "zombie_groan_2", "zombie_groan_3", "zombie_groan_4",
		"zombie_snarl", "zombie_snarl_2", "zombie_snarl_3",
		"zombie_shriek_1", "zombie_shriek_2",
		"zombie_brute_roar_1", "zombie_brute_roar_2",
		"zombie_death_1",
		"zombie_hit_thud_1", "zombie_hit_thud_2", "zombie_hit_bumper",
		"zombie_car_thump_1", "zombie_car_thump_2", "zombie_car_thump_3",
		"zombie_hood_hit_1", "zombie_hood_hit_2", "zombie_hood_hit_3", "zombie_hood_hit_4",
		"zombie_user_hit_1", "zombie_user_hit_2", "zombie_user_hit_3",
		"water_splash_heavy",
		"btr_explosion_1", "btr_explosion_2", "barrel_explosion",
		"gear_shift_up", "gear_shift_down", "exhaust_backfire", "turbo_bov",
		"weather_thunder_1", "weather_thunder_2",
		"death_sting", "garage_buy", "garage_select",
		"ui_hover", "ui_click"
	]
	for k: String in oneshot_files:
		var st := _load_audio(k)
		if st != null:
			_streams[k] = st
	_streams["zombie_soft_hit_1"] = _build_soft_zombie_hit_stream(41101, 0.94)
	_streams["zombie_soft_hit_2"] = _build_soft_zombie_hit_stream(41102, 1.00)
	_streams["zombie_soft_hit_3"] = _build_soft_zombie_hit_stream(41103, 1.08)
	if not _streams.has("water_splash_heavy"):
		_streams["water_splash_heavy"] = _build_water_splash_wav(52101)

func _build_soft_zombie_hit_stream(seed_val: int, pitch_bias: float) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.24
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_cloth: float = 0.0
	var lp_body: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.005, 0.0, 1.0)
		# Muffled fleshy chest-on-bumper thud (112 Hz -> 40 Hz, rapid non-boomy decay)
		var thud_freq: float = lerpf(112.0, 40.0, clampf(t * 22.0, 0.0, 1.0)) * pitch_bias
		var thud_env: float = atk * exp(-t * 26.0)
		var thud: float = sin(TAU * thud_freq * t) * thud_env * 0.86
		# Subtle double-thump as body rolls off hood/bumper ~38 ms later
		var t2: float = maxf(t - 0.038, 0.0)
		var thump2_env: float = (1.0 if t >= 0.038 else 0.0) * clampf(t2 / 0.006, 0.0, 1.0) * exp(-t2 * 30.0)
		var thump2: float = sin(TAU * (68.0 * pitch_bias) * t2) * thump2_env * 0.34
		# Damped low-passed cloth/flesh thump noise (cutoff ~450 Hz, zero metallic harshness)
		var n_raw: float = rng.randf_range(-1.0, 1.0)
		lp_cloth = lerpf(lp_cloth, n_raw, 0.12)
		lp_body = lerpf(lp_body, lp_cloth, 0.18)
		var noise_env: float = atk * exp(-t * 32.0)
		var tissue_thud: float = lp_body * noise_env * 0.52
		var mixed: float = (thud + thump2 + tissue_thud) * 1.15
		var warm: float = mixed / (1.0 + absf(mixed) * 0.45)
		var pcm: int = int(round(clampf(warm, -0.98, 0.98) * 32767.0))
		data.encode_s16(i * 2, pcm)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_water_splash_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 1.55
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_low: float = 0.0
	var lp_spray: float = 0.0
	var hp_prev: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.012, 0.0, 1.0)
		var plunge_freq: float = lerpf(96.0, 32.0, clampf(t * 7.5, 0.0, 1.0))
		var plunge: float = sin(TAU * plunge_freq * t) * atk * exp(-t * 11.5) * 0.85
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_low = lerpf(lp_low, n, 0.08)
		lp_spray = lerpf(lp_spray, n, 0.44)
		var bp_spray: float = lp_spray - lp_low
		var spray_env: float = clampf(t / 0.025, 0.0, 1.0) * exp(-t * 2.15)
		var rush_env: float = clampf((t - 0.05) / 0.08, 0.0, 1.0) * exp(-maxf(t - 0.05, 0.0) * 1.45)
		var cascade: float = (lp_spray - hp_prev) * 0.5 + bp_spray * 0.8
		hp_prev = lerpf(hp_prev, lp_spray, 0.25)
		var mixed: float = (plunge + bp_spray * spray_env * 0.95 + cascade * rush_env * 0.42 + lp_low * spray_env * 0.55) * 1.15
		var warm: float = mixed / (1.0 + absf(mixed) * 0.48)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_water_sink_glug_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 2.40
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var bubbles: Array[Dictionary] = []
	var cur_t: float = 0.14
	while cur_t < 2.22:
		bubbles.append({
			"t0": cur_t,
			"len": rng.randf_range(0.055, 0.115),
			"f0": rng.randf_range(135.0, 250.0),
			"f1": rng.randf_range(290.0, 440.0),
			"amp": rng.randf_range(0.32, 0.62)
		})
		cur_t += rng.randf_range(0.11, 0.23)
	var lp_sub: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var fade_out: float = clampf((duration - t) / 0.25, 0.0, 1.0)
		var fade_in: float = clampf(t / 0.18, 0.0, 1.0)
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_sub = lerpf(lp_sub, n, 0.025)
		var hull_rumble: float = lp_sub * 0.55 * exp(-t * 0.45) + sin(TAU * 48.0 * t) * 0.14
		var glug_sum: float = 0.0
		for b: Dictionary in bubbles:
			var dt_b: float = t - float(b["t0"])
			var blen: float = float(b["len"])
			if dt_b >= 0.0 and dt_b <= blen:
				var u: float = dt_b / blen
				var env_b: float = sin(u * PI)
				var freq_b: float = lerpf(float(b["f0"]), float(b["f1"]), u * u)
				glug_sum += sin(TAU * freq_b * dt_b) * env_b * float(b["amp"])
		var mixed: float = (hull_rumble + glug_sum) * fade_in * fade_out
		var warm: float = mixed / (1.0 + absf(mixed) * 0.45)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _setup_pools() -> void:
	for i in range(20):
		var p := AudioStreamPlayer.new()
		p.name = "SfxPool_%d" % i
		p.bus = BUS_SFX
		add_child(p)
		_sfx_pool.append(p)

	for i in range(8):
		var up := AudioStreamPlayer.new()
		up.name = "UserHitPool_%d" % i
		up.bus = BUS_SFX
		add_child(up)
		_user_hit_pool.append(up)

	for i in range(8):
		var p3 := AudioStreamPlayer3D.new()
		p3.name = "VoxPool3D_%d" % i
		p3.bus = BUS_SFX
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.unit_size = 13.0
		p3.max_distance = 72.0
		p3.max_db = 2.0
		add_child(p3)
		_vox_pool.append(p3)

func _setup_ambience() -> void:
	var wind_stream := _streams.get("music_wasteland", _streams.get("ambient_wind")) as AudioStream
	var rush_stream := _streams.get("ambient_wind_rush", _streams.get("ambient_wind")) as AudioStream

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "BiomeAmbience"
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.volume_db = -8.5
	add_child(_ambience_player)
	if wind_stream:
		_ambience_player.stream = wind_stream
		_ambience_player.play()

	_wind_rush_player = AudioStreamPlayer.new()
	_wind_rush_player.name = "SpeedWindRush"
	_wind_rush_player.bus = BUS_AMBIENCE
	_wind_rush_player.volume_db = -60.0
	add_child(_wind_rush_player)
	if rush_stream:
		_wind_rush_player.stream = rush_stream
		_wind_rush_player.pitch_scale = 1.05
		_wind_rush_player.play()

	var death_stream := _streams.get("death_drone") as AudioStream
	_death_drone_player = AudioStreamPlayer.new()
	_death_drone_player.name = "DeathAmbience"
	_death_drone_player.bus = BUS_AMBIENCE
	_death_drone_player.volume_db = -60.0
	_death_drone_player.pitch_scale = 0.88
	add_child(_death_drone_player)
	if death_stream:
		_death_drone_player.stream = death_stream
		_death_drone_player.play()

	var rain_stream := _streams.get("weather_rain_loop") as AudioStream
	_weather_rain_player = AudioStreamPlayer.new()
	_weather_rain_player.name = "WeatherRainLoop"
	_weather_rain_player.bus = BUS_AMBIENCE
	_weather_rain_player.volume_db = -60.0
	add_child(_weather_rain_player)
	if rain_stream:
		_weather_rain_player.stream = rain_stream
		_weather_rain_player.play()

	var tornado_stream := _streams.get("weather_tornado_loop") as AudioStream
	_weather_tornado_player = AudioStreamPlayer.new()
	_weather_tornado_player.name = "WeatherTornadoLoop"
	_weather_tornado_player.bus = BUS_AMBIENCE
	_weather_tornado_player.volume_db = -60.0
	add_child(_weather_tornado_player)
	if tornado_stream:
		_weather_tornado_player.stream = tornado_stream
		_weather_tornado_player.play()

func _process(delta: float) -> void:
	var paused_now := false
	if get_tree():
		paused_now = get_tree().paused
	var real_dt: float = clampf(delta / maxf(Engine.time_scale, 0.05), 0.0, 0.1)

	if is_instance_valid(_ambience_player):
		var dest_db: float = -34.0 if paused_now else _target_amb_db
		_ambience_player.volume_db = lerpf(_ambience_player.volume_db, dest_db, clampf(real_dt * 2.5, 0.0, 1.0))
		_ambience_player.pitch_scale = lerpf(_ambience_player.pitch_scale, _target_amb_pitch, clampf(real_dt * 1.5, 0.0, 1.0))

	if is_instance_valid(_death_drone_player):
		var drone_dest: float = -60.0 if paused_now else _target_death_drone_db
		_death_drone_player.volume_db = lerpf(_death_drone_player.volume_db, drone_dest, clampf(real_dt * 2.2, 0.0, 1.0))

	if is_instance_valid(_weather_rain_player):
		var rain_dest: float = -60.0 if (paused_now or _muted) else _target_rain_db
		_weather_rain_player.volume_db = lerpf(_weather_rain_player.volume_db, rain_dest, clampf(real_dt * 3.0, 0.0, 1.0))

	if is_instance_valid(_weather_tornado_player):
		var tor_dest: float = -60.0 if (paused_now or _muted) else _target_tornado_db
		_weather_tornado_player.volume_db = lerpf(_weather_tornado_player.volume_db, tor_dest, clampf(real_dt * 3.5, 0.0, 1.0))

	if is_instance_valid(_wind_rush_player) and paused_now:
		_wind_rush_player.volume_db = -60.0

func set_menu_ambience() -> void:
	_target_death_drone_db = -60.0
	_target_rain_db = -60.0
	_target_tornado_db = -60.0
	_target_amb_db = -8.0
	_target_amb_pitch = 1.0
	var menu_st := _streams.get("music_wasteland", _streams.get("ambient_wind")) as AudioStream
	if is_instance_valid(_ambience_player) and menu_st and _ambience_player.stream != menu_st:
		_ambience_player.stream = menu_st
		_ambience_player.play()
	if is_instance_valid(_wind_rush_player):
		_wind_rush_player.volume_db = -60.0

func set_biome_ambience(biome_id: int, red_zone: bool) -> void:
	_target_death_drone_db = -19.5 if red_zone else -60.0
	var stream_key: String = "music_wasteland"
	match biome_id:
		1: # RUINED_CITY
			stream_key = "music_city"
			_target_amb_db = -7.8
			_target_amb_pitch = 1.00
		2: # DARK_FOREST
			stream_key = "music_forest"
			_target_amb_db = -7.4
			_target_amb_pitch = 1.00
		3: # WINTER_ICE
			stream_key = "music_winter"
			_target_amb_db = -7.2
			_target_amb_pitch = 1.00
		4: # TOXIC_MARSH / ACID_STORM
			stream_key = "music_toxic"
			_target_amb_db = -7.5
			_target_amb_pitch = 0.98
		5: # SCORCHED_CANYON
			stream_key = "music_scorched"
			_target_amb_db = -7.5
			_target_amb_pitch = 0.98
		6: # BURNING_CITY
			stream_key = "music_scorched"
			_target_amb_db = -7.3
			_target_amb_pitch = 0.95
		7: # BURNT_FOREST
			stream_key = "music_forest"
			_target_amb_db = -7.6
			_target_amb_pitch = 0.92
		8: # OVERGROWN_HIGHWAY
			stream_key = "music_forest"
			_target_amb_db = -7.4
			_target_amb_pitch = 1.03
		_: # WASTELAND
			stream_key = "music_wasteland"
			_target_amb_db = -7.6
			_target_amb_pitch = 1.00
	if red_zone:
		_target_amb_db += 0.8
		_target_amb_pitch *= 0.95
	var target_st := _streams.get(stream_key, _streams.get("ambient_wind")) as AudioStream
	if is_instance_valid(_ambience_player) and target_st:
		if _ambience_player.stream != target_st or not _ambience_player.playing:
			_ambience_player.volume_db = minf(_ambience_player.volume_db, -18.0)
			_ambience_player.stream = target_st
			_ambience_player.play()

func set_death_ambience(active: bool) -> void:
	if active:
		# После смерти не запускаем зацикленный дрон и не искажаем звук — остаётся только чистый эмбиент текущего биома
		_target_death_drone_db = -60.0
		_target_tornado_db = -60.0
		_target_amb_db = -10.5
		_target_amb_pitch = 1.0
		if is_instance_valid(_death_drone_player):
			_death_drone_player.stop()
			_death_drone_player.volume_db = -60.0
		if is_instance_valid(_weather_tornado_player):
			_weather_tornado_player.stop()
			_weather_tornado_player.volume_db = -60.0
		if is_instance_valid(_wind_rush_player):
			_wind_rush_player.volume_db = -60.0
	else:
		_target_death_drone_db = -60.0

func set_speed_wind(speed_ratio: float, active: bool) -> void:
	if not is_instance_valid(_wind_rush_player):
		return
	if not active or speed_ratio < 0.28:
		_wind_rush_player.volume_db = lerpf(_wind_rush_player.volume_db, -60.0, 0.15)
		return
	var t := clampf((speed_ratio - 0.28) / 0.72, 0.0, 1.0)
	var target_db := lerpf(-42.0, -22.5, t * t)
	_wind_rush_player.volume_db = lerpf(_wind_rush_player.volume_db, target_db, 0.15)
	_wind_rush_player.pitch_scale = lerpf(0.95, 1.45, t)

func get_stream(key: String) -> AudioStream:
	return _streams.get(key) as AudioStream

func _resolve_engine_streams(engine_id: String, upgrade_tier: int = 0) -> Dictionary:
	if engine_id == "btr":
		return {
			"idle": get_stream("engine_btr_idle"),
			"mid": get_stream("engine_btr"),
			"howl": get_stream("engine_btr_howl"),
			"boost": null,
		}
	var tier: int = clampi(upgrade_tier, 0, 2)
	var s_idle: AudioStream = get_stream("engine_%s_s%d_idle" % [engine_id, tier])
	if s_idle == null:
		s_idle = get_stream("engine_%s_idle" % engine_id)
	if s_idle == null:
		s_idle = get_stream("engine_pikap_idle")

	var s_mid: AudioStream = get_stream("engine_%s_s%d_mid" % [engine_id, tier])
	if s_mid == null:
		s_mid = get_stream("engine_%s" % engine_id)
	if s_mid == null:
		s_mid = get_stream("engine_pikap")

	var s_howl: AudioStream = get_stream("engine_%s_s%d_howl" % [engine_id, tier])
	if s_howl == null:
		s_howl = get_stream("engine_%s_howl" % engine_id)
	if s_howl == null:
		s_howl = get_stream("engine_pikap_howl")

	var s_boost: AudioStream = get_stream("engine_supercharger")
	return {
		"idle": s_idle,
		"mid": s_mid,
		"howl": s_howl,
		"boost": s_boost,
	}

func apply_vehicle_engine_tier(handles: Dictionary, engine_id: String, upgrade_tier: int) -> void:
	if engine_id == "btr":
		return
	var st_map: Dictionary = _resolve_engine_streams(engine_id, upgrade_tier)
	var p_idle := handles.get("engine_idle") as AudioStreamPlayer
	var p_mid := handles.get("engine") as AudioStreamPlayer
	var p_howl := handles.get("engine_howl") as AudioStreamPlayer
	var p_boost := handles.get("engine_boost") as AudioStreamPlayer
	for pair in [[p_idle, st_map.get("idle")], [p_mid, st_map.get("mid")], [p_howl, st_map.get("howl")], [p_boost, st_map.get("boost")]]:
		var pl := pair[0] as AudioStreamPlayer
		var st := pair[1] as AudioStream
		if is_instance_valid(pl) and st and pl.stream != st:
			var was_playing: bool = pl.playing
			pl.stream = st
			if was_playing:
				pl.play()

func attach_vehicle_audio(vehicle: Node, engine_id: String, upgrade_tier: int = 0) -> Dictionary:
	var st_map: Dictionary = _resolve_engine_streams(engine_id, upgrade_tier)
	var eng := AudioStreamPlayer.new()
	eng.name = "EngineAudioPlayer"
	eng.bus = BUS_VEHICLES
	var estream := st_map.get("mid") as AudioStream
	if estream:
		eng.stream = estream
	eng.volume_db = -24.0
	vehicle.add_child(eng)

	var eng_idle := AudioStreamPlayer.new()
	eng_idle.name = "EngineIdleAudioPlayer"
	eng_idle.bus = BUS_VEHICLES
	var istream := st_map.get("idle") as AudioStream
	if istream == null:
		istream = estream
	if istream:
		eng_idle.stream = istream
	eng_idle.volume_db = -14.0
	vehicle.add_child(eng_idle)

	var eng_howl := AudioStreamPlayer.new()
	eng_howl.name = "EngineHowlAudioPlayer"
	eng_howl.bus = BUS_VEHICLES
	var hstream := st_map.get("howl") as AudioStream
	if hstream:
		eng_howl.stream = hstream
	eng_howl.volume_db = -60.0
	vehicle.add_child(eng_howl)

	var eng_boost := AudioStreamPlayer.new()
	eng_boost.name = "EngineBoostAudioPlayer"
	eng_boost.bus = BUS_VEHICLES
	var bstream := st_map.get("boost") as AudioStream
	if bstream:
		eng_boost.stream = bstream
	eng_boost.volume_db = -60.0
	vehicle.add_child(eng_boost)

	var skid := AudioStreamPlayer.new()
	skid.name = "TireSkidAudioPlayer"
	skid.bus = BUS_VEHICLES
	var sstream := get_stream("tire_skid_loop")
	if sstream:
		skid.stream = sstream
	skid.volume_db = -60.0
	vehicle.add_child(skid)

	var fire_p := AudioStreamPlayer.new()
	fire_p.name = "EngineFireAudioPlayer"
	fire_p.bus = BUS_VEHICLES
	var fstream := get_stream("fire_crackle_loop")
	if fstream:
		fire_p.stream = fstream
	fire_p.volume_db = -60.0
	vehicle.add_child(fire_p)

	return {"engine": eng, "engine_idle": eng_idle, "engine_howl": eng_howl, "engine_boost": eng_boost, "skid": skid, "fire": fire_p}

func _play_pool_slot(st: AudioStream, bus_name: StringName, volume_db: float, pitch: float) -> void:
	if _muted or _sfx_pool.is_empty() or st == null:
		return
	var p := _sfx_pool[_sfx_idx]
	_sfx_idx = (_sfx_idx + 1) % _sfx_pool.size()
	if is_instance_valid(p):
		p.stop()
		p.bus = bus_name
		p.stream = st
		p.volume_db = volume_db
		p.pitch_scale = clampf(pitch, 0.4, 2.4)
		p.play()

func play_ui(key: String, volume_db: float = -7.0, pitch: float = 1.0) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var st := _streams.get(key) as AudioStream
	if st == null:
		return
	if key == "ui_hover":
		var now := Time.get_ticks_msec()
		if now - _last_ui_hover_ms < 45:
			return
		_last_ui_hover_ms = now
	_play_pool_slot(st, BUS_SFX, volume_db, clampf(pitch, 0.5, 2.0))

func play_vehicle_sfx(key: String, volume_db: float = -5.0, pitch: float = 1.0) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var st := _streams.get(key) as AudioStream
	if st == null:
		return
	_play_pool_slot(st, BUS_VEHICLES, volume_db, pitch)

func play_sfx(key: String, volume_db: float = -2.0, pitch: float = 1.0) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var st := _streams.get(key) as AudioStream
	if st == null:
		return

	var now := Time.get_ticks_msec()
	if key == "zombie_splat":
		if now - _last_splat_ms < 55:
			return
		_last_splat_ms = now
	elif key == "crash_metal" or key == "crash_heavy":
		if now - _last_crash_ms < 140:
			return
		_last_crash_ms = now

	_play_pool_slot(st, BUS_SFX, volume_db, pitch)

var _last_btr_exp_ms: int = 0
var _last_landing_ms: int = 0
var _last_prop_hit_ms: int = 0

func play_car_landing(intensity: float = 1.0, heavy_vehicle: bool = false) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_landing_ms < 160:
		return
	_last_landing_ms = now
	var t_int: float = clampf(intensity, 0.35, 1.5)
	var use_heavy: bool = heavy_vehicle or t_int >= 0.68
	var primary_key: String = "car_landing_heavy" if use_heavy else "car_landing_light"
	var primary_st := _streams.get(primary_key, _streams.get("zombie_car_thump_2")) as AudioStream
	if primary_st:
		var vol_db: float = lerpf(-7.5, -1.8, clampf((t_int - 0.35) / 1.15, 0.0, 1.0))
		var pitch: float = randf_range(0.76, 0.88) if heavy_vehicle else randf_range(0.92, 1.06)
		_play_pool_slot(primary_st, BUS_VEHICLES, vol_db, pitch)
	if t_int > 1.15:
		var metal_st := _streams.get("crash_metal") as AudioStream
		if metal_st:
			_play_pool_slot(metal_st, BUS_SFX, -13.5, randf_range(0.92, 1.06))

func play_prop_impact(prop_material: String, speed_mps: float = 15.0) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_prop_hit_ms < 55:
		return
	_last_prop_hit_ms = now
	var key: String = "prop_clang_metal"
	match prop_material:
		"wood":
			key = "prop_snap_wood"
		"concrete":
			key = "prop_crumble_concrete"
		_:
			key = "prop_clang_metal"
	var st := _streams.get(key) as AudioStream
	if st:
		var spd_t: float = clampf((speed_mps - 4.0) / 22.0, 0.0, 1.0)
		var vol_db: float = lerpf(-8.5, -3.2, spd_t)
		_play_pool_slot(st, BUS_SFX, vol_db, randf_range(0.91, 1.10))
	if speed_mps > 14.0:
		var thump_st := _streams.get("car_landing_light") as AudioStream
		if thump_st:
			_play_pool_slot(thump_st, BUS_VEHICLES, -13.5, randf_range(1.10, 1.25))

func stop_transient_sfx() -> void:
	for p in _sfx_pool:
		if is_instance_valid(p):
			p.stop()
	for up in _user_hit_pool:
		if is_instance_valid(up):
			up.stop()
	for p3 in _vox_pool:
		if is_instance_valid(p3):
			p3.stop()
	_target_rain_db = -60.0
	_target_tornado_db = -60.0
	set_speed_wind(0.0, false)

func _play_user_hit_slot(st: AudioStream, volume_db: float, pitch: float) -> void:
	if _muted or _user_hit_pool.is_empty() or st == null:
		return
	var p: AudioStreamPlayer = null
	for i in range(_user_hit_pool.size()):
		var cand := _user_hit_pool[(_user_hit_idx + i) % _user_hit_pool.size()]
		if is_instance_valid(cand) and not cand.playing:
			p = cand
			_user_hit_idx = ((_user_hit_idx + i + 1) % _user_hit_pool.size())
			break
	if p == null:
		p = _user_hit_pool[_user_hit_idx]
		_user_hit_idx = (_user_hit_idx + 1) % _user_hit_pool.size()
	if is_instance_valid(p):
		p.stop()
		p.bus = BUS_SFX
		p.stream = st
		p.volume_db = volume_db
		p.pitch_scale = clampf(pitch, 0.75, 1.35)
		p.play()

func play_zombie_hit_thud(speed_kmh: float, lethal: bool) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_thud_ms < 48:
		return
	_last_thud_ms = now

	var spd_t := clampf((speed_kmh - 8.0) / 105.0, 0.0, 1.0)

	# 1) Текущий базовый звук сбития зомби (сбалансированный низкочастотный удар о капот без перегруза)
	var base_candidates: Array[String] = [
		"zombie_hood_hit_1", "zombie_hood_hit_2", "zombie_hood_hit_3", "zombie_hood_hit_4",
		"zombie_soft_hit_1", "zombie_soft_hit_2", "zombie_soft_hit_3"
	]
	var avail_base: Array[String] = []
	for bk: String in base_candidates:
		if _streams.has(bk):
			avail_base.append(bk)
	if not avail_base.is_empty():
		var bkey: String = avail_base[randi() % avail_base.size()]
		var bst := _streams.get(bkey) as AudioStream
		if bst:
			_play_pool_slot(bst, BUS_SFX, lerpf(-7.5, -4.8, spd_t), randf_range(0.90, 1.10))
	if lethal:
		play_sfx("zombie_splat", lerpf(-9.5, -6.5, spd_t), randf_range(0.88, 1.12))

	# 2) ПЛЮСОМ на рандом один из 3 пользовательских звуков сбития зомби (чёткий ведущий слой на отдельном канале)
	var user_keys: Array[String] = ["zombie_user_hit_1", "zombie_user_hit_2", "zombie_user_hit_3"]
	var avail_user: Array[String] = []
	for uk: String in user_keys:
		if _streams.has(uk):
			avail_user.append(uk)
	if not avail_user.is_empty():
		var u_idx: int = randi() % avail_user.size()
		if avail_user.size() > 1 and u_idx == _last_user_hit_choice:
			u_idx = (u_idx + 1 + (randi() % (avail_user.size() - 1))) % avail_user.size()
		_last_user_hit_choice = u_idx
		var ukey: String = avail_user[u_idx]
		var ust := _streams.get(ukey) as AudioStream
		if ust:
			_play_user_hit_slot(ust, lerpf(-2.0, 0.2, spd_t), randf_range(0.96, 1.04))


var _last_barrel_exp_ms: int = 0

func play_barrel_explosion() -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_barrel_exp_ms < 60:
		return
	_last_barrel_exp_ms = now
	var exp_st := _streams.get("barrel_explosion") as AudioStream
	if exp_st:
		_play_pool_slot(exp_st, BUS_SFX, -1.2, randf_range(0.94, 1.07))
	else:
		var fallback_st := _streams.get("btr_explosion_1") as AudioStream
		if fallback_st:
			_play_pool_slot(fallback_st, BUS_SFX, -2.0, randf_range(1.00, 1.12))
	var metal_st := _streams.get("prop_clang_metal") as AudioStream
	if metal_st:
		_play_pool_slot(metal_st, BUS_SFX, -11.0, randf_range(1.06, 1.22))

func set_weather_audio(rain_level: float, tornado_level: float) -> void:
	var r: float = clampf(rain_level, 0.0, 1.0)
	var tor: float = clampf(tornado_level, 0.0, 1.0)
	_target_rain_db = lerpf(-34.0, -10.5, r) if r > 0.02 else -60.0
	_target_tornado_db = lerpf(-30.0, -5.5, tor) if tor > 0.02 else -60.0

func play_thunder(volume_db: float = -2.5) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_thunder_ms < 1200:
		return
	_last_thunder_ms = now
	var key: String = "weather_thunder_1" if (randi() % 2) == 0 else "weather_thunder_2"
	var st := _streams.get(key) as AudioStream
	if st:
		_play_pool_slot(st, BUS_SFX, volume_db, randf_range(0.88, 1.10))

func play_btr_explosion() -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_btr_exp_ms < 85:
		return
	_last_btr_exp_ms = now
	var key: String = "btr_explosion_1" if (randi() % 2) == 0 else "btr_explosion_2"
	var st := _streams.get(key) as AudioStream
	if st:
		_play_pool_slot(st, BUS_SFX, -2.5, randf_range(0.88, 1.08))
	var thump_st := _streams.get("zombie_car_thump_2") as AudioStream
	if thump_st:
		_play_pool_slot(thump_st, "Vehicles", -6.0, randf_range(0.68, 0.82))

var _last_vox_key: String = ""

func play_zombie_sound(world_pos: Vector3, is_snarl: bool = false, archetype: int = -1, is_death: bool = false) -> void:
	if _muted or _vox_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	var min_gap: int = 240 if is_death else (320 if is_snarl else 620)
	if now - _last_zombie_vox_ms < min_gap:
		return
	_last_zombie_vox_ms = now

	var candidates: Array[String] = []
	var pitch_min := 0.80
	var pitch_max := 1.08
	var vol_db := -7.5

	if is_death:
		candidates = ["zombie_death_1", "zombie_snarl_2", "zombie_brute_roar_2"]
		vol_db = -2.5
		pitch_min = 0.78
		pitch_max = 1.16
	elif is_snarl:
		match archetype:
			2: # BRUTE
				candidates = ["zombie_brute_roar_1", "zombie_brute_roar_2", "zombie_snarl_3"]
				pitch_min = 0.64
				pitch_max = 0.84
				vol_db = -1.0
			3, 4: # SPRINTER / STALKER
				candidates = ["zombie_shriek_1", "zombie_shriek_2", "zombie_snarl", "zombie_snarl_3"]
				pitch_min = 1.02
				pitch_max = 1.28
				vol_db = -1.6
			_:
				candidates = ["zombie_snarl", "zombie_snarl_2", "zombie_snarl_3", "zombie_shriek_1"]
				pitch_min = 0.82
				pitch_max = 1.12
				vol_db = -2.0
	else:
		match archetype:
			2: # BRUTE
				candidates = ["zombie_brute_roar_1", "zombie_brute_roar_2", "zombie_groan_1", "zombie_groan_2"]
				pitch_min = 0.62
				pitch_max = 0.82
				vol_db = -3.0
			3: # SPRINTER
				candidates = ["zombie_shriek_1", "zombie_shriek_2", "zombie_snarl_2", "zombie_groan_4"]
				pitch_min = 1.05
				pitch_max = 1.30
				vol_db = -3.8
			4: # STALKER
				candidates = ["zombie_groan_4", "zombie_shriek_2", "zombie_groan_3", "zombie_snarl_3"]
				pitch_min = 0.88
				pitch_max = 1.16
				vol_db = -4.2
			1: # LIMP / CRAWLER
				candidates = ["zombie_groan_3", "zombie_groan_4", "zombie_groan_2", "zombie_snarl_2"]
				pitch_min = 0.74
				pitch_max = 0.96
				vol_db = -4.5
			_:
				candidates = [
					"zombie_groan_1", "zombie_groan_2", "zombie_groan_3", "zombie_groan_4",
					"zombie_shriek_1", "zombie_brute_roar_1", "zombie_snarl_3"
				]
				pitch_min = 0.75
				pitch_max = 1.15
				vol_db = -4.2

	var key: String = candidates[randi() % candidates.size()]
	if candidates.size() > 1 and key == _last_vox_key:
		key = candidates[(candidates.find(key) + 1 + (randi() % (candidates.size() - 1))) % candidates.size()]
	_last_vox_key = key

	var st := _streams.get(key) as AudioStream
	if st == null:
		return

	for i in range(_vox_pool.size()):
		var idx := (_vox_idx + i) % _vox_pool.size()
		var p3 := _vox_pool[idx]
		if is_instance_valid(p3) and not p3.playing:
			_vox_idx = (idx + 1) % _vox_pool.size()
			p3.global_position = world_pos
			p3.bus = BUS_SFX
			p3.stream = st
			p3.volume_db = vol_db
			p3.pitch_scale = randf_range(pitch_min, pitch_max)
			p3.play()
			return
