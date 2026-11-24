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
## Тип привода: "RWD" = задний привод, "AWD" = полный привод 4x4, "FWD" = передний привод
@export_enum("RWD", "AWD", "FWD") var drive_type: String = "RWD"
## Доля крутящего момента на переднюю ось для полного привода AWD (например 0.42 = 42% перед / 58% зад)
@export var awd_front_torque_split: float = 0.42
## Интенсивность пробуксовки ведущих колёс на старте при газе в пол в стоке (0.4..1.4)
@export var launch_wheelspin_intensity: float = 1.0
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
## Масштаб размеров конкретной модели машины (выравнивание габаритов между авто)
@export var vehicle_body_scale: float = 1.0
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
var _tire_smoke_wheels: Array[RaycastWheel] = []
var _fitted_lower_pts: PackedVector3Array = PackedVector3Array()
var _fitted_upper_pts: PackedVector3Array = PackedVector3Array()
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
var _ice_slide_audio: AudioStreamPlayer = null
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
var _smooth_ice_slide_vol: float = 0.0
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
var _smooth_long_accel: float = 0.0
var _smooth_pitch_shift: float = 1.0
var _smooth_steer_shift: float = 0.0
var _smooth_brake_glow: float = 0.0
var _smooth_ground_normal: Vector3 = Vector3.UP
var _smooth_ground_y: float = 0.0
var _airborne_timer: float = 0.0
var _peak_downward_vy: float = 0.0
var _prev_grounded_wheels: int = 0
var _landing_cooldown: float = 0.0
var _susp_bump_cooldown: float = 0.0
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
var _sc_pulley: Node3D = null
var _sc_butterflies: Node3D = null
var _sc_idle_phase: float = 0.0
var _intro_timer: float = 0.0
var _intro_duration: float = 2.35
var _intro_cruise_mps: float = 10.6
var _intro_fwd: Vector3 = Vector3.BACK
var _intro_hud_hidden: bool = false
var _body_scale_applied: bool = false
var _visuals_prescaled: bool = false

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
	refresh_armor_kit_refs()

func refresh_armor_kit_refs() -> void:
	_sc_pulley = find_child("SuperchargerPulley", true, false) as Node3D
	_sc_butterflies = find_child("SuperchargerButterflies", true, false) as Node3D

func _scale_collision_shape_node(cs: CollisionShape3D, vs: float) -> void:
	if cs == null:
		return
	cs.position *= vs
	if cs.shape == null:
		return
	var dup_s := cs.shape.duplicate() as Shape3D
	if dup_s is BoxShape3D:
		(dup_s as BoxShape3D).size *= vs
	elif dup_s is CapsuleShape3D:
		var cap := dup_s as CapsuleShape3D
		cap.radius *= vs
		cap.height *= vs
	elif dup_s is CylinderShape3D:
		var cyl := dup_s as CylinderShape3D
		cyl.radius *= vs
		cyl.height *= vs
	elif dup_s is SphereShape3D:
		(dup_s as SphereShape3D).radius *= vs
	elif dup_s is ConvexPolygonShape3D:
		var cvx := dup_s as ConvexPolygonShape3D
		var pts := cvx.points
		var scaled_pts := PackedVector3Array()
		scaled_pts.resize(pts.size())
		for pi in range(pts.size()):
			scaled_pts[pi] = pts[pi] * vs
		cvx.points = scaled_pts
	cs.shape = dup_s

func _apply_vehicle_body_scale() -> void:
	if _body_scale_applied or is_equal_approx(vehicle_body_scale, 1.0):
		return
	_body_scale_applied = true
	var vs: float = clampf(vehicle_body_scale, 0.5, 2.0)

	hull_half_extents *= vs
	wheelbase_m *= vs
	com_height *= vs
	com_z_offset *= vs
	headlight_proj_z_start *= vs
	taillight_proj_z_start *= vs
	shadow_blob_size *= vs
	shadow_offset *= vs
	headlight_lens_size *= vs
	taillight_lens_size *= vs
	engine_hood_offset *= vs
	exhaust_offset *= vs

	var scaled_hl: Array[Vector3] = []
	for hp in headlight_positions:
		scaled_hl.append(hp * vs)
	headlight_positions = scaled_hl

	var scaled_tl: Array[Vector3] = []
	for tp in taillight_positions:
		scaled_tl.append(tp * vs)
	taillight_positions = scaled_tl

	var scaled_ex: Array[Vector3] = []
	for ep in exhaust_offsets:
		scaled_ex.append(ep * vs)
	exhaust_offsets = scaled_ex

	for child in get_children():
		if child is RaycastWheel:
			var w := child as RaycastWheel
			if w.base_rest_length > 0.0:
				w.base_rest_length *= vs
			w.rest_length *= vs
			w.over_extend *= vs
			if not _visuals_prescaled:
				w.position *= vs
				w.wheel_radius *= vs
				for wc in w.get_children():
					if wc is Node3D:
						(wc as Node3D).position *= vs
						(wc as Node3D).scale *= vs
			w.configure_ray()
		elif child is CollisionShape3D:
			_scale_collision_shape_node(child as CollisionShape3D, vs)
		elif child is Area3D:
			var ar := child as Area3D
			ar.position *= vs
			for ach in ar.get_children():
				if ach is CollisionShape3D:
					_scale_collision_shape_node(ach as CollisionShape3D, vs)
		elif not _visuals_prescaled and child is Node3D:
			var n3 := child as Node3D
			if n3.name == "look" or n3.name.contains("Camera") or n3.name == "VisualLightsRig" or n3.name == "FullUpgradeArmorKit" or n3.name == "PropTriggerArea" or n3 is CPUParticles3D:
				continue
			n3.position *= vs
			n3.scale *= vs

func _ready() -> void:
	_apply_vehicle_body_scale()
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
	_rebuild_accurate_vehicle_collision()
	_hud_hp = get_node_or_null("Hud/HpBar") as ProgressBar
	_hud_fuel = get_node_or_null("Hud/FuelBar") as ProgressBar
	_hud_speed = get_node_or_null("Hud/speed") as Label
	_hud_metr = get_node_or_null("Hud/Metr") as Label
	_hud_death_rect = get_node_or_null("Hud/ColorRect") as ColorRect
	_hud_pause = get_node_or_null("Hud/Pause")
	_camera = get_node_or_null("look/Camera3D")
	if is_instance_valid(_camera) and _camera.has_method("recalibrate_to_vehicle"):
		_camera.call("recalibrate_to_vehicle", true)

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
		_attach_tire_smokes()
		_damage_smoke = CarVFX.create_engine_damage_smoke(self, engine_hood_offset)
		_damage_fire_root = CarVFX.create_engine_damage_fire(self, engine_hood_offset)
		_setup_vehicle_audio()
		_setup_prop_trigger_area()


func _attach_tire_smokes() -> void:
	if not _tire_smokes.is_empty():
		return
	var candidates: Array[RaycastWheel] = []
	for w: RaycastWheel in _wheels:
		if not is_instance_valid(w):
			continue
		if drive_type == "FWD":
			if w.is_front and w.use_as_traction:
				candidates.append(w)
		elif drive_type == "RWD":
			if not w.is_front and w.use_as_traction:
				candidates.append(w)
		else:
			if w.use_as_traction:
				candidates.append(w)
	if candidates.is_empty():
		for w: RaycastWheel in _wheels:
			if is_instance_valid(w) and not w.is_front:
				candidates.append(w)
	var chosen: Array[RaycastWheel] = []
	if candidates.size() <= 4:
		chosen = candidates
	else:
		var sorted_by_z: Array[RaycastWheel] = candidates.duplicate()
		sorted_by_z.sort_custom(func(a: RaycastWheel, b: RaycastWheel) -> bool: return a.position.z < b.position.z)
		chosen.append(sorted_by_z[0])
		chosen.append(sorted_by_z[1])
		chosen.append(sorted_by_z[sorted_by_z.size() - 2])
		chosen.append(sorted_by_z[sorted_by_z.size() - 1])
	for w: RaycastWheel in chosen:
		var smoke := CarVFX.create_tire_smoke(w, Vector3(0.0, -w.wheel_radius + 0.10, 0.0))
		_tire_smokes.append(smoke)
		_tire_smoke_wheels.append(w)

