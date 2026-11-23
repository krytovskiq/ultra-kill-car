extends RigidBody3D

const MPS_TO_KMH := 3.6
const ZOMBIE_KILL_REWARD := 10

const HEADLIGHT_COOKIE_TEX: Texture2D = preload("res://entities/vehicles/textures/headlight_cookie.png")
const TAILLIGHT_COOKIE_TEX: Texture2D = preload("res://entities/vehicles/textures/taillight_cookie.png")
const SHADOW_BLOB_TEX: Texture2D = preload("res://entities/vehicles/textures/car_shadow_blob.png")

const SHADER_HEADLIGHT_PROJ: Shader = preload("res://entities/vehicles/shaders/headlight_projection.gdshader")
const SHADER_LIGHT_BEAM: Shader = preload("res://entities/vehicles/shaders/light_beam.gdshader")
const SHADER_CAR_SHADOW: Shader = preload("res://entities/vehicles/shaders/car_shadow.gdshader")
const SHADER_HEADLIGHT_LENS: Shader = preload("res://entities/vehicles/shaders/headlight_lens.gdshader")
const SHADER_ACCENT_BAR: Shader = preload("res://ui/shaders/menu_accent_bar.gdshader")
const ProceduralMaterials = preload("res://levels/procedural_materials.gd")

const DEATH_SCREEN_SCENE: PackedScene = preload("res://ui/death_screen.tscn")
const FONT_DIRT: FontFile = preload("res://assets/fonts/RubikDirt-Regular.ttf")
const FONT_RUSSO: FontFile = preload("res://assets/fonts/RussoOne-Regular.ttf")
const FONT_JURA: FontFile = preload("res://assets/fonts/Jura-Variable.ttf")

static var _cached_beam_mesh: ArrayMesh = null
static var _cached_halo_mesh: QuadMesh = null

var total_distance: float = 0.0
var start_z_position: float = 0.0
var _run_money: int = 0
var _run_kills: int = 0
var _last_run_earned: int = 0
var _rewards_committed: bool = false

# ==============================================================================
# РУЧНАЯ НАСТРОЙКА ПАРАМЕТРОВ ТРАНСПОРТА (БАЗОВЫЕ ПО УМОЛЧАНИЮ)
# Конкретные значения для каждой машины переопределяются в её скрипте:
#   pikap.gd / doge_2.gd / mustang.gd / raptor.gd / btr.gd
# ==============================================================================
@export_group("Driving")
## Скорость поворота руля (чем больше — тем резче отклик руля)
@export var STEER_SPEED: float = 2.4
## Максимальный угол поворота передних колёс в радианах (0.29..0.42)
@export var STEER_LIMIT: float = 0.40
## Инерция / вес рулевой рейки (меньше = тяжелее руль)
@export var steer_inertia: float = 5.5
## Минимальная доля угла поворота на максимальной скорости (чтобы не заносило)
@export var high_speed_steer_min_ratio: float = 0.20
## Скорость набора тяги при нажатии газа (меньше = плавнее/тяжелее разгон)
@export var throttle_response: float = 3.8
## Скорость сброса газа при отпускании педали W
@export var throttle_release_rate: float = 5.5
## Сила двигателя / крутящий момент (чем выше — тем быстрее разгон)
@export var engine_force_value: int = 7500
## Базовая сила тормозов
@export var brake_force: float = 95.0
## Максимальное замедление при торможении (м/с²)
@export var max_brake_decel_mps2: float = 10.2
## Аэродинамическое сопротивление воздуха на высокой скорости
@export var aero_drag_coeff: float = 0.48
## Максимальная скорость машины (км/ч) — также усиливается прокачкой в гараже
@export var MAX_SPEED_KMH: int = 200
## Аэродинамическая прижимная сила на скорости
@export var downforce_multiplier: float = 12.0
## Максимальная прижимная сила (Н), ограничивающая чрезмерное вдавливание на предельных скоростях
@export var downforce_max: float = 9500.0

@export_group("Suspension & Handling")
## Общая жёсткость пружин подвески
@export var suspension_firmness: float = 1.25
## Демпфирование сжатия амортизатора (пробой при падении)
@export var compression_damping_ratio: float = 0.60
## Демпфирование отбоя амортизатора (раскачка вверх)
@export var rebound_damping_ratio: float = 0.60
## Жёсткость стабилизатора поперечной устойчивости (меньше крен в поворотах)
@export var anti_roll_stiffness: float = 7800.0
## Боковая жёсткость шин (цепкость в поворотах)
@export var lateral_stiffness: float = 12.5
## Коэффициент сцепления покрышек с асфальтом
@export var tire_friction: float = 2.35
## Сцепление при заносе (1.0 = без срыва, 0.65 = лёгкий контролируемый дрифт)
@export var drift_grip_factor: float = 0.78
## Множитель сцепления шин на зимнем гололёде (меньше = сильнее скользит, но остаётся управляемым)
@export var ice_grip_scale: float = 0.56
## Максимальный угол контролируемого заноса (градусы), выше него кузов плавно стабилизируется
@export var drift_max_angle_deg: float = 36.0
## Помощь контр-рулением при выходе из заноса (тяга возврата в полосу)
@export var drift_countersteer_assist: float = 4.6
## Сила самовыравнивания машины по курсу, когда руль отпущен
@export var drift_self_align_strength: float = 3.0
## Сцепление задней оси при зажатии ручного тормоза (Shift / Space)
@export var handbrake_rear_grip: float = 0.36
## Высота центра масс (ниже = устойчивее к переворотам)
@export var com_height: float = 0.34
## Продольное смещение центра масс (отрицательное = тяжелее перед/мотор)
@export var com_z_offset: float = 0.0
## Колёсная база в метрах (влияет на радиус поворота)
@export var wheelbase_m: float = 3.05
## Торможение колёс о дорогу при сильном повороте руля
@export var steering_scrub_drag: float = 0.14
## Сколько скорости сохраняется при пробивании препятствий и зомби (0.6..0.96)
@export var impact_momentum_keep: float = 0.75
## Сила поперечного крена кузова от бокового ускорения и поворота
@export var body_roll_torque_factor: float = 0.65
## Сила продольного клевка кузова при разгоне и торможении
@export var body_pitch_torque_factor: float = 0.52
## Помощь курсовой устойчивости ESC (выше = меньше виляние кормы)
@export var yaw_stability_assist: float = 3.2
## Момент выравнивания кузова в воздухе (уменьшает переворот при прыжках)
@export var air_stabilize_torque: float = 4.2
## Полуширина и полудлина кузова в плане (X = полширины, Y = полдлины в метрах)
@export var hull_half_extents: Vector2 = Vector2(1.08, 2.40)
## Жёсткость передних пружин (-1 = авторасчёт от веса машины)
@export var front_spring_stiffness: float = -1.0
## Жёсткость задних пружин (-1 = авторасчёт от веса машины)
@export var rear_spring_stiffness: float = -1.0
## Множитель длины хода передней подвески в покое (клиренс спереди)
@export var front_rest_length_scale: float = 1.0
## Множитель длины хода задней подвески в покое (клиренс сзади)
@export var rear_rest_length_scale: float = 1.0
## Баланс сцепления передних шин относительно задних (меньше = спокойнее руль)
@export var front_grip_bias: float = 0.97
## Баланс сцепления задних шин (выше = стабильнее задняя ось под газом)
@export var rear_grip_bias: float = 1.13
## Скорость визуального отклика колёс и хода подвески (выше = быстрее отрабатывает кочки)
@export var suspension_travel_speed: float = 20.0
## Перераспределение веса продольно при разгоне/торможении (загрузка осей)
@export var weight_transfer_long: float = 0.20
## Перераспределение веса поперечно в повороте (загрузка внешних колёс)
@export var weight_transfer_lat: float = 0.24

@export_group("Audio")
## Идентификатор звукового профиля двигателя (pikap / doge2 / mustang / raptor / btr)
@export var engine_sound_id: String = "pikap"
## Базовая высота тона двигателя
@export var engine_pitch_scale: float = 1.0
## Пороги скоростей (доля от MAX_SPEED_KMH) переключения передач КПП
@export var gear_speed_ratios: Array[float] = [0.24, 0.48, 0.74, 1.04]
## Множители крутящего момента для каждой передачи
@export var gear_torque_multipliers: Array[float] = [1.55, 1.18, 0.88, 0.66]
## Хлопки (отстрелы) выхлопа при переключении передач вверх
@export var has_exhaust_backfire: bool = false
@export var gear_shift_pitch_base: float = 1.0

@export_group("Visual Texture Lights & Shadow")
@export var use_visual_lights: bool = true
@export var shadow_texture: Texture2D = null
@export var shadow_blob_size: Vector2 = Vector2(4.6, 8.6)
@export var shadow_offset: Vector2 = Vector2.ZERO
@export var headlight_positions: Array[Vector3] = [Vector3(-0.70, 0.72, -2.35), Vector3(0.70, 0.72, -2.35)]
@export var taillight_positions: Array[Vector3] = [Vector3(-0.70, 0.76, 2.35), Vector3(0.70, 0.76, 2.35)]
@export var headlight_lens_size: Vector2 = Vector2(0.32, 0.32)
@export var taillight_lens_size: Vector2 = Vector2(0.30, 0.24)
@export var headlight_proj_size: Vector2 = Vector2(14.0, 34.0)
@export var headlight_proj_z_start: float = -2.35
@export var taillight_proj_size: Vector2 = Vector2(3.8, 2.3)
@export var taillight_proj_z_start: float = 2.35

@export_group("Health")
## Базовая прочность (броня / HP) машины до прокачки
@export var health: int = 100
## Множитель урона от столкновения с препятствиями
@export var collision_damage_multiplier: float = 0.45
## Включить 3D-деформацию кузова при ударах об объекты (отключено у БТР)
@export var can_deform_body: bool = true
## Множитель урона по прочности от сбивания дорожных объектов (столбы, знаки, барьеры)
@export var prop_damage_multiplier: float = 3.2
## Множитель урона по прочности от тарана обломков машин и грузовиков
@export var wreck_damage_multiplier: float = 4.2
@export var engine_hood_offset: Vector3 = Vector3(0.0, 0.95, -1.70)
@export var car_paint_color: Color = Color(0.35, 0.35, 0.38)

@export_group("Zombie Collision")
## Минимальная скорость (м/с), с которой преграды начинают наносить урон
@export var wall_damage_min_speed_mps: float = 5.0
## Скорость лобового удара о мёртвую стену для мгновенного уничтожения (м/с)
@export var crash_death_speed_mps: float = 20.0
## Базовый урон кузову за каждого сбитого зомби
@export var zombie_damage_taken: int = 10

@export_group("Fuel")
## Базовый объём топливного бака в литрах (прокачивается в гараже)
@export var max_fuel: int = 100
@export var fuel_consumption: float = 1.0
## Расход топлива в литрах на 100 метров пути под газом
@export var fuel_per_100m: float = 3.4
## Расход топлива в секунду на холостом ходу / при движении
@export var idle_fuel_per_sec: float = 0.22

@export var DeadParticles: PackedScene
@export var exhaust_offset: Vector3 = Vector3(-0.4, 0.15, 1.5)
@export var exhaust_offsets: Array[Vector3] = []
@export var exhaust_style: String = "gasoline"

@export_group("Enemy Damage")
@export var damage_per_second: int = 10

var steering: float = 0.0
var engine_force: float = 0.0
var brake: float = 0.0

var current_fuel: float = 0.0
var current_hp: int = 0
var destroyed: bool = false
var is_preview: bool = false
var damage_timer: float = 0.0
var grounded_wheels: int = 0

var _wheels: Array[RaycastWheel] = []
var _front_left: RaycastWheel = null
var _front_right: RaycastWheel = null
var _rear_left: RaycastWheel = null
var _rear_right: RaycastWheel = null

var _tire_smokes: Array[CPUParticles3D] = []
var _exhaust: CPUParticles3D = null
var _exhausts: Array[CPUParticles3D] = []
var _showcase_mode: bool = false

var _lights_rig: Node3D = null
var _shadow_mesh: MeshInstance3D = null
var _shadow_mat: ShaderMaterial = null
var _head_proj_mesh: MeshInstance3D = null
var _head_proj_mat: ShaderMaterial = null
var _tail_proj_mesh: MeshInstance3D = null
var _tail_proj_mat: ShaderMaterial = null
var _head_beam_mats: Array[ShaderMaterial] = []
var _head_beam_nodes: Array[Node3D] = []
var _tail_lens_mats: Array[ShaderMaterial] = []
var _head_lens_mats: Array[ShaderMaterial] = []

var _engine_audio: AudioStreamPlayer = null
var _engine_idle_audio: AudioStreamPlayer = null
var _engine_howl_audio: AudioStreamPlayer = null
var _engine_boost_audio: AudioStreamPlayer = null
var _skid_audio: AudioStreamPlayer = null
var _fire_audio: AudioStreamPlayer = null
var _engine_upgrade_tier: int = 0
var _air_revving: bool = false
var _air_rev_limiter_phase: float = 0.0
var _air_backfire_cd: float = 0.0
var _damage_smoke: CPUParticles3D = null
var _damage_fire_root: Node3D = null
var _engine_fire_level: float = 0.0
var _smooth_throttle: float = 0.0
var _launch_wheelspin: float = 0.0
var _steer_target_filtered: float = 0.0
var _sim_rpm: float = 0.18
var _smooth_skid_vol: float = 0.0
var _current_gear: int = 1
var _shift_timer: float = 0.0
var _shift_cooldown: float = 0.0
var _gear_shift_count: int = 0
var _display_gear: String = "N"
var _empty_fuel_stall_timer: float = 0.0
var _brake_pressure: float = 0.0
var _siphon_combo: int = 0
var _siphon_combo_timer: float = 0.0
var _overdrive_timer: float = 0.0
var _hud_notice_timer: float = 0.0
var _hud_notice_text: String = ""
var _hud_notice_color: Color = Color(0.96, 0.78, 0.30)

var _prev_forward_mps: float = 0.0
var _smooth_pitch_shift: float = 1.0
var _smooth_steer_shift: float = 0.0
var _smooth_brake_glow: float = 0.0
var _smooth_ground_normal: Vector3 = Vector3.UP
var _smooth_ground_y: float = 0.0
var _airborne_timer: float = 0.0
var _peak_downward_vy: float = 0.0
var _prev_grounded_wheels: int = 0
var _landing_cooldown: float = 0.0
var _post_landing_damp_timer: float = 0.0
var _last_landing_sparks_ms: int = 0
var _pre_step_horiz_vel: Vector2 = Vector2.ZERO
var _pre_step_vel_3d: Vector3 = Vector3.ZERO
var _prop_trigger_area: Area3D = null
var _burnout_active: bool = false
var _deformer: CarDeformer = null
var _last_wall_dmg_ms: int = -10000
var _surface_grip_mult: float = 1.0
var _surface_brake_mult: float = 1.0
var _surface_yaw_mult: float = 1.0
var _on_black_ice: bool = false
var _ice_notice_shown: bool = false
var _in_water: bool = false
var _drowned_in_water: bool = false
var _water_surface_y: float = -12.4
var _water_sink_timer: float = 0.0
var _water_splash_pos: Vector3 = Vector3.ZERO
var _water_secondary_splash: bool = false
var _water_bubbles: CPUParticles3D = null
var _air_money_acc: float = 0.0
var _air_money_banked_this_jump: int = 0
var _air_stunt_active: bool = false
var _is_handbraking: bool = false
var _tornado_timer: float = 0.0
var _tornado_cooldown: float = 0.0
var _tornado_center: Vector3 = Vector3.ZERO
var _tornado_fwd: Vector3 = Vector3.BACK
var _tornado_spin_dir: float = 1.0
var _tornado_air_stabilize: float = 0.0
var _tornado_saved_gravity: float = 1.65
var _tornado_start_y: float = 0.0

var _hud_hp: ProgressBar
var _hud_fuel: ProgressBar
var _hud_speed: Label
var _hud_metr: Label
var _hud_death_rect: ColorRect
var _hud_pause: Node
var _camera: Node

var _hud_panels: Array[Control] = []
var _hud_hp_val_lbl: Label = null
var _hud_fuel_val_lbl: Label = null
var _hud_kills_lbl: Label = null
var _hud_money_lbl: Label = null
var _hud_gear_lbl: Label = null
var _hud_rpm_bar: ProgressBar = null
var _hud_rpm_fill: StyleBoxFlat = null
var _hud_weapon_lbl: Label = null
var _hud_warn_panel: PanelContainer = null
var _hud_warn_border_sb: StyleBoxFlat = null
var _hud_warn_lbl: Label = null
var _hud_hp_fill: StyleBoxFlat = null
var _hud_fuel_fill: StyleBoxFlat = null

var _last_speed_kmh: int = -1
var _last_distance_m: int = -1
var _last_hp_shown: int = -1
var _last_fuel_pct_shown: int = -1
var _last_kills_shown: int = -1
var _last_money_shown: int = -1
var _last_gear_shown: String = ""

var _base_stats_captured: bool = false
var _base_max_fuel: int = 100
var _base_max_speed: int = 150
var _base_engine_force: int = 7500
var _base_throttle_response: float = 3.8
var _base_health: int = 100
var _base_zombie_damage: int = 10
var _base_col_dmg_mult: float = 0.45
var _base_impact_keep: float = 0.72
var _base_tire_friction: float = 2.35
var _base_steer_speed: float = 2.4
var _base_brake_force: float = 95.0
var _chassis_upgrade_lvl: int = 0
var _is_max_upgraded: bool = false

func _capture_base_stats() -> void:
	if _base_stats_captured:
		return
	_base_stats_captured = true
	_base_max_fuel = max_fuel
	_base_max_speed = MAX_SPEED_KMH
	_base_engine_force = engine_force_value
	_base_throttle_response = throttle_response
	_base_health = health
	_base_zombie_damage = zombie_damage_taken
	_base_col_dmg_mult = collision_damage_multiplier
	_base_impact_keep = impact_momentum_keep
	_base_tire_friction = tire_friction
	_base_steer_speed = STEER_SPEED
	_base_brake_force = brake_force

func _resolve_car_index() -> int:
	var g := get_node_or_null("/root/Game")
	if g == null:
		return 0
	var my_path := scene_file_path.to_lower()
	if not my_path.is_empty():
		var data: Array = g.get("car_data")
		for i in range(data.size()):
			if str(data[i].get("path", "")).to_lower() == my_path:
				return i
		return clampi(int(g.get("selected_car_index")), 0, maxi(data.size() - 1, 0))
	return maxi(int(g.get("selected_car_index")), 0)

