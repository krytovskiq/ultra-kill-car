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
var _biome_env_player: AudioStreamPlayer = null
var _biome_fire_player: AudioStreamPlayer = null
var _tornado_sub_player: AudioStreamPlayer = null
var _muted: bool = false
var _last_zombie_vox_ms: int = 0
var _last_splat_ms: int = 0
var _last_thud_ms: int = 0
var _last_crash_ms: int = 0
var _last_ui_hover_ms: int = 0
var _last_thunder_ms: int = 0
var _last_env_detail_ms: int = 0
var _next_env_detail_delay_ms: int = 4200
var _current_biome_id: int = 0
var _in_gameplay_biome: bool = false

var _target_amb_db: float = -16.0
var _target_amb_pitch: float = 1.0
var _target_death_drone_db: float = -60.0
var _target_rain_db: float = -60.0
var _target_tornado_db: float = -60.0
var _target_biome_env_db: float = -60.0
var _target_biome_env_pitch: float = 1.0
var _target_biome_fire_db: float = -60.0
var _target_tornado_sub_db: float = -60.0

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
		"engine_btr", "engine_btr_idle", "engine_btr_howl",
		"engine_supercharger",
		"fire_crackle_loop", "weather_rain_loop", "weather_tornado_loop",
		"tire_skid_loop", "ambient_wind", "ambient_wind_rush", "death_drone",
		"music_wasteland", "music_city", "music_forest",
		"music_winter", "music_toxic", "music_scorched"
	]
	var engine_cars: Array[String] = ["pikap", "doge2", "barracuda", "buhanka", "vandura", "carson", "delorean", "k2500", "paz3205", "raptor"]
	for car_id: String in engine_cars:
		for st_i: int in range(3):
			for layer_k: String in ["idle", "mid", "howl"]:
				loop_files.append("engine_%s_s%d_%s" % [car_id, st_i, layer_k])
	for k: String in loop_files:
		var st := _load_audio(k)
		if st is AudioStreamWAV:
			var dup := (st as AudioStreamWAV).duplicate() as AudioStreamWAV
			var total_frames: int = roundi(dup.get_length() * float(dup.mix_rate))
			if total_frames <= 0:
				var bps_frame: int = 2 * (2 if dup.stereo else 1)
				total_frames = floori(float(dup.data.size()) / float(maxi(bps_frame, 1)))
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

	# Алиасы базовых дорожек двигателей без дублирования файлов на диске и в памяти
	for car_id: String in engine_cars:
		if _streams.has("engine_%s_s0_mid" % car_id):
			_streams["engine_%s" % car_id] = _streams["engine_%s_s0_mid" % car_id]
		if _streams.has("engine_%s_s0_idle" % car_id):
			_streams["engine_%s_idle" % car_id] = _streams["engine_%s_s0_idle" % car_id]
		if _streams.has("engine_%s_s0_howl" % car_id):
			_streams["engine_%s_howl" % car_id] = _streams["engine_%s_s0_howl" % car_id]

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
	_streams["susp_bump_1"] = _build_suspension_bump_wav(61101, 0.95)
	_streams["susp_bump_2"] = _build_suspension_bump_wav(61102, 1.00)
	_streams["susp_bump_3"] = _build_suspension_bump_wav(61103, 1.06)
	_streams["susp_land_cushion_1"] = _build_landing_cushion_wav(62101, 0.96)
	_streams["susp_land_cushion_2"] = _build_landing_cushion_wav(62102, 1.04)
	_streams["landing_scrape_soft_1"] = _build_landing_scrape_soft_wav(63101)
	_streams["landing_scrape_soft_2"] = _build_landing_scrape_soft_wav(63102)
	_streams["ice_slide_loop"] = _build_ice_slide_loop_wav(64201)
	_streams["prop_fall_metal_1"] = _build_prop_fall_metal_wav(65101)
	_streams["prop_fall_metal_2"] = _build_prop_fall_metal_wav(65102)
	_streams["prop_fall_wood_1"] = _build_prop_fall_wood_wav(65201)
	_streams["prop_fall_wood_2"] = _build_prop_fall_wood_wav(65202)
	_streams["prop_fall_concrete_1"] = _build_prop_fall_concrete_wav(65301)
	_streams["prop_fall_concrete_2"] = _build_prop_fall_concrete_wav(65302)
	_streams["wreck_fall_heavy_1"] = _build_wreck_fall_heavy_wav(65401)
	_streams["wreck_fall_heavy_2"] = _build_wreck_fall_heavy_wav(65402)
	_streams["env_desert_wind_loop"] = _build_env_biome_loop_wav("desert", 66101)
	_streams["env_city_ruins_loop"] = _build_env_biome_loop_wav("city", 66201)
	_streams["env_forest_wind_loop"] = _build_env_biome_loop_wav("forest", 66301)
	_streams["env_winter_blizzard_loop"] = _build_env_biome_loop_wav("winter", 66401)
	_streams["env_toxic_marsh_loop"] = _build_env_biome_loop_wav("toxic", 66501)
	_streams["env_fire_inferno_loop"] = _build_env_biome_loop_wav("fire", 66601)
	_streams["tornado_vortex_roar"] = _build_env_biome_loop_wav("tornado", 66701)
	_streams["env_detail_fire_pop"] = _build_env_detail_wav("fire_pop", 67101)
	_streams["env_detail_crow"] = _build_env_detail_wav("crow", 67201)
	_streams["env_detail_metal_creak"] = _build_env_detail_wav("metal_creak", 67301)
	_streams["env_detail_acid_bubble"] = _build_env_detail_wav("acid_bubble", 67401)
	_streams["env_detail_ice_gust"] = _build_env_detail_wav("ice_gust", 67501)
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

