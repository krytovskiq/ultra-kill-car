extends Camera3D

const MPS_TO_KMH := 3.6
const SPEED_EFFECTS_SHADER: Shader = preload("res://entities/camera/speed_effects.gdshader")

# === НАСТРОЙКИ КАМЕРЫ ===
@export_group("Позиция камеры (Обычная)")
## Высота камеры над дорогой в обычном режиме (в метрах)
@export var base_height := 3.12
## Дистанция камеры позади машины на низкой скорости (в метрах)
@export var base_distance := 4.25
## Базовый угол обзора камеры (FOV) при медленной езде
@export var base_fov := 68.0

@export_group("Позиция камеры (На скорости)")
## Высота камеры на максимальной скорости
@export var speed_height := 2.84
## Дистанция камеры на максимальной скорости
@export var speed_distance := 2.85
## Угол обзора (FOV) на максимальной скорости
@export var speed_fov := 96.0

@export_group("Эффект скорости и динамика")
## С какой скорости (км/ч) начинается лёгкая микровибрация камеры
@export var min_speed_for_shake := 115.0
## Максимальная амплитуда микротряски камеры от скорости
@export var max_speed_shake := 0.022
## Максимальный наклон камеры (крен в повороте, градусы)
@export var max_bank_roll_deg := 2.6
## Плавность следования позиции камеры
@export var follow_speed := 9.5
## Плавность поворота взгляда камеры за машиной
@export var look_speed := 14.0
## Плавность изменения FOV при разгоне
@export var fov_speed := 4.2
## Полноэкранный размывающий шейдер полос скорости (false = отключён, чтобы экран и HUD были чёткими)
@export var enable_speed_lines_shader := true

var _shake_intensity := 0.0
var _shake_decay := 5.5
var follow_this: Node3D
var last_lookat: Vector3 = Vector3.ZERO
var _max_speed_kmh: float = 200.0

var _prev_forward_mps: float = 0.0
var _smooth_accel: float = 0.0
var _smooth_steer_bias: float = 0.0
var _smooth_bank_rad: float = 0.0
var _smooth_boost_pulse: float = 0.0
var _rumble_time: float = 0.0
var _chase_dir: Vector3 = Vector3.BACK

var _airborne_blend: float = 0.0
var _landing_dip_y: float = 0.0
var _landing_dip_vel: float = 0.0
var _landing_pitch_rad: float = 0.0
var _landing_pitch_vel: float = 0.0
var _landing_fov_kick: float = 0.0
var _landing_flash_pulse: float = 0.0

var _speed_canvas: CanvasLayer = null
var _speed_rect: ColorRect = null
var _speed_mat: ShaderMaterial = null

func _ready() -> void:
	var walker := get_parent()
	while walker != null and walker is Node3D:
		if "linear_velocity" in walker:
			follow_this = walker
			break
		walker = walker.get_parent()

	if follow_this == null:
		follow_this = get_parent() as Node3D

	if follow_this == null:
		return

	top_level = true

	var max_spd = follow_this.get("MAX_SPEED_KMH")
	if max_spd != null and float(max_spd) > 0.0:
		_max_speed_kmh = float(max_spd)

	_chase_dir = _get_car_forward()
	global_position = _get_target_pos(0.0, 0.0, _chase_dir)
	last_lookat = follow_this.global_transform.origin + Vector3.UP * 1.24
	if not global_position.is_equal_approx(last_lookat):
		look_at(last_lookat, Vector3.UP)
	fov = base_fov

	if enable_speed_lines_shader:
		_setup_speed_overlay()