func apply_car_upgrades(car_idx: int = -1) -> void:
	_capture_base_stats()
	var g := get_node_or_null("/root/Game")
	if g == null or not g.has_method("get_upgrade_level"):
		return
	var idx := car_idx if car_idx >= 0 else _resolve_car_index()
	var lvl_fuel: int = int(g.call("get_upgrade_level", idx, "fuel"))
	var lvl_eng: int = int(g.call("get_upgrade_level", idx, "engine"))
	var lvl_arm: int = int(g.call("get_upgrade_level", idx, "armor"))
	var lvl_chs: int = int(g.call("get_upgrade_level", idx, "chassis"))
	_chassis_upgrade_lvl = lvl_chs
	_engine_upgrade_tier = clampi(floori(float(lvl_eng) / 5.0), 0, 2)
	_is_max_upgraded = bool(g.call("is_car_max_upgraded", idx))

	if is_instance_valid(_engine_audio) and engine_sound_id != "btr":
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("apply_vehicle_engine_tier"):
			var handles := {
				"engine": _engine_audio,
				"engine_idle": _engine_idle_audio,
				"engine_howl": _engine_howl_audio,
				"engine_boost": _engine_boost_audio,
			}
			sm.call("apply_vehicle_engine_tier", handles, engine_sound_id, _engine_upgrade_tier)

	max_fuel = roundi(float(_base_max_fuel) * (1.0 + float(lvl_fuel) * Game.UPGRADE_FUEL_BONUS_PER_LVL))
	MAX_SPEED_KMH = roundi(float(_base_max_speed) * (1.0 + float(lvl_eng) * Game.UPGRADE_SPEED_BONUS_PER_LVL))
	engine_force_value = roundi(float(_base_engine_force) * (1.0 + float(lvl_eng) * Game.UPGRADE_POWER_BONUS_PER_LVL))
	throttle_response = _base_throttle_response * (1.0 + float(lvl_eng) * 0.033)
	health = roundi(float(_base_health) * (1.0 + float(lvl_arm) * Game.UPGRADE_ARMOR_HP_BONUS_PER_LVL))
	zombie_damage_taken = maxi(roundi(float(_base_zombie_damage) * maxf(1.0 - float(lvl_arm) * 0.055, 0.35)), 1)
	collision_damage_multiplier = _base_col_dmg_mult * maxf(1.0 - float(lvl_arm) * 0.048, 0.40)
	impact_momentum_keep = clampf(_base_impact_keep + float(lvl_arm) * 0.013 + float(lvl_chs) * 0.008, 0.4, 0.98)
	tire_friction = _base_tire_friction * (1.0 + float(lvl_chs) * Game.UPGRADE_CHASSIS_BONUS_PER_LVL)
	STEER_SPEED = _base_steer_speed * (1.0 + float(lvl_chs) * 0.028)
	brake_force = _base_brake_force * (1.0 + float(lvl_chs) * 0.032)

	current_hp = health
	current_fuel = float(max_fuel)
	if is_instance_valid(_hud_hp):
		_hud_hp.max_value = health
		_hud_hp.value = current_hp
	if is_instance_valid(_hud_fuel):
		_hud_fuel.max_value = max_fuel
		_hud_fuel.value = current_fuel

	var stages: Dictionary = g.call("get_maxed_upgrade_stages", idx) if g.has_method("get_maxed_upgrade_stages") else {}
	CarArmorKit.apply_staged_kits(self, engine_sound_id, stages)

func _ready() -> void:
	apply_car_upgrades()
	var kill_zone := get_node_or_null("Area3D") as Area3D
	if kill_zone:
		if not kill_zone.body_entered.is_connected(_on_kill_zone_body_entered):
			kill_zone.body_entered.connect(_on_kill_zone_body_entered)
	else:
		push_error("Vehicle: Узел Area3D не найден внутри машины!")

	start_z_position = global_position.z
	_smooth_ground_y = global_position.y
	if not is_preview:
		add_to_group("player")

	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0.0, com_height, com_z_offset)
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.008
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.65

	var body_phys := PhysicsMaterial.new()
	body_phys.friction = 0.12
	body_phys.bounce = 0.0
	physics_material_override = body_phys

	contact_monitor = true
	max_contacts_reported = 24
	if not is_preview and not body_entered.is_connected(_on_chassis_body_entered):
		body_entered.connect(_on_chassis_body_entered)
	current_hp = health
	current_fuel = float(max_fuel)

	_collect_wheels()
	_hud_hp = get_node_or_null("Hud/HpBar") as ProgressBar
	_hud_fuel = get_node_or_null("Hud/FuelBar") as ProgressBar
	_hud_speed = get_node_or_null("Hud/speed") as Label
	_hud_metr = get_node_or_null("Hud/Metr") as Label
	_hud_death_rect = get_node_or_null("Hud/ColorRect") as ColorRect
	_hud_pause = get_node_or_null("Hud/Pause")
	_camera = get_node_or_null("look/Camera3D")

	if _hud_hp:
		_hud_hp.max_value = health
		_hud_hp.value = current_hp
	if _hud_fuel:
		_hud_fuel.max_value = max_fuel
		_hud_fuel.value = current_fuel

	_setup_touch_controls()
	if not is_preview:
		_setup_apocalyptic_hud()
	if _hud_death_rect:
		_hud_death_rect.move_to_front()
	if use_visual_lights:
		_setup_visual_lights()

	var pipe_offsets: Array[Vector3] = exhaust_offsets if not exhaust_offsets.is_empty() else [exhaust_offset]
	for p_off in pipe_offsets:
		var ex := CarVFX.create_exhaust(self, p_off, exhaust_style)
		ex.visible = not is_preview
		ex.emitting = not is_preview
		_exhausts.append(ex)
	if not _exhausts.is_empty():
		_exhaust = _exhausts[0]

	if not is_preview:
		for w in _wheels:
			if not w.is_front:
				var smoke := CarVFX.create_tire_smoke(w, Vector3(0.0, -w.wheel_radius, 0.0))
				_tire_smokes.append(smoke)
		_damage_smoke = CarVFX.create_engine_damage_smoke(self, engine_hood_offset)
		_damage_fire_root = CarVFX.create_engine_damage_fire(self, engine_hood_offset)
		_setup_vehicle_audio()
		_setup_prop_trigger_area()

func _setup_prop_trigger_area() -> void:
	if is_instance_valid(_prop_trigger_area):
		return
	var area := Area3D.new()
	area.name = "PropTriggerArea"
	area.collision_layer = 0
	area.collision_mask = 8
	area.monitoring = true
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(hull_half_extents.x * 2.0 + 0.18, 1.9), 1.85, maxf(hull_half_extents.y * 2.0 + 0.34, 4.4))
	cs.shape = box
	cs.position = Vector3(0.0, 0.95, 0.0)
	area.add_child(cs)
	area.body_entered.connect(_on_prop_trigger_body_entered)
	add_child(area)
	_prop_trigger_area = area

func _setup_vehicle_audio() -> void:
	if is_instance_valid(_engine_audio) or is_instance_valid(_skid_audio):
		return
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("attach_vehicle_audio"):
		var handles: Dictionary = sm.call("attach_vehicle_audio", self, engine_sound_id, _engine_upgrade_tier)
		_engine_audio = handles.get("engine") as AudioStreamPlayer
		_engine_idle_audio = handles.get("engine_idle") as AudioStreamPlayer
		_engine_howl_audio = handles.get("engine_howl") as AudioStreamPlayer
		_engine_boost_audio = handles.get("engine_boost") as AudioStreamPlayer
		_skid_audio = handles.get("skid") as AudioStreamPlayer
		_fire_audio = handles.get("fire") as AudioStreamPlayer
		if is_instance_valid(_engine_audio) and _engine_audio.stream:
			_engine_audio.play()
		if is_instance_valid(_engine_idle_audio) and _engine_idle_audio.stream:
			_engine_idle_audio.play()
		if is_instance_valid(_engine_howl_audio) and _engine_howl_audio.stream:
			_engine_howl_audio.play()
		if is_instance_valid(_engine_boost_audio) and _engine_boost_audio.stream:
			_engine_boost_audio.play()
		if is_instance_valid(_skid_audio) and _skid_audio.stream:
			_skid_audio.play()
		if is_instance_valid(_fire_audio) and _fire_audio.stream:
			_fire_audio.play()

func _collect_wheels() -> void:
	_wheels.clear()
	_front_left = null
	_front_right = null
	_rear_left = null
	_rear_right = null

	for child in get_children():
		if child is RaycastWheel:
			var w := child as RaycastWheel
			w.add_exception(self)
			w.is_front = w.position.z < 0.0
			w.is_left = w.position.x < 0.0
			if w.base_rest_length <= 0.0:
				w.base_rest_length = w.rest_length
			w.rest_length = w.base_rest_length * (front_rest_length_scale if w.is_front else rear_rest_length_scale)
			if w.is_front and front_spring_stiffness > 0.0:
				w.spring_stiffness_override = front_spring_stiffness
			elif not w.is_front and rear_spring_stiffness > 0.0:
				w.spring_stiffness_override = rear_spring_stiffness
			w.grip_multiplier = front_grip_bias if w.is_front else rear_grip_bias
			w.visual_lerp_speed = suspension_travel_speed
			w.configure_ray()
			w.prev_compression_m = w.rest_length * 0.50
			_wheels.append(w)

			if w.is_front and w.is_left:
				_front_left = w
			elif w.is_front and not w.is_left:
				_front_right = w
			elif not w.is_front and w.is_left:
				_rear_left = w
			else:
				_rear_right = w

func _setup_touch_controls() -> void:
	var is_touch := OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")
	for touch_node: String in ["Hud/VirtualJoystick", "Hud/Brake", "Hud/Gas"]:
		var ci := get_node_or_null(touch_node) as CanvasItem
		if ci:
			ci.visible = is_touch

