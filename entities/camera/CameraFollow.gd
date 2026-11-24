extends Camera3D

const MPS_TO_KMH := 3.6
const SPEED_EFFECTS_SHADER: Shader = preload("res://entities/camera/speed_effects.gdshader")

# === НАСТРОЙКИ КАМЕРЫ ===
@export_group("Позиция камеры (Обычная)")
## Высота камеры над дорогой в обычном режиме (в метрах)
@export var base_height := 3.18
## Дистанция камеры позади машины на низкой скорости (в метрах)
@export var base_distance := 4.48
## Базовый угол обзора камеры (FOV) при медленной езде
@export var base_fov := 68.0

@export_group("Позиция камеры (На скорости)")
## Высота камеры на максимальной скорости
@export var speed_height := 2.64
## Дистанция камеры на максимальной скорости
@export var speed_distance := 3.62
## Угол обзора (FOV) на максимальной скорости
@export var speed_fov := 104.0

@export_group("Эффект скорости и динамика")
## С какой скорости (км/ч) начинается лёгкая микровибрация камеры
@export var min_speed_for_shake := 65.0
## Максимальная амплитуда микротряски камеры от скорости
@export var max_speed_shake := 0.032
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

var _base_follow_pos: Vector3 = Vector3.ZERO
var _base_fov: float = 68.0
var _crash_offset: Vector3 = Vector3.ZERO
var _crash_vel: Vector3 = Vector3.ZERO
var _crash_pitch_rad: float = 0.0
var _crash_pitch_vel: float = 0.0
var _crash_roll_rad: float = 0.0
var _crash_roll_vel: float = 0.0
var _crash_fov_kick: float = 0.0
var _crash_fov_vel: float = 0.0
var _air_cam_height_bias: float = 0.0
var _air_cam_pitch_bias: float = 0.0

var _speed_canvas: CanvasLayer = null
var _speed_rect: ColorRect = null
var _speed_mat: ShaderMaterial = null

var _intro_active: bool = false
var _intro_armed_waiting: bool = false
var _intro_elapsed: float = 0.0
var _intro_duration: float = 2.35
var _intro_side: float = 1.0

var _veh_calibrated: bool = false
var _veh_height_extra: float = 0.0
var _veh_dist_extra: float = 0.0
var _veh_look_y: float = 1.32

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

	recalibrate_to_vehicle(true)
	_base_fov = base_fov
	fov = _base_fov

	if enable_speed_lines_shader:
		_setup_speed_overlay()

func _local_to_ancestor(node: Node3D, ancestor: Node) -> Transform3D:
	var acc := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != ancestor:
		acc = cur.transform * acc
		cur = cur.get_parent() as Node3D
	return acc