func _node_local_to_car(node: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != self:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _percentile_sorted(sorted_vals: PackedFloat32Array, q: float) -> float:
	if sorted_vals.is_empty():
		return 0.0
	var idx: int = clampi(roundi(q * float(sorted_vals.size() - 1)), 0, sorted_vals.size() - 1)
	return sorted_vals[idx]

func _is_excluded_collision_node(node: Node) -> bool:
	if node == null or node == self:
		return false
	if node is RaycastWheel or node is Area3D or node is CPUParticles3D or node is Camera3D or node is Light3D or node is CollisionShape3D:
		return true
	if node is Node3D and not (node as Node3D).visible:
		return true
	var cname := String(node.name)
	if cname == "look" or cname == "VisualLightsRig" or cname == "LightsRig" or cname == "FullUpgradeArmorKit" or cname == "EngineDamageFire" or cname == "MuzzleFlashRig" or cname == "MuzzleVFX" or cname == "Turret_Gun" or cname == "ShadowBlob" or cname == "HeadlightProj" or cname == "TaillightProj" or cname.begins_with("KitStage_"):
		return true
	var lc := cname.to_lower()
	for kw: String in ["wheel", "tire", "rim", "mirror", "antenna", "aerial", "turret", "gun", "muzzle", "exhaust", "spoiler", "rear_wing", "gt_wing", "lightbar", "barbed", "spike"]:
		if lc.contains(kw):
			return true
	return false

func _collect_body_mesh_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var stack: Array[Node] = []
	for ch in get_children():
		stack.append(ch)
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if _is_excluded_collision_node(cur):
			continue
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh != null:
				var xf := _node_local_to_car(mi)
				for s in range(mi.mesh.get_surface_count()):
					var arr: Array = mi.mesh.surface_get_arrays(s)
					if arr.size() <= Mesh.ARRAY_VERTEX or not (arr[Mesh.ARRAY_VERTEX] is PackedVector3Array):
						continue
					var verts := arr[Mesh.ARRAY_VERTEX] as PackedVector3Array
					if verts.is_empty():
						continue
					var stride: int = maxi(1, floori(float(verts.size()) / 4000.0))
					var vi: int = 0
					while vi < verts.size():
						pts.append(xf * verts[vi])
						vi += stride
		for gch in cur.get_children():
			stack.append(gch)
	return pts

func _build_sliced_convex_points(
	pts: PackedVector3Array,
	z_lo: float,
	z_hi: float,
	y_lo: float,
	y_hi: float,
	inset_x: float,
	inset_z: float,
	slice_count: int = 16,
	min_peak_y: float = -INF,
	keep_main_cluster: bool = false
) -> PackedVector3Array:
	var z_span: float = maxf(z_hi - z_lo, 0.4)
	var zone_x: Array = []
	var zone_y: Array = []
	var bin_zmin := PackedFloat32Array()
	var bin_zmax := PackedFloat32Array()
	bin_zmin.resize(slice_count)
	bin_zmax.resize(slice_count)
	for bi in range(slice_count):
		zone_x.append([])
		zone_y.append([])
		bin_zmin[bi] = INF
		bin_zmax[bi] = -INF

	var total_zone_pts: int = 0
	for i in range(pts.size()):
		var p: Vector3 = pts[i]
		if p.y < y_lo or p.y > y_hi or p.z < z_lo - 0.1 or p.z > z_hi + 0.1:
			continue
		var bi: int = clampi(floori(((p.z - z_lo) / z_span) * float(slice_count)), 0, slice_count - 1)
		(zone_x[bi] as Array).append(p.x)
		(zone_y[bi] as Array).append(p.y)
		if p.z < bin_zmin[bi]:
			bin_zmin[bi] = p.z
		if p.z > bin_zmax[bi]:
			bin_zmax[bi] = p.z
		total_zone_pts += 1

	if total_zone_pts < 12:
		return PackedVector3Array()

	var min_bin_pts: int = maxi(3, floori(float(total_zone_pts) / 160.0))
	var valid_bins := PackedByteArray()
	valid_bins.resize(slice_count)
	for bi in range(slice_count):
		var ax_chk := zone_x[bi] as Array
		if ax_chk.size() < min_bin_pts:
			valid_bins[bi] = 0
			continue
		if min_peak_y > -9000.0:
			var by_chk := PackedFloat32Array(zone_y[bi] as Array)
			by_chk.sort()
			if _percentile_sorted(by_chk, 0.96) < min_peak_y:
				valid_bins[bi] = 0
				continue
		valid_bins[bi] = 1

	var first_pop: int = -1
	var last_pop: int = -1
	if keep_main_cluster:
		var best_score: int = -1
		var cur_start: int = -1
		var cur_score: int = 0
		for bi in range(slice_count + 1):
			var ok_b: bool = (bi < slice_count and valid_bins[bi] == 1)
			if ok_b:
				if cur_start < 0:
					cur_start = bi
					cur_score = 0
				cur_score += (zone_x[bi] as Array).size()
			elif cur_start >= 0:
				if cur_score > best_score:
					best_score = cur_score
					first_pop = cur_start
					last_pop = bi - 1
				cur_start = -1
				cur_score = 0
	else:
		for bi in range(slice_count):
			if valid_bins[bi] == 1:
				if first_pop < 0:
					first_pop = bi
				last_pop = bi

	if first_pop < 0 or last_pop <= first_pop or (bin_zmax[last_pop] - bin_zmin[first_pop]) < 0.35:
		return PackedVector3Array()

	var out := PackedVector3Array()
	for bi in range(first_pop, last_pop + 1):
		if valid_bins[bi] == 0:
			continue
		var ax := zone_x[bi] as Array
		var bx := PackedFloat32Array(ax)
		var by := PackedFloat32Array(zone_y[bi] as Array)
		bx.sort()
		by.sort()
		var sx_min: float = _percentile_sorted(bx, 0.03) + inset_x
		var sx_max: float = _percentile_sorted(bx, 0.97) - inset_x
		if sx_max - sx_min < 0.30:
			var cx: float = (sx_min + sx_max) * 0.5
			sx_min = cx - 0.15
			sx_max = cx + 0.15
		var sy_min: float = _percentile_sorted(by, 0.02)
		var sy_max: float = _percentile_sorted(by, 0.992)
		if sy_max - sy_min < 0.14:
			sy_max = sy_min + 0.14

		var sz: float = lerpf(z_lo, z_hi, (float(bi) + 0.5) / float(slice_count))
		if bi == first_pop:
			sz = clampf(bin_zmin[bi] + inset_z, z_lo + inset_z, sz)
		elif bi == last_pop:
			sz = clampf(bin_zmax[bi] - inset_z, sz, z_hi - inset_z)

		out.append(Vector3(sx_min, sy_min, sz))
		out.append(Vector3(sx_max, sy_min, sz))
		out.append(Vector3(sx_min * 0.94, sy_max, sz))
		out.append(Vector3(sx_max * 0.94, sy_max, sz))
	return out

func _expand_convex_points(src: PackedVector3Array, pad_x: float, pad_y: float, pad_z: float) -> PackedVector3Array:
	if src.is_empty():
		return PackedVector3Array()
	var center := Vector3.ZERO
	for i in range(src.size()):
		center += src[i]
	center /= float(src.size())
	var out := PackedVector3Array()
	out.resize(src.size())
	for i in range(src.size()):
		var p: Vector3 = src[i]
		var sx: float = 1.0 if p.x >= center.x else -1.0
		var sy: float = 1.0 if p.y >= center.y else -1.0
		var sz: float = 1.0 if p.z >= center.z else -1.0
		out[i] = p + Vector3(sx * pad_x, sy * pad_y, sz * pad_z)
	return out

func _rebuild_accurate_vehicle_collision() -> void:
	var body_pts := _collect_body_mesh_points()
	if body_pts.size() < 24:
		return
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	xs.resize(body_pts.size())
	ys.resize(body_pts.size())
	zs.resize(body_pts.size())
	for i in range(body_pts.size()):
		var p: Vector3 = body_pts[i]
		xs[i] = p.x
		ys[i] = p.y
		zs[i] = p.z
	xs.sort()
	ys.sort()
	zs.sort()

	var q_min_x: float = _percentile_sorted(xs, 0.015)
	var q_max_x: float = _percentile_sorted(xs, 0.985)
	var q_min_y: float = _percentile_sorted(ys, 0.010)
	var q_max_y: float = _percentile_sorted(ys, 0.990)
	var q_min_z: float = _percentile_sorted(zs, 0.015)
	var q_max_z: float = _percentile_sorted(zs, 0.985)

	var has_w: bool = false
	var min_w_y: float = 0.40
	for w in _wheels:
		if is_instance_valid(w):
			min_w_y = minf(min_w_y, w.position.y) if has_w else w.position.y
			has_w = true
	var min_hull_y: float = maxf(q_min_y + 0.04, clampf(min_w_y - 0.06, 0.30, 0.54))
	var split_y: float = lerpf(min_hull_y, q_max_y, 0.56)

	var lower_pts := _build_sliced_convex_points(body_pts, q_min_z, q_max_z, min_hull_y, split_y + 0.03, 0.04, 0.03, 18)
	if lower_pts.size() < 8:
		return

	var upper_pts := PackedVector3Array()
	if (q_max_y - 0.02) - (split_y - 0.04) >= 0.24:
		var cab_min_peak: float = lerpf(split_y, q_max_y, 0.28)
		upper_pts = _build_sliced_convex_points(body_pts, q_min_z, q_max_z, split_y - 0.04, q_max_y, 0.05, 0.04, 18, cab_min_peak, true)
	var has_upper: bool = upper_pts.size() >= 8

	_fitted_lower_pts = lower_pts
	_fitted_upper_pts = upper_pts if has_upper else PackedVector3Array()

	for ch in get_children():
		if ch is CollisionShape3D:
			remove_child(ch)
			ch.queue_free()

	var hull_lo := CollisionShape3D.new()
	hull_lo.name = "FittedHullLower"
	var shape_lo := ConvexPolygonShape3D.new()
	shape_lo.points = lower_pts
	hull_lo.shape = shape_lo
	add_child(hull_lo)

	if has_upper:
		var hull_up := CollisionShape3D.new()
		hull_up.name = "FittedHullUpper"
		var shape_up := ConvexPolygonShape3D.new()
		shape_up.points = upper_pts
		hull_up.shape = shape_up
		add_child(hull_up)

	hull_half_extents = Vector2(
		clampf((q_max_x - q_min_x) * 0.5 - 0.03, 0.72, 1.65),
		clampf((q_max_z - q_min_z) * 0.5 - 0.02, 1.75, 4.20)
	)

	var kill_zone := get_node_or_null("Area3D") as Area3D
	if is_instance_valid(kill_zone):
		kill_zone.position = Vector3.ZERO
		kill_zone.rotation = Vector3.ZERO
		kill_zone.scale = Vector3.ONE
		for ach in kill_zone.get_children():
			if ach is CollisionShape3D:
				kill_zone.remove_child(ach)
				ach.queue_free()
		var k_lo := CollisionShape3D.new()
		k_lo.name = "FittedKillLower"
		var ks_lo := ConvexPolygonShape3D.new()
		ks_lo.points = _expand_convex_points(lower_pts, 0.055, 0.03, 0.065)
		k_lo.shape = ks_lo
		kill_zone.add_child(k_lo)
		if has_upper:
			var k_up := CollisionShape3D.new()
			k_up.name = "FittedKillUpper"
			var ks_up := ConvexPolygonShape3D.new()
			ks_up.points = _expand_convex_points(upper_pts, 0.055, 0.03, 0.065)
			k_up.shape = ks_up
			kill_zone.add_child(k_up)

func _setup_prop_trigger_area() -> void:
	if is_instance_valid(_prop_trigger_area):
		return
	var area := Area3D.new()
	area.name = "PropTriggerArea"
	area.collision_layer = 0
	area.collision_mask = 8
	area.monitoring = true
	area.monitorable = false
	if _fitted_lower_pts.size() >= 8:
		var p_lo := CollisionShape3D.new()
		p_lo.name = "FittedPropLower"
		var ps_lo := ConvexPolygonShape3D.new()
		ps_lo.points = _expand_convex_points(_fitted_lower_pts, 0.075, 0.06, 0.08)
		p_lo.shape = ps_lo
		area.add_child(p_lo)
		if _fitted_upper_pts.size() >= 8:
			var p_up := CollisionShape3D.new()
			p_up.name = "FittedPropUpper"
			var ps_up := ConvexPolygonShape3D.new()
			ps_up.points = _expand_convex_points(_fitted_upper_pts, 0.075, 0.05, 0.08)
			p_up.shape = ps_up
			area.add_child(p_up)
	else:
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
		_ice_slide_audio = handles.get("ice_slide") as AudioStreamPlayer
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
		if is_instance_valid(_ice_slide_audio) and _ice_slide_audio.stream:
			_ice_slide_audio.play()
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
			if drive_type == "RWD":
				w.use_as_traction = not w.is_front
			elif drive_type == "FWD":
				w.use_as_traction = w.is_front
			else:
				w.use_as_traction = true
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
			w.prev_compression_m = w.rest_length * 0.45
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
		if is_instance_valid(_ice_slide_audio):
			_ice_slide_audio.stop()
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
	_attach_tire_smokes()
	for ts in _tire_smokes:
		if is_instance_valid(ts):
			ts.visible = true
			ts.emitting = true
			ts.speed_scale = 1.65
			ts.scale_amount_min = 1.25
			ts.scale_amount_max = 2.85
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
	if is_instance_valid(_ice_slide_audio):
		_ice_slide_audio.stop()
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

	var intro_autopilot := false
	if _intro_timer > 0.0:
		_intro_timer = maxf(_intro_timer - delta, 0.0)
		intro_autopilot = (_intro_timer > 0.45)
		if _intro_timer <= 0.55:
			_set_gameplay_hud_alpha(clampf(1.0 - (_intro_timer / 0.55), 0.0, 1.0))
		if _intro_timer <= 0.001:
			_intro_timer = 0.0
			_intro_hud_hidden = false
			_set_gameplay_hud_alpha(1.0)
	elif _intro_hud_hidden:
		_intro_hud_hidden = false
		_set_gameplay_hud_alpha(1.0)

	if intro_autopilot:
		wants_throttle = (forward_mps < _intro_cruise_mps * 1.08)
		engine_force = float(engine_force_value) * 0.72 if wants_throttle else 0.0
		brake = 0.0
	elif current_fuel <= 0.0:
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
		if forward_mps > 2.6:
			is_braking = true
			brake = brake_force
			engine_force = 0.0
		else:
			wants_reverse = true
			brake = 0.0
			var reverse_kmh := absf(minf(forward_mps, 0.0)) * MPS_TO_KMH
			engine_force = -float(engine_force_value) * 1.35 if reverse_kmh < 72.0 else 0.0
	else:
		engine_force = 0.0
		brake = 0.0

	var target_throt: float = 1.0 if (wants_throttle and current_fuel > 0.0) else (-1.0 if (wants_reverse and current_fuel > 0.0) else 0.0)
	var reversing_to_fwd: bool = (wants_throttle and not is_braking and current_fuel > 0.0 and forward_mps < -0.35)
	var fwd_to_reverse: bool = (wants_reverse and not is_braking and current_fuel > 0.0 and forward_mps > 0.25)
	if reversing_to_fwd and _smooth_throttle < 0.35:
		_smooth_throttle = maxf(_smooth_throttle, 0.35)
	elif fwd_to_reverse and _smooth_throttle > -0.45:
		_smooth_throttle = minf(_smooth_throttle, -0.45)
	var throt_rate: float = maxf(throttle_response * 4.5, 12.0) if (reversing_to_fwd or fwd_to_reverse) else ((throttle_response * 2.2 if wants_reverse else throttle_response) if absf(target_throt) > absf(_smooth_throttle) else throttle_release_rate)
	_smooth_throttle = move_toward(_smooth_throttle, target_throt, throt_rate * delta)

	# Пробуксовка ведущих колёс при старте с места, на развороте из заднего хода и при мощном заднем ходе
	var spin_target: float = 0.0
	var max_spin_kmh: float = 28.0 if drive_type == "AWD" else 42.0
	var chs_grip_hook: float = clampf(1.0 - float(_chassis_upgrade_lvl) * 0.025, 0.72, 1.0)
	var drive_spin_mult: float = 0.65 if drive_type == "AWD" else 1.0
	if wants_throttle and not is_braking and current_fuel > 0.0 and grounded_wheels >= 2 and forward_mps < (max_spin_kmh / MPS_TO_KMH):
		var low_spd_t: float = clampf(1.0 - maxf(forward_mps * MPS_TO_KMH, 0.0) / max_spin_kmh, 0.0, 1.0)
		var reverse_to_fwd_kick: float = 1.35 if reversing_to_fwd else 1.0
		var throt_punch: float = clampf(maxf(_smooth_throttle, 0.58), 0.0, 1.0)
		spin_target = clampf(pow(low_spd_t, 0.64) * throt_punch * launch_wheelspin_intensity * drive_spin_mult * chs_grip_hook * reverse_to_fwd_kick, 0.0, 1.35)
	elif wants_reverse and not is_braking and current_fuel > 0.0 and grounded_wheels >= 2 and absf(forward_mps) < 16.0:
		var rev_spd_t: float = clampf(1.0 - maxf(-forward_mps, 0.0) / 16.0, 0.28, 1.0)
		var rev_kick: float = 1.32 if fwd_to_reverse else 1.15
		var rev_punch: float = clampf(maxf(absf(_smooth_throttle), 0.78), 0.0, 1.0)
		spin_target = clampf(maxf(0.45 * rev_spd_t, pow(rev_spd_t, 0.52) * rev_punch * launch_wheelspin_intensity * 1.18 * drive_spin_mult * chs_grip_hook * rev_kick), 0.0, 1.32)
	var spin_rate: float = 15.0 if ((reversing_to_fwd or fwd_to_reverse) and spin_target > _launch_wheelspin) else ((10.5 if wants_reverse else 8.2) if spin_target > _launch_wheelspin else 2.8)
	_launch_wheelspin = move_toward(_launch_wheelspin, spin_target, spin_rate * delta)

	var steer_input := 0.0
	if intro_autopilot:
		var car_fwd_h := Vector3(forward_3d.x, 0.0, forward_3d.z).normalized()
		var target_dir := Vector3(_intro_fwd.x, 0.0, _intro_fwd.z).normalized()
		var desired_dir := (target_dir + Vector3(-global_position.x * 0.08, 0.0, 0.0)).normalized()
		var yaw_err := car_fwd_h.cross(desired_dir).y
		steer_input = clampf(yaw_err * 2.2, -0.35, 0.35)
	else:
		steer_input = Input.get_axis("D", "A")
	# Ручной дрифт на Пробел/Shift отключён: машина уходит в занос сама только на гололёде в зимнем биоме (_on_black_ice)
	_is_handbraking = false
	var speed_ratio := clampf(float(speed_kmh) / float(maxi(MAX_SPEED_KMH, 1)), 0.0, 1.0)
	var low_spd_steer_boost: float = lerpf(1.48, 1.0, clampf(float(speed_kmh) / 62.0, 0.0, 1.0))
	var effective_base_limit: float = minf(STEER_LIMIT * low_spd_steer_boost, 0.66)
	var dynamic_steer_limit: float = effective_base_limit * lerpf(1.0, high_speed_steer_min_ratio, pow(speed_ratio, 0.58))
	var raw_steer_target: float = steer_input * dynamic_steer_limit
	var recentering := absf(steer_input) < 0.05 or signf(steer_input) != signf(steering)
	var rack_rate: float = steer_inertia * (1.28 if recentering else lerpf(1.0, 0.58, speed_ratio))
	_steer_target_filtered = lerpf(_steer_target_filtered, raw_steer_target, clampf(rack_rate * delta, 0.0, 1.0))
	var low_spd_resp: float = lerpf(1.38, 1.0, clampf(float(speed_kmh) / 45.0, 0.0, 1.0))
	var dynamic_steer_speed: float = STEER_SPEED * low_spd_resp * (lerpf(1.38, 0.86, speed_ratio) if recentering else lerpf(1.12, 0.62, speed_ratio))
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
	var in_rev_jturn_smoke: bool = (forward_mps < -2.6 and absf(steering) > 0.16 and grounded_wheels >= 2)
	var allow_rubber_smoke: bool = (not _on_black_ice) and (_surface_grip_mult > 0.25)
	var spin_smoke_lvl: float = clampf(_launch_wheelspin * 1.15, 0.0, 1.35)
	var jturn_smoke_lvl: float = clampf((absf(forward_mps) - 2.0) / 8.0, 0.40, 1.0) if in_rev_jturn_smoke else 0.0
	var brake_smoke_lvl: float = clampf((float(speed_kmh) - 32.0) / 55.0, 0.35, 1.05) if (is_braking and speed_kmh > 32) else 0.0
	for i: int in range(_tire_smokes.size()):
		var ts: CPUParticles3D = _tire_smokes[i]
		if not is_instance_valid(ts):
			continue
		var w: RaycastWheel = _tire_smoke_wheels[i] if i < _tire_smoke_wheels.size() else null
		var w_grounded: bool = (grounded_wheels > 0) if w == null else (is_instance_valid(w) and w.is_grounded)
		var w_slip: float = absf(w.lateral_slip_mps) if (w != null and is_instance_valid(w) and w.is_grounded) else max_slip
		var w_traction: bool = (w == null) or (is_instance_valid(w) and w.use_as_traction)
		var spin_active: bool = w_traction and _launch_wheelspin > 0.10
		var slip_smoke_lvl: float = clampf((w_slip - 3.2) / 5.5, 0.35, 1.25) if (w_slip > 3.2 and speed_kmh > 20) else 0.0
		var w_emit: bool = allow_rubber_smoke and w_grounded and (spin_active or in_rev_jturn_smoke or (w_slip > 3.2 and speed_kmh > 20) or (is_braking and speed_kmh > 32))
		ts.emitting = w_emit
		if w_emit:
			var intensity: float = clampf(maxf(maxf(spin_smoke_lvl if spin_active else 0.0, jturn_smoke_lvl), maxf(slip_smoke_lvl, brake_smoke_lvl)), 0.35, 1.35)
			ts.speed_scale = lerpf(1.05, 1.85, clampf(intensity, 0.0, 1.0))
			ts.scale_amount_min = lerpf(1.05, 1.55, clampf(intensity, 0.0, 1.0))
			ts.scale_amount_max = lerpf(2.25, 3.30, clampf(intensity, 0.0, 1.0))
	_emit_drive_skid_marks(speed_kmh, wants_throttle, is_braking)

	_update_damage_vfx(delta)
	_update_visual_lights(delta, is_braking or Input.is_action_pressed("S"), false)
	_update_vehicle_audio(delta, speed_ratio, max_slip, wants_throttle, wants_reverse, is_braking, forward_mps)
	_animate_supercharger(delta, clampf(_sim_rpm, 0.0, 1.0), maxf(_smooth_throttle, 0.0))
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


func _emit_drive_skid_marks(speed_kmh: int, _wants_throttle: bool, is_braking: bool) -> void:
	if _wheels.is_empty():
		return
	if _on_black_ice:
		for w_ice in _wheels:
			if is_instance_valid(w_ice):
				CarVFX.break_tire_skid(int(w_ice.get_instance_id()))
		return
	var slip_thresh := 2.6
	for w in _wheels:
		var wid := int(w.get_instance_id())
		if not w.is_grounded or destroyed:
			CarVFX.break_tire_skid(wid)
			continue
		var lat_t := clampf((absf(w.lateral_slip_mps) - slip_thresh) / 5.0, 0.0, 1.0)
		var brk_t := clampf(_brake_pressure * 0.92, 0.0, 1.0) if (is_braking and speed_kmh > 22) else 0.0
		var axle_spin_scale: float = (awd_front_torque_split * 1.4 if w.is_front else 1.0) if drive_type == "AWD" else 1.0
		var launch_t := clampf(_launch_wheelspin * 0.92 * axle_spin_scale, 0.0, 0.92) if (w.use_as_traction and _launch_wheelspin > 0.14) else 0.0
		var intensity := maxf(maxf(lat_t, brk_t), launch_t)
		if intensity > 0.08:
			var mark_col := Color(0.035, 0.035, 0.04, 0.88)
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

	if wants_reverse and forward_mps <= 2.6:
		_current_gear = 0
		_display_gear = "R"
		_air_revving = false
		var rev_spin_boost: float = clampf(_launch_wheelspin * 0.38, 0.0, 0.42)
		var rev_rpm: float = clampf(lerpf(0.55, 0.94, clampf(absf(forward_mps) / 13.5, 0.0, 1.0)) + rev_spin_boost, 0.52, 0.98)
		_sim_rpm = lerpf(_sim_rpm, rev_rpm, clampf(delta * 14.0, 0.0, 1.0))
		return

	var fwd_speed_ratio: float = clampf(maxf(forward_mps, 0.0) * MPS_TO_KMH / float(maxi(MAX_SPEED_KMH, 1)), 0.0, 1.0)

	if wants_throttle and forward_mps < 2.0:
		_current_gear = 1
		_shift_timer = 0.0
		_display_gear = "G1"
		_air_revving = false
		var target_launch_rpm: float = clampf(0.68 + _launch_wheelspin * 0.28, 0.62, 0.98)
		_sim_rpm = lerpf(_sim_rpm, target_launch_rpm, clampf(delta * 16.0, 0.0, 1.0))
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

	if _current_gear < max_gear and fwd_speed_ratio >= gear_ceil * 0.94 and wants_throttle and _shift_cooldown <= 0.0:
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
	elif _current_gear > 1 and fwd_speed_ratio < prev_ceil * 0.78 and _shift_cooldown <= 0.0:
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
	var gear_t: float = clampf((fwd_speed_ratio - gear_floor) / maxf(gear_ceil - gear_floor, 0.08), 0.0, 1.0)

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
	var under_power: bool = (wants_throttle or wants_reverse) and not is_empty
	var rpm_c: float = clampf(_sim_rpm, 0.0, 1.05)
	var idle_weight: float = clampf(1.0 - smoothstep(0.20, 0.65, rpm_c), 0.04, 1.0)
	var mid_in: float = smoothstep(0.14, 0.42, rpm_c)
	var mid_out: float = 1.0 - 0.35 * smoothstep(0.76, 1.02, rpm_c)
	var mid_weight: float = clampf(mid_in * mid_out * (0.78 + (0.22 if under_power else -0.18)) + _launch_wheelspin * 0.20, 0.05, 1.0)
	var howl_weight: float = clampf(smoothstep(0.44, 0.86, rpm_c) * (0.85 + (0.15 if under_power else -0.25)) + _launch_wheelspin * 0.28, 0.0, 1.0)
	var gear_harmonic: float = float(maxi(_current_gear - 1, 0)) * (0.032 if is_btr else 0.044)
	var clutch_dip_db: float = (-8.5 if is_btr else (-11.0 * clampf(_shift_timer / 0.20, 0.0, 1.0))) if _shift_timer > 0.0 else 0.0
	var overrun_db: float = -4.8 if (not under_power and speed_ratio > 0.12 and _shift_timer <= 0.0) else 0.0
	var limiter_dip_db: float = 0.0
	var tier_punch_db: float = 0.0
	var load_db: float = 0.0

	if not is_btr:
		idle_weight = clampf(1.0 - smoothstep(0.16, 0.52, rpm_c), 0.02, 1.0)
		mid_in = smoothstep(0.12, 0.36, rpm_c)
		mid_out = 1.0 - 0.38 * smoothstep(0.68, 0.96, rpm_c)
		mid_weight = clampf(mid_in * mid_out * (0.80 + (0.20 if under_power else -0.22)) + _launch_wheelspin * 0.18, 0.04, 1.0)
		howl_weight = clampf(smoothstep(0.42, 0.80, rpm_c) * (0.88 + (0.14 if under_power else -0.28)) + _launch_wheelspin * 0.26 + (0.18 if _air_revving else 0.0), 0.0, 1.0)
		limiter_dip_db = (-3.8 * clampf(-sin(_air_rev_limiter_phase), 0.0, 1.0)) if (_air_revving and _sim_rpm >= 0.92) else 0.0
		tier_punch_db = float(_engine_upgrade_tier) * 1.15
		load_db = 2.2 if under_power else (-2.6 if speed_ratio > 0.10 else 0.0)
		overrun_db = -3.8 if (not under_power and speed_ratio > 0.12 and _shift_timer <= 0.0) else 0.0

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
			var boost_lvl: float = clampf((rpm_c - 0.32) / 0.68, 0.0, 1.0) * (1.0 if under_power else 0.22)
			var target_boost_db: float = (lerpf(-36.0, -16.5, boost_lvl) + clutch_dip_db * 0.5 + limiter_dip_db * 0.6) if boost_lvl > 0.05 else -60.0
			_engine_boost_audio.volume_db = lerpf(_engine_boost_audio.volume_db, target_boost_db, clampf(delta * 10.0, 0.0, 1.0))
			_engine_boost_audio.pitch_scale = lerpf(_engine_boost_audio.pitch_scale, lerpf(0.75, 1.85, boost_lvl), clampf(delta * 12.0, 0.0, 1.0))
		else:
			_engine_boost_audio.volume_db = lerpf(_engine_boost_audio.volume_db, -60.0, clampf(delta * 10.0, 0.0, 1.0))

	if is_instance_valid(_fire_audio):
		var target_fire_db: float = lerpf(-20.0, -6.5, _engine_fire_level) if _engine_fire_level > 0.01 else -60.0
		_fire_audio.volume_db = lerpf(_fire_audio.volume_db, target_fire_db, clampf(delta * 7.5, 0.0, 1.0))

	var is_ice_sliding := false
	var skid_raw := 0.0
	var ice_raw := 0.0
	if grounded_wheels > 0:
		if _on_black_ice:
			is_ice_sliding = true
			var slide_spd_t: float = clampf(maxf(absf(forward_mps), speed_ratio * 35.0) / 18.0, 0.25, 1.0)
			var slip_t: float = clampf((max_slip - 0.75) / 4.8, 0.0, 1.0)
			var spin_t: float = clampf(_launch_wheelspin * 0.75, 0.0, 0.85) if _launch_wheelspin > 0.12 else 0.0
			var brk_ice_t: float = clampf(speed_ratio * 0.65, 0.0, 0.65) if (is_braking and absf(forward_mps) > 1.8) else 0.0
			var cruise_glide_t: float = 0.22 * slide_spd_t if (absf(forward_mps) > 4.0 and (absf(steering) > 0.08 or wants_throttle or wants_reverse)) else 0.0
			ice_raw = clampf(maxf(maxf(slip_t, spin_t), maxf(brk_ice_t, cruise_glide_t)) * slide_spd_t, 0.0, 1.0)
		else:
			if _launch_wheelspin > 0.10:
				skid_raw = maxf(skid_raw, clampf(_launch_wheelspin * 0.92, 0.0, 0.92))
			if max_slip > 3.8 and speed_ratio > 0.14:
				skid_raw = maxf(skid_raw, clampf((max_slip - 3.8) / 6.5, 0.0, 0.92))
			elif is_braking and speed_ratio > 0.18:
				skid_raw = maxf(skid_raw, clampf(speed_ratio * 0.80, 0.0, 0.80))

	if is_instance_valid(_skid_audio):
		_smooth_skid_vol = lerpf(_smooth_skid_vol, 0.0 if is_ice_sliding else skid_raw, clampf(delta * 12.0, 0.0, 1.0))
		if _smooth_skid_vol > 0.03:
			_skid_audio.volume_db = lerpf(-30.0, -10.2, _smooth_skid_vol)
			_skid_audio.pitch_scale = lerpf(0.92, 1.22, _smooth_skid_vol)
		else:
			_skid_audio.volume_db = -60.0

	if is_instance_valid(_ice_slide_audio):
		_smooth_ice_slide_vol = lerpf(_smooth_ice_slide_vol, ice_raw if is_ice_sliding else 0.0, clampf(delta * 7.0, 0.0, 1.0))
		if _smooth_ice_slide_vol > 0.02:
			_ice_slide_audio.volume_db = lerpf(-38.0, -18.5, _smooth_ice_slide_vol)
			_ice_slide_audio.pitch_scale = lerpf(0.86, 1.12, clampf(speed_ratio * 0.65 + _smooth_ice_slide_vol * 0.35, 0.0, 1.0))
		else:
			_ice_slide_audio.volume_db = -60.0

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("set_speed_wind"):
		var abs_wind_t: float = maxf(speed_ratio, clampf((absf(forward_mps) * MPS_TO_KMH - 50.0) / 130.0, 0.0, 1.0))
		sm.call("set_speed_wind", abs_wind_t, not is_preview and not destroyed)

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
	var tire_loads: Array[float] = []
	tire_loads.resize(wheel_count)
	grounded_wheels = 0
	var traction_total: int = 0

	# 1. Smoothed progressive Hooke's law suspension with digressive shocks & hydraulic bump stops
	_post_landing_damp_timer = maxf(_post_landing_damp_timer - delta, 0.0)
	_susp_bump_cooldown = maxf(_susp_bump_cooldown - delta, 0.0)
	var max_landing_comp_ratio: float = 0.0
	var max_landing_spring_vel: float = 0.0
	var max_bump_delta: float = 0.0
	var max_bump_vel: float = 0.0
	var space_state := get_world_3d().direct_space_state
	for i in range(wheel_count):
		var w := _wheels[i]
		if w.use_as_traction:
			traction_total += 1

		var was_grounded: bool = w.is_grounded
		if w.cast_suspension_ray(space_state, self, car_up):
			max_landing_comp_ratio = maxf(max_landing_comp_ratio, w.compression_ratio)
			var prev_comp_ratio: float = w.prev_compression_m / maxf(w.rest_length, 0.01)

			# Авто-калибровка пружины под реальный вес колеса (чтобы в покое сжатие было ~45%, как в BeamNG)
			# с сохранением баланса передней/задней жёсткости и множителя suspension_firmness
			var k_auto: float = (per_wheel_weight / maxf(w.rest_length * 0.45, 0.04)) * suspension_firmness
			var axle_bias: float = 1.0
			if front_spring_stiffness > 0.0 and rear_spring_stiffness > 0.0 and w.spring_stiffness_override > 0.0:
				var avg_ov: float = (front_spring_stiffness + rear_spring_stiffness) * 0.5
				axle_bias = clampf(w.spring_stiffness_override / maxf(avg_ov, 1.0), 0.80, 1.28)
			var k_eff: float = k_auto * axle_bias
			var c_crit: float = 2.0 * sqrt(k_eff * per_wheel_mass)
			var damp_comp: float = w.damping_comp_override if w.damping_comp_override > 0.0 else c_crit * compression_damping_ratio
			var damp_reb: float = w.damping_rebound_override if w.damping_rebound_override > 0.0 else c_crit * rebound_damping_ratio

			var wheel_offset: Vector3 = w.global_position - global_position
			var wheel_vel: Vector3 = linear_velocity + angular_velocity.cross(wheel_offset)
			var raw_spring_vel: float = clampf(-wheel_vel.dot(w.ground_normal), -10.0, 16.0)
			max_landing_spring_vel = maxf(max_landing_spring_vel, raw_spring_vel)
			if was_grounded:
				max_bump_delta = maxf(max_bump_delta, w.compression_ratio - prev_comp_ratio)
				max_bump_vel = maxf(max_bump_vel, raw_spring_vel)
			if not was_grounded or signf(raw_spring_vel) != signf(w.smooth_spring_vel):
				w.smooth_spring_vel = raw_spring_vel
			else:
				w.smooth_spring_vel = lerpf(w.smooth_spring_vel, raw_spring_vel, clampf(delta * 30.0, 0.0, 1.0))

			# Прогрессивный резиновый отбойник (Bump Stop) при глубоком ходе подвески (>64%)
			if w.compression_ratio > 0.64:
				var bs_excess: float = w.compression_ratio - 0.64
				if w.smooth_spring_vel >= 0.0:
					k_eff *= 1.0 + bs_excess * 1.45 + bs_excess * bs_excess * 2.2
				damp_comp *= 1.0 + bs_excess * 2.6

			var recovery_t: float = clampf((w.compression_ratio - 0.56) / 0.65, 0.0, 1.0)
			if _post_landing_damp_timer > 0.0:
				if w.compression_ratio > 0.72:
					damp_reb *= 1.05
				else:
					damp_reb = maxf(damp_reb * 1.65, c_crit * 1.12)

			# Дигрессивная характеристика сжатия амортизатора (как в BeamNG):
			# плавно проглатывает резкие мелкие кочки и гребёнку, не подбрасывая кузов
			var eff_spring_vel: float = w.smooth_spring_vel
			if eff_spring_vel > 1.25:
				eff_spring_vel = 1.25 + (eff_spring_vel - 1.25) * 0.50

			var damp_eff: float = damp_comp if eff_spring_vel >= 0.0 else damp_reb
			var f_raw: float = w.compression_m * k_eff + eff_spring_vel * damp_eff
			var reb_cap_mult: float = lerpf(1.10 if _post_landing_damp_timer > 0.0 else 1.32, 1.72, recovery_t)
			var f_cap: float = per_wheel_weight * (4.4 if eff_spring_vel >= 0.0 else reb_cap_mult)
			var f_susp: float = clampf(f_raw, 0.0, f_cap)
			susp_forces[i] = f_susp
			tire_loads[i] = f_susp
			w.prev_compression_m = w.compression_m
			grounded_wheels += 1
		else:
			w.prev_compression_m = 0.0
			w.smooth_spring_vel = lerpf(w.smooth_spring_vel, 0.0, clampf(delta * 12.0, 0.0, 1.0))
			susp_forces[i] = 0.0
			tire_loads[i] = 0.0

	# Track airborne flight & trigger hard-landing sparks + sound + camera jolt on touchdown
	_landing_cooldown = maxf(_landing_cooldown - delta, 0.0)
	if grounded_wheels == 0:
		_airborne_timer += delta
		_peak_downward_vy = minf(_peak_downward_vy, linear_velocity.y)
	else:
		if linear_velocity.y < -1.0:
			_peak_downward_vy = minf(_peak_downward_vy, linear_velocity.y)
		var hard_touchdown: bool = (_prev_grounded_wheels == 0 and _airborne_timer >= 0.11 and (_peak_downward_vy < -1.7 or max_landing_spring_vel > 2.3))
		var heavy_bottom_out: bool = (_airborne_timer >= 0.07 and _peak_downward_vy < -2.9 and max_landing_comp_ratio > 0.68)
		if (hard_touchdown or heavy_bottom_out) and _landing_cooldown <= 0.0:
			var impact_t: float = clampf((absf(_peak_downward_vy) - 1.4) / 7.5 + max_landing_comp_ratio * 0.38, 0.38, 1.60)
			trigger_landing_vfx(impact_t)
		elif grounded_wheels >= 2 and speed_mps > 2.2 and (max_bump_delta > 0.14 or max_bump_vel > 1.75) and _susp_bump_cooldown <= 0.0 and _landing_cooldown <= 0.0:
			_susp_bump_cooldown = 0.16
			var sm_bump: Node = get_node_or_null("/root/SoundManager")
			if sm_bump and sm_bump.has_method("play_suspension_bump"):
				sm_bump.call("play_suspension_bump", clampf(max_bump_delta * 2.4 + max_bump_vel * 0.22, 0.25, 1.15), mass >= 2700.0)
		_airborne_timer = 0.0
		_peak_downward_vy = 0.0
	_prev_grounded_wheels = grounded_wheels

	if _post_landing_damp_timer > 0.0 and grounded_wheels >= 2:
		var deep_up: float = 0.96 if mass > 3500.0 else 1.28
		var max_up_vy: float = deep_up if max_landing_comp_ratio >= 0.70 else 0.30
		if linear_velocity.y > max_up_vy:
			linear_velocity.y = move_toward(linear_velocity.y, max_up_vy * 0.85, delta * 36.0)

	# 2. Front & rear Anti-Roll Bars + Dynamic Tire Load Transfer
	_apply_anti_roll_pair(_front_left, _front_right, anti_roll_stiffness, susp_forces, per_wheel_weight)
	_apply_anti_roll_pair(_rear_left, _rear_right, anti_roll_stiffness * 0.90, susp_forces, per_wheel_weight)

	var raw_long_accel: float = clampf((forward_mps - _prev_forward_mps) * inv_dt, -22.0, 22.0)
	_smooth_long_accel = lerpf(_smooth_long_accel, raw_long_accel, clampf(delta * 8.5, 0.0, 1.0))
	var drive_grounded_count: int = 0
	var drive_total_count: int = 0
	for w_chk in _wheels:
		if w_chk.use_as_traction:
			drive_total_count += 1
			if w_chk.is_grounded:
				drive_grounded_count += 1
	var drive_contact_ratio: float = float(drive_grounded_count) / maxf(float(drive_total_count), 1.0)
	var grip_auth: float = clampf(drive_contact_ratio * clampf(_surface_grip_mult, 0.25, 1.1), 0.0, 1.0)
	var speed_headroom: float = clampf((float(MAX_SPEED_KMH) - speed_mps * MPS_TO_KMH) / 18.0, 0.0, 1.0)
	var accel_auth: float = clampf(_smooth_long_accel / 3.8, 0.0, 1.0) * grip_auth * clampf(speed_headroom * 1.4, 0.0, 1.0)
	var decel_auth: float = clampf(-_smooth_long_accel / 4.2, 0.0, 1.0) * clampf(_surface_brake_mult, 0.25, 1.0) * clampf(forward_mps / 2.2, 0.0, 1.0)
	var launch_bite: float = minf(_launch_wheelspin, 1.35) * clampf(1.0 - maxf(forward_mps, 0.0) / 11.5, 0.0, 1.0) * accel_auth

	var cur_yaw_up: float = angular_velocity.dot(car_up)
	var est_lat_accel_left: float = forward_mps * cur_yaw_up
	if grounded_wheels >= 2:
		var est_long_g: float = clampf(_smooth_long_accel / 9.8, -1.35, 1.35)
		var est_lat_g: float = clampf(est_lat_accel_left / 9.8, -1.45, 1.45)
		var throt_squat_g: float = (_smooth_throttle * 0.34 * accel_auth + launch_bite * 0.28) if (wants_throttle and forward_mps >= -0.5) else (-_brake_pressure * 0.54 * decel_auth if (is_braking and forward_mps > 0.8) else 0.0)
		var eff_long_g: float = clampf(est_long_g * 0.68 + throt_squat_g, -1.40, 1.40)
		var long_shift: float = eff_long_g * per_wheel_weight * weight_transfer_long
		var lat_shift: float = est_lat_g * per_wheel_weight * weight_transfer_lat
		for i in range(wheel_count):
			var w_tr := _wheels[i]
			if not w_tr.is_grounded:
				continue
			# 1) Нагрузка на шину для расчёта зацепа: при разгоне догружается задняя ось (+long_shift сзади);
			# при левом повороте (est_lat_g > 0) центробежная сила догружает внешние ПРАВЫЕ колёса
			var df_tire: float = (-long_shift if w_tr.is_front else long_shift)
			df_tire += (-lat_shift if w_tr.is_left else lat_shift)
			tire_loads[i] = clampf(susp_forces[i] + df_tire, per_wheel_weight * 0.18, per_wheel_weight * 3.6)
			# 2) Инерционный момент на кузов:
			# - при разгоне (long_shift > 0) нос приподнимается (+ спереди), корма приседает (- сзади);
			# - при левом повороте (lat_shift > 0) центробежная сила наклоняет кузов ВПРАВО (левый борт +, правый внешний борт проседает -)
			var df_chassis: float = (long_shift * 0.52 if w_tr.is_front else -long_shift * 0.52)
			df_chassis += (lat_shift * 0.55 if w_tr.is_left else -lat_shift * 0.55)
			susp_forces[i] = clampf(susp_forces[i] + df_chassis, per_wheel_weight * 0.14, per_wheel_weight * 4.2)

	# 3. Aero downforce
	if grounded_wheels > 0:
		var downforce: float = clampf(speed_mps * downforce_multiplier, 0.0, downforce_max)
		apply_central_force(-car_up * downforce)
		var downforce_per_w: float = downforce / float(grounded_wheels)
		for i in range(wheel_count):
			if _wheels[i].is_grounded:
				susp_forces[i] += downforce_per_w * 0.65
				tire_loads[i] += downforce_per_w * 0.65

	if is_braking:
		_brake_pressure = minf(_brake_pressure + delta * 3.4, 1.0)
	else:
		_brake_pressure = maxf(_brake_pressure - delta * 8.0, 0.0)

	# 4. Longitudinal drive force coupled to active transmission gear, RPM band & realistic launch wheelspin
	var reversing_to_fwd: bool = (wants_throttle and not is_braking and current_fuel > 0.0 and forward_mps < -0.35 and grounded_wheels >= 2)
	var fwd_to_reverse: bool = (wants_reverse and not is_braking and current_fuel > 0.0 and forward_mps > 0.25 and grounded_wheels >= 2)
	var total_drive_force: float = 0.0
	if wants_throttle and current_fuel > 0.0:
		var g_idx: int = clampi(_current_gear - 1, 0, maxi(gear_torque_multipliers.size() - 1, 0))
		var gear_mult: float = 1.0
		if not gear_torque_multipliers.is_empty():
			gear_mult = float(gear_torque_multipliers[g_idx])
		else:
			var max_g: int = maxi(gear_speed_ratios.size(), 1)
			gear_mult = lerpf(1.45, 0.62, float(g_idx) / maxf(float(max_g - 1), 1.0))
		var rpm_t: float = clampf((_sim_rpm - 0.16) / 0.80, 0.0, 1.0)
		var rpm_curve: float = 0.78 + 0.24 * sin(rpm_t * PI)
		if _shift_timer > 0.0:
			rpm_curve *= 0.28
		var overdrive_mult: float = 1.18 if _overdrive_timer > 0.0 else 1.0
		# При пробуксовке на старте шина скользит по асфальту и передаёт меньше тяги, пока не зацепится
		var slip_loss: float = 1.0 if reversing_to_fwd else lerpf(1.0, 0.78 if drive_type != "AWD" else 0.85, clampf(_launch_wheelspin, 0.0, 1.0))
		var speed_fade: float = clampf((float(MAX_SPEED_KMH) - speed_mps * MPS_TO_KMH) / 15.0, 0.0, 1.0)
		var spool_factor: float = clampf(maxf(_smooth_throttle, 0.16), 0.16, 1.0)
		total_drive_force = float(engine_force_value) * 1.34 * gear_mult * rpm_curve * speed_fade * overdrive_mult * spool_factor * slip_loss * (1.45 if reversing_to_fwd else 1.0)
	elif wants_reverse and current_fuel > 0.0:
		var rev_kmh := absf(minf(forward_mps, 0.0)) * MPS_TO_KMH
		if rev_kmh < 72.0:
			var rev_spool: float = clampf(absf(_smooth_throttle) * 1.35, 0.42, 1.0)
			var rev_fade: float = clampf((72.0 - rev_kmh) / 15.0, 0.0, 1.0)
			var fwd_to_rev_punch: float = 1.35 if fwd_to_reverse else 1.0
			total_drive_force = -float(engine_force_value) * 1.78 * rev_spool * rev_fade * fwd_to_rev_punch

	var lat_force_right_sum: float = 0.0
	var in_reverse_jturn: bool = (not wants_throttle and forward_mps < -2.6 and absf(steering) > 0.16 and grounded_wheels >= 2)

	# 5. Apply 3D forces at tire contact patches (strictly below center of mass for true rear squat & front brake dive)
	for i in range(wheel_count):
		var w := _wheels[i]
		if not w.is_grounded:
			w.lateral_slip_mps = 0.0
			w.forward_speed_mps = lerpf(w.forward_speed_mps, forward_mps, clampf(delta * 4.0, 0.0, 1.0))
			w.update_visuals(steering, w.forward_speed_mps, delta, false)
			continue

		var f_susp: float = susp_forces[i]
		var t_load: float = maxf(tire_loads[i], per_wheel_weight * 0.35)
		var susp_dir: Vector3 = w.ground_normal.lerp(car_up, 0.35).normalized()
		var susp_offset: Vector3 = w.global_position - global_position
		apply_force(susp_dir * f_susp, susp_offset)

		# Точка приложения продольных и боковых сил шины всегда находится НИЖЕ центра масс (com_height),
		# благодаря чему разгон физически прижимает заднюю ось (приседание назад), а тормоз наклоняет нос вперёд
		var local_w_pos: Vector3 = w.position
		var contact_local := Vector3(local_w_pos.x, com_height - w.wheel_radius * 0.34, local_w_pos.z)
		var contact_offset: Vector3 = global_transform.basis * contact_local
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
			grip_mod *= 0.97
		else:
			grip_mod *= 1.10
		if in_reverse_jturn and w.is_front:
			grip_mod *= 0.72
		# Эллипс трения (Traction Circle): буксующие ведущие колёса чуть теряют боковой зацеп под полным газом
		if w.use_as_traction and _launch_wheelspin > 0.08 and (wants_throttle or wants_reverse):
			var spin_lat_drop: float = 0.18 if (drive_type == "RWD" and not w.is_front) else 0.10
			grip_mod *= clampf(1.0 - _launch_wheelspin * spin_lat_drop, 0.76, 1.0)
		if not w.is_front:
			var slip_threshold: float = (2.6 + speed_mps * 0.09) if _on_black_ice else (4.6 + speed_mps * 0.15)
			if absf(lat_vel) > slip_threshold:
				var slide_t: float = clampf((absf(lat_vel) - slip_threshold) / 7.0, 0.0, 1.0)
				var min_high_speed_grip: float = clampf(drift_grip_factor * 0.78, 0.56, 0.74) if _on_black_ice else maxf(drift_grip_factor, lerpf(0.76, 0.92, clampf(speed_ratio * 1.15, 0.0, 1.0)))
				grip_mod *= lerpf(1.0, min_high_speed_grip, slide_t)

		var max_tire_lat: float = t_load * tire_friction * grip_mod * _surface_grip_mult
		var stop_lat_force: float = per_wheel_mass * absf(lat_vel) * inv_dt * 0.92
		var lat_rate_mult: float = (0.38 if not w.is_front else 0.44) if _on_black_ice else (1.14 if not w.is_front else 0.95)
		var lat_grip_blend: float = lerpf(0.32, 0.85, _surface_grip_mult) if _on_black_ice else lerpf(0.62, 1.0, _surface_grip_mult)
		var lat_rate: float = lateral_stiffness * lat_rate_mult * lat_grip_blend
		var raw_lat_force: float = -lat_vel * per_wheel_mass * lat_rate * grip_mod
		var f_lat: float = clampf(raw_lat_force, -minf(max_tire_lat, stop_lat_force), minf(max_tire_lat, stop_lat_force))
		apply_force(wheel_right * f_lat, contact_offset)
		lat_force_right_sum += (wheel_right * f_lat).dot(car_right)

		var f_long: float = 0.0
		if w.use_as_traction and absf(total_drive_force) > 1.0:
			var wheel_torque_share: float = 0.5
			if drive_type == "AWD":
				wheel_torque_share = (awd_front_torque_split * 0.5) if w.is_front else ((1.0 - awd_front_torque_split) * 0.5)
			elif traction_total > 0:
				wheel_torque_share = 1.0 / float(traction_total)
			var raw_wheel_drive: float = total_drive_force * wheel_torque_share * lerpf(0.80, 1.0, _surface_grip_mult)
			var slip_grip_mult: float = 1.0 if (reversing_to_fwd or fwd_to_reverse) else lerpf(1.0, 0.82, clampf(_launch_wheelspin, 0.0, 1.0))
			var drive_grip_coef: float = 1.15 if (reversing_to_fwd or fwd_to_reverse) else ((0.96 if drive_type != "AWD" else 0.84) if wants_reverse else (0.82 if drive_type != "AWD" else 0.64))
			var max_tire_drive: float = t_load * tire_friction * drive_grip_coef * _surface_grip_mult * slip_grip_mult
			f_long += clampf(raw_wheel_drive, -max_tire_drive, max_tire_drive)
		if reversing_to_fwd and fwd_vel < -0.25:
			var bite_mps2: float = lerpf(11.0, 17.5, clampf(_surface_grip_mult, 0.35, 1.0))
			f_long += minf(per_wheel_mass * bite_mps2, per_wheel_mass * absf(minf(fwd_vel, 0.0)) * inv_dt * 0.85)
		elif fwd_to_reverse and fwd_vel > 0.25:
			var rev_bite_mps2: float = lerpf(10.5, 16.5, clampf(_surface_grip_mult, 0.35, 1.0))
			f_long -= minf(per_wheel_mass * rev_bite_mps2, per_wheel_mass * maxf(fwd_vel, 0.0) * inv_dt * 0.85)
		if is_braking and absf(fwd_vel) > 0.15:
			var bias: float = 1.30 if w.is_front else 0.70
			var target_decel: float = max_brake_decel_mps2 * maxf(_brake_pressure, 0.18) * clampf(brake_force / 100.0, 0.65, 1.55) * lerpf(0.54, 1.0, _surface_brake_mult)
			var max_tire_long: float = t_load * tire_friction * 0.90 * _surface_brake_mult
			var brk_mag: float = minf(per_wheel_mass * target_decel * bias, minf(max_tire_long, per_wheel_mass * absf(fwd_vel) * inv_dt * 0.85))
			f_long += -signf(fwd_vel) * brk_mag
		elif not wants_throttle and not wants_reverse and absf(fwd_vel) > 0.05:
			var roll_mag: float = minf(absf(fwd_vel) * per_wheel_mass * 0.018 + per_wheel_mass * 0.20, per_wheel_mass * absf(fwd_vel) * inv_dt * 0.25)
			f_long += -signf(fwd_vel) * roll_mag * lerpf(0.45, 1.0, _surface_grip_mult)

		if absf(f_long) > 0.01:
			apply_force(wheel_fwd * f_long, contact_offset)

		var vis_wheel_spd: float = fwd_vel
		if w.use_as_traction and reversing_to_fwd:
			vis_wheel_spd = maxf(fwd_vel, 0.0) + maxf(_launch_wheelspin, 0.55) * 22.0
		elif w.use_as_traction and fwd_to_reverse:
			vis_wheel_spd = minf(fwd_vel, 0.0) - maxf(_launch_wheelspin, 0.60) * 24.0
		elif w.use_as_traction and _launch_wheelspin > 0.02:
			var awd_vis_scale: float = (awd_front_torque_split * 1.45 if w.is_front else 1.0) if drive_type == "AWD" else 1.0
			var spin_dir_s: float = -1.0 if (wants_reverse and not wants_throttle) else 1.0
			var spin_mag_s: float = 24.0 if wants_reverse else 20.0
			vis_wheel_spd = fwd_vel + _launch_wheelspin * spin_mag_s * awd_vis_scale * spin_dir_s
		w.update_visuals(steering, vis_wheel_spd, delta, false)

	if speed_mps > 1.5:
		var drag_scale: float = 1.0 if wants_throttle else 0.28
		apply_central_force(-linear_velocity.normalized() * (aero_drag_coeff * drag_scale * speed_mps * speed_mps))

	# 6. Body roll, pitch squat/dive, launch torque shudder, realistic yaw weight damping & self-righting
	if grounded_wheels >= 2:
		var lat_tire_left_accel: float = -lat_force_right_sum / maxf(mass, 1.0)
		var eff_roll_lat_accel: float = est_lat_accel_left if forward_mps < -0.5 else (est_lat_accel_left * 0.65 + lat_tire_left_accel * 0.35)
		var roll_assist: float = clampf(eff_roll_lat_accel * mass * body_roll_torque_factor * 0.055, -mass * 7.5, mass * 7.5)
		apply_torque(car_fwd * roll_assist)

		var launch_squat_boost: float = (launch_bite * 4.2 + _smooth_throttle * 2.8 * accel_auth) if (wants_throttle and forward_mps >= -0.5) else 0.0
		var rev_squat_boost: float = (-clampf(absf(_smooth_throttle) * 2.5 + _launch_wheelspin * 2.4, 0.0, 5.2) * accel_auth) if (wants_reverse and forward_mps <= 2.6) else 0.0
		var brake_dive_boost: float = (-_brake_pressure * 6.8 * decel_auth) if (is_braking and forward_mps > 0.8) else 0.0
		var pitch_assist: float = (_smooth_long_accel * 0.92 + launch_squat_boost + rev_squat_boost + brake_dive_boost) * mass * body_pitch_torque_factor * 0.14
		apply_torque(car_right * pitch_assist)

		# Плавное демпфирование угловой скорости крена и тангажа кузова (чтобы подвеска работала упруго, без болтанки)
		var pitch_rate: float = angular_velocity.dot(car_right)
		var roll_rate_d: float = angular_velocity.dot(car_fwd)
		apply_torque(-car_right * pitch_rate * mass * 1.45)
		apply_torque(-car_fwd * roll_rate_d * mass * 1.65)

		if _launch_wheelspin > 0.14 and (wants_throttle or wants_reverse):
			var shudder_mult: float = 0.35 if drive_type == "AWD" else 0.56
			var torque_shudder: float = sin(float(Time.get_ticks_msec()) * 0.036) * _launch_wheelspin * mass * shudder_mult
			apply_torque(car_up * torque_shudder)

		if reversing_to_fwd and absf(cur_yaw_up) > 0.6:
			apply_torque(car_up * (-cur_yaw_up * mass * 2.4))

		# Cornering tire scrub drag gives heavy trucks & APCs palpable weight under hard steering
		if speed_mps > 3.0 and absf(steering) > 0.03:
			var steer_frac: float = clampf(absf(steering) / maxf(STEER_LIMIT, 0.02), 0.0, 1.0)
			apply_central_force(-linear_velocity.normalized() * steer_frac * speed_mps * mass * steering_scrub_drag * 0.22 * _surface_grip_mult)

		# Controlled 180 J-turn in reverse vs forward ESC stabilization
		if in_reverse_jturn:
			var jturn_dir: float = -signf(steering)
			var jturn_spd_t: float = clampf(absf(forward_mps) / 10.0, 0.25, 1.0)
			var jturn_str_t: float = clampf(absf(steering) / 0.45, 0.20, 1.0)
			var target_jturn_yaw: float = jturn_dir * lerpf(1.4, 3.1, jturn_spd_t) * jturn_str_t
			var cur_yaw_r: float = angular_velocity.dot(car_up)
			var jturn_trq: float = clampf((target_jturn_yaw - cur_yaw_r) * mass * 3.8, -mass * 7.2, mass * 7.2)
			apply_torque(car_up * jturn_trq)
		elif speed_mps > 2.5 and forward_mps > 1.5 and yaw_stability_assist > 0.01:
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
	if impact_t >= 0.72:
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

func _animate_supercharger(delta: float, rpm_ratio: float, throttle_ratio: float) -> void:
	if is_instance_valid(_sc_pulley):
		_sc_pulley.rotate_z(delta * lerpf(8.0, 48.0, clampf(rpm_ratio, 0.0, 1.0)))
	if is_instance_valid(_sc_butterflies):
		var target_x: float = deg_to_rad(clampf(throttle_ratio, 0.0, 1.0) * 56.0)
		_sc_butterflies.rotation.x = lerpf(_sc_butterflies.rotation.x, target_x, clampf(delta * 12.0, 0.0, 1.0))

func update_showcase_lights(delta: float = 0.016) -> void:
	if _showcase_mode and not destroyed and is_inside_tree():
		_update_visual_lights(delta, false, false)
		_sc_idle_phase += delta
		var flutter := 0.10 + 0.045 * sin(_sc_idle_phase * 2.8)
		_animate_supercharger(delta, 0.14, flutter)

func _process_vehicle_extras(_delta: float) -> void:
	pass

func _handle_zombie_overlapping_damage(delta: float) -> void:
	if destroyed or is_preview:
		return
	var eff_vel := _get_impact_vel_3d()
	var horiz_v := Vector2(eff_vel.x, eff_vel.z)
	var speed_mps: float = horiz_v.length()
	if speed_mps * MPS_TO_KMH < 4.0:
		return

	var hx: float = maxf(hull_half_extents.x, 0.85) + 0.42
	var hz: float = maxf(hull_half_extents.y, 1.90) + 0.48
	var sweep_extra: float = clampf(speed_mps * delta, 0.0, 1.25)
	var inv_xf: Transform3D = global_transform.affine_inverse()
	var vel_local: Vector3 = global_transform.basis.inverse() * eff_vel
	var moving_fwd: bool = vel_local.z < -0.5

	var cx: int = floori(global_position.x * 0.25)
	var cz: int = floori(global_position.z * 0.25)
	var hits: Array[Node3D] = []
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var bucket: Array = ZombiePool.get_grid_cell(cx + dx, cz + dz)
			for item in bucket:
				var z := item as Node3D
				if z == null or not is_instance_valid(z) or not z.visible:
					continue
				var z_st = z.get("state")
				if z_st != null and (int(z_st) == 3 or int(z_st) == 4):
					continue
				var rel: Vector3 = inv_xf * z.global_position
				if absf(rel.y) > 2.0 or absf(rel.x) > hx:
					continue
				var z_min: float = -hz - (sweep_extra if moving_fwd else 0.0)
				var z_max: float = hz + (sweep_extra if not moving_fwd else 0.0)
				if rel.z >= z_min and rel.z <= z_max:
					hits.append(z)

	for z_hit in hits:
		_impact_zombie(z_hit, eff_vel)

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
	if destroyed or is_preview or amount <= 0 or _intro_timer > 0.20:
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

func _get_node_local_aabb(node: Node3D) -> AABB:
	if node.has_meta("_cached_local_aabb"):
		return node.get_meta("_cached_local_aabb") as AABB
	var box := AABB()
	var has_b: bool = false
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.visible and mi.mesh != null:
				var rel_xf: Transform3D = Transform3D.IDENTITY
				if mi != node:
					var walker: Node3D = mi
					var acc_xf := Transform3D.IDENTITY
					while walker != null and walker != node:
						acc_xf = walker.transform * acc_xf
						walker = walker.get_parent() as Node3D
					rel_xf = acc_xf
				var la: AABB = mi.mesh.get_aabb()
				for ci in range(8):
					var pt: Vector3 = rel_xf * la.get_endpoint(ci)
					if not has_b:
						box = AABB(pt, Vector3.ZERO)
						has_b = true
					else:
						box = box.expand(pt)
		for ch in cur.get_children():
			stack.append(ch)
	if not has_b:
		box = AABB(Vector3(-0.45, 0.0, -0.45), Vector3(0.9, 1.2, 0.9))
	node.set_meta("_cached_local_aabb", box)
	return box

func _compute_impact_contact_points(target: Node3D, pre_vel: Vector3) -> Dictionary:
	var local_aabb: AABB = _get_node_local_aabb(target)
	var obj_center_world: Vector3 = target.global_transform * local_aabb.get_center()
	var hx: float = maxf(hull_half_extents.x, 0.85)
	var hz: float = maxf(hull_half_extents.y, 1.90)
	var to_obj_local: Vector3 = global_transform.affine_inverse() * obj_center_world
	var vel_local: Vector3 = global_transform.basis.inverse() * pre_vel
	var fallback_z: float = -hz if vel_local.z <= 0.1 else hz
	var car_pt_local := Vector3(
		clampf(to_obj_local.x, -hx, hx),
		clampf(to_obj_local.y, 0.48, 0.92),
		clampf(to_obj_local.z if absf(to_obj_local.z) > 0.25 else fallback_z, -hz, hz)
	)
	var car_pt: Vector3 = global_transform * car_pt_local
	var car_in_obj_local: Vector3 = target.global_transform.affine_inverse() * car_pt
	var obj_pt_local: Vector3 = car_in_obj_local.clamp(local_aabb.position, local_aabb.end)
	var obj_pt: Vector3 = target.global_transform * obj_pt_local
	var mid_pt: Vector3 = car_pt.lerp(obj_pt, 0.5)
	return {"car_pt": car_pt, "obj_pt": obj_pt, "mid_pt": mid_pt}

func _impact_zombie(body: Node3D, eff_vel: Vector3) -> void:
	if body == null or not is_instance_valid(body) or not body.visible:
		return
	var z_state_var = body.get("state")
	if z_state_var != null and (int(z_state_var) == 3 or int(z_state_var) == 4):
		return
	var horizontal_vel := Vector2(eff_vel.x, eff_vel.z)
	var speed_mps: float = horizontal_vel.length()
	var speed_kmh: float = speed_mps * MPS_TO_KMH
	if speed_kmh < 4.0:
		return

	var hx: float = maxf(hull_half_extents.x, 0.85)
	var hz: float = maxf(hull_half_extents.y, 1.90)
	var rel_local: Vector3 = global_transform.affine_inverse() * body.global_position
	var norm_x: float = clampf(rel_local.x / hx, -1.4, 1.4)
	var side_sign: float = (1.0 if rel_local.x >= 0.0 else -1.0)
	if absf(rel_local.x) < 0.06:
		side_sign = 1.0 if (body.get_instance_id() % 2) == 0 else -1.0

	var car_fwd := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()
	var car_right := Vector3(global_transform.basis.x.x, 0.0, global_transform.basis.x.z).normalized()
	var move_dir := Vector3(eff_vel.x, 0.0, eff_vel.z).normalized() if speed_mps > 0.5 else car_fwd

	var spd_t: float = clampf((speed_kmh - 12.0) / 110.0, 0.0, 1.0)
	var launch_vel: Vector3 = Vector3.ZERO
	var launch_h_dir: Vector3 = move_dir
	if rel_local.z < -hz * 0.15 and absf(norm_x) < 0.48:
		var fwd_spd: float = clampf(speed_mps * 0.88 + 0.9, 4.2, 31.0)
		var up_spd: float = clampf(1.35 + speed_mps * 0.17, 1.5, 6.8)
		var lat_spd: float = side_sign * lerpf(0.75, 3.2, spd_t) * (0.35 + absf(norm_x) * 0.85)
		launch_h_dir = (move_dir + car_right * (side_sign * 0.18)).normalized()
		launch_vel = move_dir * fwd_spd + car_right * lat_spd + Vector3.UP * up_spd
	else:
		var lat_bias: float = side_sign * clampf(absf(norm_x) * 0.85, 0.45, 1.05)
		launch_h_dir = (move_dir * 0.72 + car_right * lat_bias).normalized()
		var horiz_spd: float = clampf(speed_mps * 0.82 + 1.0, 4.0, 27.0)
		var up_spd: float = clampf(1.05 + speed_mps * 0.13, 1.2, 5.2)
		launch_vel = launch_h_dir * horiz_spd + Vector3.UP * up_spd

	# Сдвигаем точку старта тела сразу наружу, чтобы кости ragdoll не застревали внутри кузова
	body.global_position += launch_h_dir * 0.24 + Vector3.UP * lerpf(0.06, 0.18, spd_t)

	var vfx_pt: Vector3 = (global_transform * Vector3(clampf(rel_local.x, -hx, hx), 0.75, clampf(rel_local.z, -hz, hz))).lerp(body.global_position + Vector3.UP * 0.85, 0.45)
	CarVFX.spawn_impact(vfx_pt, "blood")

	var is_lethal: bool = speed_kmh >= 16.0
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_zombie_hit_thud"):
		sm.call("play_zombie_hit_thud", speed_kmh, is_lethal)
	elif sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "zombie_splat", -3.0, randf_range(0.85, 1.2))

	if is_lethal:
		if body.has_method("die"):
			body.call("die", eff_vel, speed_mps, launch_vel, side_sign)
		_on_zombie_killed()
		shake_camera(clampf(speed_mps / 55.0, 0.05, 0.22))
	else:
		if body.has_method("knockdown"):
			body.call("knockdown", launch_vel)

