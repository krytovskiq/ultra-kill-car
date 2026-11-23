class_name RaycastWheel
extends RayCast3D

@export_group("Wheel Geometry")
## Переднее колесо (true = передняя ось, false = задняя ось)
@export var is_front: bool = true
## Левое колесо (true = левый борт, false = правый борт)
@export var is_left: bool = true
## Поворачивается ли колесо от руля (обычно true только спереди)
@export var use_as_steering: bool = true
## Передаёт ли колесо тягу двигателя и тормозное усилие
@export var use_as_traction: bool = true
## Физический радиус колеса в метрах (должен совпадать с размером 3D-шины)
@export var wheel_radius: float = 0.36
## Рабочий ход подвески в метрах (длина сжатия пружины вверх от упора)
@export var rest_length: float = 0.18
## Запас вытяжения колеса вниз при отрыве/ямах (в метрах)
@export var over_extend: float = 0.09

@export_group("Suspension Tuning")
## Индивидуальная жёсткость пружины этого колеса (-1 = брать общую из скрипта машины)
@export var spring_stiffness_override: float = -1.0
## Индивидуальное демпфирование сжатия (-1 = из скрипта машины)
@export var damping_comp_override: float = -1.0
## Индивидуальное демпфирование отбоя (-1 = из скрипта машины)
@export var damping_rebound_override: float = -1.0
## Множитель сцепления конкретного колеса с дорогой (1.0 = стандарт)
@export var grip_multiplier: float = 1.0
## Скорость плавного подъёма/опускания 3D-модели колеса по кочкам
@export var visual_lerp_speed: float = 30.0

var base_rest_length: float = -1.0
var is_grounded: bool = false
var prev_compression_m: float = 0.0
var compression_m: float = 0.0
var compression_ratio: float = 0.0
var smooth_spring_vel: float = 0.0
var hub_to_ground_m: float = 0.45
var ground_point: Vector3 = Vector3.ZERO
var ground_normal: Vector3 = Vector3.UP
var lateral_slip_mps: float = 0.0
var forward_speed_mps: float = 0.0

## Запас подъёма точки старта луча вверх (внутрь арки), чтобы луч не проваливался под асфальт при пробое
const RAY_ORIGIN_LIFT: float = 0.62

var _steer_pivot: Node3D = null
var _spin_pivot: Node3D = null
var _visual_y: float = 0.0
var _initialized_pivots: bool = false
var _ray_query: PhysicsRayQueryParameters3D = null
var _ray_exclude: Array[RID] = []

func _ready() -> void:
	enabled = false
	exclude_parent = true
	collide_with_areas = false
	collide_with_bodies = true
	hit_from_inside = true
	collision_mask = 513 # World / Bridge (layer 1) + Procedural GroundBody (layer 512)
	target_position = Vector3(0.0, -(wheel_radius + rest_length + over_extend), 0.0)
	_setup_visual_pivots()

func _setup_visual_pivots() -> void:
	if _initialized_pivots:
		return
	_initialized_pivots = true

	var existing_children: Array[Node] = []
	for child in get_children():
		existing_children.append(child)

	_steer_pivot = Node3D.new()
	_steer_pivot.name = "WheelSteerPivot"
	add_child(_steer_pivot)

	_spin_pivot = Node3D.new()
	_spin_pivot.name = "WheelSpinPivot"
	_steer_pivot.add_child(_spin_pivot)

	for child in existing_children:
		remove_child(child)
		_spin_pivot.add_child(child)

func configure_ray() -> void:
	if base_rest_length <= 0.0:
		base_rest_length = rest_length
	hit_from_inside = true
	target_position = Vector3(0.0, -(wheel_radius + rest_length + over_extend), 0.0)

## Выполняет луч подвески сверху вниз от точки над колесом, чтобы при жёстком приземлении подвеска не залипала под дорогой
func cast_suspension_ray(space_state: PhysicsDirectSpaceState3D, car_body: PhysicsBody3D, car_up: Vector3) -> bool:
	if space_state == null:
		is_grounded = false
		hub_to_ground_m = wheel_radius + rest_length + over_extend
		compression_m = 0.0
		compression_ratio = 0.0
		return false

	if _ray_query == null:
		_ray_query = PhysicsRayQueryParameters3D.new()
		_ray_query.collide_with_areas = false
		_ray_query.collide_with_bodies = true
		_ray_query.hit_from_inside = true
	_ray_query.collision_mask = collision_mask
	if _ray_exclude.is_empty() and is_instance_valid(car_body):
		_ray_exclude.append(car_body.get_rid())
		_ray_query.exclude = _ray_exclude

	var gp: Vector3 = global_position
	_ray_query.from = gp + car_up * RAY_ORIGIN_LIFT
	_ray_query.to = gp - car_up * (wheel_radius + rest_length + over_extend)

	var hit: Dictionary = space_state.intersect_ray(_ray_query)
	if hit.is_empty():
		is_grounded = false
		hub_to_ground_m = wheel_radius + rest_length + over_extend
		compression_m = 0.0
		compression_ratio = 0.0
		return false

	is_grounded = true
	ground_point = hit["position"] as Vector3
	var n: Vector3 = hit["normal"] as Vector3
	ground_normal = n.normalized() if n.length_squared() >= 0.01 else Vector3.UP
	hub_to_ground_m = (gp - ground_point).dot(car_up)
	compression_m = clampf(wheel_radius + rest_length - hub_to_ground_m, 0.0, rest_length * 1.48)
	compression_ratio = compression_m / maxf(rest_length, 0.01)
	return true

func update_visuals(steer_angle: float, forward_mps: float, delta: float, is_preview_mode: bool = false) -> void:
	if _steer_pivot == null or _spin_pivot == null:
		return

	_steer_pivot.rotation.y = steer_angle if use_as_steering else 0.0

	var target_vis_y: float = 0.0
	if not is_preview_mode:
		if is_grounded:
			target_vis_y = clampf(-(hub_to_ground_m - wheel_radius), -rest_length * 0.68, rest_length * 0.72)
		else:
			target_vis_y = -(rest_length + over_extend * 0.65)

	var spd_mult: float = 1.45 if target_vis_y > _visual_y else 1.0
	var y_lerp: float = clampf(delta * visual_lerp_speed * spd_mult, 0.0, 1.0)
	_visual_y = lerpf(_visual_y, target_vis_y, y_lerp)
	_steer_pivot.position.y = _visual_y

	if not is_preview_mode:
		var r: float = maxf(wheel_radius, 0.12)
		var spin_delta: float = (forward_mps / r) * delta
		_spin_pivot.rotate_x(-spin_delta)