func _make_hud_box(bg: Color, border: Color, bw_left: int = 1, bw_right: int = 1, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = bw_left
	sb.border_width_top = 1
	sb.border_width_right = bw_right
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(radius)
	return sb

func _setup_apocalyptic_hud() -> void:
	var hud := get_node_or_null("Hud") as CanvasLayer
	if hud == null:
		return

	_hud_panels.clear()
	for child in hud.get_children():
		if child is Sprite2D:
			(child as CanvasItem).visible = false
	for raw_name: String in ["Check", "Fuel"]:
		var sp := hud.get_node_or_null(raw_name) as CanvasItem
		if sp:
			sp.visible = false

	# 1. Compact Top-Left Armor & Fuel Strip
	var tele_panel := PanelContainer.new()
	tele_panel.name = "ApocTelemetryPanel"
	tele_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tele_panel.offset_left = 12.0
	tele_panel.offset_top = 12.0
	tele_panel.offset_right = 208.0
	tele_panel.offset_bottom = 76.0
	tele_panel.add_theme_stylebox_override("panel", _make_hud_box(Color(0.05, 0.06, 0.075, 0.62), Color(0.84, 0.34, 0.14, 0.62), 3, 1, 3))
	hud.add_child(tele_panel)
	_hud_panels.append(tele_panel)

	var tele_m := MarginContainer.new()
	tele_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_m.add_theme_constant_override("margin_left", 9)
	tele_m.add_theme_constant_override("margin_top", 6)
	tele_m.add_theme_constant_override("margin_right", 9)
	tele_m.add_theme_constant_override("margin_bottom", 6)
	tele_panel.add_child(tele_m)

	var tele_v := VBoxContainer.new()
	tele_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_v.add_theme_constant_override("separation", 3)
	tele_m.add_child(tele_v)

	var hp_hdr := HBoxContainer.new()
	hp_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_v.add_child(hp_hdr)
	var hp_tag := Label.new()
	hp_tag.text = "БРОНЯ"
	hp_tag.add_theme_font_override("font", FONT_JURA)
	hp_tag.add_theme_font_size_override("font_size", 11)
	hp_tag.add_theme_color_override("font_color", Color(0.76, 0.79, 0.82))
	hp_hdr.add_child(hp_tag)
	var hp_sp := Control.new()
	hp_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_hdr.add_child(hp_sp)
	_hud_hp_val_lbl = Label.new()
	_hud_hp_val_lbl.text = "%d / %d" % [current_hp, health]
	_hud_hp_val_lbl.add_theme_font_override("font", FONT_RUSSO)
	_hud_hp_val_lbl.add_theme_font_size_override("font_size", 11)
	_hud_hp_val_lbl.add_theme_color_override("font_color", Color(0.95, 0.91, 0.87))
	hp_hdr.add_child(_hud_hp_val_lbl)

	var sb_track := StyleBoxFlat.new()
	sb_track.bg_color = Color(0.11, 0.12, 0.15, 0.85)
	sb_track.border_color = Color(0.24, 0.26, 0.29, 0.55)
	sb_track.set_border_width_all(1)
	sb_track.set_corner_radius_all(2)

	_hud_hp_fill = StyleBoxFlat.new()
	_hud_hp_fill.bg_color = Color(0.84, 0.20, 0.13, 1.0)
	_hud_hp_fill.set_corner_radius_all(2)

	if is_instance_valid(_hud_hp):
		_hud_hp.reparent(tele_v, false)
		_hud_hp.custom_minimum_size = Vector2(0.0, 6.0)
		_hud_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hud_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_hp.show_percentage = false
		_hud_hp.add_theme_stylebox_override("background", sb_track)
		_hud_hp.add_theme_stylebox_override("fill", _hud_hp_fill)

	var fuel_hdr := HBoxContainer.new()
	fuel_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tele_v.add_child(fuel_hdr)
	var fuel_tag := Label.new()
	fuel_tag.text = "ТОПЛИВО"
	fuel_tag.add_theme_font_override("font", FONT_JURA)
	fuel_tag.add_theme_font_size_override("font_size", 11)
	fuel_tag.add_theme_color_override("font_color", Color(0.76, 0.79, 0.82))
	fuel_hdr.add_child(fuel_tag)
	var fuel_sp := Control.new()
	fuel_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fuel_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_hdr.add_child(fuel_sp)
	_hud_fuel_val_lbl = Label.new()
	_hud_fuel_val_lbl.text = "100%"
	_hud_fuel_val_lbl.add_theme_font_override("font", FONT_RUSSO)
	_hud_fuel_val_lbl.add_theme_font_size_override("font_size", 11)
	_hud_fuel_val_lbl.add_theme_color_override("font_color", Color(0.96, 0.74, 0.28))
	fuel_hdr.add_child(_hud_fuel_val_lbl)

	_hud_fuel_fill = StyleBoxFlat.new()
	_hud_fuel_fill.bg_color = Color(0.90, 0.56, 0.14, 1.0)
	_hud_fuel_fill.set_corner_radius_all(2)

	if is_instance_valid(_hud_fuel):
		_hud_fuel.reparent(tele_v, false)
		_hud_fuel.custom_minimum_size = Vector2(0.0, 6.0)
		_hud_fuel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hud_fuel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_fuel.show_percentage = false
		_hud_fuel.add_theme_stylebox_override("background", sb_track)
		_hud_fuel.add_theme_stylebox_override("fill", _hud_fuel_fill)

	# 2. Compact Top-Right Raid Distance, Kills & Scrap Plaque
	var raid_panel := PanelContainer.new()
	raid_panel.name = "ApocRaidPanel"
	raid_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	raid_panel.offset_left = -188.0
	raid_panel.offset_top = 12.0
	raid_panel.offset_right = -12.0
	raid_panel.offset_bottom = 72.0
	raid_panel.add_theme_stylebox_override("panel", _make_hud_box(Color(0.05, 0.06, 0.075, 0.62), Color(0.84, 0.34, 0.14, 0.62), 1, 3, 3))
	hud.add_child(raid_panel)
	_hud_panels.append(raid_panel)

	var raid_m := MarginContainer.new()
	raid_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_m.add_theme_constant_override("margin_left", 9)
	raid_m.add_theme_constant_override("margin_top", 5)
	raid_m.add_theme_constant_override("margin_right", 9)
	raid_m.add_theme_constant_override("margin_bottom", 5)
	raid_panel.add_child(raid_m)

	var raid_v := VBoxContainer.new()
	raid_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_v.add_theme_constant_override("separation", 2)
	raid_m.add_child(raid_v)

	var dist_tag := Label.new()
	dist_tag.text = "ДИСТАНЦИЯ"
	dist_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dist_tag.add_theme_font_override("font", FONT_JURA)
	dist_tag.add_theme_font_size_override("font_size", 10)
	dist_tag.add_theme_color_override("font_color", Color(0.88, 0.46, 0.22))
	raid_v.add_child(dist_tag)

	if is_instance_valid(_hud_metr):
		_hud_metr.reparent(raid_v, false)
		_hud_metr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hud_metr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hud_metr.custom_minimum_size = Vector2(0.0, 20.0)
		_hud_metr.add_theme_font_override("font", FONT_RUSSO)
		_hud_metr.add_theme_font_size_override("font_size", 18)
		_hud_metr.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
		_hud_metr.text = "0 M"

	var loot_row := HBoxContainer.new()
	loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_v.add_child(loot_row)

	_hud_kills_lbl = Label.new()
	_hud_kills_lbl.text = "УБИТО: 0"
	_hud_kills_lbl.add_theme_font_override("font", FONT_JURA)
	_hud_kills_lbl.add_theme_font_size_override("font_size", 11)
	_hud_kills_lbl.add_theme_color_override("font_color", Color(0.96, 0.46, 0.32))
	loot_row.add_child(_hud_kills_lbl)

	var loot_sp := Control.new()
	loot_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loot_sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_row.add_child(loot_sp)

	_hud_money_lbl = Label.new()
	_hud_money_lbl.text = "+0 $"
	_hud_money_lbl.add_theme_font_override("font", FONT_RUSSO)
	_hud_money_lbl.add_theme_font_size_override("font_size", 12)
	_hud_money_lbl.add_theme_color_override("font_color", Color(0.96, 0.78, 0.32))
	loot_row.add_child(_hud_money_lbl)

	# 3. Low-Profile Bottom-Center Speedometer, Gear Indicator & RPM Strip
	var spd_panel := PanelContainer.new()
	spd_panel.name = "ApocSpeedPanel"
	spd_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spd_panel.anchor_left = 0.5
	spd_panel.anchor_top = 1.0
	spd_panel.anchor_right = 0.5
	spd_panel.anchor_bottom = 1.0
	spd_panel.offset_left = -106.0
	spd_panel.offset_top = -64.0
	spd_panel.offset_right = 106.0
	spd_panel.offset_bottom = -12.0
	spd_panel.add_theme_stylebox_override("panel", _make_hud_box(Color(0.05, 0.06, 0.075, 0.62), Color(0.32, 0.34, 0.38, 0.58), 1, 1, 4))
	hud.add_child(spd_panel)
	_hud_panels.append(spd_panel)

	var spd_outer_v := VBoxContainer.new()
	spd_outer_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spd_outer_v.add_theme_constant_override("separation", 0)
	spd_panel.add_child(spd_outer_v)

	var spd_m := MarginContainer.new()
	spd_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spd_m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spd_m.add_theme_constant_override("margin_left", 10)
	spd_m.add_theme_constant_override("margin_top", 5)
	spd_m.add_theme_constant_override("margin_right", 10)
	spd_m.add_theme_constant_override("margin_bottom", 5)
	spd_outer_v.add_child(spd_m)

	var spd_v := VBoxContainer.new()
	spd_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spd_v.add_theme_constant_override("separation", 4)
	spd_m.add_child(spd_v)

	var spd_row := HBoxContainer.new()
	spd_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spd_row.add_theme_constant_override("separation", 8)
	spd_v.add_child(spd_row)

	var gear_badge := PanelContainer.new()
	gear_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_badge.custom_minimum_size = Vector2(36.0, 28.0)
	gear_badge.add_theme_stylebox_override("panel", _make_hud_box(Color(0.18, 0.08, 0.06, 0.86), Color(0.92, 0.42, 0.16, 0.80), 2, 2, 3))
	spd_row.add_child(gear_badge)

	_hud_gear_lbl = Label.new()
	_hud_gear_lbl.name = "GearLabel"
	_hud_gear_lbl.text = "N"
	_hud_gear_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_gear_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_gear_lbl.add_theme_font_override("font", FONT_RUSSO)
	_hud_gear_lbl.add_theme_font_size_override("font_size", 17)
	_hud_gear_lbl.add_theme_color_override("font_color", Color(0.98, 0.64, 0.24))
	gear_badge.add_child(_hud_gear_lbl)

	if is_instance_valid(_hud_speed):
		_hud_speed.reparent(spd_row, false)
		_hud_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_hud_speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_hud_speed.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hud_speed.add_theme_font_override("font", FONT_RUSSO)
		_hud_speed.add_theme_font_size_override("font_size", 21)
		_hud_speed.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
		_hud_speed.text = "0  KM/H"

	_hud_rpm_bar = ProgressBar.new()
	_hud_rpm_bar.name = "RpmBar"
	_hud_rpm_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_rpm_bar.custom_minimum_size = Vector2(0.0, 4.0)
	_hud_rpm_bar.max_value = 100.0
	_hud_rpm_bar.value = 18.0
	_hud_rpm_bar.show_percentage = false
	_hud_rpm_bar.add_theme_stylebox_override("background", sb_track)
	_hud_rpm_fill = StyleBoxFlat.new()
	_hud_rpm_fill.bg_color = Color(0.94, 0.50, 0.16, 1.0)
	_hud_rpm_fill.set_corner_radius_all(2)
	_hud_rpm_bar.add_theme_stylebox_override("fill", _hud_rpm_fill)
	spd_v.add_child(_hud_rpm_bar)

	var accent_line := ColorRect.new()
	accent_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accent_line.custom_minimum_size = Vector2(0.0, 2.0)
	var acc_mat := ShaderMaterial.new()
	acc_mat.shader = SHADER_ACCENT_BAR
	acc_mat.set_shader_parameter("base_color", Color(0.76, 0.22, 0.09, 1.0))
	acc_mat.set_shader_parameter("shimmer_color", Color(1.0, 0.62, 0.24, 1.0))
	accent_line.material = acc_mat
	spd_outer_v.add_child(accent_line)

	# 4. Compact BTR Weapon Status Pill
	if engine_sound_id == "btr":
		var wpn_panel := PanelContainer.new()
		wpn_panel.name = "ApocWeaponPanel"
		wpn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wpn_panel.anchor_left = 0.5
		wpn_panel.anchor_top = 1.0
		wpn_panel.anchor_right = 0.5
		wpn_panel.anchor_bottom = 1.0
		wpn_panel.offset_left = -84.0
		wpn_panel.offset_top = -84.0
		wpn_panel.offset_right = 84.0
		wpn_panel.offset_bottom = -66.0
		wpn_panel.add_theme_stylebox_override("panel", _make_hud_box(Color(0.05, 0.06, 0.075, 0.62), Color(0.92, 0.44, 0.16, 0.58), 2, 2, 2))
		hud.add_child(wpn_panel)
		_hud_panels.append(wpn_panel)

		_hud_weapon_lbl = Label.new()
		_hud_weapon_lbl.text = "[SPACE] ПУШКА ГОТОВА"
		_hud_weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_hud_weapon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_hud_weapon_lbl.add_theme_font_override("font", FONT_JURA)
		_hud_weapon_lbl.add_theme_font_size_override("font_size", 10)
		_hud_weapon_lbl.add_theme_color_override("font_color", Color(0.96, 0.74, 0.30))
		wpn_panel.add_child(_hud_weapon_lbl)

	# 5. Styled Top-Center Telemetry & Hazard Banner
	var warn_center := CenterContainer.new()
	warn_center.name = "ApocWarnCenter"
	warn_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_center.anchor_left = 0.0
	warn_center.anchor_top = 0.0
	warn_center.anchor_right = 1.0
	warn_center.anchor_bottom = 0.0
	warn_center.offset_top = 14.0
	warn_center.offset_bottom = 48.0
	hud.add_child(warn_center)

	_hud_warn_panel = PanelContainer.new()
	_hud_warn_panel.name = "ApocWarnPanel"
	_hud_warn_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_warn_border_sb = _make_hud_box(Color(0.04, 0.05, 0.06, 0.80), Color(0.95, 0.42, 0.16, 0.85), 3, 3, 3)
	_hud_warn_panel.add_theme_stylebox_override("panel", _hud_warn_border_sb)
	_hud_warn_panel.visible = false
	warn_center.add_child(_hud_warn_panel)
	_hud_panels.append(_hud_warn_panel)

	var warn_margin := MarginContainer.new()
	warn_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warn_margin.add_theme_constant_override("margin_left", 14)
	warn_margin.add_theme_constant_override("margin_top", 5)
	warn_margin.add_theme_constant_override("margin_right", 14)
	warn_margin.add_theme_constant_override("margin_bottom", 5)
	_hud_warn_panel.add_child(warn_margin)

	_hud_warn_lbl = Label.new()
	_hud_warn_lbl.name = "ApocWarnLabel"
	_hud_warn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_warn_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hud_warn_lbl.add_theme_font_override("font", FONT_RUSSO)
	_hud_warn_lbl.add_theme_font_size_override("font_size", 13)
	_hud_warn_lbl.add_theme_color_override("font_color", Color(0.98, 0.42, 0.22))
	warn_margin.add_child(_hud_warn_lbl)

func _update_hud_telemetry() -> void:
	if is_instance_valid(_hud_hp_val_lbl) and current_hp != _last_hp_shown:
		_last_hp_shown = current_hp
		_hud_hp_val_lbl.text = "%d / %d" % [current_hp, health]
		var hp_ratio := float(current_hp) / maxf(float(health), 1.0)
		if _hud_hp_fill:
			_hud_hp_fill.bg_color = Color(0.98, 0.16, 0.12) if hp_ratio < 0.25 else Color(0.84, 0.20, 0.13)

	var fuel_pct: int = roundi((current_fuel / maxf(float(max_fuel), 1.0)) * 100.0)
	if is_instance_valid(_hud_fuel_val_lbl) and fuel_pct != _last_fuel_pct_shown:
		_last_fuel_pct_shown = fuel_pct
		_hud_fuel_val_lbl.text = "%d%%" % fuel_pct
		if _hud_fuel_fill:
			_hud_fuel_fill.bg_color = Color(0.96, 0.26, 0.14) if fuel_pct < 20 else Color(0.90, 0.56, 0.14)

	if is_instance_valid(_hud_kills_lbl) and _run_kills != _last_kills_shown:
		_last_kills_shown = _run_kills
		_hud_kills_lbl.text = "УБИТО: %d" % _run_kills

	if is_instance_valid(_hud_money_lbl) and _run_money != _last_money_shown:
		_last_money_shown = _run_money
		_hud_money_lbl.text = "+%d $" % _run_money

	if is_instance_valid(_hud_gear_lbl) and _display_gear != _last_gear_shown:
		_last_gear_shown = _display_gear
		_hud_gear_lbl.text = _display_gear

	if is_instance_valid(_hud_rpm_bar):
		_hud_rpm_bar.value = clampf(_sim_rpm * 100.0, 12.0, 100.0)
		if _hud_rpm_fill:
			_hud_rpm_fill.bg_color = Color(0.96, 0.20, 0.14) if _sim_rpm >= 0.85 else Color(0.94, 0.50, 0.16)

	if is_instance_valid(_hud_weapon_lbl):
		var ready_var = get("can_shoot")
		var can_fire: bool = (ready_var == true)
		_hud_weapon_lbl.text = "[SPACE] ПУШКА ГОТОВА" if can_fire else "[SPACE] ПЕРЕЗАРЯДКА..."
		_hud_weapon_lbl.modulate = Color.WHITE if can_fire else Color(0.65, 0.55, 0.50)

	if is_instance_valid(_hud_warn_lbl) and is_instance_valid(_hud_warn_panel):
		var low_hp := float(current_hp) / maxf(float(health), 1.0) < 0.25
		var low_fuel := current_fuel / maxf(float(max_fuel), 1.0) < 0.18
		var show_banner := true
		var banner_text := ""
		var banner_col := Color(0.98, 0.34, 0.20)
		if _hud_notice_timer > 0.0 and not _hud_notice_text.is_empty():
			banner_text = _hud_notice_text
			banner_col = _hud_notice_color
		elif low_fuel and current_fuel <= 0.0:
			banner_text = "ТОПЛИВО НА НУЛЕ // ДВИГАТЕЛЬ ГЛОХНЕТ"
			banner_col = Color(0.98, 0.34, 0.20)
		elif _engine_fire_level > 0.0:
			banner_text = "ТРЕВОГА // ВОЗГОРАНИЕ ДВИГАТЕЛЯ"
			banner_col = Color(1.0, 0.24, 0.12)
		elif low_hp:
			banner_text = "КРИТИЧЕСКИЙ ИЗНОС БРОНИ"
			banner_col = Color(0.98, 0.34, 0.20)
		elif low_fuel:
			banner_text = "РЕЗЕРВ ТОПЛИВА // НУЖНА ЗАПРАВКА"
			banner_col = Color(0.98, 0.64, 0.22)
		else:
			show_banner = false
		_hud_warn_panel.visible = show_banner
		if show_banner:
			_hud_warn_lbl.text = banner_text
			_hud_warn_lbl.add_theme_color_override("font_color", banner_col)
			if _hud_warn_border_sb:
				_hud_warn_border_sb.border_color = Color(banner_col.r, banner_col.g, banner_col.b, 0.85)

static func _get_beam_mesh() -> ArrayMesh:
	if _cached_beam_mesh != null:
		return _cached_beam_mesh

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 12
	var r0: float = 0.14
	var r1: float = 1.65
	var length_m: float = 7.5
	for i in range(segs):
		var a0: float = (float(i) / float(segs)) * TAU
		var a1: float = (float(i + 1) / float(segs)) * TAU
		var p00 := Vector3(cos(a0) * r0, sin(a0) * r0, 0.0)
		var p10 := Vector3(cos(a1) * r0, sin(a1) * r0, 0.0)
		var p01 := Vector3(cos(a0) * r1, sin(a0) * r1 - 0.55, -length_m)
		var p11 := Vector3(cos(a1) * r1, sin(a1) * r1 - 0.55, -length_m)

		st.set_uv(Vector2(float(i) / float(segs), 0.0))
		st.add_vertex(p00)
		st.set_uv(Vector2(float(i + 1) / float(segs), 0.0))
		st.add_vertex(p10)
		st.set_uv(Vector2(float(i + 1) / float(segs), 1.0))
		st.add_vertex(p11)

		st.set_uv(Vector2(float(i) / float(segs), 0.0))
		st.add_vertex(p00)
		st.set_uv(Vector2(float(i + 1) / float(segs), 1.0))
		st.add_vertex(p11)
		st.set_uv(Vector2(float(i) / float(segs), 1.0))
		st.add_vertex(p01)

	st.generate_normals()
	_cached_beam_mesh = st.commit()
	return _cached_beam_mesh

static func _get_halo_mesh() -> QuadMesh:
	if _cached_halo_mesh != null:
		return _cached_halo_mesh
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	_cached_halo_mesh = q
	return _cached_halo_mesh

func _setup_visual_lights() -> void:
	if is_instance_valid(_lights_rig):
		_lights_rig.queue_free()

	_head_beam_mats.clear()
	_head_beam_nodes.clear()
	_tail_lens_mats.clear()
	_head_lens_mats.clear()

	_lights_rig = Node3D.new()
	_lights_rig.name = "VisualLightsRig"
	add_child(_lights_rig)

	# 1. Per-vehicle silhouette contour shadow projected flat onto the road (zero black rectangle!)
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "ShadowBlobMesh"
	_shadow_mesh.top_level = true
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s_plane := PlaneMesh.new()
	s_plane.size = shadow_blob_size
	_shadow_mesh.mesh = s_plane
	_shadow_mat = ShaderMaterial.new()
	_shadow_mat.shader = SHADER_CAR_SHADOW
	_shadow_mat.render_priority = -1
	_shadow_mat.set_shader_parameter("shadow_tex", shadow_texture if shadow_texture != null else SHADOW_BLOB_TEX)
	_shadow_mat.set_shader_parameter("shadow_strength", 0.80)
	_shadow_mesh.material_override = _shadow_mat
	_lights_rig.add_child(_shadow_mesh)

	# 2. Road-aligned projected headlight cookie (never pitches below asphalt!)
	_head_proj_mesh = MeshInstance3D.new()
	_head_proj_mesh.name = "HeadlightGroundProjection"
	_head_proj_mesh.top_level = true
	_head_proj_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var hp_plane := PlaneMesh.new()
	hp_plane.size = headlight_proj_size
	hp_plane.subdivide_width = 2
	hp_plane.subdivide_depth = 6
	_head_proj_mesh.mesh = hp_plane
	_head_proj_mat = ShaderMaterial.new()
	_head_proj_mat.shader = SHADER_HEADLIGHT_PROJ
	_head_proj_mat.render_priority = 1
	_head_proj_mat.set_shader_parameter("cookie_tex", HEADLIGHT_COOKIE_TEX)
	_head_proj_mat.set_shader_parameter("light_tint", Color(1.0, 0.94, 0.82, 1.0))
	_head_proj_mat.set_shader_parameter("intensity", 1.35)
	_head_proj_mat.set_shader_parameter("flip_v", true)
	_head_proj_mesh.material_override = _head_proj_mat
	_lights_rig.add_child(_head_proj_mesh)

	# 3. Road-aligned projected taillight red glow
	_tail_proj_mesh = MeshInstance3D.new()
	_tail_proj_mesh.name = "TaillightGroundProjection"
	_tail_proj_mesh.top_level = true
	_tail_proj_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tp_plane := PlaneMesh.new()
	tp_plane.size = taillight_proj_size
	tp_plane.subdivide_width = 1
	tp_plane.subdivide_depth = 2
	_tail_proj_mesh.mesh = tp_plane
	_tail_proj_mat = ShaderMaterial.new()
	_tail_proj_mat.shader = SHADER_HEADLIGHT_PROJ
	_tail_proj_mat.render_priority = 1
	_tail_proj_mat.set_shader_parameter("cookie_tex", TAILLIGHT_COOKIE_TEX)
	_tail_proj_mat.set_shader_parameter("light_tint", Color(1.0, 0.16, 0.10, 1.0))
	_tail_proj_mat.set_shader_parameter("intensity", 0.55)
	_tail_proj_mat.set_shader_parameter("flip_v", false)
	_tail_proj_mesh.material_override = _tail_proj_mat
	_lights_rig.add_child(_tail_proj_mesh)

	var beam_mesh := _get_beam_mesh()
	var halo_mesh := _get_halo_mesh()

	# 4. Headlight lenses + volumetric fog beams (zero Light3D!)
	for i in range(headlight_positions.size()):
		var l_pos: Vector3 = headlight_positions[i]
		var lens := MeshInstance3D.new()
		lens.name = "HeadlightLens_%d" % i
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.mesh = halo_mesh
		var l_mat := ShaderMaterial.new()
		l_mat.shader = SHADER_HEADLIGHT_LENS
		l_mat.render_priority = 2
		l_mat.set_shader_parameter("lens_color", Color(1.0, 0.94, 0.80, 1.0))
		l_mat.set_shader_parameter("intensity", 1.35)
		l_mat.set_shader_parameter("forward_sign", -1.0)
		l_mat.set_shader_parameter("lens_aspect", Vector2(1.0, 1.0))
		lens.material_override = l_mat
		lens.position = l_pos
		lens.scale = Vector3(headlight_lens_size.x, headlight_lens_size.y, 1.0)
		_head_lens_mats.append(l_mat)
		_lights_rig.add_child(lens)

		var beam := MeshInstance3D.new()
		beam.name = "HeadlightBeam_%d" % i
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam.mesh = beam_mesh
		var b_mat := ShaderMaterial.new()
		b_mat.shader = SHADER_LIGHT_BEAM
		b_mat.set_shader_parameter("beam_color", Color(1.0, 0.93, 0.78, 1.0))
		b_mat.set_shader_parameter("beam_intensity", 0.24)
		beam.material_override = b_mat
		beam.position = l_pos
		_head_beam_mats.append(b_mat)
		_head_beam_nodes.append(beam)
		_lights_rig.add_child(beam)

	# 5. Taillight glowing lens halos
	for i in range(taillight_positions.size()):
		var t_pos: Vector3 = taillight_positions[i]
		var tlens := MeshInstance3D.new()
		tlens.name = "TaillightLens_%d" % i
		tlens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tlens.mesh = halo_mesh
		var t_mat := ShaderMaterial.new()
		t_mat.shader = SHADER_HEADLIGHT_LENS
		t_mat.render_priority = 2
		t_mat.set_shader_parameter("lens_color", Color(1.0, 0.14, 0.08, 1.0))
		t_mat.set_shader_parameter("intensity", 1.05)
		t_mat.set_shader_parameter("forward_sign", 1.0)
		t_mat.set_shader_parameter("lens_aspect", Vector2(1.0, 1.0))
		tlens.material_override = t_mat
		tlens.position = t_pos
		tlens.scale = Vector3(taillight_lens_size.x, taillight_lens_size.y, 1.0)
		_tail_lens_mats.append(t_mat)
		_lights_rig.add_child(tlens)

	_apply_preview_light_state()
	call_deferred("_sync_ground_decals_immediate")

func _sync_ground_decals_immediate() -> void:
	if not is_inside_tree():
		return
	_update_visual_lights(0.016, false, true)

func _apply_preview_light_state() -> void:
	var show_lights := (not is_preview or _showcase_mode) and not destroyed
	if is_instance_valid(_head_proj_mesh):
		_head_proj_mesh.visible = show_lights
	if is_instance_valid(_tail_proj_mesh):
		_tail_proj_mesh.visible = show_lights
	for bn in _head_beam_nodes:
		if is_instance_valid(bn):
			bn.visible = show_lights

func set_preview_mode(enabled: bool, showcase_mode: bool = false) -> void:
	is_preview = enabled
	_showcase_mode = enabled and showcase_mode
	if enabled:
		remove_from_group("player")
		freeze = true
		set_physics_process(false)
		set_process(false)
		var child_cam := find_child("*Camera*", true, false) as Camera3D
		if child_cam:
			child_cam.current = false
			child_cam.set_process(false)
			child_cam.set_physics_process(false)
		if is_instance_valid(_engine_audio):
			_engine_audio.stop()
		if is_instance_valid(_engine_idle_audio):
			_engine_idle_audio.stop()
		if is_instance_valid(_engine_howl_audio):
			_engine_howl_audio.stop()
		if is_instance_valid(_skid_audio):
			_skid_audio.stop()
		if is_instance_valid(_fire_audio):
			_fire_audio.stop()
		var hud := get_node_or_null("Hud") as CanvasLayer
		if hud:
			hud.visible = false
		if _hud_pause:
			_hud_pause.process_mode = Node.PROCESS_MODE_DISABLED
		var kill_zone := get_node_or_null("Area3D") as Area3D
		if kill_zone:
			kill_zone.monitoring = false
			kill_zone.monitorable = false
		if is_instance_valid(_prop_trigger_area):
			_prop_trigger_area.monitoring = false
		for ex in _exhausts:
			if is_instance_valid(ex):
				if _showcase_mode:
					ex.visible = true
					ex.emitting = true
					ex.speed_scale = 0.55
				else:
					ex.emitting = false
					ex.visible = false
		for w in _wheels:
			w.update_visuals(0.0, 0.0, 0.016, true)
	_apply_preview_light_state()
	if is_inside_tree():
		_update_visual_lights(0.016, false, true)

func start_burnout_vfx(play_audio: bool = true) -> void:
	if _burnout_active:
		return
	_burnout_active = true
	if _tire_smokes.is_empty():
		for w in _wheels:
			if not w.is_front:
				var smoke := CarVFX.create_tire_smoke(w, Vector3(0.0, -w.wheel_radius, 0.0))
				_tire_smokes.append(smoke)
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.visible = true
			ts.emitting = true
			ts.speed_scale = 1.45
			ts.scale_amount_min = 0.95
			ts.scale_amount_max = 2.25
	for ex in _exhausts:
		if is_instance_valid(ex):
			ex.visible = true
			ex.emitting = true
			ex.speed_scale = 2.0
	if play_audio:
		_setup_vehicle_audio()
		if is_instance_valid(_engine_idle_audio):
			_engine_idle_audio.volume_db = -30.0
		if is_instance_valid(_engine_audio):
			_engine_audio.volume_db = -6.0
			_engine_audio.pitch_scale = clampf(1.12 * engine_pitch_scale, 0.6, 2.2)
		if is_instance_valid(_engine_howl_audio):
			_engine_howl_audio.volume_db = -7.5
			_engine_howl_audio.pitch_scale = clampf(1.18 * engine_pitch_scale, 0.7, 2.2)
		if is_instance_valid(_skid_audio):
			_skid_audio.volume_db = -12.0
			_skid_audio.pitch_scale = 0.98
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_vehicle_sfx"):
			sm.call("play_vehicle_sfx", "exhaust_backfire", -6.0, randf_range(0.92, 1.08))

func step_burnout_visuals(delta: float, wheel_mps: float, steer_rad: float = 0.0, rpm_pitch: float = 1.15, skid_db: float = -11.0, spin_all_wheels: bool = false) -> void:
	var dt := maxf(delta, 0.001)
	var car_fwd := -global_transform.basis.z
	for w in _wheels:
		w.update_visuals(steer_rad, 0.0, dt, true)
		if spin_all_wheels or not w.is_front:
			var spin := w.get_node_or_null("WheelSteerPivot/WheelSpinPivot") as Node3D
			if spin:
				spin.rotate_x(-(wheel_mps / maxf(w.wheel_radius, 0.12)) * dt)
		# Оставляем чёрный след протектора на месте под буксующими колёсами в меню/гараже
		if not spin_all_wheels and not w.is_front and wheel_mps > 4.0 and is_inside_tree():
			var patch := w.global_position - Vector3(0.0, maxf(w.wheel_radius * 0.92, 0.25), 0.0)
			CarVFX.add_tire_skid(int(w.get_instance_id()), patch, Vector3.UP, car_fwd, clampf(w.wheel_radius * 0.78, 0.26, 0.56), 0.95)
		elif spin_all_wheels and wheel_mps > 6.0 and is_inside_tree():
			var patch_roll := w.global_position - Vector3(0.0, maxf(w.wheel_radius * 0.92, 0.25), 0.0)
			CarVFX.add_tire_skid(int(w.get_instance_id()), patch_roll, Vector3.UP, car_fwd, clampf(w.wheel_radius * 0.74, 0.24, 0.52), 0.52)
	var lerpt := clampf(dt * 11.0, 0.0, 1.0)
	if is_instance_valid(_engine_audio):
		_engine_audio.pitch_scale = lerpf(_engine_audio.pitch_scale, clampf(rpm_pitch * engine_pitch_scale, 0.6, 2.3), lerpt)
	if is_instance_valid(_engine_howl_audio):
		_engine_howl_audio.pitch_scale = lerpf(_engine_howl_audio.pitch_scale, clampf(rpm_pitch * 1.06 * engine_pitch_scale, 0.7, 2.3), lerpt)
		_engine_howl_audio.volume_db = lerpf(_engine_howl_audio.volume_db, -6.5, lerpt)
	if is_instance_valid(_skid_audio):
		_skid_audio.volume_db = lerpf(_skid_audio.volume_db, skid_db, lerpt)
	if is_inside_tree():
		_update_visual_lights(dt, false, false)

func stop_burnout_vfx() -> void:
	_burnout_active = false
	for w in _wheels:
		if is_instance_valid(w):
			CarVFX.break_tire_skid(int(w.get_instance_id()))
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.emitting = false
	if is_instance_valid(_engine_audio):
		_engine_audio.stop()
	if is_instance_valid(_engine_idle_audio):
		_engine_idle_audio.stop()
	if is_instance_valid(_engine_howl_audio):
		_engine_howl_audio.stop()
	if is_instance_valid(_engine_boost_audio):
		_engine_boost_audio.stop()
	if is_instance_valid(_skid_audio):
		_skid_audio.stop()
	if is_instance_valid(_fire_audio):
		_fire_audio.stop()

func _exit_tree() -> void:
	if _burnout_active:
		stop_burnout_vfx()

func _physics_process(delta: float) -> void:
	if _drowned_in_water and not is_preview:
		_step_water_sinking(delta, true)
		return
	if destroyed or is_preview:
		return

	if _in_water:
		_step_water_sinking(delta, false)
		return

	if global_position.y <= _water_surface_y + 0.85:
		_enter_water(_water_surface_y)
		return

	if _tornado_cooldown > 0.0:
		_tornado_cooldown = maxf(_tornado_cooldown - delta, 0.0)
	if _tornado_timer > 0.0:
		_step_tornado_capture(delta)
		return
	if _tornado_air_stabilize > 0.0:
		_tornado_air_stabilize = maxf(_tornado_air_stabilize - delta, 0.0)
		if grounded_wheels == 0:
			var cur_euler := global_transform.basis.get_euler()
			var pitch_corr := clampf(-cur_euler.x, -0.6, 0.6)
			var roll_corr := clampf(-cur_euler.z, -0.6, 0.6)
			apply_torque_impulse(global_transform.basis.x * (pitch_corr * mass * delta * 3.8))
			apply_torque_impulse(global_transform.basis.z * (roll_corr * mass * delta * 5.2))

	_process_vehicle_extras(delta)

	total_distance = absf(global_position.z - start_z_position)
	var dist_m := roundi(total_distance)
	if _hud_metr and dist_m != _last_distance_m:
		_last_distance_m = dist_m
		_hud_metr.text = str(dist_m) + " M"

	var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)
	var speed_mps: float = horizontal_vel.length()
	var speed_kmh: int = int(speed_mps * MPS_TO_KMH)

	if _hud_speed and speed_kmh != _last_speed_kmh:
		_last_speed_kmh = speed_kmh
		_hud_speed.text = str(speed_kmh) + "  KM/H"

	var forward_3d := -global_transform.basis.z
	var forward_2d := Vector2(forward_3d.x, forward_3d.z)
	var forward_mps: float = horizontal_vel.dot(forward_2d.normalized()) if forward_2d.length_squared() > 0.0001 else 0.0

	var wants_throttle := false
	var wants_reverse := false
	var is_braking := false

	if _siphon_combo_timer > 0.0:
		_siphon_combo_timer = maxf(_siphon_combo_timer - delta, 0.0)
		if _siphon_combo_timer <= 0.0:
			_siphon_combo = 0
	if _overdrive_timer > 0.0:
		_overdrive_timer = maxf(_overdrive_timer - delta, 0.0)
	if _hud_notice_timer > 0.0:
		_hud_notice_timer = maxf(_hud_notice_timer - delta, 0.0)

	if current_fuel <= 0.0:
		# Engine stalls cleanly: no forced braking, car rolls freely on inertia
		engine_force = 0.0
		if Input.is_action_pressed("S") and forward_mps > 1.2:
			is_braking = true
			brake = brake_force
		else:
			is_braking = false
			brake = 0.0
		if speed_mps < 0.85:
			_empty_fuel_stall_timer += delta
			if _empty_fuel_stall_timer >= 2.4:
				_destroy_car("ЗАКОНЧИЛОСЬ ТОПЛИВО")
				return
		else:
			_empty_fuel_stall_timer = 0.0
	elif Input.is_action_pressed("W"):
		wants_throttle = true
		engine_force = float(engine_force_value) if speed_kmh < MAX_SPEED_KMH else 0.0
		brake = 0.0
	elif Input.is_action_pressed("S"):
		if forward_mps > 1.2:
			is_braking = true
			brake = brake_force
			engine_force = 0.0
		else:
			wants_reverse = true
			brake = 0.0
			var reverse_kmh := absf(forward_mps) * MPS_TO_KMH
			engine_force = -float(engine_force_value) * 0.45 if reverse_kmh < 45.0 else 0.0
	else:
		engine_force = 0.0
		brake = 0.0

	var target_throt: float = 1.0 if (wants_throttle and current_fuel > 0.0) else (-0.75 if (wants_reverse and current_fuel > 0.0) else 0.0)
	var throt_rate: float = throttle_response if absf(target_throt) > absf(_smooth_throttle) else throttle_release_rate
	_smooth_throttle = move_toward(_smooth_throttle, target_throt, throt_rate * delta)

	# Пробуксовка ведущих колёс при резком нажатии газа с места и на малой скорости (1-я передача)
	var spin_target: float = 0.0
	if wants_throttle and not is_braking and current_fuel > 0.0 and grounded_wheels >= 2 and speed_kmh < 46:
		var low_spd_t: float = clampf(1.0 - float(speed_kmh) / 46.0, 0.0, 1.0)
		var throt_punch: float = clampf(maxf(_smooth_throttle, 0.65), 0.0, 1.0)
		spin_target = clampf(pow(low_spd_t, 0.68) * throt_punch, 0.0, 1.0)
	var spin_rate: float = 7.5 if spin_target > _launch_wheelspin else 3.4
	_launch_wheelspin = move_toward(_launch_wheelspin, spin_target, spin_rate * delta)

	var steer_input := Input.get_axis("D", "A")
	# Ручной дрифт на Пробел/Shift отключён: машина уходит в занос сама только на гололёде в зимнем биоме (_on_black_ice)
	_is_handbraking = false
	var speed_ratio := clampf(float(speed_kmh) / float(maxi(MAX_SPEED_KMH, 1)), 0.0, 1.0)
	var dynamic_steer_limit: float = STEER_LIMIT * lerpf(1.0, high_speed_steer_min_ratio, pow(speed_ratio, 0.58))
	var raw_steer_target: float = steer_input * dynamic_steer_limit
	var recentering := absf(steer_input) < 0.05 or signf(steer_input) != signf(steering)
	var rack_rate: float = steer_inertia * (1.28 if recentering else lerpf(1.0, 0.58, speed_ratio))
	_steer_target_filtered = lerpf(_steer_target_filtered, raw_steer_target, clampf(rack_rate * delta, 0.0, 1.0))
	var dynamic_steer_speed: float = STEER_SPEED * (lerpf(1.38, 0.86, speed_ratio) if recentering else lerpf(1.12, 0.62, speed_ratio))
	steering = move_toward(steering, _steer_target_filtered, dynamic_steer_speed * delta)

	_update_surface_grip_state(delta)
	_step_raycast_suspension_and_tires(delta, speed_mps, speed_ratio, forward_mps, wants_throttle, wants_reverse, is_braking)
	_update_airborne_stunt_money(delta, speed_mps)

	if wants_throttle or wants_reverse:
		var burn: float = ((speed_mps * delta) / 100.0) * fuel_per_100m * 1.05 + idle_fuel_per_sec * delta
		current_fuel = maxf(current_fuel - burn, 0.0)
	elif current_fuel > 0.0:
		current_fuel = maxf(current_fuel - idle_fuel_per_sec * 0.18 * delta, 0.0)
	if _hud_fuel:
		_hud_fuel.value = current_fuel

	var max_slip := 0.0
	for w in _wheels:
		if w.is_grounded:
			max_slip = maxf(max_slip, absf(w.lateral_slip_mps))
	var emit_smoke: bool = (_launch_wheelspin > 0.18) or (max_slip > 4.2 and speed_kmh > 28) or (is_braking and speed_kmh > 38)
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.emitting = emit_smoke
	_emit_drive_skid_marks(speed_kmh, wants_throttle, is_braking)

	_update_damage_vfx(delta)
	_update_visual_lights(delta, is_braking or Input.is_action_pressed("S"), false)
	_update_vehicle_audio(delta, speed_ratio, max_slip, wants_throttle, wants_reverse, is_braking, forward_mps)
	_update_exhaust_vfx(delta, speed_ratio, wants_throttle, wants_reverse)
	_update_hud_telemetry()
	_prev_forward_mps = forward_mps
	_handle_zombie_overlapping_damage(delta)
	_pre_step_vel_3d = linear_velocity
	_pre_step_horiz_vel = Vector2(linear_velocity.x, linear_velocity.z)