func _setup_speed_overlay() -> void:
	if not enable_speed_lines_shader or (follow_this and follow_this.get("is_preview") == true):
		return
	if is_instance_valid(_speed_canvas):
		return

	_speed_canvas = CanvasLayer.new()
	_speed_canvas.name = "SpeedEffectsOverlay"
	_speed_canvas.layer = 1
	add_child(_speed_canvas)

	_speed_rect = ColorRect.new()
	_speed_rect.name = "SpeedShaderRect"
	_speed_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speed_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speed_mat = ShaderMaterial.new()
	_speed_mat.shader = SPEED_EFFECTS_SHADER
	_speed_mat.set_shader_parameter("speed_ratio", 0.0)
	_speed_mat.set_shader_parameter("boost_pulse", 0.0)
	_speed_mat.set_shader_parameter("steer_bias", 0.0)
	_speed_mat.set_shader_parameter("effect_scale", _get_effect_scale())
	_speed_rect.material = _speed_mat
	_speed_rect.visible = false
	_speed_canvas.add_child(_speed_rect)

func _get_effect_scale() -> float:
	if follow_this and follow_this.get("is_preview") == true:
		return 0.0
	if SettingsManager and SettingsManager.has_method("get_speed_effect_scale"):
		return float(SettingsManager.get_speed_effect_scale())
	return 0.85

func _get_car_forward() -> Vector3:
	var car_forward := -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	if car_forward.length_squared() < 0.0001:
		return Vector3.BACK
	return car_forward.normalized()

