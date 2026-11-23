extends Control

@onready var _money_label: Label = find_child("Money", true, false) as Label
@onready var _settings_panel: Control = get_node_or_null("SettingsPanel") as Control
@onready var _preset_info: Label = find_child("PresetInfo", true, false) as Label
@onready var _badge_label: Label = find_child("BadgeLabel", true, false) as Label

@onready var _slider_master: HSlider = find_child("SliderMaster", true, false) as HSlider
@onready var _slider_vehicles: HSlider = find_child("SliderVehicles", true, false) as HSlider
@onready var _slider_sfx: HSlider = find_child("SliderSfx", true, false) as HSlider
@onready var _slider_ambience: HSlider = find_child("SliderAmbience", true, false) as HSlider

@onready var _val_master: Label = find_child("ValMaster", true, false) as Label
@onready var _val_vehicles: Label = find_child("ValVehicles", true, false) as Label
@onready var _val_sfx: Label = find_child("ValSfx", true, false) as Label
@onready var _val_ambience: Label = find_child("ValAmbience", true, false) as Label

var _syncing_sliders: bool = false
var _launching: bool = false

var _sb_nav_normal: StyleBoxFlat
var _sb_nav_hover: StyleBoxFlat
var _sb_nav_pressed: StyleBoxFlat
var _sb_primary_normal: StyleBoxFlat
var _sb_primary_hover: StyleBoxFlat
var _sb_pill_normal: StyleBoxFlat
var _sb_pill_active: StyleBoxFlat
var _sb_panel_card: StyleBoxFlat
var _sb_badge_plate: StyleBoxFlat
var _sb_slider_bg: StyleBoxFlat
var _sb_slider_fill: StyleBoxFlat

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	SettingsManager.apply_settings(get_tree().current_scene)

	if OS.has_feature("web") and has_node("LeftMargin/LeftVBox/Exit"):
		$LeftMargin/LeftVBox/Exit.hide()

	_init_styles()
	_apply_visual_styles()
	_wire_button_audio_and_hover()
	_wire_volume_sliders()

	_update_money(Game.money)
	if not Game.money_changed.is_connected(_update_money):
		Game.money_changed.connect(_update_money)
	if not SettingsManager.quality_changed.is_connected(_on_quality_changed):
		SettingsManager.quality_changed.connect(_on_quality_changed)
	if not SettingsManager.volume_changed.is_connected(_sync_volume_sliders_from_settings):
		SettingsManager.volume_changed.connect(_sync_volume_sliders_from_settings)

	_update_quality_buttons()
	_update_status_badge()
	_sync_volume_sliders_from_settings()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and not event.is_echo():
		if is_instance_valid(_settings_panel) and _settings_panel.visible:
			_on_btn_close_pressed()
			get_viewport().set_input_as_handled()