func show_hud_notice(msg: String, col: Color = Color(0.96, 0.78, 0.30), duration: float = 2.6) -> void:
	_hud_notice_timer = maxf(duration, 0.1)
	_hud_notice_text = msg
	_hud_notice_color = col

func _update_airborne_stunt_money(delta: float, speed_mps: float) -> void:
	if destroyed or is_preview or _in_water:
		_air_stunt_active = false
		_air_money_acc = 0.0
		_air_money_banked_this_jump = 0
		return
	if grounded_wheels == 0 and speed_mps > 9.0 and _airborne_timer >= 0.25:
		_air_stunt_active = true
		_air_money_acc += delta * (190.0 + speed_mps * 4.5) * (1.0 + _airborne_timer * 0.45)
		var whole: int = floori(_air_money_acc)
		if whole > 0:
			_air_money_acc -= float(whole)
			_run_money += whole
			_air_money_banked_this_jump += whole
		show_hud_notice("ОТРЫВ %.1f С  //  +%d $" % [_airborne_timer, _air_money_banked_this_jump], Color(1.0, 0.84, 0.28), 0.35)
	elif grounded_wheels > 0 and _air_stunt_active:
		if _air_money_banked_this_jump >= 20:
			show_hud_notice("ПРИЗЕМЛЕНИЕ // +%d $" % _air_money_banked_this_jump, Color(1.0, 0.86, 0.32), 1.9)
			var sm := get_node_or_null("/root/SoundManager")
			if sm and sm.has_method("play_ui"):
				sm.call("play_ui", "garage_select", -10.0, 1.25)
		_air_stunt_active = false
		_air_money_acc = 0.0
		_air_money_banked_this_jump = 0

func _update_surface_grip_state(delta: float) -> void:
	var target_grip := 1.0
	var target_brake := 1.0
	var target_yaw := 1.0
	var is_ice := false

	var scene := get_tree().current_scene
	if scene and scene.has_method("get_surface_grip_profile"):
		var prof: Dictionary = scene.call("get_surface_grip_profile", global_position)
		is_ice = bool(prof.get("is_ice", false))
		if is_ice:
			var base_g := float(prof.get("grip_scale", 0.56))
			target_grip = clampf(base_g * (ice_grip_scale / 0.56), 0.26, 0.78)
			target_brake = clampf(float(prof.get("brake_scale", 0.50)), 0.32, 0.85)
			target_yaw = clampf(float(prof.get("yaw_assist_scale", 0.65)), 0.35, 0.90)

	var lerpt := clampf(delta * 4.5, 0.0, 1.0)
	_surface_grip_mult = lerpf(_surface_grip_mult, target_grip, lerpt)
	_surface_brake_mult = lerpf(_surface_brake_mult, target_brake, lerpt)
	_surface_yaw_mult = lerpf(_surface_yaw_mult, target_yaw, lerpt)

	if is_ice and not _on_black_ice:
		_on_black_ice = true
		if not _ice_notice_shown:
			_ice_notice_shown = true
			show_hud_notice("ОБЛЕДЕНЕНИЕ ТРАССЫ // СКОЛЬЗКОЕ ПОКРЫТИЕ", Color(0.56, 0.86, 1.0), 2.8)
	elif not is_ice and _on_black_ice:
		_on_black_ice = false
		_ice_notice_shown = false


func _emit_drive_skid_marks(speed_kmh: int, wants_throttle: bool, is_braking: bool) -> void:
	if _wheels.is_empty():
		return
	var slip_thresh := 1.6 if _on_black_ice else 2.6
	for w in _wheels:
		var wid := int(w.get_instance_id())
		if not w.is_grounded or destroyed:
			CarVFX.break_tire_skid(wid)
			continue
		var lat_t := clampf((absf(w.lateral_slip_mps) - slip_thresh) / 5.0, 0.0, 1.0)
		var brk_t := clampf(_brake_pressure * 0.92, 0.0, 1.0) if (is_braking and speed_kmh > 22) else 0.0
		var launch_t := clampf(_launch_wheelspin * 0.92, 0.0, 0.92) if (not w.is_front and _launch_wheelspin > 0.16) else 0.0
		var ice_spin_t := 0.48 if (_on_black_ice and wants_throttle and speed_kmh < 42 and not w.is_front) else 0.0
		var intensity := maxf(maxf(lat_t, brk_t), maxf(launch_t, ice_spin_t))
		if intensity > 0.08:
			var mark_col := Color(0.16, 0.19, 0.24, 0.72) if _on_black_ice else Color(0.035, 0.035, 0.04, 0.88)
			var fwd_dir := -w.global_transform.basis.z
			CarVFX.add_tire_skid(wid, w.ground_point, w.ground_normal, fwd_dir, clampf(w.wheel_radius * 0.72, 0.24, 0.56), intensity, mark_col)
		else:
			CarVFX.break_tire_skid(wid)


func _update_damage_vfx(_delta: float) -> void:
	if is_preview:
		return
	var hp_ratio: float = clampf(float(current_hp) / float(maxi(health, 1)), 0.0, 1.0)
	_engine_fire_level = CarVFX.update_engine_damage_fx(_damage_smoke, _damage_fire_root, hp_ratio, destroyed)

func _update_exhaust_vfx(delta: float, speed_ratio: float, wants_throttle: bool, wants_reverse: bool) -> void:
	var active := not destroyed and current_fuel > 0.0
	var drive_load := clampf(_sim_rpm * 0.65 + (0.45 if (wants_throttle or wants_reverse) else 0.0) + speed_ratio * 0.25, 0.15, 1.35)
	var target_scale := lerpf(0.62, 1.80, clampf(drive_load, 0.0, 1.0))
	if _shift_timer > 0.02 or _air_revving:
		target_scale += 0.45
	var v_min := lerpf(1.4, 3.6, clampf(drive_load, 0.0, 1.0))
	var v_max := lerpf(2.8, 6.6, clampf(drive_load, 0.0, 1.0))
	for ex in _exhausts:
		if not is_instance_valid(ex):
			continue
		ex.emitting = active
		if active:
			ex.speed_scale = lerpf(ex.speed_scale, target_scale, clampf(delta * 8.0, 0.0, 1.0))
			ex.initial_velocity_min = v_min
			ex.initial_velocity_max = v_max