func _build_suspension_bump_wav(seed_val: int, pitch_bias: float) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.19
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_oil: float = 0.0
	var lp_sub: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.008, 0.0, 1.0)
		var sub_f: float = lerpf(58.0, 30.0, clampf(t * 14.0, 0.0, 1.0)) * pitch_bias
		var sub_thud: float = sin(TAU * sub_f * t) * atk * exp(-t * 21.0) * 0.78
		var bush_t: float = maxf(t - 0.014, 0.0)
		var bush: float = sin(TAU * (86.0 * pitch_bias) * bush_t) * clampf(bush_t / 0.006, 0.0, 1.0) * exp(-bush_t * 28.0) * 0.28
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_oil = lerpf(lp_oil, n, 0.16)
		lp_sub = lerpf(lp_sub, n, 0.05)
		var valve_bp: float = (lp_oil - lp_sub) * clampf(t / 0.012, 0.0, 1.0) * exp(-t * 19.0) * 0.42
		var mixed: float = (sub_thud + bush + valve_bp) * 1.10
		var warm: float = mixed / (1.0 + absf(mixed) * 0.48)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_landing_cushion_wav(seed_val: int, pitch_bias: float) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.34
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_oil: float = 0.0
	var lp_tire: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.010, 0.0, 1.0)
		var f_body: float = lerpf(74.0, 26.0, clampf(t * 10.0, 0.0, 1.0)) * pitch_bias
		var body_thump: float = sin(TAU * f_body * t) * atk * exp(-t * 12.5) * 0.85
		var t_reb: float = maxf(t - 0.055, 0.0)
		var rebound_swish: float = sin(TAU * (44.0 * pitch_bias) * t_reb) * clampf(t_reb / 0.018, 0.0, 1.0) * exp(-t_reb * 16.0) * 0.32
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_tire = lerpf(lp_tire, n, 0.07)
		lp_oil = lerpf(lp_oil, n, 0.22)
		var air_valve: float = (lp_oil - lp_tire) * clampf(t / 0.018, 0.0, 1.0) * exp(-t * 10.5) * 0.44
		var tire_pad: float = lp_tire * atk * exp(-t * 15.0) * 0.50
		var mixed: float = (body_thump + rebound_swish + air_valve + tire_pad) * 1.12
		var warm: float = mixed / (1.0 + absf(mixed) * 0.45)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_landing_scrape_soft_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.26
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_hi: float = 0.0
	var lp_lo: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_hi = lerpf(lp_hi, n, 0.56)
		lp_lo = lerpf(lp_lo, n, 0.22)
		var band: float = lp_hi - lp_lo
		var env: float = clampf(t / 0.012, 0.0, 1.0) * exp(-t * 14.0)
		var grit: float = 0.65 + 0.35 * sin(TAU * 42.0 * t + sin(t * 95.0))
		var mixed: float = band * env * grit * 0.95
		var warm: float = mixed / (1.0 + absf(mixed) * 0.50)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_ice_slide_loop_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 2.20
	var samples: int = int(mix_rate * duration)
	var fade_len: int = int(mix_rate * 0.18)
	var total_gen: int = samples + fade_len
	var buf := PackedFloat32Array()
	buf.resize(total_gen)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp_hi: float = 0.0
	var lp_lo: float = 0.0
	var lp_sub: float = 0.0
	for i in range(total_gen):
		var u: float = float(i % samples) / float(samples)
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_hi = lerpf(lp_hi, n, 0.36)
		lp_lo = lerpf(lp_lo, n, 0.10)
		lp_sub = lerpf(lp_sub, n, 0.035)
		var frost_glide: float = (lp_hi - lp_lo) * 0.62
		var ice_rumble: float = lp_sub * 0.28
		var swell: float = 0.84 + 0.16 * sin(TAU * 3.0 * u) * cos(TAU * 5.0 * u)
		buf[i] = (frost_glide + ice_rumble) * swell * 0.68

	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var val: float = buf[i]
		if i < fade_len:
			var w: float = float(i) / float(fade_len)
			val = lerpf(buf[samples + i], buf[i], w)
		var warm: float = val / (1.0 + absf(val) * 0.45)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.96, 0.96) * 32767.0)))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	return wav