func _make_box(bg: Color, border: Color, bw: int = 1, bw_left: int = -1, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	if bw_left >= 0:
		sb.border_width_left = bw_left
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _init_styles() -> void:
	_sb_nav_normal = _make_box(Color(0.08, 0.09, 0.11, 0.80), Color(0.28, 0.30, 0.33, 0.55), 1, 3, 4)
	_sb_nav_hover = _make_box(Color(0.14, 0.13, 0.14, 0.94), Color(0.88, 0.36, 0.14, 0.95), 1, 5, 4)
	_sb_nav_pressed = _make_box(Color(0.22, 0.11, 0.08, 0.98), Color(1.0, 0.55, 0.22, 1.0), 1, 6, 4)

	_sb_primary_normal = _make_box(Color(0.32, 0.09, 0.06, 0.92), Color(0.92, 0.32, 0.14, 0.92), 1, 5, 4)
	_sb_primary_hover = _make_box(Color(0.46, 0.12, 0.07, 0.98), Color(1.0, 0.52, 0.22, 1.0), 1, 6, 4)

	_sb_pill_normal = _make_box(Color(0.10, 0.11, 0.13, 0.92), Color(0.26, 0.29, 0.32, 0.70), 1, -1, 4)
	_sb_pill_normal.content_margin_left = 10
	_sb_pill_normal.content_margin_right = 10
	_sb_pill_normal.content_margin_top = 8
	_sb_pill_normal.content_margin_bottom = 8

	_sb_pill_active = _make_box(Color(0.38, 0.15, 0.08, 0.98), Color(0.96, 0.44, 0.18, 1.0), 2, -1, 4)
	_sb_pill_active.content_margin_left = 10
	_sb_pill_active.content_margin_right = 10
	_sb_pill_active.content_margin_top = 8
	_sb_pill_active.content_margin_bottom = 8

	_sb_panel_card = _make_box(Color(0.06, 0.07, 0.09, 0.95), Color(0.34, 0.36, 0.38, 0.65), 1, -1, 6)
	_sb_panel_card.set_content_margin_all(0)

	_sb_badge_plate = _make_box(Color(0.06, 0.07, 0.09, 0.84), Color(0.36, 0.34, 0.30, 0.65), 1, 3, 4)
	_sb_badge_plate.content_margin_left = 14
	_sb_badge_plate.content_margin_right = 14
	_sb_badge_plate.content_margin_top = 8
	_sb_badge_plate.content_margin_bottom = 8

	_sb_slider_bg = StyleBoxFlat.new()
	_sb_slider_bg.bg_color = Color(0.16, 0.18, 0.21, 1.0)
	_sb_slider_bg.set_corner_radius_all(3)
	_sb_slider_bg.content_margin_top = 4
	_sb_slider_bg.content_margin_bottom = 4

	_sb_slider_fill = StyleBoxFlat.new()
	_sb_slider_fill.bg_color = Color(0.88, 0.34, 0.14, 1.0)
	_sb_slider_fill.set_corner_radius_all(3)

func _apply_visual_styles() -> void:
	var play_btn := find_child("Play", true, false) as Button
	if play_btn:
		play_btn.add_theme_stylebox_override("normal", _sb_primary_normal)
		play_btn.add_theme_stylebox_override("hover", _sb_primary_hover)
		play_btn.add_theme_stylebox_override("pressed", _sb_nav_pressed)
		play_btn.add_theme_stylebox_override("focus", _sb_primary_hover)

	for bname in ["Shop", "TestPolygon", "SettingsButton", "Exit", "BtnClose"]:
		var btn := find_child(bname, true, false) as Button
		if btn:
			btn.add_theme_stylebox_override("normal", _sb_nav_normal)
			btn.add_theme_stylebox_override("hover", _sb_nav_hover)
			btn.add_theme_stylebox_override("pressed", _sb_nav_pressed)
			btn.add_theme_stylebox_override("focus", _sb_nav_hover)

	for pname in ["SelectedCarBadge", "MoneyPanel"]:
		var p := find_child(pname, true, false) as PanelContainer
		if p:
			p.add_theme_stylebox_override("panel", _sb_badge_plate)

	var card := find_child("SettingsCard", true, false) as PanelContainer
	if card:
		card.add_theme_stylebox_override("panel", _sb_panel_card)

	for sl in [_slider_master, _slider_vehicles, _slider_sfx, _slider_ambience]:
		if sl:
			sl.add_theme_stylebox_override("slider", _sb_slider_bg)
			sl.add_theme_stylebox_override("grabber_area", _sb_slider_fill)
			sl.add_theme_stylebox_override("grabber_area_highlight", _sb_slider_fill)

func _wire_button_audio_and_hover() -> void:
	var btns: Array[Button] = []
	for bname in ["Play", "Shop", "TestPolygon", "SettingsButton", "Exit", "BtnLow", "BtnMedium", "BtnHigh", "BtnUltra", "BtnClose"]:
		var b := find_child(bname, true, false) as Button
		if b:
			btns.append(b)
	for b in btns:
		if not b.mouse_entered.is_connected(_on_any_btn_hover.bind(b)):
			b.mouse_entered.connect(_on_any_btn_hover.bind(b))
		if not b.mouse_exited.is_connected(_on_any_btn_exit.bind(b)):
			b.mouse_exited.connect(_on_any_btn_exit.bind(b))

func _on_any_btn_hover(btn: Button) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_hover", -10.0, randf_range(0.96, 1.04))
	if btn.name in ["Play", "Shop", "TestPolygon", "SettingsButton", "Exit"]:
		var tw := create_tween()
		tw.tween_property(btn, "modulate", Color(1.08, 1.04, 1.02, 1.0), 0.12)

func _on_any_btn_exit(btn: Button) -> void:
	if btn.name in ["Play", "Shop", "TestPolygon", "SettingsButton", "Exit"]:
		var tw := create_tween()
		tw.tween_property(btn, "modulate", Color.WHITE, 0.12)

func _play_click() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_click", -7.0, 1.0)

func _wire_volume_sliders() -> void:
	var pairs: Array[Array] = [
		[_slider_master, "master", _val_master],
		[_slider_vehicles, "vehicles", _val_vehicles],
		[_slider_sfx, "sfx", _val_sfx],
		[_slider_ambience, "ambience", _val_ambience],
	]
	for item: Array in pairs:
		var sl := item[0] as HSlider
		var channel: String = str(item[1])
		var lbl := item[2] as Label
		if sl == null:
			continue
		if not sl.value_changed.is_connected(_on_slider_value_changed):
			sl.value_changed.connect(_on_slider_value_changed.bind(channel, lbl))
		if not sl.drag_ended.is_connected(_on_slider_drag_ended):
			sl.drag_ended.connect(_on_slider_drag_ended)

func _sync_volume_sliders_from_settings() -> void:
	_syncing_sliders = true
	var pairs: Array[Array] = [
		[_slider_master, "master", _val_master],
		[_slider_vehicles, "vehicles", _val_vehicles],
		[_slider_sfx, "sfx", _val_sfx],
		[_slider_ambience, "ambience", _val_ambience],
	]
	for item: Array in pairs:
		var sl := item[0] as HSlider
		var ch: String = str(item[1])
		var lbl := item[2] as Label
		var pct: int = roundi(SettingsManager.get_volume(ch) * 100.0)
		if sl:
			sl.value = pct
		if lbl:
			lbl.text = "%d%%" % pct
	_syncing_sliders = false

func _on_slider_value_changed(val: float, channel: String, lbl: Label) -> void:
	if _syncing_sliders:
		return
	var pct := roundi(val)
	if lbl:
		lbl.text = "%d%%" % pct
	SettingsManager.set_volume(channel, val / 100.0, false)

func _on_slider_drag_ended(_changed: bool) -> void:
	SettingsManager.save_settings()
	_play_click()

func _update_money(amount: int) -> void:
	if is_instance_valid(_money_label):
		_money_label.text = str(amount) + " $"

func _update_status_badge() -> void:
	if not is_instance_valid(_badge_label):
		return
	var car_name := "Pikap"
	var data: Variant = Game.car_data
	if data is Array and not (data as Array).is_empty():
		var safe_idx := clampi(Game.selected_car_index, 0, (data as Array).size() - 1)
		car_name = str((data as Array)[safe_idx].get("name", car_name))
	_badge_label.text = "ТЕХНИКА: %s  |  ГРАФИКА: %s" % [car_name.to_upper(), SettingsManager.get_quality_name().to_upper()]

func _on_quality_changed(_new_q: int) -> void:
	_update_quality_buttons()
	_update_status_badge()

func _on_texture_button_pressed() -> void:
	if _launching or SceneTransition.is_transitioning():
		return
	_launching = true
	_play_click()
	SceneTransition.transition_to_scene("res://ui/shop/Angar/Shop_Hungar.tscn")

func _on_test_polygon_pressed() -> void:
	if _launching or SceneTransition.is_transitioning():
		return
	_launching = true
	_play_click()
	SceneTransition.transition_to_scene("res://levels/test_polygon.tscn")

func _on_play_pressed() -> void:
	if _launching:
		return
	_launching = true
	_play_click()
	var tw := create_tween().set_parallel(true)
	for ui_name in ["LeftMargin", "MoneyPanel", "SettingsPanel"]:
		var ctrl := get_node_or_null(ui_name) as Control
		if ctrl:
			tw.tween_property(ctrl, "modulate:a", 0.0, 0.32).set_ease(Tween.EASE_OUT)
			ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var diorama := get_parent()
	if diorama and diorama.has_method("play_launch_transition"):
		diorama.call("play_launch_transition", func() -> void:
			if is_inside_tree():
				SceneTransition.transition_to_scene("res://levels/main.tscn", 0.22, 0.50)
		)
	else:
		SceneTransition.transition_to_scene("res://levels/main.tscn")

func _on_exit_pressed() -> void:
	if _launching:
		return
	_play_click()
	get_tree().quit()

func _on_settings_pressed() -> void:
	if _launching:
		return
	_play_click()
	if is_instance_valid(_settings_panel):
		_update_quality_buttons()
		_sync_volume_sliders_from_settings()
		_settings_panel.show()

func _on_btn_close_pressed() -> void:
	_play_click()
	SettingsManager.save_settings()
	if is_instance_valid(_settings_panel):
		_settings_panel.hide()

func _set_quality(q: SettingsManager.GraphicsQuality) -> void:
	_play_click()
	SettingsManager.set_quality(q)
	_update_quality_buttons()
	_update_status_badge()

func _update_quality_buttons() -> void:
	var mapping: Dictionary = {
		"BtnLow": SettingsManager.GraphicsQuality.LOW,
		"BtnMedium": SettingsManager.GraphicsQuality.MEDIUM,
		"BtnHigh": SettingsManager.GraphicsQuality.HIGH,
		"BtnUltra": SettingsManager.GraphicsQuality.ULTRA,
	}
	for bname in mapping.keys():
		var btn := find_child(str(bname), true, false) as Button
		if btn:
			var target_q: int = int(mapping[bname])
			var active: bool = (int(SettingsManager.current_quality) == target_q)
			btn.add_theme_stylebox_override("normal", _sb_pill_active if active else _sb_pill_normal)
			btn.add_theme_stylebox_override("hover", _sb_pill_active if active else _sb_nav_hover)
			btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.86) if active else Color(0.80, 0.84, 0.86))
	if is_instance_valid(_preset_info):
		_preset_info.text = SettingsManager.get_quality_description()

func _on_btn_low_pressed() -> void:
	_set_quality(SettingsManager.GraphicsQuality.LOW)

func _on_btn_medium_pressed() -> void:
	_set_quality(SettingsManager.GraphicsQuality.MEDIUM)

func _on_btn_high_pressed() -> void:
	_set_quality(SettingsManager.GraphicsQuality.HIGH)

func _on_btn_ultra_pressed() -> void:
	_set_quality(SettingsManager.GraphicsQuality.ULTRA)
