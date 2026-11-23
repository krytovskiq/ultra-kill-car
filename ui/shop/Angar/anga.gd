extends Node3D

const ProceduralMaterials = preload("res://levels/procedural_materials.gd")

var current_idx: int = 0
var car_instance: Node3D = null
var loaded_car_scenes: Dictionary = {}

@onready var _cam: Camera3D = get_node_or_null("Camera3D") as Camera3D
@onready var _spawn: Marker3D = get_node_or_null("Spawn") as Marker3D
@onready var _money_lbl: Label = find_child("money", true, false) as Label
@onready var _car_name_lbl: Label = find_child("CarName", true, false) as Label
@onready var _car_role_lbl: Label = find_child("CarRole", true, false) as Label
@onready var _index_tag_lbl: Label = find_child("IndexTag", true, false) as Label
@onready var _price_lbl: Label = find_child("Price", true, false) as Label
@onready var _btn_buy: Button = find_child("Buy", true, false) as Button
@onready var _btn_raid: Button = find_child("BtnRaid", true, false) as Button
@onready var _btn_prev: Button = find_child("Next", true, false) as Button
@onready var _btn_next: Button = find_child("Back", true, false) as Button
@onready var _btn_back_menu: Button = find_child("Back_menu", true, false) as Button
@onready var _val_speed: Label = find_child("ValSpeed", true, false) as Label
@onready var _val_armor: Label = find_child("ValArmor", true, false) as Label
@onready var _val_fuel: Label = find_child("ValFuel", true, false) as Label
@onready var _bar_speed: ProgressBar = find_child("BarSpeed", true, false) as ProgressBar
@onready var _bar_armor: ProgressBar = find_child("BarArmor", true, false) as ProgressBar
@onready var _bar_fuel: ProgressBar = find_child("BarFuel", true, false) as ProgressBar

const ROLE_DESCRIPTIONS: Dictionary = {
	"pikap": "РАЗВЕДЧИК // НАДЁЖНЫЙ ПИКАП",
	"doge2": "ШТУРМОВОЙ // V8 МАСЛКАР",
	"buhanka": "ВЕЗДЕХОД // УАЗ-452 ПОЛНЫЙ ПРИВОД",
	"vandura": "ФУРГОН // ТЯЖЁЛЫЙ V8 ТАРАН",
	"carson": "РЕТРО-ПЕРЕХВАТЧИК // V8 КУПЕ",
	"barracuda": "ПЕРЕХВАТЧИК // HEMI V8 СПОРТ",
	"delorean": "БОЛИД // V6 ТУРБО",
	"k2500": "ТЯЖЁЛЫЙ ДЖИП // 4x4 ВНЕДОРОЖНИК",
	"raptor": "ТРОФИ-ПИКАП // OFF-ROAD BITURBO",
	"paz3205": "ШТУРМОВОЙ АВТОБУС // ПУЛЕМЁТ [SPACE]",
	"btr": "БРОНЕВИК // АВТОПУШКА [SPACE]",
	"mustang": "ПЕРЕХВАТЧИК // HEMI V8 СПОРТ",
}

## Ориентация машины носом прямо по открытому выезду из ангара (+Z, без столкновения со стенами)
const DEFAULT_SHOWCASE_YAW: float = PI

var _cam_base_pos := Vector3(8.85, 2.02, 32.2)
var _cam_time: float = 0.0
var _manual_spin_hold: float = 0.0
var _dragging: bool = false
var _auto_spin: bool = false
var _launching: bool = false
var _launch_timer: float = 0.0
var _launch_start_pos: Vector3 = Vector3.ZERO
var _btn_toggle_tuning: Button = null
var _tuning_expanded: bool = true

var _gate_root: Node3D = null
var _gate_left_door: Node3D = null
var _gate_right_door: Node3D = null
var _gate_lock_bar: MeshInstance3D = null
var _gate_beacons: Array[MeshInstance3D] = []
var _gate_smashed: bool = false
var _gate_smash_elapsed: float = 0.0
var _gate_pieces: Array[Dictionary] = []
var _cam_shake: float = 0.0
var _gate_world_z: float = 40.5
var _raid_transition_started: bool = false
var _exterior_root: Node3D = null
var _raid_shift_fired: bool = false
var _raid_vel: float = 0.0
var _raid_dist: float = 0.0
var _raid_impact_pulse: float = 0.0
var _raid_ignition_fired: bool = false
var _raid_shift2_fired: bool = false

var _sb_norm: StyleBoxFlat
var _sb_hov: StyleBoxFlat
var _sb_pres: StyleBoxFlat
var _sb_prim_n: StyleBoxFlat
var _sb_prim_h: StyleBoxFlat
var _sb_card: StyleBoxFlat
var _sb_badge: StyleBoxFlat
var _sb_upg_dis: StyleBoxFlat
var _sb_upg_max: StyleBoxFlat
var _sb_upg_n: StyleBoxFlat
var _sb_upg_h: StyleBoxFlat

var _upg_card: PanelContainer = null
var _upg_total_lbl: Label = null
var _upg_kit_banner: Label = null
var _upg_rows: Dictionary = {}

# Конфигурация строк улучшений для гаража (порядок отображения)
const UPGRADE_UI_ROWS: Array[Dictionary] = [
	{"key": "fuel", "title": "ТОПЛИВНЫЙ БАК", "hint": "+12.5% объёма / ур.", "btr_hint": "+12.5% объёма / ур."},
	{"key": "engine", "title": "ДВИГАТЕЛЬ И КПП", "hint": "+4.4% скор., +6% тяги", "btr_hint": "+4.4% скор., +6% тяги"},
	{"key": "armor", "title": "БРОНЯ КУЗОВА", "hint": "+13% прочности / ур.", "btr_hint": "+13% брони / ур."},
	{"key": "chassis", "title": "ХОДОВАЯ ЧАСТЬ", "hint": "Подвеска и сцепление", "btr_hint": "Подвеска + турель"}
]

func _ready() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	SettingsManager.apply_settings(self)

	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_menu_ambience"):
		sm.call("set_menu_ambience")

	_apply_visual_styles()
	_build_upgrade_panel()
	_wire_button_audio()
	_setup_hangar_atmosphere()
	_setup_hangar_exit_gate()

	if is_instance_valid(_cam):
		_cam_base_pos = _cam.global_position
		_update_camera(0.016, true)

	current_idx = clampi(Game.selected_car_index, 0, maxi(Game.car_data.size() - 1, 0))
	preload_all_cars()
	update_shop_ui()

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
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func _apply_visual_styles() -> void:
	_sb_norm = _make_box(Color(0.08, 0.09, 0.11, 0.86), Color(0.30, 0.32, 0.36, 0.65), 1, 3, 4)
	_sb_hov = _make_box(Color(0.16, 0.13, 0.14, 0.96), Color(0.90, 0.38, 0.16, 0.98), 1, 5, 4)
	_sb_pres = _make_box(Color(0.24, 0.11, 0.08, 0.98), Color(1.0, 0.56, 0.22, 1.0), 1, 6, 4)
	_sb_prim_n = _make_box(Color(0.34, 0.09, 0.06, 0.94), Color(0.94, 0.34, 0.14, 0.96), 1, 5, 4)
	_sb_prim_h = _make_box(Color(0.48, 0.13, 0.08, 0.98), Color(1.0, 0.54, 0.22, 1.0), 1, 6, 4)

	_sb_card = _make_box(Color(0.05, 0.06, 0.08, 0.78), Color(0.36, 0.38, 0.42, 0.62), 1, -1, 5)
	_sb_card.set_content_margin_all(0)

	_sb_badge = _make_box(Color(0.055, 0.065, 0.085, 0.80), Color(0.36, 0.34, 0.30, 0.65), 1, 3, 4)
	_sb_badge.content_margin_left = 10
	_sb_badge.content_margin_right = 10
	_sb_badge.content_margin_top = 5
	_sb_badge.content_margin_bottom = 5

	_sb_upg_dis = _make_box(Color(0.06, 0.07, 0.08, 0.72), Color(0.24, 0.26, 0.30, 0.45), 1, 3, 4)
	_sb_upg_dis.content_margin_left = 8
	_sb_upg_dis.content_margin_right = 8
	_sb_upg_dis.content_margin_top = 4
	_sb_upg_dis.content_margin_bottom = 4

	_sb_upg_max = _make_box(Color(0.26, 0.16, 0.05, 0.92), Color(0.96, 0.72, 0.24, 0.95), 1, 4, 4)
	_sb_upg_max.content_margin_left = 8
	_sb_upg_max.content_margin_right = 8
	_sb_upg_max.content_margin_top = 4
	_sb_upg_max.content_margin_bottom = 4

	_sb_upg_n = _make_box(Color(0.32, 0.09, 0.06, 0.94), Color(0.94, 0.34, 0.14, 0.96), 1, 4, 4)
	_sb_upg_n.content_margin_left = 8
	_sb_upg_n.content_margin_right = 8
	_sb_upg_n.content_margin_top = 4
	_sb_upg_n.content_margin_bottom = 4

	_sb_upg_h = _make_box(Color(0.46, 0.13, 0.08, 0.98), Color(1.0, 0.54, 0.22, 1.0), 1, 5, 4)
	_sb_upg_h.content_margin_left = 8
	_sb_upg_h.content_margin_right = 8
	_sb_upg_h.content_margin_top = 4
	_sb_upg_h.content_margin_bottom = 4

	var spec_card := find_child("SpecCard", true, false) as PanelContainer
	if spec_card:
		spec_card.add_theme_stylebox_override("panel", _sb_card)
	var money_panel := find_child("MoneyPanel", true, false) as PanelContainer
	if money_panel:
		money_panel.add_theme_stylebox_override("panel", _sb_badge)

	for b in [_btn_prev, _btn_next, _btn_back_menu, _btn_raid]:
		if is_instance_valid(b):
			b.add_theme_stylebox_override("normal", _sb_norm)
			b.add_theme_stylebox_override("hover", _sb_hov)
			b.add_theme_stylebox_override("pressed", _sb_pres)
			b.add_theme_stylebox_override("focus", _sb_hov)

	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.13, 0.14, 0.17, 0.96)
	sb_track.border_color = Color(0.24, 0.26, 0.30, 0.70)
	sb_track.set_border_width_all(1)
	sb_track.set_corner_radius_all(3)

	var sb_fill_spd := StyleBoxFlat.new()
	sb_fill_spd.bg_color = Color(0.92, 0.44, 0.16, 1.0)
	sb_fill_spd.set_corner_radius_all(2)
	var sb_fill_arm := StyleBoxFlat.new()
	sb_fill_arm.bg_color = Color(0.84, 0.22, 0.14, 1.0)
	sb_fill_arm.set_corner_radius_all(2)
	var sb_fill_fuel := StyleBoxFlat.new()
	sb_fill_fuel.bg_color = Color(0.90, 0.64, 0.20, 1.0)
	sb_fill_fuel.set_corner_radius_all(2)

	if is_instance_valid(_bar_speed):
		_bar_speed.add_theme_stylebox_override("background", sb_track)
		_bar_speed.add_theme_stylebox_override("fill", sb_fill_spd)
	if is_instance_valid(_bar_armor):
		_bar_armor.add_theme_stylebox_override("background", sb_track)
		_bar_armor.add_theme_stylebox_override("fill", sb_fill_arm)
	if is_instance_valid(_bar_fuel):
		_bar_fuel.add_theme_stylebox_override("background", sb_track)
		_bar_fuel.add_theme_stylebox_override("fill", sb_fill_fuel)

