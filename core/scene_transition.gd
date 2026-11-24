extends Node

## Пост-апокалиптический переход между сценами с атмосферным фоном из игры,
## нижней тактической панелью телеметрии и неблокирующей потоковой загрузкой.

const TRANSITION_SHADER: Shader = preload("res://ui/shaders/scene_transition.gdshader")
const FONT_HEADER: Font = preload("res://assets/fonts/RussoOne-Regular.ttf")
const FONT_BODY: Font = preload("res://assets/fonts/Jura-Variable.ttf")
const BOOT_SPLASH_TEX: Texture2D = preload("res://assets/textures/ui/boot_splash.png")

const _TIPS: Array[String] = [
	"СОВЕТ: Прокачка двигателя каждые 5 уровней открывает более мощный рёв мотора и нагнетатель",
	"СОВЕТ: Полная прокачка 50/50 открывает боевую броню и защитные обвесы",
	"СОВЕТ: На БТР и ПАЗ-3205 турель ведёт огонь по нажатию ПРОБЕЛ",
	"СОВЕТ: После каждого моста орда становится плотнее и опаснее — следи за бронёй",
	"СОВЕТ: Сбивайте красные бочки и собирайте комбо для дозаправки на ходу",
]

var _layer: CanvasLayer = null
var _overlay: ColorRect = null
var _mat: ShaderMaterial = null
var _backdrop_tex: TextureRect = null

var _load_ui: Control = null
var _spinner: TextureRect = null
var _title_lbl: Label = null
var _stage_lbl: Label = null
var _pct_lbl: Label = null
var _tip_lbl: Label = null
var _bar: ProgressBar = null

var _is_transitioning: bool = false
var _shader_time: float = 0.0
var _target_progress: float = 0.0
var _shown_progress: float = 0.0
var _tip_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_overlay()

func _process(delta: float) -> void:
	if _layer == null or not _layer.visible:
		return
	var dt := clampf(delta, 0.0, 0.05)
	_shader_time += dt
	if _mat != null:
		_mat.set_shader_parameter("time_sec", _shader_time)
	if is_instance_valid(_load_ui) and _load_ui.visible:
		if is_instance_valid(_spinner):
			_spinner.rotation += dt * 3.6
		_shown_progress = lerpf(_shown_progress, _target_progress, clampf(dt * 11.0, 0.0, 1.0))
		if absf(_target_progress - _shown_progress) < 0.004:
			_shown_progress = _target_progress
		if is_instance_valid(_bar):
			_bar.value = _shown_progress
		if is_instance_valid(_pct_lbl):
			_pct_lbl.text = "%d%%" % clampi(roundi(_shown_progress * 100.0), 0, 100)