func _on_kill_zone_body_entered(body: Node3D) -> void:
	if destroyed or is_preview or body == null or body == self or body.is_in_group("player"):
		return

	var eff_vel := _get_impact_vel_3d()
	var horizontal_vel := Vector2(eff_vel.x, eff_vel.z)
	var speed_mps := horizontal_vel.length()
	var sm: Node = get_node_or_null("/root/SoundManager")

	if body.is_in_group("dead_wall"):
		if speed_mps >= crash_death_speed_mps:
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_heavy", 0.0, randf_range(0.9, 1.08))
			take_damage(current_hp, "СМЕРТЕЛЬНОЕ СТОЛКНОВЕНИЕ")
			trigger_camera_crash_impact(eff_vel, clampf(speed_mps / 14.0, 0.9, 1.9), 0.0)
			shake_camera(clampf(speed_mps / 10.0, 1.0, 4.0))
			CarVFX.spawn_impact(global_position, "dust")
			return

	if body.is_in_group("zombie"):
		_impact_zombie(body, eff_vel)
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
			var lat_b: float = clampf((body.global_position - global_position).dot(global_transform.basis.x) * 0.65, -1.0, 1.0)
			trigger_camera_crash_impact(eff_vel, clampf(speed_mps / 16.0, 0.35, 1.75), lat_b)
			shake_camera(clampf(float(damage_to_car) * 0.1, 0.2, 1.5))
			var pts: Dictionary = _compute_impact_contact_points(body, eff_vel)
			var car_pt: Vector3 = pts["car_pt"] as Vector3
			var obj_pt: Vector3 = pts["obj_pt"] as Vector3
			apply_body_deformation(car_pt, eff_vel, clampf(speed_mps / 14.0, 0.65, 1.85))
			CarVFX.spawn_contact_sparks(car_pt, -eff_vel + Vector3.UP * 2.5, speed_mps, false)
			CarVFX.spawn_crash_debris(obj_pt, -eff_vel, speed_mps, "metal", car_paint_color)
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_metal", -2.5, randf_range(0.85, 1.15))
			if body.has_method("take_damage"):
				body.take_damage(speed_mps * 2.0)
		return

	if body is CollisionObject3D and (body.collision_layer & 512) == 0 and (body.collision_layer & 4) != 0:
		if speed_mps > 3.0:
			var wpts: Dictionary = _compute_impact_contact_points(body, eff_vel)
			var w_car_pt: Vector3 = wpts["car_pt"] as Vector3
			var w_obj_pt: Vector3 = wpts["obj_pt"] as Vector3
			CarVFX.spawn_contact_sparks(w_car_pt, -eff_vel + Vector3.UP * 2.2, speed_mps, false)
			CarVFX.spawn_crash_debris(w_obj_pt, -eff_vel, speed_mps, "metal", car_paint_color)
			if sm and sm.has_method("play_sfx"):
				sm.call("play_sfx", "crash_metal", -5.0, randf_range(0.9, 1.15))
			if speed_mps > 5.0:
				apply_body_deformation(w_car_pt, eff_vel, clampf(speed_mps / 15.0, 0.55, 1.55))
				var wall_now := Time.get_ticks_msec()
				if wall_now - _last_wall_dmg_ms >= 220:
					_last_wall_dmg_ms = wall_now
					var wall_dmg := maxi(roundi(speed_mps * collision_damage_multiplier * 1.15 * clampf(1900.0 / maxf(mass, 600.0), 0.18, 1.0)), 1)
					take_damage(wall_dmg, "МАШИНА РАЗБИТА")
					var wall_lat: float = clampf((body.global_position - global_position).dot(global_transform.basis.x) * 0.5, -1.0, 1.0)
					trigger_camera_crash_impact(eff_vel, clampf(speed_mps / 18.0, 0.30, 1.65), wall_lat)

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
	var pts: Dictionary = _compute_impact_contact_points(body, pre_vel)
	var car_pt: Vector3 = pts["car_pt"] as Vector3
	var obj_pt: Vector3 = pts["obj_pt"] as Vector3
	var hit_res: Dictionary = {}
	if body.has_method("knock_down"):
		hit_res = body.call("knock_down", global_position, pre_vel, mass, self, obj_pt)
	if not hit_res.is_empty():
		var is_exploded: bool = bool(hit_res.get("exploded", false))
		var base_dmg: float = float(hit_res.get("damage", 4.0))
		var drag_k: float = float(hit_res.get("drag", 0.06))
		var prop_mass: float = maxf(float(hit_res.get("prop_mass", 180.0)), 30.0)
		var mat_k: String = str(hit_res.get("mat", "metal"))
		var dmg_to_car: int = 0
		if not is_exploded:
			var mass_dmg_scale: float = clampf(1900.0 / maxf(mass, 600.0), 0.14, 1.15)
			var spd_scale: float = clampf(speed_mps / 18.0, 0.35, 1.45)
			var hp_scale: float = clampf(float(health) / 900.0, 0.75, 2.2)
			var armor_scale: float = clampf(collision_damage_multiplier / 0.45, 0.45, 1.4)
			dmg_to_car = maxi(roundi(base_dmg * prop_damage_multiplier * mass_dmg_scale * spd_scale * hp_scale * armor_scale), 2)
			take_damage(dmg_to_car, "СТОЛКНОВЕНИЕ С ПРЕПЯТСТВИЕМ")
			apply_body_deformation(car_pt, pre_vel, clampf((speed_mps / 15.0) * (prop_mass / 240.0), 0.42, 1.35))
			if mat_k in ["metal", "metal_electric", "hydrant", "barrel_blue"]:
				CarVFX.spawn_contact_sparks(car_pt, -pre_vel + Vector3.UP * 2.2, speed_mps, mat_k == "metal_electric")
		else:
			apply_body_deformation(car_pt, pre_vel, clampf((speed_mps / 18.0) * 0.85, 0.45, 1.25))

		var mass_drag: float = (prop_mass / maxf(mass + prop_mass, 1.0)) * 0.90 + drag_k * (1600.0 / maxf(mass, 600.0)) * 0.42
		var keep_mitigation: float = 1.10 - clampf(impact_momentum_keep, 0.4, 0.98) * 0.65
		var slowdown: float = clampf(mass_drag * keep_mitigation, 0.005, 0.30)
		var cur_horiz := Vector2(linear_velocity.x, linear_velocity.z)
		var base_dir_vel := horiz_pre if horiz_pre.length_squared() >= cur_horiz.length_squared() else cur_horiz
		var new_horiz := base_dir_vel * (1.0 - slowdown)
		linear_velocity.x = new_horiz.x
		linear_velocity.z = new_horiz.y
		var prop_lat: float = clampf((body.global_position - global_position).dot(global_transform.basis.x) * 0.5, -1.0, 1.0)
		var prop_cam_int: float = clampf((speed_mps / 28.0) * clampf(prop_mass / 95.0, 0.35, 1.35), 0.16, 0.85)
		trigger_camera_crash_impact(pre_vel, prop_cam_int, prop_lat)
		shake_camera(clampf(float(maxi(dmg_to_car, 14 if is_exploded else 2)) * 0.045, 0.08, 0.75))