func _wire_button_audio() -> void:
	var all_btns: Array = [_btn_prev, _btn_next, _btn_buy, _btn_raid, _btn_back_menu, _btn_toggle_tuning]
	for stat_key in _upg_rows.keys():
		var row: Dictionary = _upg_rows[stat_key]
		all_btns.append(row.get("btn"))
	for b in all_btns:
		if is_instance_valid(b) and b is Button:
			var btn := b as Button
			if not btn.mouse_entered.is_connected(_on_btn_hover):
				btn.mouse_entered.connect(_on_btn_hover)

func _build_upgrade_panel() -> void:
	var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas == null or is_instance_valid(_upg_card):
		return

	var russo_font: Font = null
	var jura_font: Font = null
	if is_instance_valid(_car_name_lbl):
		russo_font = _car_name_lbl.get_theme_font("font")
	if is_instance_valid(_index_tag_lbl):
		jura_font = _index_tag_lbl.get_theme_font("font")

	var tog := Button.new()
	tog.name = "BtnToggleTuning"
	tog.anchor_left = 1.0
	tog.anchor_right = 1.0
	tog.anchor_top = 0.0
	tog.anchor_bottom = 0.0
	tog.offset_left = -224.0
	tog.offset_top = 58.0
	tog.offset_right = -18.0
	tog.offset_bottom = 86.0
	tog.text = "ТЮНИНГ ▲"
	tog.add_theme_font_size_override("font_size", 12)
	if russo_font:
		tog.add_theme_font_override("font", russo_font)
	tog.add_theme_stylebox_override("normal", _sb_norm)
	tog.add_theme_stylebox_override("hover", _sb_hov)
	tog.add_theme_stylebox_override("pressed", _sb_pres)
	tog.add_theme_stylebox_override("focus", _sb_hov)
	tog.pressed.connect(_on_toggle_tuning_pressed)
	canvas.add_child(tog)
	_btn_toggle_tuning = tog

	var card := PanelContainer.new()
	card.name = "UpgradeCard"
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -280.0
	card.offset_top = -170.0
	card.offset_right = -18.0
	card.offset_bottom = 184.0
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_theme_stylebox_override("panel", _sb_card)
	canvas.add_child(card)
	_upg_card = card

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	card.add_child(vbox)

	var accent := ColorRect.new()
	accent.custom_minimum_size = Vector2(0, 3)
	accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent.color = Color(0.92, 0.36, 0.14, 1.0)
	var src_accent := find_child("SpecAccent", true, false) as ColorRect
	if src_accent and src_accent.material:
		accent.material = src_accent.material
	vbox.add_child(accent)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	vbox.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 5)
	margin.add_child(inner)

	# Заголовок блока тюнинга
	var hdr_row := HBoxContainer.new()
	inner.add_child(hdr_row)

	var tag_lbl := Label.new()
	tag_lbl.text = "МАСТЕРСКАЯ"
	tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_lbl.add_theme_color_override("font_color", Color(0.66, 0.70, 0.72, 1.0))
	tag_lbl.add_theme_font_size_override("font_size", 10)
	if jura_font:
		tag_lbl.add_theme_font_override("font", jura_font)
	hdr_row.add_child(tag_lbl)

	var total_lbl := Label.new()
	total_lbl.text = "0 / 50"
	total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_lbl.add_theme_color_override("font_color", Color(0.94, 0.74, 0.30, 1.0))
	total_lbl.add_theme_font_size_override("font_size", 11)
	if russo_font:
		total_lbl.add_theme_font_override("font", russo_font)
	hdr_row.add_child(total_lbl)
	_upg_total_lbl = total_lbl

	var title_lbl := Label.new()
	title_lbl.text = "ТЮНИНГ АВТО"
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88, 1.0))
	title_lbl.add_theme_font_size_override("font_size", 16)
	if russo_font:
		title_lbl.add_theme_font_override("font", russo_font)
	inner.add_child(title_lbl)

	var sep_top := HSeparator.new()
	inner.add_child(sep_top)

	for meta: Dictionary in UPGRADE_UI_ROWS:
		var stat_key: String = str(meta["key"])
		var max_lvl: int = Game.get_max_upgrade_level(stat_key)
		var sep_px: int = 1 if max_lvl >= 15 else 2
		var pip_w: float = maxf((88.0 - float(maxi(max_lvl - 1, 0) * sep_px)) / float(maxi(max_lvl, 1)), 2.5)

		var row_box := VBoxContainer.new()
		row_box.add_theme_constant_override("separation", 2)
		inner.add_child(row_box)

		var top_line := HBoxContainer.new()
		top_line.add_theme_constant_override("separation", 4)
		row_box.add_child(top_line)

		var name_lbl := Label.new()
		name_lbl.text = str(meta["title"])
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.92, 0.94, 1.0))
		name_lbl.add_theme_font_size_override("font_size", 11)
		if russo_font:
			name_lbl.add_theme_font_override("font", russo_font)
		top_line.add_child(name_lbl)

		var pips_box := HBoxContainer.new()
		pips_box.custom_minimum_size = Vector2(88, 0)
		pips_box.add_theme_constant_override("separation", sep_px)
		pips_box.alignment = BoxContainer.ALIGNMENT_CENTER
		top_line.add_child(pips_box)
		var pips: Array[ColorRect] = []
		for _i in range(max_lvl):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(pip_w, 6)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.color = Color(0.14, 0.16, 0.20, 1.0)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pips_box.add_child(pip)
			pips.append(pip)

		var lvl_lbl := Label.new()
		lvl_lbl.text = "0/%d" % max_lvl
		lvl_lbl.custom_minimum_size = Vector2(34, 0)
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_lbl.add_theme_color_override("font_color", Color(0.76, 0.80, 0.84, 1.0))
		lvl_lbl.add_theme_font_size_override("font_size", 10)
		if jura_font:
			lvl_lbl.add_theme_font_override("font", jura_font)
		top_line.add_child(lvl_lbl)

		var bot_line := HBoxContainer.new()
		bot_line.add_theme_constant_override("separation", 6)
		row_box.add_child(bot_line)

		var hint_lbl := Label.new()
		hint_lbl.text = str(meta["hint"])
		hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hint_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hint_lbl.clip_text = true
		hint_lbl.add_theme_color_override("font_color", Color(0.62, 0.66, 0.70, 1.0))
		hint_lbl.add_theme_font_size_override("font_size", 10)
		if jura_font:
			hint_lbl.add_theme_font_override("font", jura_font)
		bot_line.add_child(hint_lbl)

		var buy_btn := Button.new()
		buy_btn.custom_minimum_size = Vector2(92, 23)
		buy_btn.text = "1 000 $"
		buy_btn.add_theme_font_size_override("font_size", 11)
		if russo_font:
			buy_btn.add_theme_font_override("font", russo_font)
		buy_btn.pressed.connect(_on_upgrade_pressed.bind(stat_key))
		bot_line.add_child(buy_btn)

		_upg_rows[stat_key] = {
			"meta": meta,
			"pips": pips,
			"lvl_lbl": lvl_lbl,
			"hint_lbl": hint_lbl,
			"btn": buy_btn,
		}

	var sep_bot := HSeparator.new()
	inner.add_child(sep_bot)

	var kit_lbl := Label.new()
	kit_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kit_lbl.text = "10/10 — ставит обвес; 50/50 — камуфляж"
	kit_lbl.add_theme_color_override("font_color", Color(0.72, 0.76, 0.80, 1.0))
	kit_lbl.add_theme_font_size_override("font_size", 10)
	if jura_font:
		kit_lbl.add_theme_font_override("font", jura_font)
	inner.add_child(kit_lbl)
	_upg_kit_banner = kit_lbl