func _step_transmission(
	delta: float,
	speed_ratio: float,
	forward_mps: float,
	wants_throttle: bool,
	wants_reverse: bool,
	play_shift_sfx: bool = true
) -> void:
	_shift_timer = maxf(_shift_timer - delta, 0.0)
	_shift_cooldown = maxf(_shift_cooldown - delta, 0.0)
	_air_backfire_cd = maxf(_air_backfire_cd - delta, 0.0)

	var sm: Node = get_node_or_null("/root/SoundManager") if play_shift_sfx else null
	var ratios: Array[float] = gear_speed_ratios if not gear_speed_ratios.is_empty() else [0.24, 0.48, 0.74, 1.04]
	var max_gear: int = ratios.size()

	if current_fuel <= 0.0 and not is_preview:
		_current_gear = 1
		_display_gear = "N"
		_air_revving = false
		_sim_rpm = lerpf(_sim_rpm, 0.0, clampf(delta * 4.5, 0.0, 1.0))
		return

	if wants_reverse and forward_mps < -0.5:
		_current_gear = 0
		_display_gear = "R"
		_air_revving = false
		var rev_rpm: float = lerpf(0.26, 0.78, clampf(absf(forward_mps) / 12.0, 0.0, 1.0))
		_sim_rpm = lerpf(_sim_rpm, rev_rpm, clampf(delta * 9.0, 0.0, 1.0))
		return

	if speed_ratio < 0.015 and not wants_throttle and not wants_reverse:
		_current_gear = 1
		_display_gear = "N"
		_air_revving = false
		var wobble: float = 0.012 * sin(float(Time.get_ticks_msec()) * 0.018)
		_sim_rpm = lerpf(_sim_rpm, 0.17 + wobble, clampf(delta * 7.0, 0.0, 1.0))
		return

	var is_airborne_throttle: bool = (grounded_wheels == 0 and wants_throttle and current_fuel > 0.0 and not is_preview and not destroyed and _tornado_timer <= 0.0)
	_current_gear = clampi(_current_gear, 1, max_gear)
	var gear_ceil: float = float(ratios[_current_gear - 1])
	var prev_ceil: float = 0.0 if _current_gear == 1 else float(ratios[_current_gear - 2])

	if is_airborne_throttle:
		_air_revving = true
		if _sim_rpm >= 0.93:
			_air_rev_limiter_phase += delta * 95.0
			var bounce_rpm: float = 0.985 + 0.055 * sin(_air_rev_limiter_phase)
			_sim_rpm = lerpf(_sim_rpm, bounce_rpm, clampf(delta * 22.0, 0.0, 1.0))
			if has_exhaust_backfire and engine_sound_id != "btr" and _air_backfire_cd <= 0.0:
				_air_backfire_cd = randf_range(0.35, 0.56)
				if sm and sm.has_method("play_vehicle_sfx"):
					sm.call("play_vehicle_sfx", "exhaust_backfire", -5.2, clampf(gear_shift_pitch_base * randf_range(0.95, 1.12), 0.78, 1.30))
		else:
			_air_rev_limiter_phase = 0.0
			_sim_rpm = lerpf(_sim_rpm, 1.02, clampf(delta * 14.0, 0.0, 1.0))
		_display_gear = "G%d" % _current_gear
		return

	_air_revving = false
	_air_rev_limiter_phase = 0.0

	if _current_gear < max_gear and speed_ratio >= gear_ceil * 0.94 and wants_throttle and _shift_cooldown <= 0.0:
		_current_gear += 1
		_gear_shift_count += 1
		_shift_timer = 0.24
		_shift_cooldown = 0.44
		_sim_rpm = maxf(_sim_rpm * 0.50, 0.32)
		if sm and sm.has_method("play_vehicle_sfx"):
			if engine_sound_id == "btr":
				sm.call("play_vehicle_sfx", "gear_shift_up", -4.5, gear_shift_pitch_base * randf_range(0.95, 1.06))
			else:
				var s_pitch := gear_shift_pitch_base * randf_range(0.95, 1.05)
				sm.call("play_vehicle_sfx", "gear_shift_up", -2.2, s_pitch)
				if (engine_sound_id == "raptor" and _engine_upgrade_tier >= 1) or engine_sound_id == "delorean":
					sm.call("play_vehicle_sfx", "turbo_bov", -4.8, randf_range(0.95, 1.08))
				if has_exhaust_backfire and _current_gear >= 2:
					var bf_db: float = -4.6 if (engine_sound_id == "doge2" or engine_sound_id == "barracuda") else (-5.2 if (engine_sound_id == "mustang" or engine_sound_id == "carson") else (-5.6 if engine_sound_id == "delorean" else -7.2))
					var bf_p: float = clampf(gear_shift_pitch_base * randf_range(0.92, 1.08), 0.78, 1.25)
					sm.call("play_vehicle_sfx", "exhaust_backfire", bf_db, bf_p)
	elif _current_gear > 1 and speed_ratio < prev_ceil * 0.78 and _shift_cooldown <= 0.0:
		_current_gear -= 1
		_gear_shift_count += 1
		_shift_timer = 0.16
		_shift_cooldown = 0.36
		_sim_rpm = minf(_sim_rpm + 0.24, 0.86)
		if sm and sm.has_method("play_vehicle_sfx"):
			var d_db: float = -6.5 if engine_sound_id == "btr" else -3.6
			sm.call("play_vehicle_sfx", "gear_shift_down", d_db, gear_shift_pitch_base * randf_range(0.90, 1.04))

	gear_ceil = float(ratios[_current_gear - 1])
	prev_ceil = 0.0 if _current_gear == 1 else float(ratios[_current_gear - 2])
	var gear_floor: float = prev_ceil * 0.62
	var gear_t: float = clampf((speed_ratio - gear_floor) / maxf(gear_ceil - gear_floor, 0.08), 0.0, 1.0)

	var min_gear_rpm: float = 0.22 if _current_gear == 1 else 0.34
	var target_rpm: float = lerpf(min_gear_rpm, 0.98, gear_t)
	if wants_throttle and _shift_timer <= 0.0:
		var limiter_bounce: float = sin(float(Time.get_ticks_msec()) * 0.075) * 0.025 if target_rpm >= 0.96 else 0.0
		target_rpm = minf(maxf(target_rpm + 0.08 + limiter_bounce, _launch_wheelspin * 0.92), 1.04)
	elif not wants_throttle:
		target_rpm = maxf(target_rpm - 0.08, 0.16)

	var rpm_rate: float = 16.5 if _shift_timer > 0.0 else (13.5 if _launch_wheelspin > 0.15 else 9.5)
	_sim_rpm = lerpf(_sim_rpm, target_rpm, clampf(delta * rpm_rate, 0.0, 1.0))
	_display_gear = "G%d" % _current_gear

func _update_vehicle_audio(
	delta: float,
	speed_ratio: float,
	max_slip: float,
	wants_throttle: bool,
	wants_reverse: bool,
	is_braking: bool,
	forward_mps: float = 0.0
) -> void:
	_step_transmission(delta, speed_ratio, forward_mps, wants_throttle, wants_reverse, not is_preview and not destroyed)

	var is_btr: bool = (engine_sound_id == "btr")
	var is_empty: bool = current_fuel <= 0.0 and not is_preview
	var rpm_c: float = clampf(_sim_rpm, 0.0, 1.05)
	var idle_weight: float = clampf(1.0 - smoothstep(0.20, 0.65, rpm_c), 0.04, 1.0)
	var mid_in: float = smoothstep(0.14, 0.42, rpm_c)
	var mid_out: float = 1.0 - 0.35 * smoothstep(0.76, 1.02, rpm_c)
	var mid_weight: float = clampf(mid_in * mid_out * (0.78 + (0.22 if wants_throttle else -0.18)) + _launch_wheelspin * 0.20, 0.05, 1.0)
	var howl_weight: float = clampf(smoothstep(0.44, 0.86, rpm_c) * (0.85 + (0.15 if wants_throttle else -0.25)) + _launch_wheelspin * 0.28, 0.0, 1.0)
	var gear_harmonic: float = float(maxi(_current_gear - 1, 0)) * (0.032 if is_btr else 0.044)
	var clutch_dip_db: float = (-8.5 if is_btr else (-11.0 * clampf(_shift_timer / 0.20, 0.0, 1.0))) if _shift_timer > 0.0 else 0.0
	var overrun_db: float = -4.8 if (not wants_throttle and speed_ratio > 0.12 and _shift_timer <= 0.0) else 0.0
	var limiter_dip_db: float = 0.0
	var tier_punch_db: float = 0.0
	var load_db: float = 0.0

	if not is_btr:
		idle_weight = clampf(1.0 - smoothstep(0.16, 0.52, rpm_c), 0.02, 1.0)
		mid_in = smoothstep(0.12, 0.36, rpm_c)
		mid_out = 1.0 - 0.38 * smoothstep(0.68, 0.96, rpm_c)
		mid_weight = clampf(mid_in * mid_out * (0.80 + (0.20 if wants_throttle else -0.22)) + _launch_wheelspin * 0.18, 0.04, 1.0)
		howl_weight = clampf(smoothstep(0.42, 0.80, rpm_c) * (0.88 + (0.14 if wants_throttle else -0.28)) + _launch_wheelspin * 0.26 + (0.18 if _air_revving else 0.0), 0.0, 1.0)
		limiter_dip_db = (-3.8 * clampf(-sin(_air_rev_limiter_phase), 0.0, 1.0)) if (_air_revving and _sim_rpm >= 0.92) else 0.0
		tier_punch_db = float(_engine_upgrade_tier) * 1.15
		load_db = 2.2 if wants_throttle else (-2.6 if speed_ratio > 0.10 else 0.0)
		overrun_db = -3.8 if (not wants_throttle and speed_ratio > 0.12 and _shift_timer <= 0.0) else 0.0

	if is_instance_valid(_engine_audio):
		if is_empty:
			_engine_audio.pitch_scale = lerpf(_engine_audio.pitch_scale, 0.52, clampf(delta * 4.0, 0.0, 1.0))
			_engine_audio.volume_db = lerpf(_engine_audio.volume_db, -60.0, clampf(delta * 5.5, 0.0, 1.0))
		else:
			var rev_pitch: float = clampf((lerpf(0.72, 1.66, pow(rpm_c, 0.90)) + gear_harmonic) * engine_pitch_scale, 0.65, 2.05) if is_btr else clampf((lerpf(0.72, 1.72, clampf((rpm_c - 0.08) / 0.88, 0.0, 1.0)) + gear_harmonic) * engine_pitch_scale, 0.65, 1.82)
			_engine_audio.pitch_scale = lerpf(_engine_audio.pitch_scale, rev_pitch, clampf(delta * 16.0, 0.0, 1.0))
			var target_rev_db: float = lerpf(-24.0, -6.4 if is_btr else -4.8, mid_weight) + clutch_dip_db + overrun_db + (0.0 if is_btr else (tier_punch_db + load_db * 0.45 + limiter_dip_db))
			_engine_audio.volume_db = lerpf(_engine_audio.volume_db, clampf(target_rev_db, -60.0, 1.5), clampf(delta * 12.5, 0.0, 1.0))

	if is_instance_valid(_engine_howl_audio):
		if is_empty:
			_engine_howl_audio.pitch_scale = lerpf(_engine_howl_audio.pitch_scale, 0.60, clampf(delta * 4.0, 0.0, 1.0))
			_engine_howl_audio.volume_db = lerpf(_engine_howl_audio.volume_db, -60.0, clampf(delta * 5.5, 0.0, 1.0))
		else:
			var howl_pitch: float = clampf((lerpf(0.84, 1.68, rpm_c) + gear_harmonic * 0.85) * engine_pitch_scale, 0.72, 2.10) if is_btr else clampf((lerpf(0.78, 1.76, clampf((rpm_c - 0.36) / 0.64, 0.0, 1.0)) + gear_harmonic * 0.72) * engine_pitch_scale, 0.70, 1.88)
			_engine_howl_audio.pitch_scale = lerpf(_engine_howl_audio.pitch_scale, howl_pitch, clampf(delta * 16.0, 0.0, 1.0))
			var target_howl_db: float = (lerpf(-32.0, -5.8 if is_btr else -3.8, howl_weight * howl_weight) + clutch_dip_db + overrun_db * 0.75 + (0.0 if is_btr else (tier_punch_db + load_db * 0.55 + limiter_dip_db))) if howl_weight > 0.02 else -60.0
			_engine_howl_audio.volume_db = lerpf(_engine_howl_audio.volume_db, clampf(target_howl_db, -60.0, 2.0), clampf(delta * 13.0, 0.0, 1.0))

	if is_instance_valid(_engine_idle_audio):
		if is_empty:
			_engine_idle_audio.pitch_scale = lerpf(_engine_idle_audio.pitch_scale, 0.56, clampf(delta * 4.0, 0.0, 1.0))
			_engine_idle_audio.volume_db = lerpf(_engine_idle_audio.volume_db, -60.0, clampf(delta * 5.5, 0.0, 1.0))
		else:
			var idle_pitch: float = clampf(lerpf(0.88, 1.28, clampf(rpm_c / 0.65, 0.0, 1.0)) * engine_pitch_scale, 0.72, 1.45) if is_btr else clampf(lerpf(0.80, 1.48, clampf(rpm_c / 0.56, 0.0, 1.0)) * engine_pitch_scale, 0.74, 1.56)
			_engine_idle_audio.pitch_scale = lerpf(_engine_idle_audio.pitch_scale, idle_pitch, clampf(delta * 14.0, 0.0, 1.0))
			var target_idle_db: float = lerpf(-28.0, -7.8 if is_btr else -5.8, idle_weight) + clutch_dip_db * 0.35 + (0.0 if is_btr else tier_punch_db * 0.5)
			_engine_idle_audio.volume_db = lerpf(_engine_idle_audio.volume_db, clampf(target_idle_db, -60.0, 0.0), clampf(delta * 10.5, 0.0, 1.0))

	if is_instance_valid(_engine_boost_audio):
		var has_boost: bool = (not is_btr) and not is_empty and (_engine_upgrade_tier >= 2 or (engine_sound_id == "raptor" and _engine_upgrade_tier >= 1) or engine_sound_id == "delorean")
		if has_boost:
			var boost_lvl: float = clampf((rpm_c - 0.32) / 0.68, 0.0, 1.0) * (1.0 if wants_throttle else 0.22)
			var target_boost_db: float = (lerpf(-36.0, -16.5, boost_lvl) + clutch_dip_db * 0.5 + limiter_dip_db * 0.6) if boost_lvl > 0.05 else -60.0
			_engine_boost_audio.volume_db = lerpf(_engine_boost_audio.volume_db, target_boost_db, clampf(delta * 10.0, 0.0, 1.0))
			_engine_boost_audio.pitch_scale = lerpf(_engine_boost_audio.pitch_scale, lerpf(0.75, 1.85, boost_lvl), clampf(delta * 12.0, 0.0, 1.0))
		else:
			_engine_boost_audio.volume_db = lerpf(_engine_boost_audio.volume_db, -60.0, clampf(delta * 10.0, 0.0, 1.0))

	if is_instance_valid(_fire_audio):
		var target_fire_db: float = lerpf(-20.0, -6.5, _engine_fire_level) if _engine_fire_level > 0.01 else -60.0
		_fire_audio.volume_db = lerpf(_fire_audio.volume_db, target_fire_db, clampf(delta * 7.5, 0.0, 1.0))

	if is_instance_valid(_skid_audio):
		var skid_raw := 0.0
		if grounded_wheels > 0:
			if _launch_wheelspin > 0.10:
				skid_raw = maxf(skid_raw, clampf(_launch_wheelspin * 0.92, 0.0, 0.92))
			if max_slip > 3.8 and speed_ratio > 0.14:
				skid_raw = maxf(skid_raw, clampf((max_slip - 3.8) / 6.5, 0.0, 0.92))
			elif is_braking and speed_ratio > 0.18:
				skid_raw = maxf(skid_raw, clampf(speed_ratio * 0.80, 0.0, 0.80))
		_smooth_skid_vol = lerpf(_smooth_skid_vol, skid_raw, clampf(delta * 12.0, 0.0, 1.0))
		if _smooth_skid_vol > 0.03:
			_skid_audio.volume_db = lerpf(-30.0, -10.2, _smooth_skid_vol)
			_skid_audio.pitch_scale = lerpf(0.92, 1.22, _smooth_skid_vol)
		else:
			_skid_audio.volume_db = -60.0

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_speed_wind"):
		sm.call("set_speed_wind", speed_ratio, not is_preview and not destroyed)