func _physics_process(delta: float) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return
	if follow_this.get("is_preview") == true:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		return

	var in_water: bool = (follow_this.get("_in_water") == true) or (follow_this.get("_drowned_in_water") == true)
	if in_water:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		var water_y: float = float(follow_this.get("_water_surface_y")) if follow_this.get("_water_surface_y") != null else -12.4
		var splash_v: Variant = follow_this.get("_water_splash_pos")
		var splash_pos: Vector3 = splash_v if (splash_v is Vector3 and (splash_v as Vector3).length_squared() > 0.01) else Vector3(follow_this.global_position.x, water_y, follow_this.global_position.z)
		var w_dt := clampf(delta / maxf(Engine.time_scale, 0.05), 0.001, 0.08)
		_rumble_time += w_dt
		var view_goal := splash_pos - _chase_dir * (base_distance + 4.4) + Vector3.UP * 5.4
		view_goal.y = maxf(view_goal.y, water_y + 3.6)
		global_position = global_position.lerp(view_goal, clampf(w_dt * 2.8, 0.0, 1.0))
		global_position.y = maxf(global_position.y, water_y + 3.2)
		var car_p := follow_this.global_position
		var look_goal := Vector3(car_p.x, clampf(car_p.y + 0.5, water_y - 4.0, water_y + 2.0), car_p.z)
		last_lookat = last_lookat.lerp(look_goal, clampf(w_dt * 4.0, 0.0, 1.0))
		if not global_position.is_equal_approx(last_lookat):
			look_at(last_lookat, Vector3.UP)
		if _shake_intensity > 0.001:
			var rx := sin(_rumble_time * 31.0) * _shake_intensity * 0.14
			var ry := cos(_rumble_time * 27.0) * _shake_intensity * 0.12
			global_position.x += rx
			global_position.y = maxf(global_position.y + ry, water_y + 3.2)
			_shake_intensity = lerpf(_shake_intensity, 0.0, clampf(w_dt * _shake_decay, 0.0, 1.0))
		fov = lerpf(fov, base_fov + 2.0, clampf(w_dt * 2.5, 0.0, 1.0))
		return

	if follow_this.get("destroyed") == true:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		var dead_dt: float = maxf(delta / maxf(Engine.time_scale, 0.05), 0.001)
		var dead_origin := follow_this.global_transform.origin
		var dead_chase := _get_car_forward()
		var dead_pos := dead_origin - dead_chase * (base_distance + 2.4) + Vector3.UP * (base_height + 1.05)
		global_position = global_position.lerp(dead_pos, clampf(dead_dt * 2.2, 0.0, 1.0))
		last_lookat = last_lookat.lerp(dead_origin + Vector3.UP * 0.9, clampf(dead_dt * 3.0, 0.0, 1.0))
		if not global_position.is_equal_approx(last_lookat):
			look_at(last_lookat, Vector3.UP)
		fov = lerpf(fov, 64.0, clampf(dead_dt * 2.0, 0.0, 1.0))
		return

	var dt := maxf(delta, 0.001)
	_rumble_time += dt

	var vel: Vector3 = Vector3.ZERO
	if "linear_velocity" in follow_this:
		vel = follow_this.linear_velocity
	var horiz_vel := Vector3(vel.x, 0.0, vel.z)
	var speed_mps := horiz_vel.length()
	var speed_kmh := speed_mps * MPS_TO_KMH
	var speed_ratio := clampf(speed_kmh / maxf(_max_speed_kmh, 1.0), 0.0, 1.15)

	var car_fwd := _get_car_forward()
	var forward_mps := horiz_vel.dot(car_fwd)
	var raw_accel := clampf((forward_mps - _prev_forward_mps) / dt, -22.0, 22.0)
	_prev_forward_mps = forward_mps
	_smooth_accel = lerpf(_smooth_accel, raw_accel, clampf(dt * 6.5, 0.0, 1.0))

	# Blend chase direction toward actual velocity vector on drifts / turns
	var desired_dir := car_fwd
	if speed_mps > 6.0 and forward_mps > 3.0:
		var vel_dir := horiz_vel.normalized()
		desired_dir = car_fwd.lerp(vel_dir, clampf(speed_ratio * 0.42, 0.0, 0.42)).normalized()
	_chase_dir = _chase_dir.lerp(desired_dir, clampf(dt * 7.5, 0.0, 1.0)).normalized()

	# Атмосферная динамика камеры в прыжке (отдаление, ракурс снизу-вверх, парение)
	var gw_var = follow_this.get("grounded_wheels")
	var air_t_var = follow_this.get("_airborne_timer")
	var is_airborne: bool = (gw_var != null and int(gw_var) == 0 and air_t_var != null and float(air_t_var) > 0.03)
	var air_dur: float = float(air_t_var) if air_t_var != null else 0.0
	var target_air_blend: float = clampf((air_dur - 0.03) / 0.14, 0.0, 1.0) if is_airborne else 0.0
	var air_lerp_rate: float = 9.5 if is_airborne else 11.0
	_airborne_blend = lerpf(_airborne_blend, target_air_blend, clampf(dt * air_lerp_rate, 0.0, 1.0))

	# Пружинно-массовая физика проседания и упругого отскока камеры при приземлении на землю
	var spring_omega: float = 18.5
	var spring_zeta: float = 0.56
	var dip_acc: float = -(spring_omega * spring_omega) * _landing_dip_y - (2.0 * spring_omega * spring_zeta) * _landing_dip_vel
	_landing_dip_vel += dip_acc * dt
	_landing_dip_y = clampf(_landing_dip_y + _landing_dip_vel * dt, -1.15, 0.55)

	var pitch_omega: float = 20.0
	var pitch_acc: float = -(pitch_omega * pitch_omega) * _landing_pitch_rad - (2.0 * pitch_omega * 0.58) * _landing_pitch_vel
	_landing_pitch_vel += pitch_acc * dt
	_landing_pitch_rad = clampf(_landing_pitch_rad + _landing_pitch_vel * dt, -0.22, 0.14)
	_landing_fov_kick = lerpf(_landing_fov_kick, 0.0, clampf(dt * 8.5, 0.0, 1.0))
	_landing_flash_pulse = lerpf(_landing_flash_pulse, 0.0, clampf(dt * 5.5, 0.0, 1.0))

	var target_pos := _get_target_pos(clampf(speed_ratio, 0.0, 1.0), _smooth_accel, _chase_dir)
	var air_vy_lag: float = clampf(-vel.y * 0.048, -0.58, 0.48) * _airborne_blend
	target_pos += -_chase_dir * (1.28 * _airborne_blend) + Vector3.UP * (-0.38 * _airborne_blend + air_vy_lag + _landing_dip_y)

	var pos_follow := lerpf(follow_speed, follow_speed * 1.45, clampf(speed_ratio, 0.0, 1.0))
	global_position = global_position.lerp(target_pos, clampf(dt * pos_follow, 0.0, 1.0))
	global_position.y += _landing_dip_y * 0.38
	if follow_this.global_position.y < -4.0:
		var wy: float = float(follow_this.get("_water_surface_y")) if follow_this.get("_water_surface_y") != null else -12.4
		global_position.y = maxf(global_position.y, wy + 3.2)

	# Look-ahead shifts toward turn lateral motion + airborne lift & landing compression kick
	var car_origin := follow_this.global_transform.origin
	var car_right := follow_this.global_transform.basis.x
	car_right.y = 0.0
	if car_right.length_squared() > 0.0001:
		car_right = car_right.normalized()
	var lat_mps := horiz_vel.dot(car_right)
	var steer_val: float = float(follow_this.get("steering")) if follow_this.get("steering") != null else 0.0
	var lat_shift := clampf(lat_mps * 0.075 - steer_val * 0.85, -1.6, 1.6)

	var look_ahead := lerpf(2.0, 5.2, clampf(speed_ratio, 0.0, 1.0)) + _airborne_blend * 1.15
	var look_up_offset: float = 1.24 + _airborne_blend * 0.42 + _landing_dip_y * 0.65
	var look_target := car_origin + Vector3.UP * look_up_offset + _chase_dir * look_ahead + car_right * lat_shift
	last_lookat = last_lookat.lerp(look_target, clampf(dt * look_speed, 0.0, 1.0))
	if not global_position.is_equal_approx(last_lookat):
		look_at(last_lookat, Vector3.UP)

	# Subtle camera bank roll on turns + weightless airborne float + landing pitch punch
	var air_float_deg: float = sin(_rumble_time * 3.6) * 1.45 * _airborne_blend
	var target_bank_deg: float = clampf(-lat_mps * 0.18 + steer_val * 3.8, -max_bank_roll_deg, max_bank_roll_deg) * clampf(speed_ratio * 1.35, 0.15, 1.0) + air_float_deg
	_smooth_bank_rad = lerpf(_smooth_bank_rad, deg_to_rad(target_bank_deg), clampf(dt * 7.0, 0.0, 1.0))
	rotate_object_local(Vector3.BACK, _smooth_bank_rad)
	if absf(_landing_pitch_rad) > 0.0005:
		rotate_object_local(Vector3.RIGHT, _landing_pitch_rad)

	# Dynamic FOV ramp + acceleration surge punch + airborne panorama + landing snap
	var fov_curve := pow(clampf(speed_ratio, 0.0, 1.0), 1.35)
	var accel_fov := clampf(_smooth_accel * 0.30, -3.5, 5.5) * clampf(speed_ratio + 0.25, 0.25, 1.0)
	var air_fov := _airborne_blend * 7.8
	var target_fov := clampf(lerpf(base_fov, speed_fov, fov_curve) + accel_fov + air_fov + _landing_fov_kick, 58.0, 110.0)
	fov = lerpf(fov, target_fov, clampf(dt * (fov_speed + _airborne_blend * 2.5), 0.0, 1.0))

	# High-speed suspension micro-vibration + impact shake
	var shake_threshold := minf(min_speed_for_shake, _max_speed_kmh * 0.62)
	var current_speed_shake := 0.0
	if speed_kmh > shake_threshold:
		var shake_t := clampf((speed_kmh - shake_threshold) / maxf(_max_speed_kmh * 0.42, 25.0), 0.0, 1.0)
		current_speed_shake = shake_t * shake_t * max_speed_shake

	var total_shake := maxf(_shake_intensity, current_speed_shake)
	if total_shake > 0.001:
		var rumble_x := sin(_rumble_time * 31.0) * 0.6 + cos(_rumble_time * 53.0) * 0.4
		var rumble_y := cos(_rumble_time * 27.0) * 0.6 + sin(_rumble_time * 47.0) * 0.4
		var rumble_z := sin(_rumble_time * 19.0)
		var impact_jitter := _shake_intensity * 0.55

		rotation += Vector3(
			rumble_y * total_shake * 0.09 + randf_range(-impact_jitter, impact_jitter) * 0.07,
			rumble_x * total_shake * 0.07 + randf_range(-impact_jitter, impact_jitter) * 0.07,
			rumble_z * total_shake * 0.04
		)
		var pos_offset := Vector3(
			rumble_x * total_shake * 0.16,
			rumble_y * total_shake * 0.14,
			0.0
		)
		global_position += basis * pos_offset
		_shake_intensity = lerpf(_shake_intensity, 0.0, clampf(dt * _shake_decay, 0.0, 1.0))
	else:
		_shake_intensity = 0.0

	# Drive radial blur / speed lines shader overlay
	_smooth_steer_bias = lerpf(_smooth_steer_bias, clampf(lat_mps * 0.08, -1.0, 1.0), clampf(dt * 8.0, 0.0, 1.0))
	var target_pulse := clampf(_smooth_accel / 12.0 + _airborne_blend * 0.35 + _landing_flash_pulse, 0.0, 1.0)
	_smooth_boost_pulse = lerpf(_smooth_boost_pulse, target_pulse, clampf(dt * 8.0, 0.0, 1.0))
	if is_instance_valid(_speed_rect) and _speed_mat:
		var eff_scale := _get_effect_scale() if enable_speed_lines_shader else 0.0
		var show_fx := enable_speed_lines_shader and current and visible and eff_scale > 0.01 and (speed_ratio > 0.16 or _airborne_blend > 0.1 or _landing_flash_pulse > 0.1)
		_speed_rect.visible = show_fx
		if show_fx:
			_speed_mat.set_shader_parameter("speed_ratio", clampf(maxf(speed_ratio, _airborne_blend * 0.75 + _landing_flash_pulse * 0.65), 0.0, 1.2))
			_speed_mat.set_shader_parameter("boost_pulse", _smooth_boost_pulse)
			_speed_mat.set_shader_parameter("steer_bias", _smooth_steer_bias)
			_speed_mat.set_shader_parameter("effect_scale", eff_scale)