func _make_spinner_tex(size_px: int = 96) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var half := float(size_px) * 0.5
	var r_outer := half * 0.88
	var r_inner := half * 0.62
	for y in range(size_px):
		for x in range(size_px):
			var dx := float(x) + 0.5 - half
			var dy := float(y) + 0.5 - half
			var dist := sqrt(dx * dx + dy * dy)
			if dist < r_inner - 1.5 or dist > r_outer + 1.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var ring_a := clampf(minf(dist - (r_inner - 1.5), (r_outer + 1.5) - dist) / 2.2, 0.0, 1.0)
			var ang := fmod(atan2(dy, dx) + TAU, TAU) / TAU
			var arc_fade := pow(1.0 - ang, 1.35)
			var gap := 0.0 if (ang > 0.78 and ang < 0.84) or (ang > 0.90 and ang < 0.95) else 1.0
			var alpha := ring_a * arc_fade * gap
			var col := Color(1.0, 0.72, 0.24).lerp(Color(0.90, 0.26, 0.10), clampf(ang * 1.15, 0.0, 1.0))
			img.set_pixel(x, y, Color(col.r, col.g, col.b, clampf(alpha, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _make_hazard_stripe_tex(w: int = 16, h: int = 128) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		for x in range(w):
			var band := fposmod(float(x + y) / 14.0, 1.0)
			if band < 0.50:
				img.set_pixel(x, y, Color(0.92, 0.36, 0.12, 0.92))
			else:
				img.set_pixel(x, y, Color(0.08, 0.08, 0.10, 0.92))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _ensure_overlay() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "SceneTransitionLayer"
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.visible = false
	add_child(_layer)

	_overlay = ColorRect.new()
	_overlay.name = "TransitionVeil"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1.0, 1.0, 1.0, 1.0)

	_mat = ShaderMaterial.new()
	_mat.shader = TRANSITION_SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("time_sec", 0.0)
	_overlay.material = _mat
	_layer.add_child(_overlay)

	_build_loading_ui()

func _build_loading_ui() -> void:
	_load_ui = Control.new()
	_load_ui.name = "LoadingOverlayUI"
	_load_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_load_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_ui.visible = false
	_load_ui.modulate.a = 0.0
	_layer.add_child(_load_ui)

	_backdrop_tex = TextureRect.new()
	_backdrop_tex.name = "AtmosphericBackdrop"
	_backdrop_tex.texture = BOOT_SPLASH_TEX
	_backdrop_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop_tex.modulate = Color(0.75, 0.72, 0.74, 0.42)
	_backdrop_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_load_ui.add_child(_backdrop_tex)

	# Full-width sleek bottom tactical telemetry deck
	var footer := PanelContainer.new()
	footer.name = "TacticalFooter"
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -126
	footer.offset_bottom = 0
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb_footer := StyleBoxFlat.new()
	sb_footer.bg_color = Color(0.032, 0.036, 0.046, 0.94)
	sb_footer.border_color = Color(0.92, 0.40, 0.14, 0.88)
	sb_footer.border_width_top = 2
	sb_footer.content_margin_left = 0
	sb_footer.content_margin_right = 0
	sb_footer.content_margin_top = 0
	sb_footer.content_margin_bottom = 0
	footer.add_theme_stylebox_override("panel", sb_footer)
	_load_ui.add_child(footer)

	var outer_hbox := HBoxContainer.new()
	outer_hbox.add_theme_constant_override("separation", 0)
	outer_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(outer_hbox)

	var hazard_bar := TextureRect.new()
	hazard_bar.texture = _make_hazard_stripe_tex(12, 128)
	hazard_bar.custom_minimum_size = Vector2(10, 0)
	hazard_bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hazard_bar.stretch_mode = TextureRect.STRETCH_TILE
	hazard_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_hbox.add_child(hazard_bar)

	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_theme_constant_override("margin_left", 28)
	pad.add_theme_constant_override("margin_right", 36)
	pad.add_theme_constant_override("margin_top", 16)
	pad.add_theme_constant_override("margin_bottom", 18)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer_hbox.add_child(pad)

	var vstack := VBoxContainer.new()
	vstack.add_theme_constant_override("separation", 12)
	vstack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(vstack)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 18)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vstack.add_child(top_row)

	_spinner = TextureRect.new()
	_spinner.texture = _make_spinner_tex(96)
	_spinner.custom_minimum_size = Vector2(46, 46)
	_spinner.pivot_offset = Vector2(23, 23)
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_spinner)

	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 3)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(left_col)

	_title_lbl = Label.new()
	_title_lbl.text = "ВЫЕЗД НА ТРАССУ"
	_title_lbl.add_theme_font_override("font", FONT_HEADER)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90, 1.0))
	left_col.add_child(_title_lbl)

	_tip_lbl = Label.new()
	_tip_lbl.text = _TIPS[0]
	_tip_lbl.add_theme_font_override("font", FONT_BODY)
	_tip_lbl.add_theme_font_size_override("font_size", 13)
	_tip_lbl.add_theme_color_override("font_color", Color(0.68, 0.71, 0.76, 0.90))
	_tip_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	left_col.add_child(_tip_lbl)

	var right_col := HBoxContainer.new()
	right_col.add_theme_constant_override("separation", 16)
	right_col.alignment = BoxContainer.ALIGNMENT_END
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(right_col)

	_stage_lbl = Label.new()
	_stage_lbl.text = "ЗАГРУЗКА..."
	_stage_lbl.add_theme_font_override("font", FONT_BODY)
	_stage_lbl.add_theme_font_size_override("font_size", 14)
	_stage_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88, 0.95))
	right_col.add_child(_stage_lbl)

	_pct_lbl = Label.new()
	_pct_lbl.text = "0%"
	_pct_lbl.custom_minimum_size = Vector2(72, 0)
	_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct_lbl.add_theme_font_override("font", FONT_HEADER)
	_pct_lbl.add_theme_font_size_override("font_size", 24)
	_pct_lbl.add_theme_color_override("font_color", Color(0.98, 0.62, 0.20, 1.0))
	right_col.add_child(_pct_lbl)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 8)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.09, 0.10, 0.13, 1.0)
	sb_track.border_color = Color(0.22, 0.24, 0.29, 0.80)
	sb_track.set_border_width_all(1)
	sb_track.set_corner_radius_all(2)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.96, 0.44, 0.14, 1.0)
	sb_fill.set_corner_radius_all(2)
	_bar.add_theme_stylebox_override("background", sb_track)
	_bar.add_theme_stylebox_override("fill", sb_fill)
	vstack.add_child(_bar)

func is_transitioning() -> bool:
	return _is_transitioning