func _on_toggle_tuning_pressed() -> void:
	_play_ui("ui_click", -7.0, 1.05)
	_tuning_expanded = not _tuning_expanded
	if is_instance_valid(_upg_card):
		_upg_card.visible = _tuning_expanded
	if is_instance_valid(_btn_toggle_tuning):
		_btn_toggle_tuning.text = "ТЮНИНГ ▲" if _tuning_expanded else "ТЮНИНГ ▼"

func _refresh_upgrade_panel() -> void:
	if _upg_rows.is_empty():
		return
	var owned: bool = current_idx in Game.owned_cars
	var prog: Vector2i = Game.get_upgrade_progress(current_idx)
	var is_max_kit: bool = Game.is_car_max_upgraded(current_idx)
	var stages: Dictionary = Game.get_maxed_upgrade_stages(current_idx)
	var unlocked_stages: int = 0
	for k in stages.keys():
		if bool(stages[k]):
			unlocked_stages += 1
	var snd_id: String = str(car_instance.get("engine_sound_id")) if is_instance_valid(car_instance) and car_instance.get("engine_sound_id") != null else ""

	if is_instance_valid(_upg_total_lbl):
		if is_max_kit:
			_upg_total_lbl.text = "ПОЛНЫЙ ОБВЕС // %d/%d" % [prog.x, prog.y]
			_upg_total_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.24, 1.0))
		else:
			_upg_total_lbl.text = "%d / %d" % [prog.x, prog.y]
			_upg_total_lbl.add_theme_color_override("font_color", Color(0.92, 0.56, 0.24, 1.0))

	if is_instance_valid(_upg_kit_banner):
		if not owned:
			_upg_kit_banner.text = "Купите машину, чтобы открыть мастерскую и поэтапный обвес"
			_upg_kit_banner.add_theme_color_override("font_color", Color(0.68, 0.68, 0.72, 1.0))
		elif is_max_kit:
			_upg_kit_banner.text = "★ ПОЛНАЯ БРОНЯ И БОЕВОЙ ОКРАС УСТАНОВЛЕНЫ (50/50)"
			_upg_kit_banner.add_theme_color_override("font_color", Color(1.0, 0.78, 0.28, 1.0))
		elif unlocked_stages > 0:
			_upg_kit_banner.text = "Установлено элементов обвеса: %d/4 • На %d/%d откроется боевой окрас" % [unlocked_stages, prog.y, prog.y]
			_upg_kit_banner.add_theme_color_override("font_color", Color(0.96, 0.76, 0.34, 1.0))
		else:
			_upg_kit_banner.text = "Прокачайте любой узел на максимум для этапа обвеса; все %d/%d — боевой окрас" % [prog.y, prog.y]
			_upg_kit_banner.add_theme_color_override("font_color", Color(0.76, 0.80, 0.84, 1.0))

	for stat_key in _upg_rows.keys():
		var row: Dictionary = _upg_rows[stat_key]
		var meta: Dictionary = row["meta"]
		var pips: Array = row["pips"]
		var lvl_lbl := row["lvl_lbl"] as Label
		var hint_lbl := row["hint_lbl"] as Label
		var btn := row["btn"] as Button

		var max_lvl: int = Game.get_max_upgrade_level(stat_key)
		var lvl: int = Game.get_upgrade_level(current_idx, stat_key)
		var is_stat_max: bool = lvl >= max_lvl
		var cost: int = Game.get_upgrade_cost(current_idx, stat_key)
		var can_afford: bool = Game.money >= cost

		if is_instance_valid(hint_lbl):
			hint_lbl.text = str(meta["btr_hint"] if (snd_id == "btr" or snd_id == "paz3205") else meta["hint"])
		if is_instance_valid(lvl_lbl):
			lvl_lbl.text = "%d/%d" % [lvl, max_lvl]
			lvl_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.30, 1.0) if is_stat_max else Color(0.78, 0.82, 0.86, 1.0))

		for i in range(pips.size()):
			var pip := pips[i] as ColorRect
			if not is_instance_valid(pip):
				continue
			if i < lvl:
				pip.color = Color(0.98, 0.76, 0.24, 1.0) if is_stat_max else Color(0.92, 0.44, 0.16, 1.0)
			else:
				pip.color = Color(0.14, 0.16, 0.20, 1.0)

		if is_instance_valid(btn):
			if not owned:
				btn.text = "НЕТ АВТО"
				btn.disabled = true
				btn.add_theme_stylebox_override("disabled", _sb_upg_dis)
				btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.58, 0.62, 1.0))
			elif is_stat_max:
				btn.text = "МАКС. %d/%d" % [max_lvl, max_lvl]
				btn.disabled = true
				btn.add_theme_stylebox_override("disabled", _sb_upg_max)
				btn.add_theme_color_override("font_disabled_color", Color(1.0, 0.84, 0.36, 1.0))
			else:
				btn.text = "%s $" % _format_money(cost)
				btn.disabled = not can_afford
				btn.add_theme_stylebox_override("normal", _sb_upg_n if can_afford else _sb_upg_dis)
				btn.add_theme_stylebox_override("hover", _sb_upg_h if can_afford else _sb_upg_dis)
				btn.add_theme_stylebox_override("pressed", _sb_pres)
				btn.add_theme_stylebox_override("focus", _sb_upg_h if can_afford else _sb_upg_dis)
				btn.add_theme_stylebox_override("disabled", _sb_upg_dis)
				btn.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90, 1.0))
				btn.add_theme_color_override("font_disabled_color", Color(0.74, 0.34, 0.28, 1.0))

func _on_upgrade_pressed(stat_key: String) -> void:
	if _launching or not (current_idx in Game.owned_cars):
		return
	var old_lvl: int = Game.get_upgrade_level(current_idx, stat_key)
	var was_stage_max := Game.is_stat_maxed(current_idx, stat_key)
	if not Game.buy_upgrade(current_idx, stat_key):
		return
	var new_lvl: int = Game.get_upgrade_level(current_idx, stat_key)
	var now_max := Game.is_car_max_upgraded(current_idx)
	var now_stage_max := Game.is_stat_maxed(current_idx, stat_key)
	var stage_unlocked: bool = now_stage_max and not was_stage_max
	var sound_tier_up: bool = (stat_key == "engine") and (floori(float(new_lvl) / 5.0) > floori(float(old_lvl) / 5.0))
	_play_ui("garage_buy" if stage_unlocked else "ui_click", -3.5 if stage_unlocked else -5.5, 1.08 if now_max else (1.02 if stage_unlocked else 1.15))
	if sound_tier_up:
		var sm := get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_sfx"):
			sm.call("play_sfx", "exhaust_backfire", -4.0, 1.04)
			var eng_id: String = str(car_instance.get("engine_sound_id")) if is_instance_valid(car_instance) else ""
			if eng_id != "btr" and (floori(float(new_lvl) / 5.0) >= 2 or eng_id == "raptor" or eng_id == "delorean"):
				sm.call("play_sfx", "turbo_bov", -5.0, 1.02)
	if is_instance_valid(_money_lbl):
		_money_lbl.text = _format_money(Game.money) + " $"
	if is_instance_valid(car_instance):
		if car_instance.has_method("apply_car_upgrades"):
			car_instance.call("apply_car_upgrades", current_idx)
		_populate_vehicle_stats(car_instance)
	_refresh_upgrade_panel()