func _handle_wreck_obstacle_hit(wreck: RigidBody3D, pre_vel: Vector3) -> void:
	if not is_instance_valid(wreck) or wreck == self:
		return
	var horiz_pre := Vector2(pre_vel.x, pre_vel.z)
	var speed_mps := horiz_pre.length()
	if speed_mps < 1.8:
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
	var wfa: Node = wreck.get_node_or_null("WreckFallAudio")
	if wfa == null:
		var wfa_script: Resource = preload("res://core/wreck_fall_audio.gd")
		if wfa_script is GDScript:
			wfa = (wfa_script as GDScript).new() as Node
			if wfa != null:
				wreck.add_child(wfa)
	elif wfa.has_method("reset_tracking"):
		wfa.call("reset_tracking")
	var pts: Dictionary = _compute_impact_contact_points(wreck, pre_vel)
	var car_pt: Vector3 = pts["car_pt"] as Vector3
	var obj_pt: Vector3 = pts["obj_pt"] as Vector3
	var fwd_dir := Vector3(horiz_pre.x, 0.0, horiz_pre.y).normalized()
	var offset_xz := obj_pt - global_position
	offset_xz.y = 0.0
	var side_push := offset_xz - fwd_dir * offset_xz.dot(fwd_dir)
	var side_dir := side_push.normalized() if side_push.length_squared() > 0.002 else (Vector3.RIGHT * (1.0 if randf() > 0.5 else -1.0))
	var fwd_v: float = lerpf(0.55, 0.96, clampf((mass_share - 0.35) / 0.55, 0.0, 1.0))
	var lat_v: float = lerpf(0.32, 0.58, mass_share)
	var up_v: float = lerpf(0.18, 0.34, mass_share)
	var push_spd: float = clampf(speed_mps, 1.0, 38.0)
	var impulse_vec: Vector3 = (fwd_dir * fwd_v + side_dir * lat_v + Vector3.UP * up_v) * (actual_wreck_mass * push_spd)
	var est_vel := impulse_vec / maxf(actual_wreck_mass, 150.0)
	if est_vel.length() > 24.0:
		impulse_vec = est_vel.normalized() * (24.0 * actual_wreck_mass)
	var arm: Vector3 = (obj_pt - wreck.global_position).limit_length(2.2)
	wreck.apply_impulse(impulse_vec * 0.65, arm)
	wreck.apply_central_impulse(impulse_vec * 0.45)
	var hit_lat_sign: float = signf((obj_pt - wreck.global_position).dot(global_transform.basis.x))
	if absf(hit_lat_sign) < 0.1:
		hit_lat_sign = 1.0 if randf() > 0.5 else -1.0
	var spin_axis := Vector3.UP.cross(fwd_dir).normalized() * randf_range(0.45, 1.15) + Vector3.UP * (hit_lat_sign * randf_range(1.1, 2.2))
	wreck.apply_torque_impulse(spin_axis * actual_wreck_mass * 2.1)

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
	apply_body_deformation(car_pt, pre_vel, clampf((speed_mps / 13.0) * (eff_wreck_mass / 450.0), 0.72, 1.95))
	_crumple_wreck_obstacle(wreck, obj_pt, pre_vel, speed_mps)
	CarVFX.spawn_contact_sparks(car_pt, -pre_vel + global_transform.basis.y * 3.0, speed_mps, false)
	CarVFX.spawn_contact_sparks(obj_pt.lerp(car_pt, 0.35) + Vector3.UP * 0.35, -fwd_dir + Vector3.UP * 0.45, speed_mps, false)
	CarVFX.spawn_crash_debris(obj_pt, pre_vel * 0.45 - fwd_dir * 4.0 + Vector3.UP * 2.5, speed_mps, "wreck", car_paint_color)
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "crash_wreck_hit" if speed_mps > 12.0 else "crash_metal", -1.5, randf_range(0.86, 1.06))
	var wreck_lat: float = clampf((obj_pt - global_position).dot(global_transform.basis.x) * 0.5, -1.0, 1.0)
	trigger_camera_crash_impact(pre_vel, clampf(speed_mps / 18.0, 0.45, 1.65), wreck_lat)
	shake_camera(clampf(float(dmg_to_car) * 0.04 + (1.0 - keep_frac) * 0.45, 0.14, 0.90))