func _get_target_pos(speed_ratio: float, accel_mps2: float, chase_dir: Vector3) -> Vector3:
	var car_origin := follow_this.global_transform.origin
	var t := speed_ratio * speed_ratio
	var cur_height := lerpf(base_height, speed_height, t)
	var accel_pullback := clampf(accel_mps2 * 0.042, -0.35, 0.65)
	var cur_distance := lerpf(base_distance, speed_distance, t) + accel_pullback
	return car_origin - (chase_dir * cur_distance) + (Vector3.UP * cur_height)

func add_shake(amount: float) -> void:
	_shake_intensity = clampf(_shake_intensity + amount, 0.0, 3.0)

func trigger_landing_impact(impact_t: float = 1.0) -> void:
	var sev := clampf(impact_t, 0.35, 1.65)
	_landing_dip_y = minf(_landing_dip_y, -0.24 * sev)
	_landing_dip_vel = -clampf(sev * 6.8, 2.8, 9.8)
	_landing_pitch_rad = minf(_landing_pitch_rad, -0.045 * sev)
	_landing_pitch_vel = -clampf(sev * 1.35, 0.55, 2.15)
	_landing_fov_kick = -clampf(sev * 5.2, 2.0, 7.8)
	_landing_flash_pulse = clampf(sev * 0.85, 0.35, 1.0)
	_airborne_blend = 0.0
