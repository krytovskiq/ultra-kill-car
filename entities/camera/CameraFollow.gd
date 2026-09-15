extends Camera3D

## Базовые расстояния
@export var base_height := 3.5          # Высота камеры над машиной (стоя)
@export var base_distance := 4.0        # Расстояние сзади (стоя)
@export var base_fov := 65.0            # FOV стоя

## Эффект скорости
@export var speed_height := 3.0         # Высота на макс. скорости (ниже = круче)
@export var speed_distance := 4.5      # Расстояние на макс. скорости (дальше = обзор)
@export var speed_fov := 95.0           # FOV на макс. скорости (широко)

## Плавность
@export var follow_speed := 6.0         # Как быстро камера догоняет
@export var look_speed := 12.0          # Как быстро наводится прицел
@export var fov_speed := 3.0            # Скорость перехода FOV

## Тряска при ударе
var _shake_intensity := 0.0
var _shake_decay := 5.0

var follow_this: Node3D
var last_lookat: Vector3 = Vector3.ZERO
var _max_speed_kmh: float = 200.0

func _ready() -> void:
	follow_this = get_parent() as Node3D
	if follow_this == null:
		return

	# Камера летает свободно в мировом пространстве
	top_level = true

	# Достаём максимальную скорость из машины
	if follow_this.get("MAX_SPEED_KMH"):
		_max_speed_kmh = float(follow_this.MAX_SPEED_KMH)

	global_position = _get_target_pos(0.0)
	last_lookat = follow_this.global_transform.origin + Vector3.UP
	fov = base_fov

func _physics_process(delta: float) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return

	# Считаем скорость машины
	var speed_mps: float = 0.0
	if follow_this.get("linear_velocity") != null:
		speed_mps = follow_this.linear_velocity.length()
	var speed_kmh := speed_mps * 3.6
	var speed_ratio := clampf(speed_kmh / _max_speed_kmh, 0.0, 1.0)

	# --- 1. ПОЗИЦИЯ: плавный полёт ---
	var target_pos = _get_target_pos(speed_ratio)
	var fly_weight: float = clampf(delta * follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, fly_weight)

	# --- 2. ПРИЦЕЛ: смотрим чуть впереди машины (больше скорость = дальше вперёд) ---
	var car_origin = follow_this.global_transform.origin
	var car_forward = -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	car_forward = car_forward.normalized()
	var look_ahead := speed_ratio * 4.0
	var look_target = car_origin + Vector3.UP * 1.2 + car_forward * look_ahead
	var look_weight: float = clampf(delta * look_speed, 0.0, 1.0)
	last_lookat = last_lookat.lerp(look_target, look_weight)
	look_at(last_lookat, Vector3.UP)

	# --- 3. FOV: ширится от скорости ---
	var target_fov = lerpf(base_fov, speed_fov, speed_ratio * speed_ratio)
	fov = lerpf(fov, target_fov, delta * fov_speed)

	# --- 4. ТРЯСКА ---
	if _shake_intensity > 0.01:
		h_offset = randf_range(-_shake_intensity, _shake_intensity)
		v_offset = randf_range(-_shake_intensity, _shake_intensity)
		_shake_intensity = lerpf(_shake_intensity, 0.0, delta * _shake_decay)
	else:
		h_offset = lerpf(h_offset, 0.0, delta * 10.0)
		v_offset = lerpf(v_offset, 0.0, delta * 10.0)
		_shake_intensity = 0.0

func _get_target_pos(speed_ratio: float) -> Vector3:
	var car_origin = follow_this.global_transform.origin

	# Направление «назад» от машины
	var car_forward = -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	car_forward = car_forward.normalized()

	# Интерполируем высоту и расстояние по скорости (квадратичная кривая — резче на высоких)
	var t := speed_ratio * speed_ratio
	var cur_height := lerpf(base_height, speed_height, t)
	var cur_distance := lerpf(base_distance, speed_distance, t)

	return car_origin - (car_forward * cur_distance) + (Vector3.UP * cur_height)

## Вызывается из машины при ударе
func add_shake(amount: float) -> void:
	_shake_intensity = clampf(_shake_intensity + amount, 0.0, 3.0)