func _build_prop_fall_metal_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.42
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var f_bias: float = 0.94 if (seed_val % 2) == 1 else 1.07
	var lp_n: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.005, 0.0, 1.0)
		var thud: float = sin(TAU * lerpf(130.0, 62.0, clampf(t * 18.0, 0.0, 1.0)) * f_bias * t) * atk * exp(-t * 17.0) * 0.65
		var ring: float = (
			sin(TAU * 218.0 * f_bias * t) * 0.45
			+ sin(TAU * 348.0 * f_bias * t) * 0.30
			+ sin(TAU * 524.0 * f_bias * t) * 0.16
		) * atk * exp(-t * 11.5)
		var t2: float = maxf(t - 0.105, 0.0)
		var bounce: float = (1.0 if t >= 0.105 else 0.0) * clampf(t2 / 0.004, 0.0, 1.0) * exp(-t2 * 19.0) * (
			sin(TAU * 185.0 * f_bias * t2) * 0.42 + sin(TAU * 395.0 * f_bias * t2) * 0.25
		)
		lp_n = lerpf(lp_n, rng.randf_range(-1.0, 1.0), 0.34)
		var clatter: float = lp_n * atk * exp(-t * 22.0) * 0.28
		var mixed: float = (thud + ring + bounce + clatter) * 1.05
		var warm: float = mixed / (1.0 + absf(mixed) * 0.48)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_prop_fall_wood_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.34
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var f_bias: float = 0.95 if (seed_val % 2) == 1 else 1.06
	var lp_w: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.004, 0.0, 1.0)
		var body: float = (
			sin(TAU * lerpf(165.0, 88.0, clampf(t * 24.0, 0.0, 1.0)) * f_bias * t) * 0.72
			+ sin(TAU * 292.0 * f_bias * t) * 0.32
		) * atk * exp(-t * 23.0)
		var t2: float = maxf(t - 0.092, 0.0)
		var clack: float = (1.0 if t >= 0.092 else 0.0) * clampf(t2 / 0.004, 0.0, 1.0) * exp(-t2 * 26.0) * (
			sin(TAU * 145.0 * f_bias * t2) * 0.45 + sin(TAU * 265.0 * f_bias * t2) * 0.24
		)
		lp_w = lerpf(lp_w, rng.randf_range(-1.0, 1.0), 0.24)
		var dry_crack: float = lp_w * atk * exp(-t * 28.0) * 0.35
		var mixed: float = (body + clack + dry_crack) * 1.12
		var warm: float = mixed / (1.0 + absf(mixed) * 0.45)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_prop_fall_concrete_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.40
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var f_bias: float = 0.93 if (seed_val % 2) == 1 else 1.05
	var lp_sub: float = 0.0
	var lp_grit: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.006, 0.0, 1.0)
		var thud: float = sin(TAU * lerpf(82.0, 32.0, clampf(t * 16.0, 0.0, 1.0)) * f_bias * t) * atk * exp(-t * 16.0) * 0.92
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_sub = lerpf(lp_sub, n, 0.09)
		lp_grit = lerpf(lp_grit, n, 0.45)
		var crunch: float = (lp_grit - lp_sub) * atk * exp(-t * 12.5) * 0.46 + lp_sub * exp(-t * 15.0) * 0.55
		var mixed: float = (thud + crunch) * 1.12
		var warm: float = mixed / (1.0 + absf(mixed) * 0.48)
		data.encode_s16(i * 2, int(round(clampf(warm, -0.98, 0.98) * 32767.0)))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = mix_rate
	wav.stereo = false
	wav.data = data
	return wav