func _crumple_wreck_obstacle(wreck: RigidBody3D, obj_hit_pt: Vector3, pre_vel: Vector3, speed_mps: float) -> void:
	var wdef: CarDeformer = null
	if wreck.has_meta("_wreck_deformer"):
		wdef = wreck.get_meta("_wreck_deformer") as CarDeformer
	else:
		wdef = CarDeformer.new()
		wreck.set_meta("_wreck_deformer", wdef)
	var d_amt: float = wdef.deform_wreck_at_world_point(wreck, obj_hit_pt, pre_vel, clampf((speed_mps / 11.0) * clampf(wreck.mass / 550.0, 0.75, 1.35), 0.75, 2.0))
	if d_amt > 0.001:
		return
	var hits: int = int(wreck.get_meta("_crumple_hits")) if wreck.has_meta("_crumple_hits") else 0
	if hits >= 2:
		return
	wreck.set_meta("_crumple_hits", hits + 1)
	var strength: float = clampf((speed_mps - 3.0) / 22.0, 0.25, 0.85) * (1.0 if hits == 0 else 0.55)
	var hit_dir: Vector3 = Vector3(pre_vel.x, 0.0, pre_vel.z).normalized() if Vector2(pre_vel.x, pre_vel.z).length_squared() > 0.01 else Vector3.FORWARD
	var inv_b: Basis = wreck.global_transform.basis.inverse()
	var local_dir: Vector3 = (inv_b * hit_dir).normalized()
	var ax := Vector3(absf(local_dir.x), absf(local_dir.y), absf(local_dir.z))
	var max_c: float = maxf(maxf(ax.x, ax.y), maxf(ax.z, 0.001))
	ax /= max_c
	var sq_v := Vector3(
		clampf(1.0 - ax.x * 0.18 * strength + (1.0 - ax.x) * 0.06 * strength, 0.72, 1.15),
		clampf(1.0 - ax.y * 0.12 * strength + 0.04 * strength, 0.82, 1.14),
		clampf(1.0 - ax.z * 0.18 * strength + (1.0 - ax.z) * 0.06 * strength, 0.72, 1.15)
	)
	for ch in wreck.get_children():
		if ch is MeshInstance3D or (ch is Node3D and not (ch is CollisionShape3D)):
			var n3 := ch as Node3D
			n3.scale *= sq_v
			var bend_ax: Vector3 = Vector3.UP.cross(local_dir)
			if bend_ax.length_squared() > 0.001:
				n3.rotate(bend_ax.normalized(), deg_to_rad(6.5 * strength))

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
	if is_instance_valid(_ice_slide_audio):
		_ice_slide_audio.stop()
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
	_intro_timer = 0.0
	_intro_hud_hidden = false
	_set_gameplay_hud_alpha(1.0)
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
	if is_instance_valid(_ice_slide_audio):
		_ice_slide_audio.stop()

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

		# Радиальная взрывная волна: подбрасывает всех зомби вокруг машины в воздух
		var blast_origin: Vector3 = global_position
		var z_snap: Array = ZombiePool.active_zombies.duplicate()
		for z_var in z_snap:
			var z_node := z_var as Node3D
			if not is_instance_valid(z_node) or not z_node.visible:
				continue
			var z_st = z_node.get("state")
			if z_st != null and int(z_st) == 3:
				continue
			var to_z: Vector3 = z_node.global_position - blast_origin
			to_z.y = 0.0
			var dist_z: float = to_z.length()
			if dist_z > 22.0:
				continue
			var out_dir: Vector3 = (to_z / dist_z) if dist_z > 0.05 else Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
			var prox: float = clampf(1.0 - dist_z / 22.0, 0.15, 1.0)
			var blast_vel: Vector3 = out_dir * lerpf(11.0, 30.0, prox) + Vector3.UP * lerpf(6.0, 14.5, prox)
			if z_node.has_method("die"):
				z_node.call("die", blast_vel, blast_vel.length(), blast_vel, signf(out_dir.x))

		if get_tree():
			for p_var in get_tree().get_nodes_in_group("knockable_prop"):
				var p_node := p_var as Node3D
				if not is_instance_valid(p_node) or not p_node.visible:
					continue
				var pd: float = p_node.global_position.distance_to(blast_origin)
				if pd <= 14.0 and p_node.has_method("knock_down"):
					var p_out: Vector3 = (p_node.global_position - blast_origin).normalized() * 24.0
					p_node.call("knock_down", blast_origin, p_out, mass, self)

		var car_fwd_h := Vector3(-global_transform.basis.z.x, 0.0, -global_transform.basis.z.z).normalized()
		apply_central_impulse(Vector3(car_fwd_h.x * 2.2, 5.4, car_fwd_h.z * 2.2) * mass)
		apply_torque_impulse(Vector3(randf_range(0.85, 1.45), randf_range(-0.75, 0.75), randf_range(-1.35, 1.35)) * mass * 1.15)
		shake_camera(2.8)

	if _hud_death_rect:
		_hud_death_rect.show()
		var mat := _hud_death_rect.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("effect_strength", 0.0)
			var tween_blood := create_tween().set_ignore_time_scale(true)
			var target_vig := 0.32 if is_water_drown else 0.85
			tween_blood.tween_property(mat, "shader_parameter/effect_strength", target_vig, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	if is_explosive:
		await get_tree().create_timer(0.09, true, false, true).timeout
		if not is_inside_tree():
			return
		var tween_time := create_tween().set_ignore_time_scale(true)
		tween_time.tween_property(Engine, "time_scale", 0.16, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.15, true, false, true).timeout
	else:
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

	await get_tree().create_timer(1.70 if is_explosive else 1.15, true, false, true).timeout
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

func trigger_camera_crash_impact(world_impact_dir: Vector3, intensity: float = 1.0, lateral_bias: float = 0.0) -> void:
	if is_instance_valid(_camera) and _camera.has_method("trigger_crash_impact"):
		_camera.call("trigger_crash_impact", world_impact_dir, intensity, lateral_bias)

func _set_gameplay_hud_alpha(a: float) -> void:
	var hud := get_node_or_null("Hud") as CanvasLayer
	if hud == null:
		return
	var clamped_a := clampf(a, 0.0, 1.0)
	for ch in hud.get_children():
		if ch.name == "ColorRect" or ch.name == "Pause" or ch.name == "Check" or ch.name == "Fuel":
			continue
		if ch is CanvasItem:
			(ch as CanvasItem).modulate.a = clamped_a

func prepare_side_intro_pose(fwd_dir: Vector3 = Vector3.BACK) -> void:
	_intro_fwd = fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.BACK
	_intro_hud_hidden = true
	_set_gameplay_hud_alpha(0.0)
	if is_instance_valid(_camera) and _camera.has_method("prepare_side_intro"):
		_camera.call("prepare_side_intro", 1.0)

func start_run_intro(duration: float = 2.35, cruise_mps: float = 10.6, fwd_dir: Vector3 = Vector3.BACK) -> void:
	_intro_duration = maxf(duration, 0.5)
	_intro_timer = _intro_duration
	_intro_cruise_mps = cruise_mps
	_intro_fwd = fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.BACK
	_intro_hud_hidden = true
	set_initial_rolling_start(cruise_mps, _intro_fwd)
	_set_gameplay_hud_alpha(0.0)
	if is_instance_valid(_camera) and _camera.has_method("start_side_intro"):
		_camera.call("start_side_intro", _intro_duration, 1.0)

func set_initial_rolling_start(speed_mps: float, fwd_dir: Vector3) -> void:
	var dir := fwd_dir.normalized() if fwd_dir.length_squared() > 0.001 else Vector3.FORWARD
	linear_velocity = dir * speed_mps
	_prev_forward_mps = speed_mps
	_smooth_long_accel = 0.0
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