func set_tint_for_scene(scene_path: String) -> void:
	_ensure_overlay()
	if _mat == null:
		return
	if scene_path.find("Shop_Hungar") >= 0:
		_mat.set_shader_parameter("fog_color_dark", Color(0.024, 0.027, 0.034, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.11, 0.10, 0.10, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.95, 0.42, 0.16, 1.0))
	elif scene_path.find("main.tscn") >= 0:
		_mat.set_shader_parameter("fog_color_dark", Color(0.025, 0.025, 0.032, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.12, 0.09, 0.085, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.96, 0.34, 0.12, 1.0))
	else:
		_mat.set_shader_parameter("fog_color_dark", Color(0.025, 0.028, 0.035, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.10, 0.10, 0.11, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.90, 0.38, 0.14, 1.0))

func _set_progress(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress", clampf(v, 0.0, 1.0))

func _configure_loading_labels(scene_path: String) -> void:
	_target_progress = 0.04
	_shown_progress = 0.0
	if is_instance_valid(_bar):
		_bar.value = 0.0
	if is_instance_valid(_pct_lbl):
		_pct_lbl.text = "0%"
	if is_instance_valid(_title_lbl):
		if scene_path.find("Shop_Hungar") >= 0:
			_title_lbl.text = "АНГАР // МАСТЕРСКАЯ"
		elif scene_path.find("test_polygon") >= 0:
			_title_lbl.text = "ТЕСТОВЫЙ ПОЛИГОН"
		elif scene_path.find("main.tscn") >= 0:
			_title_lbl.text = "ВЫЕЗД НА ТРАССУ"
		else:
			_title_lbl.text = "ГЛАВНОЕ МЕНЮ"
	if is_instance_valid(_stage_lbl):
		_stage_lbl.text = "ЗАГРУЗКА СЦЕНЫ..."
	if is_instance_valid(_tip_lbl):
		_tip_lbl.text = _TIPS[_tip_idx % _TIPS.size()]
		_tip_idx += 1

func _resolve_selected_car_path() -> String:
	var g := get_node_or_null("/root/Game")
	if g == null:
		return ""
	var data_v: Variant = g.get("car_data")
	if not (data_v is Array) or (data_v as Array).is_empty():
		return ""
	var data := data_v as Array
	var idx := clampi(int(g.get("selected_car_index")), 0, data.size() - 1)
	return str(data[idx].get("path", ""))

func crossfade_from_boot(packed_scene: PackedScene, fade_in_sec: float = 0.65) -> void:
	if _is_transitioning or packed_scene == null:
		return
	_is_transitioning = true
	_ensure_overlay()
	set_tint_for_scene("res://ui/menu.tscn")

	_layer.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_load_ui.visible = false
	_load_ui.modulate.a = 0.0
	_set_progress(1.0)
	await get_tree().process_frame
	if not is_inside_tree():
		_is_transitioning = false
		return

	get_tree().paused = false
	Engine.time_scale = 1.0
	var err: int = get_tree().change_scene_to_packed(packed_scene)
	if err != OK:
		get_tree().change_scene_to_file("res://ui/menu.tscn")

	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame

	if fade_in_sec > 0.01 and is_inside_tree():
		var tw_in := create_tween()
		tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.set_ignore_time_scale(true)
		tw_in.tween_method(Callable(self, "_set_progress"), 1.0, 0.0, fade_in_sec)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_in.finished

	_set_progress(0.0)
	if is_instance_valid(_overlay):
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_layer):
		_layer.visible = false
	_is_transitioning = false