func _step_raycast_suspension_and_tires(
	delta: float,
	speed_mps: float,
	speed_ratio: float,
	forward_mps: float,
	wants_throttle: bool,
	wants_reverse: bool,
	is_braking: bool
) -> void:
	var wheel_count: int = _wheels.size()
	if wheel_count == 0:
		_apply_traction(speed_mps)
		return

	var inv_dt: float = 1.0 / maxf(delta, 0.002)
	var g_total: float = mass * 9.8 * maxf(gravity_scale, 0.25)
	var per_wheel_mass: float = mass / float(wheel_count)
	var per_wheel_weight: float = g_total / float(wheel_count)
	var car_up: Vector3 = global_transform.basis.y
	var car_fwd: Vector3 = -global_transform.basis.z
	var car_right: Vector3 = global_transform.basis.x

	var susp_forces: Array[float] = []
	susp_forces.resize(wheel_count)
	grounded_wheels = 0
	var traction_total: int = 0

	# 1. Smoothed progressive Hooke's law suspension with inelastic landing absorption
	_post_landing_damp_timer = maxf(_post_landing_damp_timer - delta, 0.0)
	var max_landing_comp_ratio: float = 0.0
	var max_landing_spring_vel: float = 0.0
	var space_state := get_world_3d().direct_space_state
	for i in range(wheel_count):
		var w := _wheels[i]
		if w.use_as_traction:
			traction_total += 1

		var was_grounded: bool = w.is_grounded
		if w.cast_suspension_ray(space_state, self, car_up):
			max_landing_comp_ratio = maxf(max_landing_comp_ratio, w.compression_ratio)

			var k_eff: float = w.spring_stiffness_override if w.spring_stiffness_override > 0.0 else (per_wheel_weight / maxf(w.rest_length * 0.50, 0.05)) * suspension_firmness
			var c_crit: float = 2.0 * sqrt(k_eff * per_wheel_mass)
			var damp_comp: float = w.damping_comp_override if w.damping_comp_override > 0.0 else c_crit * compression_damping_ratio
			var damp_reb: float = w.damping_rebound_override if w.damping_rebound_override > 0.0 else c_crit * rebound_damping_ratio

			var wheel_offset: Vector3 = w.global_position - global_position
			var wheel_vel: Vector3 = linear_velocity + angular_velocity.cross(wheel_offset)
			var raw_spring_vel: float = clampf(-wheel_vel.dot(w.ground_normal), -10.0, 16.0)
			max_landing_spring_vel = maxf(max_landing_spring_vel, raw_spring_vel)
			if not was_grounded or signf(raw_spring_vel) != signf(w.smooth_spring_vel):
				w.smooth_spring_vel = raw_spring_vel
			else:
				w.smooth_spring_vel = lerpf(w.smooth_spring_vel, raw_spring_vel, clampf(delta * 28.0, 0.0, 1.0))

			# Позиционно-зависимый гидравлический отбойник:
			# при глубоком пробое позволяет быстро вернуться в норму, а возле рабочего клиренса жёстко гасит раскачку и прыжок
			if w.compression_ratio > 0.68:
				var bs_excess: float = w.compression_ratio - 0.68
				if w.smooth_spring_vel >= 0.0:
					k_eff *= 1.0 + bs_excess * 0.85
				damp_comp *= 1.0 + bs_excess * 2.5

			var recovery_t: float = clampf((w.compression_ratio - 0.58) / 0.65, 0.0, 1.0)
			if _post_landing_damp_timer > 0.0:
				if w.compression_ratio > 0.72:
					damp_reb *= 1.05
				else:
					damp_reb = maxf(damp_reb * 1.65, c_crit * 1.12)

			var damp_eff: float = damp_comp if w.smooth_spring_vel >= 0.0 else damp_reb
			var f_raw: float = w.compression_m * k_eff + w.smooth_spring_vel * damp_eff
			var reb_cap_mult: float = lerpf(1.08 if _post_landing_damp_timer > 0.0 else 1.24, 1.65, recovery_t)
			var f_cap: float = per_wheel_weight * (4.2 if w.smooth_spring_vel >= 0.0 else reb_cap_mult)
			var f_susp: float = clampf(f_raw, 0.0, f_cap)
			susp_forces[i] = f_susp
			w.prev_compression_m = w.compression_m
			grounded_wheels += 1
		else:
			w.prev_compression_m = 0.0
			w.smooth_spring_vel = lerpf(w.smooth_spring_vel, 0.0, clampf(delta * 12.0, 0.0, 1.0))
			susp_forces[i] = 0.0

	# Track airborne flight & trigger hard-landing sparks + sound + camera jolt on touchdown
	_landing_cooldown = maxf(_landing_cooldown - delta, 0.0)
	if grounded_wheels == 0:
		_airborne_timer += delta
		_peak_downward_vy = minf(_peak_downward_vy, linear_velocity.y)
	else:
		if linear_velocity.y < -1.0:
			_peak_downward_vy = minf(_peak_downward_vy, linear_velocity.y)
		var hard_touchdown: bool = (_prev_grounded_wheels == 0 and _airborne_timer >= 0.14 and (_peak_downward_vy < -2.1 or max_landing_spring_vel > 2.8))
		var heavy_bottom_out: bool = (_airborne_timer >= 0.08 and _peak_downward_vy < -3.2 and max_landing_comp_ratio > 0.72)
		if (hard_touchdown or heavy_bottom_out) and _landing_cooldown <= 0.0:
			var impact_t: float = clampf((absf(_peak_downward_vy) - 1.8) / 8.0 + max_landing_comp_ratio * 0.35, 0.40, 1.50)
			trigger_landing_vfx(impact_t)
		_airborne_timer = 0.0
		_peak_downward_vy = 0.0
	_prev_grounded_wheels = grounded_wheels

	if _post_landing_damp_timer > 0.0 and grounded_wheels >= 2:
		var deep_up: float = 0.96 if mass > 3500.0 else 1.28
		var max_up_vy: float = deep_up if max_landing_comp_ratio >= 0.70 else 0.30
		if linear_velocity.y > max_up_vy:
			linear_velocity.y = move_toward(linear_velocity.y, max_up_vy * 0.85, delta * 36.0)

	# 2. Front & rear Anti-Roll Bars + Dynamic Weight Transfer
	_apply_anti_roll_pair(_front_left, _front_right, anti_roll_stiffness, susp_forces, per_wheel_weight)
	_apply_anti_roll_pair(_rear_left, _rear_right, anti_roll_stiffness * 0.90, susp_forces, per_wheel_weight)

	if grounded_wheels >= 2:
		var est_long_g: float = clampf(((forward_mps - _prev_forward_mps) * inv_dt) / 9.8, -1.35, 1.35)
		var est_lat_g: float = clampf((speed_mps * angular_velocity.dot(car_up)) / 9.8, -1.45, 1.45)
		var long_shift: float = est_long_g * per_wheel_weight * weight_transfer_long
		var lat_shift: float = est_lat_g * per_wheel_weight * weight_transfer_lat
		for i in range(wheel_count):
			var w_tr := _wheels[i]
			if not w_tr.is_grounded:
				continue
			# Acceleration shifts load to rear; braking shifts load to front
			var df_w: float = (-long_shift if w_tr.is_front else long_shift)
			# Right turn (positive yaw -> negative lat_g) shifts load to left wheels and vice versa
			df_w += (lat_shift if w_tr.is_left else -lat_shift)
			var rec_tr: float = clampf((w_tr.compression_ratio - 0.58) / 0.65, 0.0, 1.0)
			var reb_tr: float = lerpf(1.08 if _post_landing_damp_timer > 0.0 else 1.24, 1.65, rec_tr)
			var tr_cap: float = per_wheel_weight * (4.2 if w_tr.smooth_spring_vel >= 0.0 else reb_tr)
			susp_forces[i] = clampf(susp_forces[i] + df_w, per_wheel_weight * 0.15, tr_cap)

	# 3. Aero downforce
	if grounded_wheels > 0:
		var downforce: float = clampf(speed_mps * downforce_multiplier, 0.0, downforce_max)
		apply_central_force(-car_up * downforce)
		var downforce_per_w: float = downforce / float(grounded_wheels)
		for i in range(wheel_count):
			if _wheels[i].is_grounded:
				susp_forces[i] += downforce_per_w * 0.65

	if is_braking:
		_brake_pressure = minf(_brake_pressure + delta * 3.4, 1.0)
	else:
		_brake_pressure = maxf(_brake_pressure - delta * 8.0, 0.0)

	# 4. Longitudinal drive force coupled to active transmission gear & RPM band
	var total_drive_force: float = 0.0
	if wants_throttle and current_fuel > 0.0:
		var g_idx: int = clampi(_current_gear - 1, 0, maxi(gear_torque_multipliers.size() - 1, 0))
		var gear_mult: float = 1.0
		if not gear_torque_multipliers.is_empty():
			gear_mult = float(gear_torque_multipliers[g_idx])
		else:
			var max_g: int = maxi(gear_speed_ratios.size(), 1)
			gear_mult = lerpf(1.50, 0.64, float(g_idx) / maxf(float(max_g - 1), 1.0))
		var rpm_t: float = clampf((_sim_rpm - 0.16) / 0.80, 0.0, 1.0)
		var rpm_curve: float = 0.84 + 0.22 * sin(rpm_t * PI)
		if _shift_timer > 0.0:
			rpm_curve *= 0.28
		var overdrive_mult: float = 1.18 if _overdrive_timer > 0.0 else 1.0
		var launch_punch: float = 1.0 + _launch_wheelspin * 0.26
		var speed_fade: float = clampf((float(MAX_SPEED_KMH) - speed_mps * MPS_TO_KMH) / 14.0, 0.0, 1.0)
		var spool_factor: float = clampf(maxf(_smooth_throttle, 0.18), 0.18, 1.0)
		total_drive_force = float(engine_force_value) * 1.72 * gear_mult * rpm_curve * speed_fade * overdrive_mult * spool_factor * launch_punch
	elif wants_reverse and current_fuel > 0.0:
		var rev_kmh := absf(forward_mps) * MPS_TO_KMH
		if rev_kmh < 42.0:
			var rev_spool: float = clampf(absf(_smooth_throttle) * 1.25, 0.20, 1.0)
			total_drive_force = -float(engine_force_value) * 1.15 * rev_spool

	var traction_divisor: float = float(maxi(traction_total, 1))
	var drive_per_wheel: float = total_drive_force / traction_divisor
	var lat_accel_sum: float = 0.0

	# 5. Apply 3D forces at tire contact patches (rear-anchored stability prevents spinouts)
	for i in range(wheel_count):
		var w := _wheels[i]
		if not w.is_grounded:
			w.lateral_slip_mps = 0.0
			w.forward_speed_mps = lerpf(w.forward_speed_mps, forward_mps, clampf(delta * 4.0, 0.0, 1.0))
			w.update_visuals(steering, w.forward_speed_mps, delta, false)
			continue

		var f_susp: float = susp_forces[i]
		var susp_dir: Vector3 = w.ground_normal.lerp(car_up, 0.35).normalized()
		var susp_offset: Vector3 = w.global_position - global_position
		apply_force(susp_dir * f_susp, susp_offset)

		var contact_offset: Vector3 = (w.global_position - car_up * (w.wheel_radius * 0.38)) - global_position
		var vel_at_wheel: Vector3 = linear_velocity + angular_velocity.cross(contact_offset)

		var steer_ang: float = steering if w.use_as_steering else 0.0
		var wheel_basis: Basis = global_transform.basis * Basis(Vector3.UP, steer_ang)
		var wheel_fwd: Vector3 = -wheel_basis.z
		var wheel_right: Vector3 = wheel_basis.x

		var fwd_vel: float = vel_at_wheel.dot(wheel_fwd)
		var lat_vel: float = vel_at_wheel.dot(wheel_right)
		w.forward_speed_mps = fwd_vel
		w.lateral_slip_mps = lat_vel

		# Planted rear bias on dry asphalt + wide controllable balanced slide on Winter Ice (_on_black_ice)
		var grip_mod: float = w.grip_multiplier
		if _on_black_ice:
			grip_mod *= (front_grip_bias * 0.94 if w.is_front else rear_grip_bias * 0.86)
		elif w.is_front:
			grip_mod *= 0.96
		else:
			grip_mod *= 1.12
		if not w.is_front:
			var slip_threshold: float = (2.6 + speed_mps * 0.09) if _on_black_ice else (4.8 + speed_mps * 0.15)
			if absf(lat_vel) > slip_threshold:
				var slide_t: float = clampf((absf(lat_vel) - slip_threshold) / 7.0, 0.0, 1.0)
				var min_high_speed_grip: float = clampf(drift_grip_factor * 0.78, 0.56, 0.74) if _on_black_ice else maxf(drift_grip_factor, lerpf(0.76, 0.92, clampf(speed_ratio * 1.15, 0.0, 1.0)))
				grip_mod *= lerpf(1.0, min_high_speed_grip, slide_t)

		var max_tire_lat: float = maxf(f_susp, per_wheel_weight * 0.45) * tire_friction * grip_mod * _surface_grip_mult
		var stop_lat_force: float = per_wheel_mass * absf(lat_vel) * inv_dt * 0.92
		var lat_rate_mult: float = (0.38 if not w.is_front else 0.44) if _on_black_ice else (1.14 if not w.is_front else 0.94)
		var lat_grip_blend: float = lerpf(0.32, 0.85, _surface_grip_mult) if _on_black_ice else lerpf(0.62, 1.0, _surface_grip_mult)
		var lat_rate: float = lateral_stiffness * lat_rate_mult * lat_grip_blend
		var raw_lat_force: float = -lat_vel * per_wheel_mass * lat_rate * grip_mod
		var f_lat: float = clampf(raw_lat_force, -minf(max_tire_lat, stop_lat_force), minf(max_tire_lat, stop_lat_force))
		apply_force(wheel_right * f_lat, contact_offset)
		lat_accel_sum += f_lat

		var f_long: float = 0.0
		if w.use_as_traction and absf(total_drive_force) > 1.0:
			f_long += drive_per_wheel * lerpf(0.82, 1.0, _surface_grip_mult)
		if is_braking and absf(fwd_vel) > 0.15:
			var bias: float = 1.30 if w.is_front else 0.70
			var target_decel: float = max_brake_decel_mps2 * maxf(_brake_pressure, 0.18) * clampf(brake_force / 100.0, 0.65, 1.55) * lerpf(0.54, 1.0, _surface_brake_mult)
			var max_tire_long: float = maxf(f_susp, per_wheel_weight * 0.45) * tire_friction * 0.90 * _surface_brake_mult
			var brk_mag: float = minf(per_wheel_mass * target_decel * bias, minf(max_tire_long, per_wheel_mass * absf(fwd_vel) * inv_dt * 0.85))
			f_long += -signf(fwd_vel) * brk_mag
		elif not wants_throttle and not wants_reverse and absf(fwd_vel) > 0.05:
			var roll_mag: float = minf(absf(fwd_vel) * per_wheel_mass * 0.018 + per_wheel_mass * 0.20, per_wheel_mass * absf(fwd_vel) * inv_dt * 0.25)
			f_long += -signf(fwd_vel) * roll_mag * lerpf(0.45, 1.0, _surface_grip_mult)

		if absf(f_long) > 0.01:
			apply_force(wheel_fwd * f_long, contact_offset)

		var vis_wheel_spd: float = fwd_vel + (_launch_wheelspin * 24.0 if (w.use_as_traction or not w.is_front) else 0.0)
		w.update_visuals(steering, vis_wheel_spd, delta, false)

	if speed_mps > 1.5:
		var drag_scale: float = 1.0 if wants_throttle else 0.28
		apply_central_force(-linear_velocity.normalized() * (aero_drag_coeff * drag_scale * speed_mps * speed_mps))

	# 6. Body roll, pitch squat/dive, launch torque shudder, realistic yaw weight damping & self-righting
	if grounded_wheels >= 2:
		var roll_assist: float = (lat_accel_sum / maxf(mass, 1.0)) * mass * body_roll_torque_factor * 0.068
		apply_torque(car_fwd * (-roll_assist))

		var long_accel: float = clampf((forward_mps - _prev_forward_mps) * inv_dt, -25.0, 25.0)
		var launch_squat_boost: float = _launch_wheelspin * 6.5 if wants_throttle else 0.0
		var pitch_assist: float = (long_accel + launch_squat_boost) * mass * body_pitch_torque_factor * 0.018
		apply_torque(car_right * pitch_assist)

		if _launch_wheelspin > 0.18 and wants_throttle:
			var torque_shudder: float = sin(float(Time.get_ticks_msec()) * 0.036) * _launch_wheelspin * mass * 0.48
			apply_torque(car_up * torque_shudder)

		# Cornering tire scrub drag gives heavy trucks & APCs palpable weight under hard steering
		if speed_mps > 3.0 and absf(steering) > 0.03:
			var steer_frac: float = clampf(absf(steering) / maxf(STEER_LIMIT, 0.02), 0.0, 1.0)
			apply_central_force(-linear_velocity.normalized() * steer_frac * speed_mps * mass * steering_scrub_drag * 0.22 * _surface_grip_mult)

		# Subtle yaw stability damping + active counter-steer & anti-spinout drift control
		if speed_mps > 2.5 and absf(forward_mps) > 1.5 and yaw_stability_assist > 0.01:
			var wheelbase: float = maxf(wheelbase_m, 1.8)
			var steer_gain: float = lerpf(0.84, 0.52, speed_ratio)
			var ideal_yaw: float = clampf((forward_mps / wheelbase) * tan(steering) * steer_gain, -1.35, 1.35)
			var cur_yaw: float = angular_velocity.dot(car_up)
			var yaw_err: float = ideal_yaw - cur_yaw
			var esc_torque: float = clampf(yaw_err * mass * yaw_stability_assist * _surface_yaw_mult, -mass * 6.5, mass * 6.5)
			var drift_esc_scale: float = 0.72 if _on_black_ice else 1.0
			apply_torque(car_up * (esc_torque * drift_esc_scale))
			if _on_black_ice:
				apply_torque(car_up * (-cur_yaw * mass * 2.8))

			if speed_mps > 5.0 and forward_mps > 2.0:
				var flat_fwd_3d := Vector3(car_fwd.x, 0.0, car_fwd.z)
				var horiz_vel_3d := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
				if flat_fwd_3d.length_squared() > 0.01 and horiz_vel_3d.length_squared() > 1.0:
					flat_fwd_3d = flat_fwd_3d.normalized()
					horiz_vel_3d = horiz_vel_3d.normalized()
					# slip_angle: отрицательный = нос смотрит левее курса; положительный = нос смотрит правее
					var slip_angle: float = flat_fwd_3d.signed_angle_to(horiz_vel_3d, Vector3.UP)
					var max_slip_rad: float = minf(deg_to_rad(drift_max_angle_deg), deg_to_rad(22.0)) if _on_black_ice else deg_to_rad(drift_max_angle_deg)
					if _on_black_ice and speed_mps > 7.5 and absf(steering) > 0.06 and absf(slip_angle) < max_slip_rad * 0.55:
						if signf(steering) != signf(slip_angle) or absf(slip_angle) < 0.08:
							var init_steer_frac: float = clampf(absf(steering) / maxf(STEER_LIMIT, 0.05), 0.25, 1.0)
							var init_gain: float = 0.24
							apply_torque(car_up * (signf(steering) * mass * init_gain * init_steer_frac))
					if absf(slip_angle) > max_slip_rad * 0.62:
						var over_rad: float = absf(slip_angle) - max_slip_rad * 0.62
						apply_torque(car_up * (signf(slip_angle) * over_rad * mass * 26.0))
						if signf(cur_yaw) != 0.0 and signf(cur_yaw) != signf(slip_angle):
							apply_torque(car_up * (-cur_yaw * mass * 5.2))
					if absf(steering) > 0.05 and absf(slip_angle) > 0.09 and signf(steering) == signf(slip_angle):
						var cs_ratio: float = clampf(absf(steering) / maxf(STEER_LIMIT, 0.05), 0.25, 1.0)
						apply_torque(car_up * (signf(slip_angle) * mass * drift_countersteer_assist * cs_ratio))
					elif absf(steering) < 0.05 and absf(slip_angle) > 0.05:
						apply_torque(car_up * (clampf(slip_angle, -0.65, 0.65) * mass * drift_self_align_strength))

		var tilt_axis: Vector3 = car_up.cross(Vector3.UP)
		var tilt_len: float = tilt_axis.length()
		if tilt_len > 0.14:
			var excess: float = tilt_len - 0.14
			apply_torque(tilt_axis.normalized() * mass * (16.0 * excess + 28.0 * excess * excess))
			var roll_rate: float = angular_velocity.dot(car_fwd)
			apply_torque(-car_fwd * roll_rate * mass * 2.4)
	else:
		var air_axis: Vector3 = car_up.cross(Vector3.UP)
		apply_torque(air_axis * mass * (air_stabilize_torque + 3.0) - angular_velocity * mass * 0.72)

func trigger_landing_vfx(impact_t: float = 1.0) -> void:
	if destroyed or is_preview:
		return
	_landing_cooldown = 0.35
	_post_landing_damp_timer = 0.65
	angular_velocity.x *= 0.42
	angular_velocity.z *= 0.42
	if linear_velocity.y > 0.25:
		linear_velocity.y *= 0.25
	_last_landing_sparks_ms = Time.get_ticks_msec()
	var contact_pts: Array[Vector3] = []
	for w in _wheels:
		if w.is_grounded:
			contact_pts.append(w.ground_point + Vector3(0.0, 0.08, 0.0))
	if contact_pts.is_empty():
		var car_up: Vector3 = global_transform.basis.y
		var car_right: Vector3 = global_transform.basis.x
		var base_pt: Vector3 = global_position - car_up * 0.35
		contact_pts.append(base_pt - car_right * 0.75)
		contact_pts.append(base_pt + car_right * 0.75)
	CarVFX.spawn_landing_sparks(contact_pts, linear_velocity, impact_t)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_car_landing"):
		sm.call("play_car_landing", impact_t, mass >= 2700.0)
	if is_instance_valid(_camera) and _camera.has_method("trigger_landing_impact"):
		_camera.call("trigger_landing_impact", impact_t)
	shake_camera(clampf(impact_t * 0.65, 0.28, 1.10))

func _apply_anti_roll_pair(left_w: RaycastWheel, right_w: RaycastWheel, stiffness: float, forces: Array[float], per_w_weight: float) -> void:
	if left_w == null or right_w == null:
		return
	var idx_l: int = _wheels.find(left_w)
	var idx_r: int = _wheels.find(right_w)
	if idx_l < 0 or idx_r < 0:
		return
	var travel_diff: float = left_w.compression_ratio - right_w.compression_ratio
	var arb: float = travel_diff * stiffness
	if left_w.is_grounded:
		var rec_l: float = clampf((left_w.compression_ratio - 0.58) / 0.65, 0.0, 1.0)
		var reb_l: float = lerpf(1.08 if _post_landing_damp_timer > 0.0 else 1.24, 1.65, rec_l)
		var cap_l: float = per_w_weight * (4.2 if left_w.smooth_spring_vel >= 0.0 else reb_l)
		forces[idx_l] = clampf(forces[idx_l] + arb, 0.0, cap_l)
	if right_w.is_grounded:
		var rec_r: float = clampf((right_w.compression_ratio - 0.58) / 0.65, 0.0, 1.0)
		var reb_r: float = lerpf(1.08 if _post_landing_damp_timer > 0.0 else 1.24, 1.65, rec_r)
		var cap_r: float = per_w_weight * (4.2 if right_w.smooth_spring_vel >= 0.0 else reb_r)
		forces[idx_r] = clampf(forces[idx_r] - arb, 0.0, cap_r)