func _on_btn_hover() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", "ui_hover", -9.0, randf_range(0.95, 1.05))

func _play_ui(key: String, vol: float = -6.0, pitch: float = 1.0) -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ui"):
		sm.call("play_ui", key, vol, pitch)

func _make_soft_radial_texture(size_px: int = 128) -> ImageTexture:
	var img := Image.create(size_px, size_px, false, Image.FORMAT_RGBA8)
	var half := float(size_px - 1) * 0.5
	for y in range(size_px):
		for x in range(size_px):
			var nx: float = (float(x) - half) / half
			var ny: float = (float(y) - half) / half
			var r: float = sqrt(nx * nx + ny * ny)
			var a: float = clampf(1.0 - r, 0.0, 1.0)
			a = a * a * (3.0 - 2.0 * a)
			a *= a
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)

func _setup_hangar_atmosphere() -> void:
	if _spawn == null:
		return

	var radial_tex := _make_soft_radial_texture(128)

	# Overhead concrete light pool decal around spawn turntable (zero SpotLight3D!)
	var pool := MeshInstance3D.new()
	pool.name = "HangarFloorLightPool"
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(7.6, 7.6)
	pool.mesh = plane

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = radial_tex
	mat.albedo_color = Color(0.75, 0.58, 0.38, 0.24)
	pool.material_override = mat
	add_child(pool)
	pool.global_position = _spawn.global_position + Vector3(0.0, 0.025, 0.0)

	# Floating industrial dust motes around showcase
	var motes := CPUParticles3D.new()
	motes.name = "HangarDustMotes"
	motes.amount = 24
	motes.lifetime = 4.5
	motes.preprocess = 2.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(3.6, 1.8, 3.6)
	motes.gravity = Vector3(0.04, 0.03, 0.0)
	motes.initial_velocity_min = 0.04
	motes.initial_velocity_max = 0.14
	motes.scale_amount_min = 0.025
	motes.scale_amount_max = 0.06
	var qm := QuadMesh.new()
	qm.size = Vector2(1.0, 1.0)
	motes.mesh = qm
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pmat.billboard_keep_scale = true
	pmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	pmat.albedo_texture = radial_tex
	pmat.albedo_color = Color(0.90, 0.72, 0.52, 0.42)
	motes.material_override = pmat
	add_child(motes)
	motes.global_position = _spawn.global_position + Vector3(0.0, 1.6, 0.0)