func transition_to_scene(scene_path: String, fade_out_sec: float = 0.36, fade_in_sec: float = 0.48, _hold_sec: float = 0.05) -> void:
	if _is_transitioning or scene_path.is_empty():
		return
	_is_transitioning = true
	_ensure_overlay()
	set_tint_for_scene(scene_path)
	_configure_loading_labels(scene_path)

	_layer.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_progress(0.0)
	_load_ui.visible = true
	_load_ui.modulate.a = 0.0

	var fade_out_t := maxf(fade_out_sec, 0.18)
	var tw_out := create_tween().set_parallel(true)
	tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw_out.set_ignore_time_scale(true)
	tw_out.tween_method(Callable(self, "_set_progress"), 0.0, 1.0, fade_out_t)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw_out.tween_property(_load_ui, "modulate:a", 1.0, minf(fade_out_t, 0.24))\
		.set_ease(Tween.EASE_OUT)
	await tw_out.finished

	if not is_inside_tree():
		_is_transitioning = false
		return

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("stop_transient_sfx"):
		sm.call("stop_transient_sfx")

	var is_main_target := (scene_path.find("main.tscn") >= 0)
	var is_shop_target := (scene_path.find("Shop_Hungar") >= 0)
	var is_poly_target := (scene_path.find("test_polygon") >= 0)
	var car_path := _resolve_selected_car_path() if (is_main_target or is_shop_target or is_poly_target) else ""
	if not car_path.is_empty():
		ResourceLoader.load_threaded_request(car_path, "PackedScene", false)
	var req_err := ResourceLoader.load_threaded_request(scene_path, "PackedScene", false)

	var packed: PackedScene = null
	var progress_arr: Array = []
	var max_scene_share := 0.52 if is_main_target else 0.92
	var start_ms := Time.get_ticks_msec()

	if req_err == OK:
		while is_inside_tree():
			var status := ResourceLoader.load_threaded_get_status(scene_path, progress_arr)
			var raw_p: float = float(progress_arr[0]) if not progress_arr.is_empty() else 0.35
			_target_progress = lerpf(0.06, max_scene_share, clampf(raw_p, 0.0, 1.0))
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				packed = ResourceLoader.load_threaded_get(scene_path) as PackedScene
				break
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			if Time.get_ticks_msec() - start_ms > 12000:
				break
			await get_tree().process_frame

	if not car_path.is_empty() and is_inside_tree():
		var car_wait_ms := Time.get_ticks_msec()
		while ResourceLoader.load_threaded_get_status(car_path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if Time.get_ticks_msec() - car_wait_ms > 4000:
				break
			await get_tree().process_frame

	if packed == null and is_inside_tree():
		packed = ResourceLoader.load(scene_path) as PackedScene

	if not is_inside_tree():
		_is_transitioning = false
		return

	if is_instance_valid(_stage_lbl):
		_stage_lbl.text = "ЗАПУСК МИРА..." if is_main_target else "ПОДГОТОВКА СЦЕНЫ..."
	_target_progress = maxf(_target_progress, max_scene_share)
	await get_tree().process_frame

	get_tree().paused = false
	Engine.time_scale = 1.0
	var err: int = ERR_CANT_CREATE
	if packed != null:
		err = get_tree().change_scene_to_packed(packed)
	if err != OK:
		err = get_tree().change_scene_to_file(scene_path)
		if err != OK:
			push_warning("SceneTransition: change_scene failed (%s): %d" % [scene_path, err])

	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame

	var cur_scene := get_tree().current_scene if is_inside_tree() else null
	if is_instance_valid(cur_scene) and ("scene_ready" in cur_scene):
		var init_start_ms := Time.get_ticks_msec()
		while is_inside_tree() and is_instance_valid(cur_scene):
			var ready_v: Variant = cur_scene.get("scene_ready")
			if ready_v != null and bool(ready_v):
				break
			var lp_v: Variant = cur_scene.get("scene_load_progress")
			var st_v: Variant = cur_scene.get("scene_load_stage")
			if lp_v != null:
				_target_progress = maxf(_target_progress, lerpf(0.55, 0.98, clampf(float(lp_v), 0.0, 1.0)))
			if st_v != null and is_instance_valid(_stage_lbl):
				var s_txt := str(st_v)
				if not s_txt.is_empty():
					_stage_lbl.text = s_txt
			if Time.get_ticks_msec() - init_start_ms > 12000:
				break
			await get_tree().process_frame

	_target_progress = 1.0
	if is_instance_valid(_stage_lbl):
		_stage_lbl.text = "ГОТОВО"

	var fin_ms := Time.get_ticks_msec()
	while is_inside_tree() and (_shown_progress < 0.985 or Time.get_ticks_msec() - fin_ms < 140):
		if Time.get_ticks_msec() - fin_ms > 500:
			break
		await get_tree().process_frame

	if is_inside_tree():
		var tw_ui_out := create_tween()
		tw_ui_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_ui_out.set_ignore_time_scale(true)
		tw_ui_out.tween_property(_load_ui, "modulate:a", 0.0, 0.16).set_ease(Tween.EASE_OUT)
		await tw_ui_out.finished
		if is_instance_valid(_load_ui):
			_load_ui.visible = false

	cur_scene = get_tree().current_scene if is_inside_tree() else null
	if is_instance_valid(cur_scene) and cur_scene.has_method("on_transition_reveal"):
		cur_scene.call("on_transition_reveal")

	if fade_in_sec > 0.01 and is_inside_tree():
		var tw_in := create_tween()
		tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.set_ignore_time_scale(true)
		tw_in.tween_method(Callable(self, "_set_progress"), 1.0, 0.0, fade_in_sec)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_in.finished

	_set_progress(0.0)
	if is_instance_valid(_load_ui):
		_load_ui.visible = false
		_load_ui.modulate.a = 0.0
	if is_instance_valid(_overlay):
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_layer):
		_layer.visible = false
	_is_transitioning = false