func recalibrate_to_vehicle(snap_pose: bool = true) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return
	var max_spd = follow_this.get("MAX_SPEED_KMH")
	if max_spd != null and float(max_spd) > 0.0:
		_max_speed_kmh = float(max_spd)

	var inv_car: Transform3D = follow_this.global_transform.affine_inverse() if follow_this.is_inside_tree() else follow_this.transform.affine_inverse()
	var has_top: bool = false
	var veh_top_y: float = 1.55
	var stack: Array[Node] = [follow_this]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		if cur != follow_this:
			var cname := String(cur.name)
			if cur is Area3D or cur is RaycastWheel or cur is CPUParticles3D or cur is Camera3D or cname == "look" or cname == "VisualLightsRig" or cname == "PropTriggerArea" or cname == "EngineDamageFire" or cname == "MuzzleFlashRig" or cname == "Turret_Gun" or cname == "FullUpgradeArmorKit" or cname.begins_with("KitStage_"):
				continue
			if cur is CollisionShape3D:
				var cs := cur as CollisionShape3D
				if cs.shape != null and not cs.disabled:
					var top_local_y: float = cs.position.y
					if cs.shape is BoxShape3D:
						top_local_y += (cs.shape as BoxShape3D).size.y * 0.5
					elif cs.shape is CapsuleShape3D:
						top_local_y += (cs.shape as CapsuleShape3D).height * 0.5
					elif cs.shape is SphereShape3D:
						top_local_y += (cs.shape as SphereShape3D).radius
					veh_top_y = maxf(veh_top_y, top_local_y) if has_top else top_local_y
					has_top = true
			elif cur is MeshInstance3D:
				var mi := cur as MeshInstance3D
				if mi.visible and mi.mesh != null:
					var xf: Transform3D = (inv_car * mi.global_transform) if (follow_this.is_inside_tree() and mi.is_inside_tree()) else _local_to_ancestor(mi, follow_this)
					var ma: AABB = mi.mesh.get_aabb()
					for ci in range(8):
						var pt: Vector3 = xf * ma.get_endpoint(ci)
						veh_top_y = maxf(veh_top_y, pt.y) if has_top else pt.y
						has_top = true
		for ch in cur.get_children():
			stack.append(ch)
	veh_top_y = clampf(veh_top_y, 1.15, 3.60)
	var veh_half_len: float = 2.40
	var ext_v = follow_this.get("hull_half_extents")
	if ext_v is Vector2:
		veh_half_len = clampf((ext_v as Vector2).y, 1.80, 4.20)

	var tall_excess: float = maxf(veh_top_y - 1.65, 0.0)
	var long_excess: float = maxf(veh_half_len - 2.25, 0.0)
	_veh_height_extra = tall_excess * 1.45
	_veh_dist_extra = long_excess * 1.35 + tall_excess * 0.65
	_veh_look_y = 1.30 + tall_excess * 0.68
	_veh_calibrated = true

	if snap_pose and not _intro_active and not _intro_armed_waiting and follow_this.is_inside_tree():
		_chase_dir = _get_car_forward()
		_base_follow_pos = _get_target_pos(0.0, 0.0, _chase_dir)
		global_position = _base_follow_pos
		last_lookat = follow_this.global_transform.origin + Vector3.UP * _veh_look_y
		if not global_position.is_equal_approx(last_lookat):
			look_at(last_lookat, Vector3.UP)

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
	if not _veh_calibrated:
		recalibrate_to_vehicle(false)

	var in_water: bool = (follow_this.get("_in_water") == true) or (follow_this.get("_drowned_in_water") == true)
	if in_water:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		var water_y: float = float(follow_this.get("_water_surface_y")) if follow_this.get("_water_surface_y") != null else -12.4
		var splash_v: Variant = follow_this.get("_water_splash_pos")
		var splash_pos: Vector3 = splash_v if (splash_v is Vector3 and (splash_v as Vector3).length_squared() > 0.01) else Vector3(follow_this.global_position.x, water_y, follow_this.global_position.z)
		var w_dt := clampf(delta / maxf(Engine.time_scale, 0.05), 0.001, 0.08)
		_rumble_time += w_dt
		var view_goal := splash_pos - _chase_dir * (base_distance + _veh_dist_extra + 4.4) + Vector3.UP * (5.4 + _veh_height_extra)
		view_goal.y = maxf(view_goal.y, water_y + 3.6)
		global_position = global_position.lerp(view_goal, clampf(w_dt * 2.8, 0.0, 1.0))
		_base_follow_pos = global_position
		global_position.y = maxf(global_position.y, water_y + 3.2)
		var car_p := follow_this.global_position
		var look_goal := Vector3(car_p.x, clampf(car_p.y + _veh_look_y * 0.45, water_y - 4.0, water_y + 2.0), car_p.z)
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
		_intro_active = false
		_intro_armed_waiting = false
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		var dead_dt: float = maxf(delta / maxf(Engine.time_scale, 0.05), 0.001)
		var dead_origin := follow_this.global_transform.origin
		var dead_chase := _get_car_forward()
		var dead_pos := dead_origin - dead_chase * (base_distance + _veh_dist_extra + 2.4) + Vector3.UP * (base_height + _veh_height_extra + 1.05)
		global_position = global_position.lerp(dead_pos, clampf(dead_dt * 2.2, 0.0, 1.0))
		_base_follow_pos = global_position
		last_lookat = last_lookat.lerp(dead_origin + Vector3.UP * _veh_look_y * 0.75, clampf(dead_dt * 3.0, 0.0, 1.0))
		if not global_position.is_equal_approx(last_lookat):
			look_at(last_lookat, Vector3.UP)
		fov = lerpf(fov, 64.0, clampf(dead_dt * 2.0, 0.0, 1.0))
		return

	if _intro_armed_waiting:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		_apply_intro_pose(0.0)
		return

	if _intro_active:
		if is_instance_valid(_speed_rect):
			_speed_rect.visible = false
		_intro_elapsed += maxf(delta, 0.001)
		var t_intro := clampf(_intro_elapsed / maxf(_intro_duration, 0.01), 0.0, 1.0)
		_apply_intro_pose(t_intro)
		if t_intro >= 1.0:
			_intro_active = false
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

	# Blend chase direction toward actual velocity vector on drifts / turns (stay behind hood during reverse J-turns)
	var desired_dir := car_fwd
	if speed_mps > 6.0 and forward_mps > 3.0:
		var vel_dir := horiz_vel.normalized()
		desired_dir = car_fwd.lerp(vel_dir, clampf(speed_ratio * 0.42, 0.0, 0.42)).normalized()
	var chase_rate: float = 4.2 if forward_mps < -1.5 else 7.5
	_chase_dir = _chase_dir.lerp(desired_dir, clampf(dt * chase_rate, 0.0, 1.0)).normalized()

	var abs_speed_t: float = clampf((speed_kmh - 22.0) / 145.0, 0.0, 1.22)
	var visual_speed_t: float = clampf(maxf(speed_ratio, abs_speed_t * 0.94), 0.0, 1.25)
	var vis_t01: float = clampf(visual_speed_t, 0.0, 1.0)

	# Атмосферная динамика камеры в прыжке (отдаление, ракурс снизу-вверх, парение)
	var gw_var = follow_this.get("grounded_wheels")
	var air_t_var = follow_this.get("_airborne_timer")
	var is_airborne: bool = (gw_var != null and int(gw_var) == 0 and air_t_var != null and float(air_t_var) > 0.03)
	var air_dur: float = float(air_t_var) if air_t_var != null else 0.0
	var target_air_blend: float = clampf((air_dur - 0.03) / 0.14, 0.0, 1.0) if is_airborne else 0.0
	var air_lerp_rate: float = 9.5 if is_airborne else 11.0
	_airborne_blend = lerpf(_airborne_blend, target_air_blend, clampf(dt * air_lerp_rate, 0.0, 1.0))

	# Пружинно-массовая физика проседания и упругого отскока камеры при приземлении и столкновении
	var spring_omega: float = 10.5
	var spring_zeta: float = 0.44
	var dip_acc: float = -(spring_omega * spring_omega) * _landing_dip_y - (2.0 * spring_omega * spring_zeta) * _landing_dip_vel
	_landing_dip_vel += dip_acc * dt
	_landing_dip_y = clampf(_landing_dip_y + _landing_dip_vel * dt, -1.35, 0.65)

	var pitch_omega: float = 14.5
	var pitch_acc: float = -(pitch_omega * pitch_omega) * _landing_pitch_rad - (2.0 * pitch_omega * 0.48) * _landing_pitch_vel
	_landing_pitch_vel += pitch_acc * dt
	_landing_pitch_rad = clampf(_landing_pitch_rad + _landing_pitch_vel * dt, -0.26, 0.16)
	_landing_fov_kick = lerpf(_landing_fov_kick, 0.0, clampf(dt * 8.5, 0.0, 1.0))
	_landing_flash_pulse = lerpf(_landing_flash_pulse, 0.0, clampf(dt * 5.5, 0.0, 1.0))

	# Направленная физика отдачи камеры при ударе (погружение вперёд в момент столкновения + крен + кивок)
	var crash_omega: float = 13.5
	var crash_zeta: float = 0.48
	var crash_acc: Vector3 = -(crash_omega * crash_omega) * _crash_offset - (2.0 * crash_omega * crash_zeta) * _crash_vel
	_crash_vel += crash_acc * dt
	_crash_offset.x = clampf(_crash_offset.x + _crash_vel.x * dt, -0.95, 0.95)
	_crash_offset.y = clampf(_crash_offset.y + _crash_vel.y * dt, -0.85, 0.55)
	_crash_offset.z = clampf(_crash_offset.z + _crash_vel.z * dt, -1.10, 0.55)

	var cp_omega: float = 15.0
	var cp_acc: float = -(cp_omega * cp_omega) * _crash_pitch_rad - (2.0 * cp_omega * 0.48) * _crash_pitch_vel
	_crash_pitch_vel += cp_acc * dt
	_crash_pitch_rad = clampf(_crash_pitch_rad + _crash_pitch_vel * dt, -0.24, 0.16)

	var cr_omega: float = 12.0
	var cr_acc: float = -(cr_omega * cr_omega) * _crash_roll_rad - (2.0 * cr_omega * 0.50) * _crash_roll_vel
	_crash_roll_vel += cr_acc * dt
	_crash_roll_rad = clampf(_crash_roll_rad + _crash_roll_vel * dt, -0.22, 0.22)

	var cf_omega: float = 11.5
	var cf_acc: float = -(cf_omega * cf_omega) * _crash_fov_kick - (2.0 * cf_omega * 0.52) * _crash_fov_vel
	_crash_fov_vel += cf_acc * dt
	_crash_fov_kick = clampf(_crash_fov_kick + _crash_fov_vel * dt, -8.5, 4.5)

	var target_air_h: float = 0.0
	var target_air_p: float = 0.0
	if _airborne_blend > 0.05 and air_dur > 0.08:
		var descent_t: float = clampf(-vel.y / 11.0, 0.0, 1.0)
		target_air_h = lerpf(0.28, 0.85, descent_t) * _airborne_blend
		target_air_p = -deg_to_rad(lerpf(1.6, 4.8, descent_t)) * _airborne_blend
	_air_cam_height_bias = lerpf(_air_cam_height_bias, target_air_h, clampf(dt * (7.5 if _airborne_blend > 0.1 else 12.0), 0.0, 1.0))
	_air_cam_pitch_bias = lerpf(_air_cam_pitch_bias, target_air_p, clampf(dt * (7.5 if _airborne_blend > 0.1 else 12.0), 0.0, 1.0))

	var target_pos := _get_target_pos(vis_t01, _smooth_accel, _chase_dir)
	var air_vy_lag: float = clampf(-vel.y * 0.048, -0.58, 0.48) * _airborne_blend
	target_pos += -_chase_dir * (1.28 * _airborne_blend) + Vector3.UP * (-0.38 * _airborne_blend + air_vy_lag)

	var pos_follow := lerpf(follow_speed, follow_speed * 1.45, vis_t01)
	if _base_follow_pos == Vector3.ZERO:
		_base_follow_pos = global_position
	_base_follow_pos = _base_follow_pos.lerp(target_pos, clampf(dt * pos_follow, 0.0, 1.0))

	var car_origin := follow_this.global_transform.origin
	var car_right := follow_this.global_transform.basis.x
	car_right.y = 0.0
	if car_right.length_squared() > 0.0001:
		car_right = car_right.normalized()

	var fwd_lunge: float = clampf(-_crash_offset.z, -0.55, 1.05)
	var lunge_lift: float = maxf(fwd_lunge, 0.0) * 0.22
	global_position = _base_follow_pos + car_right * _crash_offset.x + Vector3.UP * (_crash_offset.y + _landing_dip_y + _air_cam_height_bias + lunge_lift) + _chase_dir * fwd_lunge
	if follow_this.global_position.y < -4.0:
		var wy: float = float(follow_this.get("_water_surface_y")) if follow_this.get("_water_surface_y") != null else -12.4
		global_position.y = maxf(global_position.y, wy + 3.2)

	# Look-ahead shifts toward turn lateral motion + airborne lift & landing compression kick
	var lat_mps := horiz_vel.dot(car_right)
	var steer_val: float = float(follow_this.get("steering")) if follow_this.get("steering") != null else 0.0
	var lat_shift := clampf(lat_mps * 0.075 - steer_val * 0.85, -1.6, 1.6)

	var look_ahead := lerpf(2.0, 5.2, clampf(speed_ratio, 0.0, 1.0)) + _airborne_blend * 1.15
	var look_up_offset: float = _veh_look_y + _airborne_blend * 0.36 + (_landing_dip_y + _crash_offset.y) * 0.52
	var look_target := car_origin + Vector3.UP * look_up_offset + _chase_dir * look_ahead + car_right * (lat_shift + _crash_offset.x * 0.45)
	last_lookat = last_lookat.lerp(look_target, clampf(dt * look_speed, 0.0, 1.0))
	if not global_position.is_equal_approx(last_lookat):
		look_at(last_lookat, Vector3.UP)

	# Subtle camera bank roll on turns + weightless airborne float + landing/crash pitch & roll punch
	var air_float_deg: float = sin(_rumble_time * 3.6) * 1.45 * _airborne_blend
	var target_bank_deg: float = clampf(-lat_mps * 0.18 + steer_val * 3.8, -max_bank_roll_deg, max_bank_roll_deg) * clampf(speed_ratio * 1.35, 0.15, 1.0) + air_float_deg
	_smooth_bank_rad = lerpf(_smooth_bank_rad, deg_to_rad(target_bank_deg), clampf(dt * 7.0, 0.0, 1.0))
	rotate_object_local(Vector3.BACK, _smooth_bank_rad + _crash_roll_rad)
	var total_pitch_off: float = _landing_pitch_rad + _crash_pitch_rad + _air_cam_pitch_bias
	if absf(total_pitch_off) > 0.0005:
		rotate_object_local(Vector3.RIGHT, total_pitch_off)

	# Dynamic FOV ramp + acceleration surge punch + airborne panorama + landing/crash snap
	var fov_curve := pow(vis_t01, 0.85)
	var accel_fov := clampf(_smooth_accel * 0.34, -3.5, 6.2) * clampf(vis_t01 + 0.25, 0.25, 1.0)
	var air_fov := _airborne_blend * 7.8
	var target_fov := clampf(lerpf(base_fov, speed_fov, fov_curve) + accel_fov + air_fov + _landing_fov_kick, 56.0, 114.0)
	_base_fov = lerpf(_base_fov, target_fov, clampf(dt * (fov_speed + _airborne_blend * 2.5), 0.0, 1.0))
	fov = clampf(_base_fov + _crash_fov_kick * 0.55, 54.0, 116.0)

	# High-speed suspension micro-vibration + impact shake
	var shake_threshold := minf(min_speed_for_shake, _max_speed_kmh * 0.50)
	var current_speed_shake := 0.0
	if speed_kmh > shake_threshold:
		var shake_t := clampf((speed_kmh - shake_threshold) / maxf(_max_speed_kmh * 0.52, 45.0), 0.0, 1.0)
		current_speed_shake = pow(shake_t, 1.65) * max_speed_shake

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
		var show_fx := enable_speed_lines_shader and current and visible and eff_scale > 0.01 and (visual_speed_t > 0.12 or _airborne_blend > 0.1 or _landing_flash_pulse > 0.1)
		_speed_rect.visible = show_fx
		if show_fx:
			_speed_mat.set_shader_parameter("speed_ratio", clampf(maxf(visual_speed_t, _airborne_blend * 0.75 + _landing_flash_pulse * 0.65), 0.0, 1.2))
			_speed_mat.set_shader_parameter("boost_pulse", _smooth_boost_pulse)
			_speed_mat.set_shader_parameter("steer_bias", _smooth_steer_bias)
			_speed_mat.set_shader_parameter("effect_scale", eff_scale)