func _make_gate_box(box_size: Vector3, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _build_gate_door(side_sign: float) -> Node3D:
	var door := Node3D.new()
	door.name = "LeftGateDoor" if side_sign < 0.0 else "RightGateDoor"
	door.position = Vector3(side_sign * 2.0, 2.4, 0.0)

	var mat_steel := ProceduralMaterials.get_material("gate_steel")
	var mat_frame := ProceduralMaterials.get_material("pole_steel")
	var mat_rust := ProceduralMaterials.get_material("rusty_metal")
	var mat_haz := ProceduralMaterials.get_material("hazard_stripe")

	# Heavy weathered steel industrial blast door leaf (3.92 x 4.78 x 0.24)
	door.add_child(_make_gate_box(Vector3(3.92, 4.78, 0.24), mat_steel, Vector3.ZERO))
	# Perimeter & central vertical structural I-beams
	door.add_child(_make_gate_box(Vector3(4.00, 0.28, 0.34), mat_frame, Vector3(0.0, 2.26, 0.0)))
	door.add_child(_make_gate_box(Vector3(4.00, 0.32, 0.34), mat_frame, Vector3(0.0, -2.24, 0.0)))
	door.add_child(_make_gate_box(Vector3(0.28, 4.78, 0.34), mat_frame, Vector3(-1.84, 0.0, 0.0)))
	door.add_child(_make_gate_box(Vector3(0.28, 4.78, 0.34), mat_frame, Vector3(1.84, 0.0, 0.0)))
	door.add_child(_make_gate_box(Vector3(0.22, 4.64, 0.32), mat_frame, Vector3(0.0, 0.0, 0.0)))
	# Horizontal stiffener ribs + armored lower kickplate & bolted latch gusset
	door.add_child(_make_gate_box(Vector3(3.84, 0.18, 0.32), mat_frame, Vector3(0.0, 0.85, 0.0)))
	door.add_child(_make_gate_box(Vector3(3.84, 1.35, 0.30), mat_rust, Vector3(0.0, -1.42, 0.0)))
	door.add_child(_make_gate_box(Vector3(0.54, 0.56, 0.38), mat_rust, Vector3(-side_sign * 1.48, -0.18, 0.0)))
	# Subtle weathered caution strip along lower kickplate edge only
	door.add_child(_make_gate_box(Vector3(3.56, 0.16, 0.34), mat_haz, Vector3(0.0, -0.78, 0.0)))
	return door

func _setup_hangar_exit_gate() -> void:
	if _spawn == null or is_instance_valid(_gate_root):
		return
	# Реальный выездной портал самого ангара (Z = 77.2, проём X = [-5.9 .. +15.75], высота Y = 0..8.42)
	var gate_pos := Vector3(_spawn.global_position.x, _spawn.global_position.y - 0.1, 77.2)
	_gate_world_z = gate_pos.z
	_gate_root = Node3D.new()
	_gate_root.name = "HangarExitGate"
	add_child(_gate_root)
	_gate_root.global_position = gate_pos

	var mat_conc := ProceduralMaterials.get_material("concrete_rubble")
	var mat_rust := ProceduralMaterials.get_material("rusty_metal")
	var mat_frame := ProceduralMaterials.get_material("pole_steel")
	var mat_beacon := ProceduralMaterials.get_material("lamp_glow")

	# Бетонные косяки + стальные перегородки, обрамляющие выездной портал ангара
	_gate_root.add_child(_make_gate_box(Vector3(6.2, 8.6, 0.85), mat_rust, Vector3(-7.45, 4.3, 0.0)))
	_gate_root.add_child(_make_gate_box(Vector3(7.9, 8.6, 0.85), mat_rust, Vector3(8.30, 4.3, 0.0)))
	for s in [-1.0, 1.0]:
		_gate_root.add_child(_make_gate_box(Vector3(1.5, 8.6, 1.6), mat_conc, Vector3(s * 4.85, 4.3, 0.0)))
		_gate_root.add_child(_make_gate_box(Vector3(0.48, 8.5, 1.2), mat_frame, Vector3(s * 4.05, 4.25, 0.0)))
		var beacon := _make_gate_box(Vector3(0.44, 0.50, 0.44), mat_beacon, Vector3(s * 4.35, 5.55, -0.92))
		_gate_root.add_child(beacon)
		_gate_beacons.append(beacon)

	# Верхняя стальная фрамуга над створками вплоть до арки ворот ангара (Y = 5.4..8.6)
	_gate_root.add_child(_make_gate_box(Vector3(10.8, 3.35, 1.55), mat_frame, Vector3(0.0, 6.85, 0.0)))
	_gate_root.add_child(_make_gate_box(Vector3(9.8, 0.52, 1.70), mat_rust, Vector3(0.0, 5.18, 0.0)))

	# Яркий прожектор над выездным порталом ангара для подсветки ворот и дороги за ними
	var bay_light := OmniLight3D.new()
	bay_light.name = "ExitGateBayLight"
	bay_light.light_color = Color(1.0, 0.78, 0.52)
	bay_light.light_energy = 2.8
	bay_light.omni_range = 34.0
	bay_light.shadow_enabled = false
	bay_light.position = Vector3(0.0, 6.8, -6.5)
	_gate_root.add_child(bay_light)

	# Пробивные двойные стальные ворота прямо в проёме выхода ангара
	_gate_left_door = _build_gate_door(-1.0)
	_gate_right_door = _build_gate_door(1.0)
	_gate_root.add_child(_gate_left_door)
	_gate_root.add_child(_gate_right_door)

	_gate_lock_bar = _make_gate_box(Vector3(4.8, 0.24, 0.24), mat_frame, Vector3(0.0, 1.68, -0.22))
	_gate_root.add_child(_gate_lock_bar)
	_setup_hangar_exterior_world()

func _freeze_ext_node(node: Node) -> void:
	if node is RigidBody3D:
		var rb := node as RigidBody3D
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
		rb.sleeping = true
	for ch in node.get_children():
		_freeze_ext_node(ch)

func _setup_hangar_exterior_world() -> void:
	if _spawn == null or is_instance_valid(_exterior_root):
		return
	var gate_x: float = _spawn.global_position.x
	var floor_y: float = _spawn.global_position.y - 0.1
	_exterior_root = Node3D.new()
	_exterior_root.name = "HangarExteriorWorld"
	add_child(_exterior_root)
	_exterior_root.global_position = Vector3(gate_x, floor_y, _gate_world_z)

	# 1. Cracked asphalt exterior highway with authentic lane lines (172m from portal onward)
	var st_road := SurfaceTool.new()
	st_road.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rw_half: float = 12.0
	var z_len: float = 172.0
	var z_segs: int = 34
	for iz in range(z_segs):
		var t0 := float(iz) / float(z_segs)
		var t1 := float(iz + 1) / float(z_segs)
		var z0 := lerpf(-0.4, z_len, t0)
		var z1 := lerpf(-0.4, z_len, t1)
		var c0 := Color(clampf((-rw_half / 25.0) * 0.5 + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0)
		var c1 := Color(clampf((rw_half / 25.0) * 0.5 + 0.5, 0.0, 1.0), 0.0, 0.0, 1.0)
		var uv_u: float = 2.4
		var uv_v0: float = (z0 / 10.0)
		var uv_v1: float = (z1 / 10.0)
		st_road.set_color(c0); st_road.set_uv(Vector2(0.0, uv_v0)); st_road.add_vertex(Vector3(-rw_half, 0.01, z0))
		st_road.set_color(c1); st_road.set_uv(Vector2(uv_u, uv_v0)); st_road.add_vertex(Vector3(rw_half, 0.01, z0))
		st_road.set_color(c1); st_road.set_uv(Vector2(uv_u, uv_v1)); st_road.add_vertex(Vector3(rw_half, 0.01, z1))
		st_road.set_color(c0); st_road.set_uv(Vector2(0.0, uv_v0)); st_road.add_vertex(Vector3(-rw_half, 0.01, z0))
		st_road.set_color(c1); st_road.set_uv(Vector2(uv_u, uv_v1)); st_road.add_vertex(Vector3(rw_half, 0.01, z1))
		st_road.set_color(c0); st_road.set_uv(Vector2(0.0, uv_v1)); st_road.add_vertex(Vector3(-rw_half, 0.01, z1))
	st_road.generate_normals()
	var road_mesh := st_road.commit()
	if road_mesh and road_mesh.get_surface_count() > 0:
		var mat_road := ProceduralMaterials.get_material("asphalt")
		if mat_road:
			road_mesh.surface_set_material(0, mat_road)
	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road_mesh
	road_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_exterior_root.add_child(road_mi)

	# 2. Dusty wasteland plains outside hangar
	var mat_desert := ProceduralMaterials.get_material("desert")
	_exterior_root.add_child(_make_gate_box(Vector3(220.0, 0.36, 176.0), mat_desert, Vector3(0.0, -0.22, 87.5)))

	# 3. Flanking apron security fence, concrete barriers, guardrails & utility poles (center X [-4.8..+4.8] clear!)
	var bar_mesh := ProceduralMaterials.get_ph_concrete_barrier_mesh()
	if bar_mesh:
		for s in [-1.0, 1.0]:
			for bz: float in [4.5, 11.5]:
				var bmi := MeshInstance3D.new()
				bmi.mesh = bar_mesh
				bmi.position = Vector3(s * 7.4, 0.0, bz)
				bmi.rotation.y = s * 0.22
				bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_exterior_root.add_child(bmi)

	var fence_mesh := ProceduralMaterials.get_ph_chainlink_fence_mesh()
	if fence_mesh:
		for s in [-1.0, 1.0]:
			for fx: float in [11.5, 16.5]:
				var fmi := MeshInstance3D.new()
				fmi.mesh = fence_mesh
				fmi.position = Vector3(s * fx, 0.0, 2.2)
				fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_exterior_root.add_child(fmi)

	var rail_mesh := ProceduralMaterials.get_guardrail_mesh()
	if rail_mesh:
		for s in [-1.0, 1.0]:
			for gz: float in [20.0, 38.0, 56.0, 74.0, 92.0, 110.0, 128.0]:
				var rmi := MeshInstance3D.new()
				rmi.mesh = rail_mesh
				rmi.position = Vector3(s * 12.6, 0.0, gz)
				rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_exterior_root.add_child(rmi)

	var pole_mesh := ProceduralMaterials.get_ph_utility_pole_mesh()
	if pole_mesh:
		for s in [-1.0, 1.0]:
			for pz: float in [16.0, 44.0, 72.0, 100.0, 128.0]:
				var pmi := MeshInstance3D.new()
				pmi.mesh = pole_mesh
				pmi.position = Vector3(s * 15.0, 0.0, pz)
				pmi.rotation.y = 0.0 if s < 0.0 else PI
				pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				_exterior_root.add_child(pmi)

	var red_drum := ProceduralMaterials.get_ph_barrel_mesh()
	var blue_drum := ProceduralMaterials.get_ph_blue_barrel_mesh()
	var crate_mesh := ProceduralMaterials.get_ph_wooden_crate_mesh()
	var d_spots: Array[Dictionary] = [
		{"pos": Vector3(-6.2, 0.0, 6.2), "red": true},
		{"pos": Vector3(-6.9, 0.0, 7.6), "red": false},
		{"pos": Vector3(6.4, 0.0, 5.4), "red": false},
		{"pos": Vector3(7.1, 0.0, 9.2), "red": true},
		{"pos": Vector3(8.4, 0.0, 16.5), "red": false},
	]
	for ds: Dictionary in d_spots:
		var dm := red_drum if bool(ds["red"]) else blue_drum
		if dm:
			var dmi := MeshInstance3D.new()
			dmi.mesh = dm
			dmi.position = ds["pos"] as Vector3
			dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(dmi)
	if crate_mesh:
		for cp: Vector3 in [Vector3(-8.4, 0.0, 13.5), Vector3(8.5, 0.0, 13.8)]:
			var cmi := MeshInstance3D.new()
			cmi.mesh = crate_mesh
			cmi.position = cp
			cmi.rotation.y = 0.35
			cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(cmi)

	var rock_mesh := ProceduralMaterials.get_ph_boulder_desert_mesh()
	var tree_mesh := ProceduralMaterials.get_scorched_pine_tree_mesh()
	var bb_mesh := ProceduralMaterials.get_billboard_frame_mesh(0)
	var sign_mesh := ProceduralMaterials.get_road_sign_mesh(true)
	for i in range(10):
		var s := -1.0 if (i % 2 == 0) else 1.0
		var z_off: float = 18.0 + float(i) * 14.5
		if rock_mesh:
			var r_mi := MeshInstance3D.new()
			r_mi.mesh = rock_mesh
			r_mi.position = Vector3(s * (22.0 + float((i * 7) % 24)), 0.0, z_off)
			r_mi.scale = Vector3.ONE * (0.9 + float(i % 3) * 0.35)
			r_mi.rotation.y = float(i) * 1.1
			r_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(r_mi)
		if tree_mesh and (i % 2 == 0):
			var t_mi := MeshInstance3D.new()
			t_mi.mesh = tree_mesh
			t_mi.position = Vector3(-s * (24.0 + float((i * 5) % 18)), 0.0, z_off + 6.0)
			t_mi.scale = Vector3.ONE * (0.95 + float(i % 3) * 0.22)
			t_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(t_mi)
	if bb_mesh:
		for bi in range(2):
			var bs := -1.0 if bi == 0 else 1.0
			var bmi := MeshInstance3D.new()
			bmi.mesh = bb_mesh
			bmi.position = Vector3(bs * 18.5, 0.0, 42.0 + float(bi) * 48.0)
			bmi.rotation.y = -bs * 0.25
			bmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(bmi)
	if sign_mesh:
		for si in range(2):
			var s_sign := 1.0 if si == 0 else -1.0
			var smi := MeshInstance3D.new()
			smi.mesh = sign_mesh
			smi.position = Vector3(s_sign * 13.4, 0.0, 24.0 + float(si) * 34.0)
			smi.rotation.y = PI
			smi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_exterior_root.add_child(smi)

	for w_info: Dictionary in [
		{"path": "res://environment/model/decor/wrekers_car/van_001a_reference_smd_3.tscn", "pos": Vector3(-13.8, 0.65, 28.0), "yaw": 0.42},
		{"path": "res://environment/model/decor/wrekers_car/truck_001a_reference_smd_0.tscn", "pos": Vector3(14.2, 1.13, 56.0), "yaw": -0.35},
	]:
		var ps := ResourceLoader.load(String(w_info["path"]), "PackedScene") as PackedScene
		if ps:
			var wr := ps.instantiate() as Node3D
			if wr:
				_exterior_root.add_child(wr)
				wr.position = w_info["pos"] as Vector3
				wr.rotation.y = float(w_info["yaw"])
				_freeze_ext_node(wr)
				ProceduralMaterials.apply_headlight_materials_to_node(wr)

	# 4. Warm dusty wasteland daylight right outside the doorway
	var ext_sun := OmniLight3D.new()
	ext_sun.name = "ExteriorSunGlow"
	ext_sun.light_color = Color(1.0, 0.80, 0.56)
	ext_sun.light_energy = 4.2
	ext_sun.omni_range = 68.0
	ext_sun.shadow_enabled = false
	ext_sun.position = Vector3(0.0, 11.0, 16.0)
	_exterior_root.add_child(ext_sun)

	var ext_far := OmniLight3D.new()
	ext_far.name = "ExteriorHorizonGlow"
	ext_far.light_color = Color(0.95, 0.72, 0.48)
	ext_far.light_energy = 3.2
	ext_far.omni_range = 85.0
	ext_far.shadow_enabled = false
	ext_far.position = Vector3(0.0, 15.0, 72.0)
	_exterior_root.add_child(ext_far)

func _update_camera(_delta: float, immediate: bool = false) -> void:
	if not is_instance_valid(_cam) or _spawn == null:
		return
	var sway_x: float = 0.0 if immediate else sin(_cam_time * 0.45) * 0.16
	var sway_y: float = 0.0 if immediate else cos(_cam_time * 0.35) * 0.06
	var extra_off := Vector3.ZERO
	var focus_lift := 0.0
	if is_instance_valid(car_instance):
		var ext: Variant = car_instance.get("hull_half_extents")
		if ext is Vector2 and (ext as Vector2).y > 2.8:
			var t_big: float = clampf(((ext as Vector2).y - 2.8) / 0.55, 0.0, 1.0)
			extra_off = Vector3(1.15, 0.55, -1.65) * t_big
			focus_lift = 0.42 * t_big
	_cam.global_position = _cam_base_pos + extra_off + Vector3(sway_x, sway_y, 0.0)
	# Центрируем машину между левой SpecCard и правой UpgradeCard
	var target := _spawn.global_position + Vector3(-0.04, 0.84 + focus_lift, 0.25)
	if not _cam.global_position.is_equal_approx(target):
		_cam.look_at(target, Vector3.UP)

func preload_all_cars() -> void:
	for info: Dictionary in Game.car_data:
		var path: String = info["path"]
		var scene := load(path) as PackedScene
		if scene:
			loaded_car_scenes[path] = scene

func _format_money(val: int) -> String:
	var s := str(maxi(val, 0))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and (count % 3) == 0:
			out = " " + out
		out = s[i] + out
		count += 1
	return out

func update_shop_ui() -> void:
	if is_instance_valid(_money_lbl):
		_money_lbl.text = _format_money(Game.money) + " $"

	if Game.car_data.is_empty():
		return

	var car_info: Dictionary = Game.car_data[current_idx]
	if is_instance_valid(_car_name_lbl):
		_car_name_lbl.text = str(car_info.get("name", "Машина #" + str(current_idx + 1)))
	if is_instance_valid(_index_tag_lbl):
		_index_tag_lbl.text = "%02d / %02d  //  ТЕХНИКА" % [current_idx + 1, Game.car_data.size()]

	var is_owned: bool = current_idx in Game.owned_cars
	var is_selected: bool = (current_idx == Game.selected_car_index)

	if is_owned:
		if is_instance_valid(_price_lbl):
			_price_lbl.text = "В АНГАРЕ // ГОТОВА К ВЫЕЗДУ" if is_selected else "В АНГАРЕ // КУПЛЕНО"
			_price_lbl.add_theme_color_override("font_color", Color(0.56, 0.88, 0.46) if is_selected else Color(0.76, 0.84, 0.82))
		if is_instance_valid(_btn_buy):
			if is_selected:
				_btn_buy.text = "ВЫБРАНО"
				_btn_buy.disabled = true
				_btn_buy.add_theme_stylebox_override("normal", _sb_norm)
				_btn_buy.add_theme_stylebox_override("disabled", _sb_norm)
			else:
				_btn_buy.text = "ВЫБРАТЬ"
				_btn_buy.disabled = false
				_btn_buy.add_theme_stylebox_override("normal", _sb_prim_n)
				_btn_buy.add_theme_stylebox_override("hover", _sb_prim_h)
				_btn_buy.add_theme_stylebox_override("pressed", _sb_pres)
		if is_instance_valid(_btn_raid):
			_btn_raid.disabled = false
			_btn_raid.visible = true
	else:
		var price: int = int(car_info.price)
		var can_afford: bool = Game.money >= price
		if is_instance_valid(_price_lbl):
			_price_lbl.text = "ЦЕНА: " + _format_money(price) + " $"
			_price_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.32) if can_afford else Color(0.88, 0.32, 0.24))
		if is_instance_valid(_btn_buy):
			_btn_buy.text = "КУПИТЬ" if can_afford else "НЕ ХВАТАЕТ $"
			_btn_buy.disabled = not can_afford
			_btn_buy.add_theme_stylebox_override("normal", _sb_prim_n if can_afford else _sb_norm)
			_btn_buy.add_theme_stylebox_override("hover", _sb_prim_h if can_afford else _sb_norm)
			_btn_buy.add_theme_stylebox_override("disabled", _sb_norm)
		if is_instance_valid(_btn_raid):
			_btn_raid.disabled = true
			_btn_raid.visible = false

	spawn_car_preview(str(car_info.path))
	_refresh_upgrade_panel()

