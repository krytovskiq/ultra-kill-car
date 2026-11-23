extends CanvasLayer

@onready var _root: Control = get_node_or_null("RootControl") as Control
@onready var _card: PanelContainer = find_child("DeathCard", true, false) as PanelContainer
@onready var _reason_label: Label = find_child("ReasonLabel", true, false) as Label
@onready var _val_dist: Label = find_child("ValDistance", true, false) as Label
@onready var _val_kills: Label = find_child("ValKills", true, false) as Label
@onready var _val_earned: Label = find_child("ValEarned", true, false) as Label
@onready var _val_balance: Label = find_child("ValBalance", true, false) as Label
@onready var _car_tag: Label = find_child("CarTag", true, false) as Label
@onready var _btn_retry: Button = find_child("BtnRetry", true, false) as Button
@onready var _btn_garage: Button = find_child("BtnGarage", true, false) as Button
@onready var _btn_menu: Button = find_child("BtnMenu", true, false) as Button

var _input_ready: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_styles()
	_wire_buttons()
	if is_instance_valid(_root):
		_root.modulate.a = 0.0

func _format_int(val: int) -> String:
	var s := str(maxi(val, 0))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and (count % 3) == 0:
			out = " " + out
		out = s[i] + out
		count += 1
	return out

func _make_box(bg: Color, border: Color, bw: int = 1, bw_left: int = -1, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	if bw_left >= 0:
		sb.border_width_left = bw_left
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _apply_styles() -> void:
	if is_instance_valid(_card):
		var sb_card := _make_box(Color(0.055, 0.06, 0.075, 0.94), Color(0.76, 0.22, 0.12, 0.88), 1, -1, 6)
		sb_card.set_content_margin_all(0)
		_card.add_theme_stylebox_override("panel", sb_card)

	var sb_stat := _make_box(Color(0.08, 0.09, 0.11, 0.88), Color(0.28, 0.30, 0.34, 0.55), 1, 3, 4)
	sb_stat.content_margin_left = 12
	sb_stat.content_margin_right = 12
	sb_stat.content_margin_top = 8
	sb_stat.content_margin_bottom = 8
	for stat_name: String in ["StatDistance", "StatKills", "StatEarned", "StatBalance"]:
		var p := find_child(stat_name, true, false) as PanelContainer
		if p:
			p.add_theme_stylebox_override("panel", sb_stat)

	var sb_prim_n := _make_box(Color(0.36, 0.09, 0.06, 0.94), Color(0.94, 0.32, 0.14, 0.96), 1, 5, 4)
	var sb_prim_h := _make_box(Color(0.50, 0.13, 0.08, 0.98), Color(1.0, 0.52, 0.22, 1.0), 1, 6, 4)
	var sb_prim_p := _make_box(Color(0.24, 0.07, 0.05, 0.98), Color(1.0, 0.62, 0.28, 1.0), 1, 6, 4)

	if is_instance_valid(_btn_retry):
		_btn_retry.add_theme_stylebox_override("normal", sb_prim_n)
		_btn_retry.add_theme_stylebox_override("hover", sb_prim_h)
		_btn_retry.add_theme_stylebox_override("pressed", sb_prim_p)
		_btn_retry.add_theme_stylebox_override("focus", sb_prim_h)

	var sb_sec_n := _make_box(Color(0.09, 0.10, 0.12, 0.88), Color(0.30, 0.32, 0.36, 0.65), 1, 3, 4)
	var sb_sec_h := _make_box(Color(0.16, 0.13, 0.14, 0.96), Color(0.90, 0.38, 0.16, 0.98), 1, 5, 4)
	for b in [_btn_garage, _btn_menu]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", sb_sec_n)
			b.add_theme_stylebox_override("hover", sb_sec_h)
			b.add_theme_stylebox_override("pressed", sb_prim_p)
			b.add_theme_stylebox_override("focus", sb_sec_h)

func _wire_buttons() -> void:
	for b in [_btn_retry, _btn_garage, _btn_menu]:
		if is_instance_valid(b):
			if not b.mouse_entered.is_connected(_on_btn_hover):
				b.mouse_entered.connect(_on_btn_hover)

func _on_btn_hover() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_hover", -9.0, randf_range(0.95, 1.05))

func _play_click() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_click", -6.0, 1.0)

func show_death_summary(stats: Dictionary) -> void:
	var reason := str(stats.get("reason", "МАШИНА УНИЧТОЖЕНА")).to_upper()
	var dist_m := int(stats.get("distance_m", 0))
	var kills := int(stats.get("kills", 0))
	var earned := int(stats.get("earned", 0))
	var balance := int(stats.get("balance", Game.money))
	var car_name := str(stats.get("car_name", "ТЕХНИКА")).to_upper()

	if is_instance_valid(_reason_label):
		_reason_label.text = reason
	if is_instance_valid(_car_tag):
		var suffix := "БАК ПУСТ — ПРОКАЧАЙ БАК В ГАРАЖЕ" if reason.contains("ТОПЛИВ") else "ПРОКАЧАЙ БРОНЮ И ХОДОВУЮ В ГАРАЖЕ"
		_car_tag.text = "ТЕХНИКА: %s  //  %s" % [car_name, suffix]
	if is_instance_valid(_val_dist):
		_val_dist.text = _format_int(dist_m) + " М"
	if is_instance_valid(_val_kills):
		_val_kills.text = _format_int(kills) + " ЗОМБИ"
	if is_instance_valid(_val_earned):
		_val_earned.text = "+" + _format_int(earned) + " $"
	if is_instance_valid(_val_balance):
		_val_balance.text = _format_int(balance) + " $"

	show()
	if is_instance_valid(_root):
		_root.modulate.a = 0.0
		var tw := create_tween().set_ignore_time_scale(true)
		tw.tween_property(_root, "modulate:a", 1.0, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_instance_valid(_card):
		_card.scale = Vector2(0.95, 0.95)
		_card.pivot_offset = _card.size * 0.5
		var ctw := create_tween().set_ignore_time_scale(true)
		ctw.tween_property(_card, "scale", Vector2.ONE, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	_input_ready = false
	await get_tree().create_timer(0.35, true, false, true).timeout
	if is_instance_valid(self):
		_input_ready = true
		if is_instance_valid(_btn_retry):
			_btn_retry.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not _input_ready or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_R or k == KEY_ENTER or k == KEY_KP_ENTER:
			_on_retry_pressed()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			_on_menu_pressed()
			get_viewport().set_input_as_handled()

func _navigate_to(scene_path: String) -> void:
	if SceneTransition.is_transitioning():
		return
	_play_click()
	Engine.time_scale = 1.0
	get_tree().paused = false
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_death_ambience"):
		sm.call("set_death_ambience", false)
	var zp := get_node_or_null("/root/ZombiePool")
	if zp:
		zp.get("pool").clear()
		zp.get("active_zombies").clear()
	SceneTransition.transition_to_scene(scene_path)

func _on_retry_pressed() -> void:
	_navigate_to("res://levels/main.tscn")

func _on_garage_pressed() -> void:
	_navigate_to("res://ui/shop/Angar/Shop_Hungar.tscn")

func _on_menu_pressed() -> void:
	_navigate_to("res://ui/menu.tscn")