func _update_visual_lights(delta: float, braking_now: bool, immediate: bool = false) -> void:
	if not use_visual_lights or _lights_rig == null:
		return

	var ground_sum_y: float = 0.0
	var g_count: int = 0
	var normal_sum := Vector3.ZERO
	var front_hit := Vector3.ZERO
	var rear_hit := Vector3.ZERO
	var front_hits: int = 0
	var rear_hits: int = 0

	for w in _wheels:
		if w.is_grounded:
			ground_sum_y += w.ground_point.y
			normal_sum += w.ground_normal
			g_count += 1
			if w.is_front:
				front_hit += w.ground_point
				front_hits += 1
			else:
				rear_hit += w.ground_point
				rear_hits += 1

	var target_ground_y: float = (ground_sum_y / float(g_count)) if g_count > 0 else (global_position.y - 0.06)
	var target_normal: Vector3 = normal_sum.normalized() if g_count > 0 and normal_sum.length_squared() > 0.001 else Vector3.UP

	# Align light plane longitudinal pitch with actual front-vs-rear wheel road slope (climbs bridges!)
	var car_fwd := -global_transform.basis.z
	var flat_fwd := Vector3(car_fwd.x, 0.0, car_fwd.z)
	if flat_fwd.length_squared() < 0.0001:
		flat_fwd = Vector3.BACK
	else:
		flat_fwd = flat_fwd.normalized()

	if front_hits > 0 and rear_hits > 0:
		var axle_vec := (front_hit / float(front_hits)) - (rear_hit / float(rear_hits))
		if axle_vec.length_squared() > 0.25:
			var road_fwd_dir := axle_vec.normalized()
			var up_ortho := (target_normal - road_fwd_dir * target_normal.dot(road_fwd_dir))
			if up_ortho.length_squared() > 0.001:
				target_normal = up_ortho.normalized()

	var lerp_t: float = 1.0 if immediate else clampf(delta * 16.0, 0.0, 1.0)
	_smooth_ground_y = lerpf(_smooth_ground_y, target_ground_y, lerp_t)
	_smooth_ground_normal = _smooth_ground_normal.lerp(target_normal, lerp_t).normalized()

	var road_y_base: Vector3 = _smooth_ground_normal
	var road_z: Vector3 = -flat_fwd
	var road_x: Vector3 = road_y_base.cross(road_z)
	if road_x.length_squared() < 0.0001:
		road_x = Vector3.RIGHT
	else:
		road_x = road_x.normalized()
	road_z = road_x.cross(road_y_base).normalized()
	var road_basis := Basis(road_x, road_y_base, road_z)

	var base_origin := Vector3(global_position.x, _smooth_ground_y, global_position.z)

	if is_instance_valid(_shadow_mesh) and _shadow_mat:
		_shadow_mesh.global_transform = Transform3D(road_basis, base_origin + road_basis * Vector3(shadow_offset.x, 0.028, shadow_offset.y))
		var shadow_fade: float = 0.82 if (g_count > 0 or is_preview) else 0.22
		_shadow_mat.set_shader_parameter("shadow_strength", shadow_fade)

	var target_steer_shift: float = clampf(steering / maxf(STEER_LIMIT, 0.01), -1.0, 1.0)
	_smooth_steer_shift = lerpf(_smooth_steer_shift, target_steer_shift, clampf(delta * 12.0, 0.0, 1.0))

	var pitch_val: float = clampf(1.0 + global_transform.basis.z.y * 0.9, 0.80, 1.25)
	_smooth_pitch_shift = lerpf(_smooth_pitch_shift, pitch_val, clampf(delta * 10.0, 0.0, 1.0))

	var hl_boost: float = 1.0
	var main_sc := get_tree().current_scene if is_inside_tree() else null
	if main_sc and main_sc.has_method("get_headlight_boost"):
		hl_boost = float(main_sc.call("get_headlight_boost"))

	var ground_factor: float = 1.0 if (g_count > 0 or _showcase_mode) else 0.45
	if is_instance_valid(_head_proj_mesh) and _head_proj_mat:
		var head_local := Vector3(0.0, 0.044, headlight_proj_z_start - headlight_proj_size.y * 0.5 + 1.0)
		_head_proj_mesh.global_transform = Transform3D(road_basis, base_origin + road_basis * head_local)
		_head_proj_mat.set_shader_parameter("steer_shift", _smooth_steer_shift)
		_head_proj_mat.set_shader_parameter("pitch_stretch", _smooth_pitch_shift)
		_head_proj_mat.set_shader_parameter("intensity", 1.05 * ground_factor * hl_boost)

	_smooth_brake_glow = lerpf(_smooth_brake_glow, 1.0 if braking_now else 0.0, clampf(delta * 14.0, 0.0, 1.0))
	if is_instance_valid(_tail_proj_mesh) and _tail_proj_mat:
		var tail_local := Vector3(0.0, 0.040, taillight_proj_z_start + taillight_proj_size.y * 0.5 - 0.28)
		_tail_proj_mesh.global_transform = Transform3D(road_basis, base_origin + road_basis * tail_local)
		_tail_proj_mat.set_shader_parameter("intensity", lerpf(0.44, 1.38, _smooth_brake_glow) * ground_factor)

	for bm in _head_beam_mats:
		if bm:
			bm.set_shader_parameter("beam_intensity", lerpf(0.22, 0.28, absf(_smooth_steer_shift)) * lerpf(1.0, 1.45, clampf(hl_boost - 1.0, 0.0, 1.0)))

	if (not is_preview or _showcase_mode) and not destroyed:
		var hl_l_local: Vector3 = headlight_positions[0] if headlight_positions.size() >= 1 else Vector3(-0.7, 0.75, -2.3)
		var hl_r_local: Vector3 = headlight_positions[1] if headlight_positions.size() >= 2 else hl_l_local
		var hl_l_world: Vector3 = global_transform * hl_l_local
		var hl_r_world: Vector3 = global_transform * hl_r_local
		var hl_dir_world: Vector3 = (car_fwd + global_transform.basis.x * (_smooth_steer_shift * 0.14) + Vector3(0.0, -0.055, 0.0)).normalized()
		var hl_base_int: float = (1.65 if _showcase_mode else 1.25 * hl_boost) * ground_factor
		var hl_rng: float = (74.0 if _showcase_mode else 68.0) * lerpf(1.0, 1.18, clampf(hl_boost - 1.0, 0.0, 1.0))
		ZombiePool.update_headlight_uniforms(hl_l_world, hl_r_world, hl_dir_world, hl_base_int, Color(1.0, 0.94, 0.78, 1.0), hl_rng)
		ProceduralMaterials.update_headlight_uniforms(hl_l_world, hl_r_world, hl_dir_world, hl_base_int, Color(1.0, 0.94, 0.78, 1.0), hl_rng)

	for hl in _head_lens_mats:
		if hl:
			var h_int: float = 0.0 if destroyed else (1.15 if is_preview else 1.35)
			hl.set_shader_parameter("intensity", h_int)

	for tm in _tail_lens_mats:
		if tm:
			var t_int: float = 0.0 if destroyed else (0.90 if is_preview else lerpf(1.05, 2.35, _smooth_brake_glow))
			tm.set_shader_parameter("intensity", t_int)
			tm.set_shader_parameter("lens_color", Color(1.0, lerpf(0.14, 0.24, _smooth_brake_glow), 0.08, 1.0))

func update_showcase_lights(delta: float = 0.016) -> void:
	if _showcase_mode and not destroyed and is_inside_tree():
		_update_visual_lights(delta, false, false)

func _process_vehicle_extras(_delta: float) -> void:
	pass

func _handle_zombie_overlapping_damage(_delta: float) -> void:
	pass

func refuel(amount: float) -> void:
	current_fuel = clampf(current_fuel + amount, 0.0, float(max_fuel))
	_empty_fuel_stall_timer = 0.0
	if _hud_fuel:
		_hud_fuel.value = current_fuel

func siphon_fuel(amount: float, show_notice: bool = false, custom_msg: String = "", col: Color = Color(0.96, 0.78, 0.30)) -> void:
	# Strictly block fuel recovery from kills/combos/barrels once tank hits empty (only physical canisters/stations rescue 0 fuel!)
	if destroyed or is_preview or amount <= 0.0 or current_fuel <= 0.0:
		return
	refuel(amount)
	if show_notice:
		_hud_notice_timer = 1.9
		_hud_notice_text = custom_msg if not custom_msg.is_empty() else ("+%.0f Л СИФОН ТОПЛИВА" % amount)
		_hud_notice_color = col

func refuel_from_canister(fuel_ratio: float = 1.0) -> void:
	if destroyed or is_preview:
		return
	var added: float = maxf(float(max_fuel) * clampf(fuel_ratio, 0.1, 1.0), 15.0)
	var before: float = current_fuel
	refuel(added)
	var gained: float = maxf(current_fuel - before, 0.0)
	_hud_notice_timer = 2.5
	_hud_notice_text = "ЗАПРАВКА: +%.0f Л ТОПЛИВА (БАК %.0f%%)" % [gained, (current_fuel / maxf(float(max_fuel), 1.0)) * 100.0]
	_hud_notice_color = Color(0.96, 0.78, 0.28)

func pitstop_refuel_and_repair(fuel_ratio: float = 1.0, _armor_ratio: float = 0.0) -> void:
	refuel_from_canister(fuel_ratio)

func repair_percent(ratio: float) -> void:
	if destroyed or is_preview or ratio <= 0.0:
		return
	var heal: int = maxi(roundi(float(health) * ratio), 1)
	current_hp = mini(current_hp + heal, health)
	if _hud_hp:
		_hud_hp.value = current_hp

func _apply_traction(speed: float) -> void:
	var downforce := clampf(speed * downforce_multiplier, 0.0, downforce_max)
	apply_central_force(Vector3.DOWN * downforce)

func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration * 0.1, true, false, true).timeout
	Engine.time_scale = 1.0

func take_damage(amount: int, cause: String = "МАШИНА УНИЧТОЖЕНА") -> void:
	if destroyed or is_preview or amount <= 0:
		return
	current_hp = maxi(current_hp - amount, 0)
	if _hud_hp:
		_hud_hp.value = current_hp
	if current_hp <= 0:
		_destroy_car(cause)

func _on_zombie_killed() -> void:
	_run_kills += 1
	var kill_bonus: int = ZOMBIE_KILL_REWARD + mini(floori(total_distance / 1500.0) * 5, 25)
	_run_money += kill_bonus

	# Боевые серии убийств каждые x10 дают небольшой долив (1/16 бака) и денежную премию; 0 л не спасает!
	if current_fuel <= 0.0:
		return
	_siphon_combo += 1
	_siphon_combo_timer = 2.4
	if _siphon_combo >= 10 and (_siphon_combo % 10) == 0:
		var combo_fuel: float = float(max_fuel) / 16.0
		var money_bonus: int = 100 if (_siphon_combo % 30) == 0 else (80 if (_siphon_combo % 20) == 0 else 40)
		_run_money += money_bonus
		var title := "КАТОК" if _siphon_combo >= 20 else "СЕРИЯ"
		var msg := "%s x%d (+%d $, +%.1f Л)" % [title, _siphon_combo, money_bonus, combo_fuel]
		var col := Color(1.0, 0.34, 0.20) if _siphon_combo >= 20 else Color(1.0, 0.62, 0.24)
		siphon_fuel(combo_fuel, true, msg, col)
	elif _siphon_combo >= 25 and (_siphon_combo % 25) == 0:
		_run_money += 100
		_hud_notice_timer = 1.9
		_hud_notice_text = "КАТОК x%d (+100 $)" % _siphon_combo
		_hud_notice_color = Color(1.0, 0.34, 0.20)

func commit_run_rewards() -> int:
	if _rewards_committed:
		return _last_run_earned
	_rewards_committed = true
	var distance_bonus := floori(total_distance / 10.0)
	_last_run_earned = _run_money + distance_bonus
	if _last_run_earned > 0:
		Game.add_money(_last_run_earned)
	return _last_run_earned

func _get_car_display_name() -> String:
	var my_path := scene_file_path
	if not my_path.is_empty():
		for entry: Dictionary in Game.car_data:
			if str(entry.get("path", "")).to_lower() == my_path.to_lower():
				return str(entry.get("name", engine_sound_id))
	if not Game.car_data.is_empty():
		var idx := clampi(Game.selected_car_index, 0, Game.car_data.size() - 1)
		return str(Game.car_data[idx].get("name", engine_sound_id))
	return engine_sound_id.capitalize()

func apply_body_deformation(world_hit_pos: Vector3, impact_vel: Vector3, severity: float = 1.0) -> float:
	if is_preview or not can_deform_body or engine_sound_id == "btr":
		return 0.0
	if _deformer == null:
		_deformer = CarDeformer.new()
	return _deformer.deform_at_world_point(self, world_hit_pos, impact_vel, hull_half_extents, severity)

func _get_impact_vel_3d() -> Vector3:
	var cur_sq: float = Vector2(linear_velocity.x, linear_velocity.z).length_squared()
	if cur_sq >= _pre_step_horiz_vel.length_squared():
		return linear_velocity
	return _pre_step_vel_3d

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if destroyed or is_preview or body == null or body == self or body.is_in_group("player"):
		return

	var eff_vel := _get_impact_vel_3d()
	var horizontal_vel := Vector2(eff_vel.x, eff_vel.z)
	var speed_mps := horizontal_vel.length()
	var speed_kmh := speed_mps * MPS_TO_KMH
	var sm: Node = get_node_or_null("/root/SoundManager")

	if body.is_in_group("dead_wall"):
		if speed_mps >= crash_death_speed_mps:
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_heavy", 0.0, randf_range(0.9, 1.08))
			take_damage(current_hp, "СМЕРТЕЛЬНОЕ СТОЛКНОВЕНИЕ")
			shake_camera(clampf(speed_mps / 10.0, 1.0, 4.0))
			CarVFX.spawn_impact(global_position, "dust")
			return

	if body.is_in_group("zombie"):
		var z_state_var = body.get("state")
		if z_state_var != null and (int(z_state_var) == 3 or int(z_state_var) == 4):
			return
		if speed_kmh < 3.0:
			return
		CarVFX.spawn_impact(body.global_position + Vector3.UP, "blood")
		var is_lethal: bool = speed_kmh >= 24.0
		if sm and sm.has_method("play_zombie_hit_thud"):
			sm.call("play_zombie_hit_thud", speed_kmh, is_lethal)
		elif sm and sm.has_method("play_sfx"):
			sm.call("play_sfx", "zombie_splat", -3.0, randf_range(0.85, 1.2))
		var z_mult_var = body.get("ram_damage_mult")
		var z_mult: float = float(z_mult_var) if z_mult_var != null else 1.0
		var z_dmg: int = maxi(roundi(float(zombie_damage_taken) * z_mult), 1)
		apply_body_deformation(body.global_position + Vector3.UP * 0.72, eff_vel, clampf((speed_mps / 22.0) * z_mult * 0.28, 0.18, 0.55))
		if is_lethal:
			take_damage(z_dmg, "МАШИНА РАЗБИТА ОБ ОРДУ")
			if body.has_method("die"):
				body.die(eff_vel, speed_mps)
			_on_zombie_killed()
			shake_camera(clampf(speed_mps / 50.0, 0.05, 0.3))
		else:
			take_damage(maxi(roundi(float(z_dmg) * 0.5), 1), "МАШИНА РАЗБИТА ОБ ОРДУ")
			if body.has_method("knockdown"):
				body.knockdown(eff_vel)
		return

	if body.is_in_group("knockable_prop"):
		_handle_knockable_hit(body, eff_vel)
		return

	if body is RigidBody3D:
		_handle_wreck_obstacle_hit(body as RigidBody3D, eff_vel)
		return

	if body.is_in_group("object_hit"):
		if speed_mps > wall_damage_min_speed_mps:
			var mass_mult: float = clampf(1900.0 / maxf(mass, 600.0), 0.28, 1.10)
			var damage_to_car := maxi(roundi(speed_mps * collision_damage_multiplier * mass_mult * 2.4), 2)
			take_damage(damage_to_car, "МАШИНА РАЗБИТА")
			shake_camera(clampf(float(damage_to_car) * 0.1, 0.2, 1.5))
			var impact_pt := body.global_position + Vector3.UP * 0.6
			apply_body_deformation(impact_pt, eff_vel, clampf(speed_mps / 14.0, 0.65, 1.85))
			CarVFX.spawn_crash_debris(impact_pt, -eff_vel, speed_mps, "metal", car_paint_color)
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_metal", -2.5, randf_range(0.85, 1.15))
			if body.has_method("take_damage"):
				body.take_damage(speed_mps * 2.0)
		return

	if body is CollisionObject3D and (body.collision_layer & 512) == 0 and (body.collision_layer & 4) != 0:
		if speed_mps > 3.0:
			var hit_pt := body.global_position + Vector3.UP * 0.4
			CarVFX.spawn_crash_debris(hit_pt, -eff_vel, speed_mps, "metal", car_paint_color)
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_metal", -5.0, randf_range(0.9, 1.15))
			if speed_mps > 5.0:
				apply_body_deformation(hit_pt, eff_vel, clampf(speed_mps / 15.0, 0.55, 1.55))
				var wall_now := Time.get_ticks_msec()
				if wall_now - _last_wall_dmg_ms >= 220:
					_last_wall_dmg_ms = wall_now
					var wall_dmg := maxi(roundi(speed_mps * collision_damage_multiplier * 1.15 * clampf(1900.0 / maxf(mass, 600.0), 0.18, 1.0)), 1)
					take_damage(wall_dmg, "МАШИНА РАЗБИТА")

func _on_chassis_body_entered(body: Node) -> void:
	if destroyed or is_preview or body == null or body == self or not (body is Node3D):
		return
	var eff_vel := _get_impact_vel_3d()
	if body.is_in_group("knockable_prop"):
		_handle_knockable_hit(body as Node3D, eff_vel)
	elif body is RigidBody3D and not body.is_in_group("zombie") and not body.is_in_group("dead_wall") and not body.is_in_group("player"):
		_handle_wreck_obstacle_hit(body as RigidBody3D, eff_vel)

func _on_prop_trigger_body_entered(body: Node3D) -> void:
	if destroyed or is_preview or body == null or body == self:
		return
	if body.is_in_group("knockable_prop"):
		_handle_knockable_hit(body, _get_impact_vel_3d())

func _handle_knockable_hit(body: Node3D, pre_vel: Vector3) -> void:
	var horiz_pre := Vector2(pre_vel.x, pre_vel.z)
	var speed_mps := horiz_pre.length()
	if speed_mps < 2.2:
		return
	var hit_res: Dictionary = {}
	if body.has_method("knock_down"):
		hit_res = body.call("knock_down", global_position, pre_vel, mass, self)
	if not hit_res.is_empty():
		var is_exploded: bool = bool(hit_res.get("exploded", false))
		var base_dmg: float = float(hit_res.get("damage", 4.0))
		var drag_k: float = float(hit_res.get("drag", 0.06))
		var prop_mass: float = maxf(float(hit_res.get("prop_mass", 180.0)), 30.0)
		var dmg_to_car: int = 0
		if not is_exploded:
			var mass_dmg_scale: float = clampf(1900.0 / maxf(mass, 600.0), 0.14, 1.15)
			var spd_scale: float = clampf(speed_mps / 18.0, 0.35, 1.45)
			var hp_scale: float = clampf(float(health) / 900.0, 0.75, 2.2)
			var armor_scale: float = clampf(collision_damage_multiplier / 0.45, 0.45, 1.4)
			dmg_to_car = maxi(roundi(base_dmg * prop_damage_multiplier * mass_dmg_scale * spd_scale * hp_scale * armor_scale), 2)
			take_damage(dmg_to_car, "СТОЛКНОВЕНИЕ С ПРЕПЯТСТВИЕМ")
			apply_body_deformation(body.global_position + Vector3.UP * 0.75, pre_vel, clampf((speed_mps / 15.0) * (prop_mass / 240.0), 0.42, 1.35))
		else:
			apply_body_deformation(body.global_position + Vector3.UP * 0.75, pre_vel, clampf((speed_mps / 18.0) * 0.85, 0.45, 1.25))

		var mass_drag: float = (prop_mass / maxf(mass + prop_mass, 1.0)) * 0.90 + drag_k * (1600.0 / maxf(mass, 600.0)) * 0.42
		var keep_mitigation: float = 1.10 - clampf(impact_momentum_keep, 0.4, 0.98) * 0.65
		var slowdown: float = clampf(mass_drag * keep_mitigation, 0.005, 0.30)
		var cur_horiz := Vector2(linear_velocity.x, linear_velocity.z)
		var base_dir_vel := horiz_pre if horiz_pre.length_squared() >= cur_horiz.length_squared() else cur_horiz
		var new_horiz := base_dir_vel * (1.0 - slowdown)
		linear_velocity.x = new_horiz.x
		linear_velocity.z = new_horiz.y
		shake_camera(clampf(float(maxi(dmg_to_car, 14 if is_exploded else 2)) * 0.045, 0.08, 0.75))