func spawn_car_preview(path: String) -> void:
	if is_instance_valid(car_instance):
		car_instance.queue_free()
		car_instance = null

	if not loaded_car_scenes.has(path):
		return

	var car_scene: PackedScene = loaded_car_scenes[path]
	car_instance = car_scene.instantiate() as Node3D
	if car_instance == null:
		return
	car_instance.set("is_preview", true)
	add_child(car_instance)

	if car_instance.has_method("apply_car_upgrades"):
		car_instance.call("apply_car_upgrades", current_idx)

	var car_camera := car_instance.find_child("*Camera*", true, false) as Camera3D
	if car_camera:
		car_camera.current = false

	if _spawn:
		car_instance.global_position = _spawn.global_position
	car_instance.rotation.y = DEFAULT_SHOWCASE_YAW

	_populate_vehicle_stats(car_instance)

	if car_instance.has_method("set_preview_mode"):
		car_instance.set_preview_mode(true, true)
	else:
		if car_instance is RigidBody3D:
			car_instance.freeze = true
		car_instance.set_physics_process(false)
	if car_instance.has_method("update_showcase_lights"):
		car_instance.call("update_showcase_lights", 0.016)

func _populate_vehicle_stats(car: Node) -> void:
	if car == null:
		return
	var max_spd: int = int(car.get("MAX_SPEED_KMH")) if car.get("MAX_SPEED_KMH") != null else 150
	var hp_val: int = int(car.get("health")) if car.get("health") != null else 600
	var fuel_val: int = int(car.get("max_fuel")) if car.get("max_fuel") != null else 85
	var snd_id: String = str(car.get("engine_sound_id")) if car.get("engine_sound_id") != null else "pikap"

	if is_instance_valid(_car_role_lbl):
		_car_role_lbl.text = str(ROLE_DESCRIPTIONS.get(snd_id, "БОЕВОЙ ТРАНСПОРТ"))
	if is_instance_valid(_val_speed):
		_val_speed.text = "%d KM/H" % max_spd
	if is_instance_valid(_bar_speed):
		_bar_speed.max_value = 350.0
		_bar_speed.value = clampf(float(max_spd), 0.0, 350.0)
	if is_instance_valid(_val_armor):
		_val_armor.text = "%d" % hp_val
	if is_instance_valid(_bar_armor):
		_bar_armor.max_value = 8400.0
		_bar_armor.value = clampf(float(hp_val), 0.0, 8400.0)
	if is_instance_valid(_val_fuel):
		_val_fuel.text = "%d Л" % fuel_val
	if is_instance_valid(_bar_fuel):
		_bar_fuel.max_value = 720.0
		_bar_fuel.value = clampf(float(fuel_val), 0.0, 720.0)

func set_showcase_angle(yaw_rad: float, auto_spin: bool = false) -> void:
	_auto_spin = auto_spin
	if is_instance_valid(car_instance):
		car_instance.rotation.y = yaw_rad