func _build_wreck_fall_heavy_wav(seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.62
	var samples: int = int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var f_bias: float = 0.94 if (seed_val % 2) == 1 else 1.04
	var lp_low: float = 0.0
	var lp_rattle: float = 0.0
	for i in range(samples):
		var t: float = float(i) / float(mix_rate)
		var atk: float = clampf(t / 0.008, 0.0, 1.0)
		var slam: float = sin(TAU * lerpf(58.0, 22.0, clampf(t * 10.0, 0.0, 1.0)) * f_bias * t) * atk * exp(-t * 10.5) * 0.92
		var panel: float = (
			sin(TAU * 138.0 * f_bias * t) * 0.36
			+ sin(TAU * 236.0 * f_bias * t) * 0.24
		) * atk * exp(-t * 13.0)
		var t2: float = maxf(t - 0.14, 0.0)
		var rebound: float = (1.0 if t >= 0.14 else 0.0) * clampf(t2 / 0.010, 0.0, 1.0) * exp(-t2 * 12.0) * (
			sin(TAU * 46.0 * f_bias * t2) * 0.48 + sin(TAU * 168.0 * f_bias * t2) * 0.22
		)
		var n: float = rng.randf_range(-1.0, 1.0)
		lp_low = lerpf(lp_low, n, 0.08)
		lp_rattle = lerpf(lp_rattle, n, 0.38)
		var rattle_burst: float = (lp_rattle - lp_low) * (0.55 + 0.45 * sin(t * 54.0)) * atk * exp(-t * 8.0) * 0.42
		var mixed: float = (slam + panel + rebound + rattle_burst + lp_low * atk * exp(-t * 9.0) * 0.45) * 1.15
		var warm: float = mixed / (1.0 + absf(mixed) * 0.48)
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

	var env_init := _streams.get("env_desert_wind_loop", _streams.get("ambient_wind")) as AudioStream
	_biome_env_player = AudioStreamPlayer.new()
	_biome_env_player.name = "BiomeEnvSoundscape"
	_biome_env_player.bus = BUS_AMBIENCE
	_biome_env_player.volume_db = -60.0
	add_child(_biome_env_player)
	if env_init:
		_biome_env_player.stream = env_init
		_biome_env_player.play()

	var fire_init := _streams.get("fire_crackle_loop") as AudioStream
	_biome_fire_player = AudioStreamPlayer.new()
	_biome_fire_player.name = "BiomeFireLoop"
	_biome_fire_player.bus = BUS_AMBIENCE
	_biome_fire_player.volume_db = -60.0
	add_child(_biome_fire_player)
	if fire_init:
		_biome_fire_player.stream = fire_init
		_biome_fire_player.play()

	var tornado_sub := _streams.get("tornado_vortex_roar", tornado_stream) as AudioStream
	_tornado_sub_player = AudioStreamPlayer.new()
	_tornado_sub_player.name = "TornadoSubRoar"
	_tornado_sub_player.bus = BUS_AMBIENCE
	_tornado_sub_player.volume_db = -60.0
	add_child(_tornado_sub_player)
	if tornado_sub:
		_tornado_sub_player.stream = tornado_sub
		_tornado_sub_player.play()

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

	if is_instance_valid(_biome_env_player):
		var env_dest: float = -60.0 if (paused_now or _muted) else _target_biome_env_db
		_biome_env_player.volume_db = lerpf(_biome_env_player.volume_db, env_dest, clampf(real_dt * 2.4, 0.0, 1.0))
		_biome_env_player.pitch_scale = lerpf(_biome_env_player.pitch_scale, _target_biome_env_pitch, clampf(real_dt * 1.8, 0.0, 1.0))

	if is_instance_valid(_biome_fire_player):
		var fire_dest: float = -60.0 if (paused_now or _muted) else _target_biome_fire_db
		_biome_fire_player.volume_db = lerpf(_biome_fire_player.volume_db, fire_dest, clampf(real_dt * 2.8, 0.0, 1.0))

	if is_instance_valid(_tornado_sub_player):
		var tsub_dest: float = -60.0 if (paused_now or _muted) else _target_tornado_sub_db
		_tornado_sub_player.volume_db = lerpf(_tornado_sub_player.volume_db, tsub_dest, clampf(real_dt * 3.6, 0.0, 1.0))

	if is_instance_valid(_wind_rush_player) and paused_now:
		_wind_rush_player.volume_db = -60.0

	if _in_gameplay_biome and not paused_now and not _muted and not _sfx_pool.is_empty():
		var now_ms: int = Time.get_ticks_msec()
		if now_ms - _last_env_detail_ms >= _next_env_detail_delay_ms:
			_last_env_detail_ms = now_ms
			match _current_biome_id:
				5, 6, 7:
					var st_pop := _streams.get("env_detail_fire_pop") as AudioStream
					if st_pop:
						var pop_db: float = -15.5 if _current_biome_id == 6 else (-19.0 if _current_biome_id == 7 else -24.0)
						_play_pool_slot(st_pop, BUS_AMBIENCE, pop_db, randf_range(0.84, 1.24))
					_next_env_detail_delay_ms = randi_range(1200, 2900)
				4:
					var st_bub := _streams.get("env_detail_acid_bubble") as AudioStream
					if st_bub:
						_play_pool_slot(st_bub, BUS_AMBIENCE, -19.0, randf_range(0.86, 1.18))
					_next_env_detail_delay_ms = randi_range(2600, 5200)
				3:
					var st_ice := _streams.get("env_detail_ice_gust") as AudioStream
					if st_ice:
						_play_pool_slot(st_ice, BUS_AMBIENCE, -18.5, randf_range(0.88, 1.15))
					_next_env_detail_delay_ms = randi_range(3400, 6800)
				1:
					var key_c: String = "env_detail_metal_creak" if (randi() % 2) == 0 else "env_detail_crow"
					var st_c := _streams.get(key_c) as AudioStream
					if st_c:
						_play_pool_slot(st_c, BUS_AMBIENCE, -21.0, randf_range(0.86, 1.14))
					_next_env_detail_delay_ms = randi_range(4200, 8200)
				_:
					var st_crow := _streams.get("env_detail_crow") as AudioStream
					if st_crow:
						_play_pool_slot(st_crow, BUS_AMBIENCE, -22.5, randf_range(0.88, 1.14))
					_next_env_detail_delay_ms = randi_range(4800, 9200)

func set_menu_ambience() -> void:
	_in_gameplay_biome = false
	_target_death_drone_db = -60.0
	_target_rain_db = -60.0
	_target_tornado_db = -60.0
	_target_biome_env_db = -60.0
	_target_biome_fire_db = -60.0
	_target_tornado_sub_db = -60.0
	_target_amb_db = -8.0
	_target_amb_pitch = 1.0
	var menu_st := _streams.get("music_wasteland", _streams.get("ambient_wind")) as AudioStream
	if is_instance_valid(_ambience_player) and menu_st and _ambience_player.stream != menu_st:
		_ambience_player.stream = menu_st
		_ambience_player.play()
	if is_instance_valid(_wind_rush_player):
		_wind_rush_player.volume_db = -60.0
	if is_instance_valid(_biome_env_player):
		_biome_env_player.volume_db = -60.0
	if is_instance_valid(_biome_fire_player):
		_biome_fire_player.volume_db = -60.0
	if is_instance_valid(_tornado_sub_player):
		_tornado_sub_player.volume_db = -60.0

func set_biome_ambience(biome_id: int, red_zone: bool) -> void:
	_current_biome_id = biome_id
	_in_gameplay_biome = true
	_target_death_drone_db = -19.5 if red_zone else -60.0
	var stream_key: String = "music_wasteland"
	var env_key: String = "env_desert_wind_loop"
	_target_biome_fire_db = -60.0
	_target_biome_env_pitch = 1.0
	match biome_id:
		1: # RUINED_CITY
			stream_key = "music_city"
			_target_amb_db = -7.8
			_target_amb_pitch = 1.00
			env_key = "env_city_ruins_loop"
			_target_biome_env_db = -15.5
		2: # DARK_FOREST
			stream_key = "music_forest"
			_target_amb_db = -7.4
			_target_amb_pitch = 1.00
			env_key = "env_forest_wind_loop"
			_target_biome_env_db = -15.0
		3: # WINTER_ICE
			stream_key = "music_winter"
			_target_amb_db = -7.2
			_target_amb_pitch = 1.00
			env_key = "env_winter_blizzard_loop"
			_target_biome_env_db = -13.5
			_target_biome_env_pitch = 1.02
		4: # TOXIC_MARSH / ACID_STORM
			stream_key = "music_toxic"
			_target_amb_db = -7.5
			_target_amb_pitch = 0.98
			env_key = "env_toxic_marsh_loop"
			_target_biome_env_db = -14.5
			_target_biome_env_pitch = 0.98
		5: # SCORCHED_CANYON
			stream_key = "music_scorched"
			_target_amb_db = -7.5
			_target_amb_pitch = 0.98
			env_key = "env_desert_wind_loop"
			_target_biome_env_db = -16.0
			_target_biome_env_pitch = 0.94
			_target_biome_fire_db = -21.5
		6: # BURNING_CITY
			stream_key = "music_scorched"
			_target_amb_db = -7.3
			_target_amb_pitch = 0.95
			env_key = "env_fire_inferno_loop"
			_target_biome_env_db = -10.5
			_target_biome_fire_db = -10.0
		7: # BURNT_FOREST
			stream_key = "music_forest"
			_target_amb_db = -7.6
			_target_amb_pitch = 0.92
			env_key = "env_fire_inferno_loop"
			_target_biome_env_db = -14.5
			_target_biome_env_pitch = 0.92
			_target_biome_fire_db = -15.5
		8: # OVERGROWN_HIGHWAY
			stream_key = "music_forest"
			_target_amb_db = -7.4
			_target_amb_pitch = 1.03
			env_key = "env_forest_wind_loop"
			_target_biome_env_db = -16.5
			_target_biome_env_pitch = 1.05
		_: # WASTELAND
			stream_key = "music_wasteland"
			_target_amb_db = -7.6
			_target_amb_pitch = 1.00
			env_key = "env_desert_wind_loop"
			_target_biome_env_db = -16.5
	if red_zone:
		_target_amb_db += 0.8
		_target_amb_pitch *= 0.95
		_target_biome_env_db += 1.5
		if _target_biome_fire_db > -55.0:
			_target_biome_fire_db += 1.0
	var target_st := _streams.get(stream_key, _streams.get("ambient_wind")) as AudioStream
	if is_instance_valid(_ambience_player) and target_st:
		if _ambience_player.stream != target_st or not _ambience_player.playing:
			_ambience_player.volume_db = minf(_ambience_player.volume_db, -18.0)
			_ambience_player.stream = target_st
			_ambience_player.play()
	var env_st := _streams.get(env_key, _streams.get("ambient_wind")) as AudioStream
	if is_instance_valid(_biome_env_player) and env_st:
		if _biome_env_player.stream != env_st or not _biome_env_player.playing:
			_biome_env_player.volume_db = minf(_biome_env_player.volume_db, -24.0)
			_biome_env_player.stream = env_st
			_biome_env_player.play()
	if is_instance_valid(_biome_fire_player):
		var fire_st := _streams.get("fire_crackle_loop") as AudioStream
		if fire_st and (_biome_fire_player.stream != fire_st or (not _biome_fire_player.playing and _target_biome_fire_db > -55.0)):
			_biome_fire_player.stream = fire_st
			_biome_fire_player.play()

func set_death_ambience(active: bool) -> void:
	if active:
		# После смерти не запускаем зацикленный дрон и не искажаем звук — остаётся только чистый эмбиент текущего биома
		_target_death_drone_db = -60.0
		_target_tornado_db = -60.0
		_target_tornado_sub_db = -60.0
		_target_amb_db = -10.5
		_target_amb_pitch = 1.0
		if _target_biome_env_db > -55.0:
			_target_biome_env_db = minf(_target_biome_env_db, -17.5)
		if _target_biome_fire_db > -55.0:
			_target_biome_fire_db = minf(_target_biome_fire_db, -17.5)
		if is_instance_valid(_death_drone_player):
			_death_drone_player.stop()
			_death_drone_player.volume_db = -60.0
		if is_instance_valid(_weather_tornado_player):
			_weather_tornado_player.stop()
			_weather_tornado_player.volume_db = -60.0
		if is_instance_valid(_tornado_sub_player):
			_tornado_sub_player.stop()
			_tornado_sub_player.volume_db = -60.0
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

	var ice_slide := AudioStreamPlayer.new()
	ice_slide.name = "IceSlideAudioPlayer"
	ice_slide.bus = BUS_VEHICLES
	var ice_stream := get_stream("ice_slide_loop")
	if ice_stream:
		ice_slide.stream = ice_stream
	ice_slide.volume_db = -60.0
	vehicle.add_child(ice_slide)

	var fire_p := AudioStreamPlayer.new()
	fire_p.name = "EngineFireAudioPlayer"
	fire_p.bus = BUS_VEHICLES
	var fstream := get_stream("fire_crackle_loop")
	if fstream:
		fire_p.stream = fstream
	fire_p.volume_db = -60.0
	vehicle.add_child(fire_p)

	return {"engine": eng, "engine_idle": eng_idle, "engine_howl": eng_howl, "engine_boost": eng_boost, "skid": skid, "ice_slide": ice_slide, "fire": fire_p}

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
var _last_susp_bump_ms: int = 0
var _last_prop_hit_ms: int = 0
var _last_prop_fall_ms: int = 0
var _last_wreck_fall_ms: int = 0

func play_suspension_bump(intensity: float = 0.5, heavy_vehicle: bool = false) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_susp_bump_ms < 135:
		return
	_last_susp_bump_ms = now
	var t_int: float = clampf(intensity, 0.20, 1.25)
	var keys: Array[String] = ["susp_bump_1", "susp_bump_2", "susp_bump_3"]
	var st := _streams.get(keys[randi() % keys.size()]) as AudioStream
	if st:
		var vol_db: float = lerpf(-14.0, -5.5, clampf((t_int - 0.20) / 1.05, 0.0, 1.0))
		var pitch: float = randf_range(0.82, 0.94) if heavy_vehicle else randf_range(0.95, 1.08)
		_play_pool_slot(st, BUS_VEHICLES, vol_db, pitch)

func play_car_landing(intensity: float = 1.0, heavy_vehicle: bool = false) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var now := Time.get_ticks_msec()
	if now - _last_landing_ms < 160:
		return
	_last_landing_ms = now
	var t_int: float = clampf(intensity, 0.35, 1.5)
	var t01: float = clampf((t_int - 0.35) / 1.15, 0.0, 1.0)
	var c_key: String = "susp_land_cushion_1" if (randi() % 2) == 0 else "susp_land_cushion_2"
	var cushion_st := _streams.get(c_key) as AudioStream
	if cushion_st:
		var vol_db: float = lerpf(-7.5, -2.0, t01)
		var pitch: float = randf_range(0.80, 0.92) if heavy_vehicle else randf_range(0.94, 1.08)
		_play_pool_slot(cushion_st, BUS_VEHICLES, vol_db, pitch)
	var old_key: String = "car_landing_heavy" if (t_int >= 0.72 or heavy_vehicle) else "car_landing_light"
	var old_st := _streams.get(old_key) as AudioStream
	if old_st:
		var old_db: float = lerpf(-8.5, -2.2, t01)
		var old_pitch: float = randf_range(0.82, 0.96) if heavy_vehicle else randf_range(0.94, 1.08)
		_play_pool_slot(old_st, BUS_VEHICLES, old_db, old_pitch)
	if t_int > 0.88:
		var hard_t: float = clampf((t_int - 0.88) / 0.62, 0.0, 1.0)
		var sc_key: String = "landing_scrape_soft_1" if (randi() % 2) == 0 else "landing_scrape_soft_2"
		var scrape_st := _streams.get(sc_key) as AudioStream
		if scrape_st:
			_play_pool_slot(scrape_st, BUS_SFX, lerpf(-11.0, -7.0, hard_t), randf_range(0.90, 1.12))
		var metal_st := _streams.get("crash_metal") as AudioStream
		if metal_st:
			_play_pool_slot(metal_st, BUS_SFX, lerpf(-13.5, -8.0, hard_t), randf_range(0.78, 0.94))

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

func play_prop_fall(mat_kind: String, impact_speed: float, world_pos: Vector3, is_heavy_wreck: bool = false) -> void:
	if _muted or _sfx_pool.is_empty():
		return
	var dist_db: float = 0.0
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	if is_instance_valid(cam):
		var dist: float = cam.global_position.distance_to(world_pos)
		if dist > 72.0:
			return
		dist_db = lerpf(0.0, -24.0, clampf((dist - 5.0) / 62.0, 0.0, 1.0))

	var now := Time.get_ticks_msec()
	if is_heavy_wreck or mat_kind == "wreck":
		if now - _last_wreck_fall_ms < 95:
			return
		_last_wreck_fall_ms = now
	else:
		if now - _last_prop_fall_ms < 50:
			return
		_last_prop_fall_ms = now

	var suffix: String = "1" if (randi() % 2) == 0 else "2"
	var key: String = "prop_fall_metal_" + suffix
	var extra_key: String = "prop_clang_metal"
	if is_heavy_wreck or mat_kind == "wreck":
		key = "wreck_fall_heavy_" + suffix
		extra_key = "crash_metal"
	elif mat_kind == "wood":
		key = "prop_fall_wood_" + suffix
		extra_key = "prop_snap_wood"
	elif mat_kind == "concrete":
		key = "prop_fall_concrete_" + suffix
		extra_key = "prop_crumble_concrete"

	var st := _streams.get(key) as AudioStream
	if st:
		var spd_t: float = clampf((impact_speed - 2.0) / 16.0, 0.0, 1.0)
		var base_db: float = lerpf(-12.5, -2.0, spd_t) if (is_heavy_wreck or mat_kind == "wreck") else lerpf(-13.5, -4.5, spd_t)
		_play_pool_slot(st, BUS_SFX, base_db + dist_db, randf_range(0.86, 1.14))
	if impact_speed > 7.5:
		var extra_st := _streams.get(extra_key) as AudioStream
		if extra_st:
			_play_pool_slot(extra_st, BUS_SFX, -11.0 + dist_db, randf_range(0.85, 1.10))

func stop_transient_sfx() -> void:
	_in_gameplay_biome = false
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
	_target_tornado_sub_db = -60.0
	_target_biome_env_db = -60.0
	_target_biome_fire_db = -60.0
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
	_target_tornado_sub_db = lerpf(-26.0, -4.5, tor) if tor > 0.02 else -60.0
	if tor > 0.02:
		if is_instance_valid(_weather_tornado_player) and _weather_tornado_player.stream != null and not _weather_tornado_player.playing:
			_weather_tornado_player.play()
		if is_instance_valid(_tornado_sub_player) and _tornado_sub_player.stream != null and not _tornado_sub_player.playing:
			_tornado_sub_player.play()

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


func _build_env_biome_loop_wav(kind: String, seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 2.4
	var samples: int = int(float(mix_rate) * duration)
	var fade_len: int = int(float(mix_rate) * 0.18)
	var total_samples: int = samples + fade_len
	var buf := PackedFloat32Array()
	buf.resize(total_samples)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp1: float = 0.0
	var lp2: float = 0.0
	var lp3: float = 0.0
	var lp4: float = 0.0
	var crackle_env: float = 0.0
	var crackle_sign: float = 1.0
	var bubble_t: float = -1.0
	var bubble_f0: float = 190.0

	for i: int in range(total_samples):
		var t: float = float(i % samples) / float(mix_rate)
		var wn: float = rng.randf_range(-1.0, 1.0)
		lp1 = lerpf(lp1, wn, 0.24)
		lp2 = lerpf(lp2, lp1, 0.11)
		lp3 = lerpf(lp3, lp2, 0.05)
		lp4 = lerpf(lp4, lp3, 0.018)

		var s: float = 0.0
		match kind:
			"desert":
				var gust: float = 0.58 + 0.42 * sin(TAU * (1.0 / duration) * t)
				var whistle_f: float = 285.0 + 48.0 * sin(TAU * (2.0 / duration) * t)
				var dry_band: float = (lp1 - lp3) * (0.45 + 0.55 * gust)
				var howl: float = sin(TAU * whistle_f * t) * (0.045 + 0.040 * gust)
				s = dry_band * 0.65 + lp4 * 0.28 + howl
			"city":
				var hollow: float = (sin(TAU * 62.0 * t) * 0.07 + sin(TAU * 94.0 * t) * 0.05)
				var draft: float = 0.55 + 0.45 * cos(TAU * (2.0 / duration) * t)
				var grit: float = (lp2 - lp4) * (0.45 + 0.50 * draft)
				s = hollow + grit * 0.72 + (wn - lp1) * 0.06
			"forest":
				var swell: float = 0.52 + 0.48 * sin(TAU * (2.0 / duration) * t + 0.7)
				var foliage: float = (wn - lp2) * (0.14 + 0.16 * swell)
				var canopy: float = (lp2 - lp4) * 0.55
				s = foliage + canopy + lp4 * 0.22
			"winter":
				var gale_mod: float = 0.55 + 0.45 * sin(TAU * (2.0 / duration) * t + 0.4)
				var gale_f: float = 470.0 + 170.0 * sin(TAU * (1.0 / duration) * t)
				var frost_hiss: float = (wn - lp2) * (0.20 + 0.16 * gale_mod)
				var whistle: float = sin(TAU * gale_f * t) * (0.055 + 0.050 * gale_mod)
				s = frost_hiss + (lp1 - lp3) * 0.48 + whistle
			"toxic":
				var sub: float = sin(TAU * 48.0 * t) * 0.10 + sin(TAU * 73.0 * t) * 0.06
				var murk: float = (lp2 - lp4) * 0.58 + lp4 * 0.35
				if bubble_t < 0.0 and rng.randf() < 0.00028:
					bubble_t = 0.0
					bubble_f0 = rng.randf_range(160.0, 310.0)
				var b_sig: float = 0.0
				if bubble_t >= 0.0:
					bubble_t += 1.0 / float(mix_rate)
					var bt_n: float = bubble_t / 0.11
					if bt_n >= 1.0:
						bubble_t = -1.0
					else:
						var bf: float = bubble_f0 + bt_n * 380.0
						b_sig = sin(TAU * bf * bubble_t) * sin(PI * bt_n) * 0.20
				s = sub + murk + (wn - lp1) * 0.07 + b_sig
			"fire":
				var flame_mod: float = 0.65 + 0.35 * sin(TAU * (3.0 / duration) * t)
				if rng.randf() < 0.0045:
					crackle_env = rng.randf_range(0.35, 0.95)
					crackle_sign = -1.0 if rng.randf() < 0.5 else 1.0
				var crackle: float = crackle_env * crackle_sign * (0.45 + 0.55 * wn)
				crackle_env *= 0.91
				var roar: float = lp3 * 0.85 + (lp1 - lp3) * (0.62 * flame_mod)
				s = roar + crackle * 0.34
			_: # tornado
				var shear: float = 0.58 + 0.42 * sin(TAU * (3.0 / duration) * t) + 0.16 * cos(TAU * (5.0 / duration) * t)
				var vortex_sub: float = (sin(TAU * 38.0 * t) * 0.20 + sin(TAU * 57.0 * t) * 0.13) * (0.7 + 0.3 * shear)
				var rush: float = (lp1 - lp4) * (0.72 * shear) + lp4 * 0.95
				s = vortex_sub + rush

		buf[i] = clampf(s * 0.78, -0.95, 0.95)

	for k: int in range(fade_len):
		var alpha: float = float(k) / float(fade_len)
		buf[k] = buf[k] * alpha + buf[samples + k] * (1.0 - alpha)

	var data := PackedByteArray()
	data.resize(samples * 2)
	for j: int in range(samples):
		data.encode_s16(j * 2, clampi(int(buf[j] * 32767.0), -32768, 32767))

	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = mix_rate
	st.stereo = false
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = samples
	st.data = data
	return st


func _build_env_detail_wav(kind: String, seed_val: int) -> AudioStreamWAV:
	var mix_rate: int = 22050
	var duration: float = 0.85
	match kind:
		"fire_pop":
			duration = 0.38
		"acid_bubble":
			duration = 0.42
		"crow":
			duration = 0.78
		"metal_creak":
			duration = 0.90
		_:
			duration = 0.85
	var samples: int = int(float(mix_rate) * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var lp: float = 0.0

	for i: int in range(samples):
		var t: float = float(i) / float(mix_rate)
		var n: float = t / duration
		var wn: float = rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, wn, 0.18)
		var env: float = clampf(n / 0.08, 0.0, 1.0) * pow(1.0 - n, 1.8)
		var s: float = 0.0
		match kind:
			"fire_pop":
				var snap: float = sin(TAU * 135.0 * t * exp(-t * 14.0)) * exp(-t * 28.0) * 0.65
				var fizz: float = (wn - lp) * exp(-t * 9.5) * 0.45
				s = snap + fizz
			"crow":
				var caw1: float = 1.0 if (t >= 0.04 and t <= 0.28) else 0.0
				var caw2: float = 1.0 if (t >= 0.38 and t <= 0.66) else 0.0
				var p1: float = clampf((t - 0.04) / 0.24, 0.0, 1.0)
				var p2: float = clampf((t - 0.38) / 0.28, 0.0, 1.0)
				var w_env: float = caw1 * sin(PI * p1) + caw2 * sin(PI * p2) * 0.88
				var freq: float = lerpf(640.0, 430.0, p1 if caw1 > 0.0 else p2)
				var rasp: float = sin(TAU * freq * t + sin(TAU * 92.0 * t) * 1.45)
				var overtone: float = sin(TAU * freq * 2.04 * t) * 0.35
				s = (rasp + overtone + wn * 0.12) * w_env * 0.48
			"metal_creak":
				var f_base: float = 242.0 - 42.0 * n + 14.0 * sin(TAU * 9.0 * t)
				var tone: float = sin(TAU * f_base * t) * 0.42 + sin(TAU * f_base * 1.53 * t) * 0.30
				var grind: float = (wn - lp) * (0.18 + 0.18 * sin(TAU * 14.0 * t))
				s = (tone + grind) * env * 0.62
			"acid_bubble":
				var b1_t: float = clampf((t - 0.02) / 0.14, 0.0, 1.0)
				var b2_t: float = clampf((t - 0.20) / 0.16, 0.0, 1.0)
				var b1_on: float = 1.0 if (t >= 0.02 and t <= 0.16) else 0.0
				var b2_on: float = 1.0 if (t >= 0.20 and t <= 0.36) else 0.0
				var s1: float = sin(TAU * lerpf(185.0, 540.0, b1_t) * t) * sin(PI * b1_t) * b1_on
				var s2: float = sin(TAU * lerpf(235.0, 690.0, b2_t) * t) * sin(PI * b2_t) * b2_on * 0.82
				s = (s1 + s2) * 0.55 + (lp * 0.06 * (1.0 - n))
			_: # ice_gust
				var arch: float = sin(PI * n)
				var sweep_f: float = 420.0 + 280.0 * arch
				var crystal: float = sin(TAU * sweep_f * t) * 0.12
				s = ((wn - lp) * 0.45 + lp * 0.28 + crystal) * arch

		data.encode_s16(i * 2, clampi(int(clampf(s * 0.80, -0.95, 0.95) * 32767.0), -32768, 32767))

	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = mix_rate
	st.stereo = false
	st.loop_mode = AudioStreamWAV.LOOP_DISABLED
	st.data = data
	return st