func _handle_wreck_obstacle_hit(wreck: RigidBody3D, pre_vel: Vector3) -> void:
	if not is_instance_valid(wreck) or wreck == self:
		return
	var horiz_pre := Vector2(pre_vel.x, pre_vel.z)
	var speed_mps := horiz_pre.length()
	if speed_mps < 2.4:
		return

	var eff_wreck_mass: float = clampf(wreck.mass, 180.0, 1400.0)
	var actual_wreck_mass: float = clampf(wreck.mass, 150.0, 5500.0)
	var mass_share: float = mass / maxf(mass + eff_wreck_mass, 1.0)
	var keep_frac: float = clampf(mass_share * (0.93 + impact_momentum_keep * 0.11), 0.35, 0.93)

	var now_ms := Time.get_ticks_msec()
	var prev_ms: int = int(wreck.get_meta("_car_ram_ms")) if wreck.has_meta("_car_ram_ms") else -10000
	var target_horiz := horiz_pre * keep_frac
	var cur_horiz := Vector2(linear_velocity.x, linear_velocity.z)
	if now_ms - prev_ms < 280:
		if cur_horiz.length() < target_horiz.length() * 0.94:
			linear_velocity.x = target_horiz.x
			linear_velocity.z = target_horiz.y
		return
	wreck.set_meta("_car_ram_ms", now_ms)

	if wreck.freeze:
		wreck.freeze = false
	wreck.sleeping = false
	var fwd_dir := Vector3(horiz_pre.x, 0.0, horiz_pre.y).normalized()
	var offset_xz := wreck.global_position - global_position
	offset_xz.y = 0.0
	var side_push := offset_xz - fwd_dir * offset_xz.dot(fwd_dir)
	var side_dir := side_push.normalized() if side_push.length_squared() > 0.002 else (Vector3.RIGHT * (1.0 if randf() > 0.5 else -1.0))
	var fwd_v: float = lerpf(0.52, 0.92, clampf((mass_share - 0.35) / 0.55, 0.0, 1.0))
	var lat_v: float = lerpf(0.28, 0.54, mass_share)
	var up_v: float = lerpf(0.10, 0.24, mass_share)
	var push_spd: float = clampf(speed_mps, 1.0, 38.0)
	var impulse_vec: Vector3 = (fwd_dir * fwd_v + side_dir * lat_v + Vector3.UP * up_v) * (actual_wreck_mass * push_spd)
	var est_vel := impulse_vec / maxf(actual_wreck_mass, 150.0)
	if est_vel.length() > 22.0:
		impulse_vec = est_vel.normalized() * (22.0 * actual_wreck_mass)
	wreck.apply_central_impulse(impulse_vec)
	var spin_axis := Vector3.UP.cross(fwd_dir).normalized() * randf_range(-0.9, 0.9) + Vector3.UP * randf_range(-1.2, 1.2)
	wreck.apply_torque_impulse(spin_axis * actual_wreck_mass * 1.9)

	var cur_speed: float = cur_horiz.length()
	var target_speed: float = target_horiz.length()
	if cur_speed > target_speed:
		var clamped_horiz := cur_horiz.normalized() * target_speed
		linear_velocity.x = clamped_horiz.x
		linear_velocity.z = clamped_horiz.y
	elif cur_speed < target_speed * 0.96:
		linear_velocity.x = target_horiz.x
		linear_velocity.z = target_horiz.y

	var rel_ratio: float = clampf(eff_wreck_mass / maxf(mass, 500.0), 0.05, 1.2)
	var hp_scale: float = clampf(float(health) / 900.0, 0.80, 2.4)
	var raw_dmg: float = speed_mps * 1.38 * wreck_damage_multiplier * rel_ratio * collision_damage_multiplier * hp_scale
	var dmg_to_car: int = maxi(roundi(raw_dmg), 3)
	if speed_mps > 3.2:
		take_damage(dmg_to_car, "СТОЛКНОВЕНИЕ С ОБЛОМКОМ")
	var wreck_hit_pt := wreck.global_position + Vector3.UP * 0.85
	apply_body_deformation(wreck_hit_pt, pre_vel, clampf((speed_mps / 13.0) * (eff_wreck_mass / 450.0), 0.72, 1.95))
	CarVFX.spawn_crash_debris(wreck_hit_pt, -pre_vel, speed_mps, "metal", car_paint_color)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "crash_wreck_hit" if speed_mps > 12.0 else "crash_metal", -1.5, randf_range(0.86, 1.06))
	shake_camera(clampf(float(dmg_to_car) * 0.04 + (1.0 - keep_frac) * 0.45, 0.14, 0.90))

func on_barrel_explosion_kills(kills: int) -> void:
	for _i in range(maxi(kills, 0)):
		_on_zombie_killed()
	if kills > 0:
		show_hud_notice("ПОДРЫВ БОЧКИ // ЛИКВИДИРОВАНО: %d" % kills, Color(1.0, 0.54, 0.22), 2.1)

func _enter_water(surface_y: float) -> void:
	if _in_water:
		return
	_in_water = true
	_water_surface_y = surface_y
	_water_sink_timer = 0.0
	_water_secondary_splash = false
	_water_splash_pos = Vector3(global_position.x, surface_y, global_position.z)
	engine_force = 0.0
	brake = 0.0
	gravity_scale = 0.0

	if is_instance_valid(_engine_audio):
		_engine_audio.stop()
	if is_instance_valid(_engine_idle_audio):
		_engine_idle_audio.stop()
	if is_instance_valid(_engine_howl_audio):
		_engine_howl_audio.stop()
	if is_instance_valid(_engine_boost_audio):
		_engine_boost_audio.stop()
	if is_instance_valid(_skid_audio):
		_skid_audio.stop()
	if is_instance_valid(_fire_audio):
		_fire_audio.stop()
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.emitting = false
	for ex in _exhausts:
		if is_instance_valid(ex):
			ex.emitting = false
	CarVFX.update_engine_damage_fx(_damage_smoke, _damage_fire_root, 1.0, false)
	for w in _wheels:
		if is_instance_valid(w):
			CarVFX.break_tire_skid(int(w.get_instance_id()))

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm:
		if sm.has_method("set_speed_wind"):
			sm.call("set_speed_wind", 0.0, false)
		if sm.has_method("play_sfx"):
			sm.call("play_sfx", "water_splash_heavy", 2.0, randf_range(0.78, 0.90))

	CarVFX.spawn_water_splash(_water_splash_pos + Vector3(0.0, 0.12, 0.0), maxf(linear_velocity.length(), 14.0))
	if not is_instance_valid(_water_bubbles):
		_water_bubbles = CarVFX.create_water_bubbles(self)

	linear_velocity = Vector3(linear_velocity.x * 0.42, clampf(linear_velocity.y * 0.26, -5.2, -1.2), linear_velocity.z * 0.42)
	angular_velocity *= 0.35
	shake_camera(0.45)

func _step_water_sinking(delta: float, post_death: bool = false) -> void:
	_water_sink_timer += delta
	var horiz_damp := exp(-2.3 * delta)
	linear_velocity.x *= horiz_damp
	linear_velocity.z *= horiz_damp
	var target_vy := -1.45 if post_death else -2.10
	linear_velocity.y = lerpf(linear_velocity.y, target_vy, clampf(delta * 2.4, 0.0, 1.0))

	angular_velocity *= exp(-2.6 * delta)
	var nose_down_pitch: float = clampf(0.42 - _water_sink_timer * 0.12, 0.05, 0.42)
	angular_velocity += global_transform.basis.x * (-nose_down_pitch * delta * 1.1)

	if not _water_secondary_splash and _water_sink_timer >= 0.65:
		_water_secondary_splash = true
		CarVFX.spawn_water_splash(Vector3(global_position.x, _water_surface_y + 0.08, global_position.z), 8.5)
		var sm2: Node = get_node_or_null("/root/SoundManager")
		if sm2 and sm2.has_method("play_sfx"):
			sm2.call("play_sfx", "water_splash_heavy", -9.0, 0.64)

	var hl_fade: float = clampf(1.0 - _water_sink_timer * 0.52, 0.0, 1.0)
	if not post_death and is_inside_tree():
		var car_fwd := -global_transform.basis.z
		var hl_l_local: Vector3 = headlight_positions[0] if headlight_positions.size() >= 1 else Vector3(-0.7, 0.75, -2.3)
		var hl_r_local: Vector3 = headlight_positions[1] if headlight_positions.size() >= 2 else hl_l_local
		var hl_l_world: Vector3 = global_transform * hl_l_local
		var hl_r_world: Vector3 = global_transform * hl_r_local
		var hl_dir_world: Vector3 = (car_fwd + Vector3(0.0, -0.055, 0.0)).normalized()
		ZombiePool.update_headlight_uniforms(hl_l_world, hl_r_world, hl_dir_world, 1.10 * hl_fade, Color(0.65, 0.88, 1.0, 1.0), 48.0)
		ProceduralMaterials.update_headlight_uniforms(hl_l_world, hl_r_world, hl_dir_world, 1.10 * hl_fade, Color(0.65, 0.88, 1.0, 1.0), 48.0)
		for hl in _head_lens_mats:
			if hl:
				hl.set_shader_parameter("intensity", 1.15 * hl_fade)
		for tl in _tail_lens_mats:
			if tl:
				tl.set_shader_parameter("intensity", 0.85 * hl_fade)

	if not post_death and _water_sink_timer >= 2.15:
		_drowned_in_water = true
		_destroy_car("МАШИНА УТОНУЛА")

func _destroy_car(death_reason: String = "МАШИНА УНИЧТОЖЕНА") -> void:
	if destroyed:
		return
	destroyed = true
	engine_force = 0.0
	brake = brake_force * 3.0

	if is_instance_valid(_engine_audio):
		_engine_audio.stop()
	if is_instance_valid(_engine_idle_audio):
		_engine_idle_audio.stop()
	if is_instance_valid(_engine_howl_audio):
		_engine_howl_audio.stop()
	if is_instance_valid(_engine_boost_audio):
		_engine_boost_audio.stop()
	if is_instance_valid(_skid_audio):
		_skid_audio.stop()

	var is_fuel_stall: bool = (death_reason == "ЗАКОНЧИЛОСЬ ТОПЛИВО")
	var is_water_drown: bool = (death_reason == "МАШИНА УТОНУЛА")
	var is_explosive: bool = (not is_fuel_stall) and (not is_water_drown)
	if is_water_drown:
		_drowned_in_water = true
		gravity_scale = 0.0

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		if is_explosive:
			sm.call("play_sfx", "crash_heavy", 0.5, 0.88)
			sm.call("play_sfx", "btr_explosion_1", 1.0, randf_range(0.88, 1.02))
		sm.call("set_speed_wind", 0.0, false)

	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.emitting = false
	for ex in _exhausts:
		if is_instance_valid(ex):
			ex.emitting = false

	if is_instance_valid(_fire_audio):
		_fire_audio.stop()
	if is_explosive:
		_engine_fire_level = CarVFX.update_engine_damage_fx(_damage_smoke, _damage_fire_root, 0.0, true)
		CarVFX.spawn_car_destruction_explosion(global_position + Vector3(0.0, 0.65, 0.0), linear_velocity, car_paint_color)
	else:
		CarVFX.update_engine_damage_fx(_damage_smoke, _damage_fire_root, 1.0, false)

	if _hud_pause:
		_hud_pause.visible = false
		_hud_pause.process_mode = Node.PROCESS_MODE_DISABLED

	for touch_node: String in ["Hud/VirtualJoystick", "Hud/Brake", "Hud/Gas"]:
		var ci := get_node_or_null(touch_node) as CanvasItem
		if ci:
			ci.visible = false

	for pnl: Control in _hud_panels:
		if is_instance_valid(pnl):
			var hud_tw := create_tween().set_ignore_time_scale(true)
			hud_tw.tween_property(pnl, "modulate:a", 0.0, 0.45)

	_apply_preview_light_state()
	ZombiePool.update_headlight_uniforms(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, 0.0)
	ProceduralMaterials.update_headlight_uniforms(Vector3.ZERO, Vector3.ZERO, Vector3.FORWARD, 0.0)
	for hl in _head_lens_mats:
		if hl:
			hl.set_shader_parameter("intensity", 0.0)
	for tl in _tail_lens_mats:
		if tl:
			tl.set_shader_parameter("intensity", 0.0)

	var earned: int = commit_run_rewards()

	if is_explosive:
		if DeadParticles and get_tree().current_scene:
			var dead_fx := DeadParticles.instantiate() as CPUParticles3D
			get_tree().current_scene.add_child(dead_fx)
			dead_fx.global_position = global_position
			dead_fx.lifetime = 1.6
			dead_fx.anim_speed_min = 1.8
			dead_fx.anim_speed_max = 2.4
			dead_fx.emitting = true
			dead_fx.restart()

		apply_central_impulse(Vector3(0.0, mass * 3.8, 0.0))
		apply_torque_impulse(Vector3(randf_range(-0.85, 0.85), randf_range(-0.45, 0.45), randf_range(-1.15, 1.15)) * mass)
		shake_camera(2.8)

	if _hud_death_rect:
		_hud_death_rect.show()
		var mat := _hud_death_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("effect_strength", 0.0)
			var tween_blood := create_tween().set_ignore_time_scale(true)
			var target_vig := 0.32 if is_water_drown else 0.85
			tween_blood.tween_property(mat, "shader_parameter/effect_strength", target_vig, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var tween_time := create_tween().set_ignore_time_scale(true)
	var target_ts := 0.55 if is_water_drown else 0.14
	tween_time.tween_property(Engine, "time_scale", target_ts, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.22, true, false, true).timeout
	if not is_inside_tree():
		return
	if sm:
		if sm.has_method("play_sfx"):
			sm.call("play_sfx", "death_sting", -1.5, 0.78)
		if sm.has_method("set_death_ambience"):
			sm.call("set_death_ambience", true)

	await get_tree().create_timer(1.15, true, false, true).timeout
	if not is_inside_tree():
		return

	var host: Node = get_tree().current_scene if get_tree().current_scene != null else self
	if DEATH_SCREEN_SCENE:
		var death_ui := DEATH_SCREEN_SCENE.instantiate()
		death_ui.name = "DeathScreen"
		host.add_child(death_ui)
		if death_ui.has_method("show_death_summary"):
			death_ui.call("show_death_summary", {
				"reason": death_reason,
				"distance_m": roundi(total_distance),
				"kills": _run_kills,
				"earned": earned,
				"balance": Game.money,
				"car_name": _get_car_display_name(),
			})

func shake_camera(amount: float) -> void:
	if is_instance_valid(_camera) and _camera.has_method("add_shake"):
		_camera.add_shake(amount)

func set_initial_rolling_start(speed_mps: float, fwd_dir: Vector3) -> void:
	var dir := fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.FORWARD
	linear_velocity = dir * speed_mps
	_prev_forward_mps = speed_mps
	_pre_step_vel_3d = linear_velocity
	_pre_step_horiz_vel = Vector2(linear_velocity.x, linear_velocity.z)
	_current_gear = 1
	_display_gear = "G1"
	_sim_rpm = 0.44
	_smooth_throttle = 0.85
	for w in _wheels:
		if is_instance_valid(w):
			w.forward_speed_mps = speed_mps
	_update_hud_telemetry()

func enter_tornado_capture(vortex_pos: Vector3, fwd_dir: Vector3) -> void:
	if destroyed or is_preview or _in_water or _tornado_timer > 0.0 or _tornado_cooldown > 0.0:
		return
	_tornado_timer = 1.15
	_tornado_center = vortex_pos
	_tornado_fwd = fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.BACK
	_tornado_fwd.y = 0.0
	if _tornado_fwd.length_squared() > 0.001:
		_tornado_fwd = _tornado_fwd.normalized()
	else:
		_tornado_fwd = Vector3.BACK
	_tornado_spin_dir = -1.0 if (randi() % 2) == 0 else 1.0
	_tornado_saved_gravity = gravity_scale
	_tornado_start_y = maxf(global_position.y, 0.5)
	gravity_scale = 0.0
	engine_force = 0.0
	brake = 0.0
	show_hud_notice("СМЕРЧ // ВИХРЕВОЙ ЗАХВАТ!", Color(0.84, 0.90, 1.0), 2.2)
	shake_camera(1.35)
	CarVFX.spawn_impact(global_position + Vector3.UP * 0.5, "dust")

func _step_tornado_capture(delta: float) -> void:
	_tornado_timer = maxf(_tornado_timer - delta, 0.0)
	_process_vehicle_extras(delta)
	total_distance = absf(global_position.z - start_z_position)
	_hud_notice_timer = maxf(_hud_notice_timer - delta, 0.0)
	var t_prog: float = clampf(1.0 - _tornado_timer / 1.15, 0.0, 1.0)
	var swirl_ang: float = t_prog * TAU * 1.45 * _tornado_spin_dir
	var orbit_r: float = lerpf(4.5, 2.2, t_prog)
	var target_y: float = _tornado_start_y + lerpf(0.0, 11.2, sin(t_prog * PI * 0.65))
	var target_pos := Vector3(
		_tornado_center.x + cos(swirl_ang) * orbit_r,
		target_y,
		_tornado_center.z + sin(swirl_ang) * orbit_r + t_prog * 14.0 * _tornado_fwd.z
	)
	var to_t: Vector3 = target_pos - global_position
	linear_velocity = to_t / maxf(delta, 0.016)
	linear_velocity = linear_velocity.limit_length(42.0)
	angular_velocity = Vector3(
		sin(t_prog * 9.0) * 1.8,
		_tornado_spin_dir * 6.4,
		cos(t_prog * 7.5) * 2.1
	)
	_update_visual_lights(delta, false, false)
	_update_vehicle_audio(delta, 0.65, 6.0, false, false, false, 18.0)
	_update_hud_telemetry()

	if _tornado_timer <= 0.0:
		_tornado_cooldown = 5.5
		_tornado_air_stabilize = 1.85
		gravity_scale = _tornado_saved_gravity
		# Выбрасываем машину СТРОГО ВПЕРЁД по трассе (с живым неровным креном, но безопасно на дорогу!)
		var right_vec := Vector3(_tornado_fwd.z, 0.0, -_tornado_fwd.x).normalized()
		var road_cx := 0.0
		var scene := get_tree().current_scene
		if scene and scene.has_method("_get_biome_for_index"):
			road_cx = global_position.x * 0.45
		var lat_nudge: float = clampf((road_cx - global_position.x) * 0.16 + randf_range(-2.6, 2.6), -4.2, 4.2)
		var eject_horiz_spd: float = clampf(randf_range(26.5, 34.0), 26.5, 36.0)
		linear_velocity = _tornado_fwd * eject_horiz_spd + right_vec * lat_nudge + Vector3(0.0, 6.2, 0.0)
		angular_velocity = Vector3(randf_range(-0.6, 0.9), _tornado_spin_dir * randf_range(1.2, 2.4), randf_range(-1.6, 1.6))
		_pre_step_vel_3d = linear_velocity
		_pre_step_horiz_vel = Vector2(linear_velocity.x, linear_velocity.z)
		shake_camera(0.95)
		CarVFX.spawn_impact(global_position, "dust")
		show_hud_notice("ВЫБРОС ИЗ СМЕРЧА!", Color(1.0, 0.78, 0.34), 1.8)