func _unhandled_input(event: InputEvent) -> void:
	if _launching:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			if not mb.pressed:
				_manual_spin_hold = 0.0
	elif event is InputEventMouseMotion and _dragging:
		if is_instance_valid(car_instance):
			car_instance.rotate_y((event as InputEventMouseMotion).relative.x * 0.0085)
			_manual_spin_hold = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_LEFT or k == KEY_A:
			_on_back_pressed()
			get_viewport().set_input_as_handled()
		elif k == KEY_RIGHT or k == KEY_D:
			_on_next_pressed()
			get_viewport().set_input_as_handled()
		elif k == KEY_ESCAPE:
			_on_back_menu_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_cam_time += delta
	for i in range(_gate_beacons.size()):
		var b := _gate_beacons[i]
		if is_instance_valid(b):
			var pulse := 0.55 + 0.45 * sin(_cam_time * (9.5 if _launching else 3.2) + float(i) * PI)
			b.scale = Vector3.ONE * lerpf(0.85, 1.18, pulse)
	if is_instance_valid(car_instance) and car_instance.has_method("update_showcase_lights"):
		car_instance.call("update_showcase_lights", delta)
	if _launching:
		_step_raid_launch(delta)
		return
	if is_instance_valid(car_instance) and not _dragging:
		if _auto_spin:
			if _manual_spin_hold > 0.0:
				_manual_spin_hold -= delta
			else:
				car_instance.rotate_y(delta * 0.42)
		else:
			car_instance.rotation.y = lerp_angle(car_instance.rotation.y, DEFAULT_SHOWCASE_YAW, clampf(delta * 8.5, 0.0, 1.0))
	_update_camera(delta, false)

func _smash_hangar_gate() -> void:
	if _gate_smashed:
		return
	_gate_smashed = true
	_cam_shake = 1.08
	_raid_vel = maxf(_raid_vel * 0.84, 14.5)
	_raid_impact_pulse = 0.14
	var floor_y: float = (_spawn.global_position.y - 0.1) if _spawn else 0.0
	var impact_pos := Vector3(_launch_start_pos.x, floor_y + 1.4, _gate_world_z)

	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "crash_heavy", 1.5, 0.90)
		sm.call("play_sfx", "prop_clang_metal", 0.5, 0.82)
		sm.call("play_sfx", "crash_metal", -1.0, 0.95)

	CarVFX.spawn_crash_debris(impact_pos, Vector3(0.0, 0.35, 1.0), 34.0, "metal", Color(0.88, 0.62, 0.14))
	CarVFX.spawn_crash_debris(impact_pos + Vector3(-1.4, 1.1, 0.2), Vector3(-0.32, 0.42, 1.0), 28.0, "metal_electric", Color(0.28, 0.30, 0.33))
	CarVFX.spawn_crash_debris(impact_pos + Vector3(1.4, 1.1, 0.2), Vector3(0.32, 0.42, 1.0), 28.0, "metal_electric", Color(0.28, 0.30, 0.33))

	if is_instance_valid(_gate_left_door):
		_gate_pieces.append({
			"node": _gate_left_door,
			"vel": Vector3(-11.5, 4.2, 26.0),
			"ang_vel": Vector3(3.4, -5.8, 2.8),
			"half_h": 1.3,
			"bounced": false,
		})
	if is_instance_valid(_gate_right_door):
		_gate_pieces.append({
			"node": _gate_right_door,
			"vel": Vector3(11.5, 4.4, 26.0),
			"ang_vel": Vector3(3.8, 6.2, -3.1),
			"half_h": 1.3,
			"bounced": false,
		})
	if is_instance_valid(_gate_lock_bar):
		_gate_pieces.append({
			"node": _gate_lock_bar,
			"vel": Vector3(-2.4, 7.2, 33.5),
			"ang_vel": Vector3(8.5, 4.2, -6.4),
			"half_h": 0.25,
			"bounced": false,
		})

	if is_instance_valid(_gate_root):
		var shard_mats: Array[Material] = [
			ProceduralMaterials.get_material("gate_steel"),
			ProceduralMaterials.get_material("rusty_metal"),
			ProceduralMaterials.get_material("pole_steel"),
		]
		for k in range(6):
			var dir_x := -1.0 if (k % 2 == 0) else 1.0
			var shard := _make_gate_box(Vector3(randf_range(0.55, 1.15), randf_range(0.06, 0.14), randf_range(0.30, 0.72)), shard_mats[k % shard_mats.size()], Vector3(dir_x * randf_range(0.5, 2.6), randf_range(0.8, 3.0), -0.1))
			_gate_root.add_child(shard)
			_gate_pieces.append({
				"node": shard,
				"vel": Vector3(dir_x * randf_range(6.0, 15.0), randf_range(5.5, 11.5), randf_range(22.0, 36.0)),
				"ang_vel": Vector3(randf_range(-11.0, 11.0), randf_range(-10.0, 10.0), randf_range(-11.0, 11.0)),
				"half_h": 0.25,
				"bounced": false,
			})

func _step_gate_debris(delta: float) -> void:
	var floor_y: float = (_spawn.global_position.y - 0.1) if _spawn else 0.0
	for p: Dictionary in _gate_pieces:
		var node := p["node"] as Node3D
		if not is_instance_valid(node):
			continue
		var vel: Vector3 = p["vel"]
		var ang_vel: Vector3 = p["ang_vel"]
		var half_h: float = float(p["half_h"])
		vel.y -= 21.0 * delta
		node.global_position += vel * delta
		node.rotation += ang_vel * delta
		if node.global_position.y <= floor_y + half_h and vel.y < 0.0:
			node.global_position.y = floor_y + half_h
			vel.y = absf(vel.y) * 0.36
			vel.x *= 0.78
			vel.z *= 0.78
			ang_vel *= 0.65
			if not bool(p["bounced"]):
				p["bounced"] = true
				CarVFX.spawn_crash_debris(node.global_position, Vector3(0.0, 0.4, 0.8), 14.0, "metal_electric", Color(0.4, 0.4, 0.42))
		p["vel"] = vel
		p["ang_vel"] = ang_vel