func _get_target_pos(speed_ratio: float, accel_mps2: float, chase_dir: Vector3) -> Vector3:
	var car_origin := follow_this.global_transform.origin
	var t := speed_ratio * speed_ratio
	var cur_height := lerpf(base_height, speed_height, t) + _veh_height_extra
	var accel_pullback := clampf(accel_mps2 * 0.042, -0.35, 0.65)
	var cur_distance := lerpf(base_distance, speed_distance, t) + _veh_dist_extra + accel_pullback
	return car_origin - (chase_dir * cur_distance) + (Vector3.UP * cur_height)

func prepare_side_intro(side_sign: float = 1.0) -> void:
	_intro_side = -1.0 if side_sign < 0.0 else 1.0
	_intro_armed_waiting = true
	_intro_active = false
	_intro_elapsed = 0.0
	_apply_intro_pose(0.0)

func start_side_intro(duration: float = 2.35, side_sign: float = 1.0) -> void:
	_intro_duration = maxf(duration, 0.5)
	_intro_side = -1.0 if side_sign < 0.0 else 1.0
	_intro_armed_waiting = false
	_intro_active = true
	_intro_elapsed = 0.0
	_apply_intro_pose(0.0)

func _apply_intro_pose(t_norm: float) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return
	var t := clampf(t_norm, 0.0, 1.0)
	var u := t * t * t * (t * (t * 6.0 - 15.0) + 10.0)

	var car_origin := follow_this.global_transform.origin
	var car_fwd := _get_car_forward()
	var car_right := follow_this.global_transform.basis.x
	car_right.y = 0.0
	if car_right.length_squared() > 0.0001:
		car_right = car_right.normalized()
	else:
		car_right = Vector3.RIGHT

	var vel := Vector3.ZERO
	if "linear_velocity" in follow_this:
		vel = follow_this.linear_velocity
	var speed_mps := Vector2(vel.x, vel.z).length()
	var speed_ratio := clampf((speed_mps * MPS_TO_KMH) / maxf(_max_speed_kmh, 1.0), 0.0, 1.0)
	_prev_forward_mps = Vector3(vel.x, 0.0, vel.z).dot(car_fwd)

	var chase_pos := _get_target_pos(speed_ratio, 0.0, car_fwd)
	var chase_dist := maxf(Vector2(chase_pos.x - car_origin.x, chase_pos.z - car_origin.z).length(), base_distance + _veh_dist_extra)
	var chase_h := chase_pos.y - car_origin.y
	var chase_look := car_origin + Vector3.UP * _veh_look_y + car_fwd * lerpf(2.0, 5.2, speed_ratio)

	# Облетаем сбоку дороги (56°) через чистый бок (90°) прямо в кормовой ракурс (180°) позади машины
	var theta := lerpf(deg_to_rad(56.0), PI, u)
	var orbit_dir := (car_fwd * cos(theta) + car_right * (sin(theta) * _intro_side)).normalized()
	var cur_dist := lerpf(7.6 + _veh_dist_extra * 0.5, chase_dist, u)
	var cur_h := lerpf(1.48 + _veh_height_extra * 0.5, chase_h, u)

	global_position = car_origin + orbit_dir * cur_dist + Vector3.UP * cur_h
	_base_follow_pos = global_position
	var side_look := car_origin + Vector3.UP * 1.02 + car_fwd * 0.75
	last_lookat = side_look.lerp(chase_look, u)
	_chase_dir = car_fwd
	_base_fov = lerpf(52.0, base_fov, u)
	fov = _base_fov
	if is_inside_tree() and not global_position.is_equal_approx(last_lookat):
		look_at(last_lookat, Vector3.UP)

