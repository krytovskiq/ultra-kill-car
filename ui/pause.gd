extends CanvasLayer

@onready var _graphics_btn: Button = find_child("GraphicsBtn", true, false) as Button
@onready var _card: PanelContainer = find_child("PauseCard", true, false) as PanelContainer
@onready var _btn_continue: Button = find_child("contiue", true, false) as Button
@onready var _btn_menu: Button = find_child("menu", true, false) as Button

@onready var _slider_master: HSlider = find_child("SliderMaster", true, false) as HSlider
@onready var _slider_sfx: HSlider = find_child("SliderSfx", true, false) as HSlider
@onready var _val_master: Label = find_child("ValMaster", true, false) as Label
@onready var _val_sfx: Label = find_child("ValSfx", true, false) as Label

var _syncing_sliders: bool = false

func _ready() -> void:
	_apply_styles()
	_wire_sliders()
	_wire_buttons()
	_update_graphics_label()
	_sync_sliders()
	if not SettingsManager.volume_changed.is_connected(_sync_sliders):
		SettingsManager.volume_changed.connect(_sync_sliders)

func _wire_buttons() -> void:
	for b in [_btn_continue, _graphics_btn, _btn_menu]:
		if is_instance_valid(b) and not b.mouse_entered.is_connected(_on_btn_hover):
			b.mouse_entered.connect(_on_btn_hover)

func _on_btn_hover() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_hover", -10.0, randf_range(0.96, 1.04))

func _apply_styles() -> void:
	var sb_card := StyleBoxFlat.new()
	sb_card.bg_color = Color(0.06, 0.07, 0.09, 0.94)
	sb_card.border_color = Color(0.36, 0.36, 0.38, 0.72)
	sb_card.set_border_width_all(1)
	sb_card.set_corner_radius_all(6)
	if is_instance_valid(_card):
		_card.add_theme_stylebox_override("panel", sb_card)

	var sb_norm := StyleBoxFlat.new()
	sb_norm.bg_color = Color(0.10, 0.11, 0.13, 0.90)
	sb_norm.border_color = Color(0.30, 0.32, 0.35, 0.65)
	sb_norm.set_border_width_all(1)
	sb_norm.border_width_left = 4
	sb_norm.set_corner_radius_all(4)
	sb_norm.content_margin_left = 14
	sb_norm.content_margin_right = 14
	sb_norm.content_margin_top = 8
	sb_norm.content_margin_bottom = 8

	var sb_hov := sb_norm.duplicate() as StyleBoxFlat
	sb_hov.bg_color = Color(0.18, 0.14, 0.14, 0.96)
	sb_hov.border_color = Color(0.92, 0.36, 0.15, 1.0)
	sb_hov.border_width_left = 6

	for b in [_btn_continue, _graphics_btn, _btn_menu]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", sb_norm)
			b.add_theme_stylebox_override("hover", sb_hov)
			b.add_theme_stylebox_override("pressed", sb_hov)
			b.add_theme_stylebox_override("focus", sb_hov)

	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.16, 0.18, 0.21, 1.0)
	sb_bg.set_corner_radius_all(3)
	sb_bg.content_margin_top = 4
	sb_bg.content_margin_bottom = 4

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.88, 0.34, 0.14, 1.0)
	sb_fill.set_corner_radius_all(3)

	for sl in [_slider_master, _slider_sfx]:
		if is_instance_valid(sl):
			sl.add_theme_stylebox_override("slider", sb_bg)
			sl.add_theme_stylebox_override("grabber_area", sb_fill)
			sl.add_theme_stylebox_override("grabber_area_highlight", sb_fill)

func _wire_sliders() -> void:
	if is_instance_valid(_slider_master):
		if not _slider_master.value_changed.is_connected(_on_slider_changed):
			_slider_master.value_changed.connect(_on_slider_changed.bind("master", _val_master))
		if not _slider_master.drag_ended.is_connected(_on_slider_drag_ended):
			_slider_master.drag_ended.connect(_on_slider_drag_ended)
	if is_instance_valid(_slider_sfx):
		if not _slider_sfx.value_changed.is_connected(_on_slider_changed):
			_slider_sfx.value_changed.connect(_on_slider_changed.bind("sfx", _val_sfx))
		if not _slider_sfx.drag_ended.is_connected(_on_slider_drag_ended):
			_slider_sfx.drag_ended.connect(_on_slider_drag_ended)

func _sync_sliders() -> void:
	_syncing_sliders = true
	var mpct := roundi(SettingsManager.get_volume("master") * 100.0)
	var spct := roundi(SettingsManager.get_volume("sfx") * 100.0)
	if is_instance_valid(_slider_master):
		_slider_master.value = mpct
	if is_instance_valid(_val_master):
		_val_master.text = "%d%%" % mpct
	if is_instance_valid(_slider_sfx):
		_slider_sfx.value = spct
	if is_instance_valid(_val_sfx):
		_val_sfx.text = "%d%%" % spct
	_syncing_sliders = false

func _on_slider_changed(val: float, channel: String, lbl: Label) -> void:
	if _syncing_sliders:
		return
	if is_instance_valid(lbl):
		lbl.text = "%d%%" % roundi(val)
	SettingsManager.set_volume(channel, val / 100.0, false)

func _on_slider_drag_ended(_changed: bool) -> void:
	SettingsManager.save_settings()
	_play_click()

func _play_click() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_click", -7.0, 1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and not event.is_echo():
		var car := _get_parent_car()
		if car and (car.get("destroyed") == true or car.get("is_preview") == true):
			return
		get_tree().paused = not get_tree().paused
		visible = get_tree().paused
		if visible:
			_update_graphics_label()
			_sync_sliders()
		get_viewport().set_input_as_handled()

func _get_parent_car() -> Node:
	var parent := get_parent()
	if parent:
		return parent.get_parent()
	return null

func _update_graphics_label() -> void:
	if is_instance_valid(_graphics_btn):
		_graphics_btn.text = "Графика: " + SettingsManager.get_quality_name()

func _on_contiue_pressed() -> void:
	_play_click()
	get_tree().paused = false
	hide()

func _on_graphics_btn_pressed() -> void:
	_play_click()
	SettingsManager.cycle_quality()
	_update_graphics_label()

func _on_menu_pressed() -> void:
	if SceneTransition.is_transitioning():
		return
	_play_click()
	var car := _get_parent_car()
	if car and car.has_method("commit_run_rewards"):
		car.commit_run_rewards()
	SceneTransition.transition_to_scene("res://ui/menu.tscn")