func _step_raid_launch(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_launch_timer += dt
	if _gate_smashed:
		_gate_smash_elapsed += dt
	if _raid_impact_pulse > 0.0:
		_raid_impact_pulse = maxf(_raid_impact_pulse - dt, 0.0)
	var time_mul := 0.62 if _raid_impact_pulse > 0.0 else 1.0
	var sim_dt := dt * time_mul
	_step_gate_debris(sim_dt)
	_cam_shake = maxf(_cam_shake - dt * 1.45, 0.0)

	if is_instance_valid(car_instance):
		var launch_dir := Vector3.BACK
		var sm := get_node_or_null("/root/SoundManager")
		var snd_id: String = str(car_instance.get("engine_sound_id")) if car_instance.get("engine_sound_id") != null else "pikap"
		var accel: float = 0.0
		var rpm_p: float = 1.05
		var pitch_squat: float = 0.0
		var roll_torque: float = 0.0
		var x_sway: float = 0.0
		var yaw_off: float = 0.0
		var steer_vis: float = 0.0
		var wheel_mps: float = 0.0
		var skid_db: float = -18.0
		var spin_all: bool = false

		if _launch_timer < 0.38:
			# Фаза 1: зажигание, рывок крутящего момента и прогазовка на месте
			var t1 := clampf(_launch_timer / 0.38, 0.0, 1.0)
			if not _raid_ignition_fired:
				_raid_ignition_fired = true
				if sm and sm.has_method("play_vehicle_sfx"):
					sm.call("play_vehicle_sfx", "exhaust_backfire", -9.0, randf_range(0.88, 0.98))
			roll_torque = sin(t1 * PI) * 0.028
			pitch_squat = lerpf(0.0, 0.018, t1)
			rpm_p = lerpf(0.92, 1.32, t1 * t1)
			wheel_mps = lerpf(4.0, 18.0, t1)
			skid_db = -26.0
		elif _launch_timer < 1.24:
			# Фаза 2: тяжёлый бёрнаут — дым из-под задних колёс, приседание кормы, ползучий срыв
			var t2 := clampf((_launch_timer - 0.38) / 0.86, 0.0, 1.0)
			var target_v := lerpf(0.0, 2.3, t2 * t2)
			_raid_vel = lerpf(_raid_vel, target_v, clampf(sim_dt * 6.5, 0.0, 1.0))
			_raid_dist += _raid_vel * sim_dt
			var jitter_x := sin(_launch_timer * 42.0) * 0.016 * t2
			x_sway = jitter_x
			pitch_squat = lerpf(0.018, 0.039, sqrt(t2))
			roll_torque = sin(t2 * PI) * 0.020 + sin(_launch_timer * 29.0) * 0.006
			yaw_off = sin(_launch_timer * 14.0) * 0.015 * t2
			steer_vis = sin(_launch_timer * 14.0) * -0.10 * t2
			rpm_p = lerpf(1.28, 1.62, t2)
			wheel_mps = lerpf(22.0, 48.0, t2)
			skid_db = lerpf(-12.0, -8.5, t2)
		else:
			# Фаза 3–4: 1-я передача (зацеп + виляние кормы) -> переключение на 2-ю перед воротами -> таран ворот и выход
			var t_el := _launch_timer - 1.24
			spin_all = true
			if t_el < 1.04:
				# 1-я передача: зацеп и стремительный набор ~16 м/с
				var u1 := clampf(t_el / 1.04, 0.0, 1.0)
				accel = lerpf(8.5, 14.8, smoothstep(0.0, 0.35, u1))
				_raid_vel += accel * sim_dt
				rpm_p = lerpf(1.22, 1.76, u1)
				pitch_squat = 0.036 * exp(-t_el * 0.8)
				skid_db = lerpf(-10.5, -24.0, u1)
			elif t_el < 1.22:
				# Короткий провал тяги на переключении 1 -> 2, кивок носа и отстрел выхлопа
				var s_u := clampf((t_el - 1.04) / 0.18, 0.0, 1.0)
				if not _raid_shift_fired:
					_raid_shift_fired = true
					if sm and sm.has_method("play_vehicle_sfx"):
						sm.call("play_vehicle_sfx", "gear_shift_up", -3.8, 0.96)
						sm.call("play_vehicle_sfx", "exhaust_backfire", -7.2, 0.92)
						if snd_id == "raptor" or snd_id == "delorean":
							sm.call("play_vehicle_sfx", "turbo_bov", -5.2, 1.0)
				accel = 1.6
				_raid_vel += accel * sim_dt
				rpm_p = lerpf(1.74, 1.18, sin(s_u * PI * 0.5))
				pitch_squat = lerpf(0.024, -0.017, sin(s_u * PI))
				skid_db = -30.0
			else:
				# 2-я -> 3-я передача: уверенный таран ворот на ~90–102 км/ч и выход на трассу
				var u2 := clampf((t_el - 1.22) / 1.85, 0.0, 1.0)
				if t_el >= 2.28 and not _raid_shift2_fired:
					_raid_shift2_fired = true
					if sm and sm.has_method("play_vehicle_sfx"):
						sm.call("play_vehicle_sfx", "gear_shift_up", -4.2, 1.03)
						if snd_id == "raptor" or snd_id == "delorean":
							sm.call("play_vehicle_sfx", "turbo_bov", -5.5, 1.04)
						elif snd_id in ["doge2", "mustang", "barracuda", "carson", "delorean"]:
							sm.call("play_vehicle_sfx", "exhaust_backfire", -7.8, 1.02)
				accel = lerpf(11.8, 6.2, u2)
				_raid_vel = minf(_raid_vel + accel * sim_dt, 30.5)
				var s2_win := 1.0 - clampf(absf(t_el - 2.34) / 0.11, 0.0, 1.0)
				rpm_p = lerpf(1.24, 1.72, u2) - s2_win * 0.30
				pitch_squat = lerpf(0.020 * (1.0 - u2 * 0.5), -0.012, s2_win)
				skid_db = -36.0
			_raid_dist += _raid_vel * sim_dt
			x_sway = sin(t_el * 4.2) * exp(-t_el * 1.35) * 0.58
			yaw_off = cos(t_el * 4.2) * exp(-t_el * 1.25) * 0.056
			steer_vis = clampf(-yaw_off * 2.5, -0.35, 0.35)
			wheel_mps = maxf(_raid_vel * 1.22, 12.0)

		car_instance.global_position = _launch_start_pos + launch_dir * _raid_dist + Vector3(x_sway, 0.0, 0.0)
		car_instance.rotation = Vector3(pitch_squat, DEFAULT_SHOWCASE_YAW + yaw_off, roll_torque - yaw_off * 0.34)
		if car_instance.has_method("step_burnout_visuals"):
			car_instance.call("step_burnout_visuals", sim_dt, wheel_mps, steer_vis, rpm_p, skid_db, spin_all)

		if not _gate_smashed and car_instance.global_position.z + 2.45 >= _gate_world_z:
			_smash_hangar_gate()

		if is_instance_valid(_cam):
			var cam_goal := Vector3.ZERO
			var look_goal := Vector3.ZERO
			if _launch_timer < 1.24:
				var p_arc := clampf(_launch_timer / 1.24, 0.0, 1.0)
				var p_smooth := p_arc * p_arc * (3.0 - 2.0 * p_arc)
				var mid_ctrl := Vector3(11.0, 2.25, 22.8)
				var chase_start := _launch_start_pos + Vector3(-2.35, 1.98, -6.2)
				var a := _cam_base_pos.lerp(mid_ctrl, p_smooth)
				var b := mid_ctrl.lerp(chase_start, p_smooth)
				cam_goal = a.lerp(b, p_smooth)
				var idle_focus := _spawn.global_position + Vector3(-0.04, 0.84, 0.25)
				var gate_focus := Vector3(_launch_start_pos.x, _launch_start_pos.y + 1.6, _gate_world_z)
				look_goal = idle_focus.lerp(gate_focus, p_smooth)
			else:
				cam_goal = car_instance.global_position + Vector3(-1.85, 1.95, -6.6)
				cam_goal.z = minf(cam_goal.z, _gate_world_z - 5.2)
				look_goal = car_instance.global_position + Vector3(0.0, 1.30, 7.5)
			if _cam_shake > 0.005:
				cam_goal += Vector3(sin(_launch_timer * 52.0), cos(_launch_timer * 61.0), 0.0) * (_cam_shake * 0.36)
			_cam.global_position = _cam.global_position.lerp(cam_goal, clampf(dt * 7.2, 0.0, 1.0))
			_cam.global_position.z = minf(_cam.global_position.z, _gate_world_z - 5.0)
			var spd_t := clampf(_raid_vel / 28.0, 0.0, 1.0)
			var target_fov := lerpf(54.0, 69.0, spd_t)
			_cam.fov = lerpf(_cam.fov, target_fov, clampf(dt * 4.5, 0.0, 1.0))
			if not _cam.global_position.is_equal_approx(look_goal):
				_cam.look_at(look_goal, Vector3.UP)

	# Провожаем машину взглядом через выбитые ворота ~30-35м на внешнюю дорогу перед плавным переходом
	if ((_gate_smashed and _gate_smash_elapsed >= 1.15) or _launch_timer >= 4.75) and not _raid_transition_started:
		_raid_transition_started = true
		SceneTransition.transition_to_scene("res://levels/main.tscn", 0.38, 0.45)
	elif _raid_transition_started and _gate_smash_elapsed >= 1.45:
		if is_instance_valid(car_instance) and car_instance.has_method("set_preview_mode"):
			car_instance.call("set_preview_mode", true, false)
		var sm2 := get_node_or_null("/root/SoundManager")
		if sm2 and sm2.has_method("stop_transient_sfx"):
			sm2.call("stop_transient_sfx")
		set_process(false)

func _on_next_pressed() -> void:
	if _launching:
		return
	_play_ui("ui_click", -7.0, 1.0)
	current_idx = (current_idx + 1) % Game.car_data.size()
	update_shop_ui()

func _on_back_pressed() -> void:
	if _launching:
		return
	_play_ui("ui_click", -7.0, 0.96)
	current_idx = (current_idx - 1 + Game.car_data.size()) % Game.car_data.size()
	update_shop_ui()

func _on_buy_pressed() -> void:
	if _launching:
		return
	var car_info: Dictionary = Game.car_data[current_idx]
	if current_idx in Game.owned_cars:
		Game.select_car(current_idx)
		_play_ui("garage_select", -4.0, 1.0)
	else:
		if Game.buy_car(current_idx, int(car_info.price)):
			_play_ui("garage_buy", -3.0, 1.0)
	update_shop_ui()

func _on_raid_pressed() -> void:
	if _launching or not (current_idx in Game.owned_cars):
		return
	Game.select_car(current_idx)
	_launching = true
	_launch_timer = 0.0
	_raid_vel = 0.0
	_raid_dist = 0.0
	_raid_impact_pulse = 0.0
	_raid_ignition_fired = false
	_raid_shift_fired = false
	_raid_shift2_fired = false
	_dragging = false
	_play_ui("garage_select", -4.0, 1.05)

	for btn in [_btn_buy, _btn_raid, _btn_next, _btn_prev, _btn_back_menu, _btn_toggle_tuning]:
		if is_instance_valid(btn):
			btn.disabled = true

	var canvas := get_node_or_null("CanvasLayer") as CanvasLayer
	if canvas:
		var tw := create_tween().set_parallel(true)
		for ui_name in ["SpecCard", "UpgradeCard", "BtnToggleTuning", "BottomDock", "TopLeftHeader", "MoneyPanel"]:
			var ctrl := canvas.get_node_or_null(ui_name) as Control
			if ctrl:
				tw.tween_property(ctrl, "modulate:a", 0.0, 0.34).set_ease(Tween.EASE_OUT)

	if is_instance_valid(car_instance):
		car_instance.rotation.y = DEFAULT_SHOWCASE_YAW
		_launch_start_pos = car_instance.global_position
		if car_instance.has_method("start_burnout_vfx"):
			car_instance.call("start_burnout_vfx", true)

func _on_back_menu_pressed() -> void:
	if _launching or SceneTransition.is_transitioning():
		return
	_launching = true
	_play_ui("ui_click", -7.0, 1.0)
	SceneTransition.transition_to_scene("res://ui/menu.tscn")