func add_shake(amount: float) -> void:
	_shake_intensity = clampf(_shake_intensity + amount, 0.0, 3.0)

func trigger_crash_impact(world_impact_dir: Vector3, intensity: float = 1.0, lateral_bias: float = 0.0) -> void:
	var sev := clampf(intensity, 0.15, 2.0)
	var h_dir := Vector3(world_impact_dir.x, 0.0, world_impact_dir.z)
	var fwd_proj: float = 1.0
	var right_proj: float = 0.0
	if h_dir.length_squared() > 0.0004:
		h_dir = h_dir.normalized()
		fwd_proj = clampf(h_dir.dot(_chase_dir), -1.0, 1.0)
		var cam_right := _chase_dir.cross(Vector3.UP).normalized()
		if cam_right.length_squared() > 0.0004:
			right_proj = h_dir.dot(cam_right)
	_crash_vel.z -= (3.8 + 4.8 * sev) * clampf(absf(fwd_proj), 0.35, 1.25)
	_crash_vel.x += (lateral_bias * 3.0 - right_proj * 2.4) * sev
	_crash_vel.y -= (0.95 + 1.15 * sev)
	_crash_pitch_vel -= deg_to_rad(18.5 + 22.5 * sev)
	_crash_roll_vel += deg_to_rad((lateral_bias * 11.0 + clampf(-right_proj * 7.5, -8.5, 8.5)) * sev)
	_crash_fov_vel -= (16.0 + 20.0 * sev)
	add_shake(clampf(0.18 + sev * 0.32, 0.0, 1.15))

func trigger_landing_impact(impact_t: float = 1.0) -> void:
	var sev := clampf(impact_t, 0.35, 1.75)
	_landing_dip_y = minf(_landing_dip_y, -0.26 * sev)
	_landing_dip_vel = -clampf(3.8 + sev * 4.6, 3.2, 11.2)
	_landing_pitch_rad = minf(_landing_pitch_rad, -0.048 * sev)
	_landing_pitch_vel = -clampf(deg_to_rad(9.5 + 10.5 * sev), 0.25, 2.45)
	_landing_fov_kick = -clampf(sev * 5.6, 2.2, 8.2)
	_landing_flash_pulse = clampf(sev * 0.88, 0.35, 1.0)
	_crash_vel.z -= 1.8 * sev
	_crash_fov_vel -= 7.2 * sev
	_airborne_blend = 0.0
