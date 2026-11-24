extends Control

const MENU_PATH: String = "res://ui/menu.tscn"
const MIN_LOAD_SEC: float = 1.15

const FONT_TITLE: Font = preload("res://assets/fonts/RubikDirt-Regular.ttf")
const FONT_HEADER: Font = preload("res://assets/fonts/RussoOne-Regular.ttf")
const FONT_BODY: Font = preload("res://assets/fonts/Jura-Variable.ttf")
const BOOT_SPLASH_TEX: Texture2D = preload("res://assets/textures/ui/boot_splash.png")

var _bg_tex: TextureRect = null
var _ui_group: Control = null
var _bar: ProgressBar = null
var _pct_lbl: Label = null
var _stage_lbl: Label = null
var _spinner: TextureRect = null

var _elapsed: float = 0.0
var _shown_progress: float = 0.0
var _target_progress: float = 0.05
var _menu_packed: PackedScene = null
var _handoff_started: bool = false
var _load_requested: bool = false
var _frame_count: int = 0
var _req_ok: bool = false
var _load_progress_arr: Array = []

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	_build_ui()

	if is_instance_valid(_ui_group):
		_ui_group.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_ui_group, "modulate:a", 1.0, 0.38).set_ease(Tween.EASE_OUT)

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

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var base_bg := ColorRect.new()
	base_bg.name = "BaseBg"
	base_bg.color = Color(0.025, 0.028, 0.035, 1.0)
	base_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(base_bg)

	_bg_tex = TextureRect.new()
	_bg_tex.name = "BootSplashTex"
	_bg_tex.texture = BOOT_SPLASH_TEX
	_bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_tex)

	_ui_group = Control.new()
	_ui_group.name = "UiOverlayGroup"
	_ui_group.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui_group)

	# Upper-left title lockup
	var title_box := VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_box.offset_left = 44
	title_box.offset_top = 38
	title_box.add_theme_constant_override("separation", 6)
	_ui_group.add_child(title_box)

	var title_lbl := Label.new()
	title_lbl.text = "ULTRA KILL CAR"
	title_lbl.add_theme_font_override("font", FONT_TITLE)
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.86, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 4)
	title_box.add_child(title_lbl)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(210, 3)
	accent.color = Color(0.92, 0.36, 0.14, 0.95)
	title_box.add_child(accent)

	var sub_lbl := Label.new()
	sub_lbl.text = "DEAD HIGHWAY SURVIVAL"
	sub_lbl.add_theme_font_override("font", FONT_BODY)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color(0.76, 0.72, 0.66, 0.88))
	title_box.add_child(sub_lbl)

	# Sleek full-width bottom loader deck matching SceneTransition
	var footer := PanelContainer.new()
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -114
	footer.offset_bottom = 0
	var sb_footer := StyleBoxFlat.new()
	sb_footer.bg_color = Color(0.032, 0.036, 0.046, 0.90)
	sb_footer.border_color = Color(0.92, 0.40, 0.14, 0.88)
	sb_footer.border_width_top = 2
	sb_footer.content_margin_left = 36
	sb_footer.content_margin_right = 36
	sb_footer.content_margin_top = 14
	sb_footer.content_margin_bottom = 18
	footer.add_theme_stylebox_override("panel", sb_footer)
	_ui_group.add_child(footer)

	var vstack := VBoxContainer.new()
	vstack.add_theme_constant_override("separation", 12)
	footer.add_child(vstack)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vstack.add_child(row)

	_spinner = TextureRect.new()
	_spinner.texture = _make_spinner_tex(96)
	_spinner.custom_minimum_size = Vector2(38, 38)
	_spinner.pivot_offset = Vector2(19, 19)
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_spinner)

	_stage_lbl = Label.new()
	_stage_lbl.text = "ПРОГРЕВ ДВИГАТЕЛЯ..."
	_stage_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stage_lbl.add_theme_font_override("font", FONT_BODY)
	_stage_lbl.add_theme_font_size_override("font_size", 15)
	_stage_lbl.add_theme_color_override("font_color", Color(0.84, 0.86, 0.90, 0.95))
	row.add_child(_stage_lbl)

	_pct_lbl = Label.new()
	_pct_lbl.text = "0%"
	_pct_lbl.custom_minimum_size = Vector2(68, 0)
	_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pct_lbl.add_theme_font_override("font", FONT_HEADER)
	_pct_lbl.add_theme_font_size_override("font_size", 22)
	_pct_lbl.add_theme_color_override("font_color", Color(0.98, 0.62, 0.20, 1.0))
	row.add_child(_pct_lbl)

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

func _process(delta: float) -> void:
	if _handoff_started:
		return
	var dt := clampf(delta, 0.0, 0.05)
	_elapsed += dt
	_frame_count += 1
	if not _load_requested and _frame_count >= 3:
		_load_requested = true
		_req_ok = (ResourceLoader.load_threaded_request(MENU_PATH, "PackedScene", false) == OK)

	if is_instance_valid(_spinner):
		_spinner.rotation += dt * 3.6
	if is_instance_valid(_bg_tex):
		_bg_tex.pivot_offset = _bg_tex.size * 0.5
		var zoom := 1.0 + clampf(_elapsed / 4.5, 0.0, 0.045)
		_bg_tex.scale = Vector2(zoom, zoom)

	var real_p: float = 0.25
	if _menu_packed == null:
		if not _load_requested:
			real_p = 0.25
		elif _req_ok:
			var status := ResourceLoader.load_threaded_get_status(MENU_PATH, _load_progress_arr)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				_menu_packed = ResourceLoader.load_threaded_get(MENU_PATH) as PackedScene
				real_p = 1.0
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE or _elapsed > 8.0:
				_menu_packed = ResourceLoader.load(MENU_PATH) as PackedScene
				real_p = 1.0
			elif not _load_progress_arr.is_empty():
				real_p = clampf(float(_load_progress_arr[0]), 0.12, 0.94)
		else:
			_menu_packed = ResourceLoader.load(MENU_PATH) as PackedScene
			real_p = 1.0
	else:
		real_p = 1.0

	var time_p: float = clampf(_elapsed / MIN_LOAD_SEC, 0.0, 1.0)
	_target_progress = minf(real_p, time_p) if _menu_packed == null else time_p
	_shown_progress = lerpf(_shown_progress, _target_progress, clampf(dt * 12.0, 0.0, 1.0))
	if absf(_target_progress - _shown_progress) < 0.006:
		_shown_progress = _target_progress

	if is_instance_valid(_bar):
		_bar.value = _shown_progress
	if is_instance_valid(_pct_lbl):
		_pct_lbl.text = "%d%%" % clampi(roundi(_shown_progress * 100.0), 0, 100)
	if is_instance_valid(_stage_lbl):
		if _shown_progress < 0.42:
			_stage_lbl.text = "ПРОГРЕВ ДВИГАТЕЛЯ..."
		elif _shown_progress < 0.88:
			_stage_lbl.text = "ПОДГОТОВКА ОКРУЖЕНИЯ..."
		else:
			_stage_lbl.text = "ГОТОВ К ЗАЕЗДУ"

	if _menu_packed != null and _elapsed >= MIN_LOAD_SEC and _shown_progress >= 0.99:
		_handoff_started = true
		var tw := create_tween()
		tw.tween_property(_ui_group, "modulate:a", 0.0, 0.20).set_ease(Tween.EASE_OUT)
		await tw.finished
		if is_inside_tree():
			SceneTransition.crossfade_from_boot(_menu_packed, 0.65)
