extends Camera3D

@export_group("Позиция камеры (Обычная)")
@export var base_height := 3.2          ## Сделал камеру сильно ниже (было 3.5), ближе к асфальту кажется быстрее!
@export var base_distance := 4.0        
@export var base_fov := 70.0            ## Чуть шире изначально

@export_group("Позиция камеры (На скорости)")
@export var speed_height := 3.1         ## Камера почти прижимается к дороге на 200 км/ч
@export var speed_distance := 2.0       ## Камера подъезжает почти вплотную к багажнику
@export var speed_fov := 95.0          ## Мощнейшее искажение (тоннельный эффект) как в Need For Speed

@export_group("Настройка тряски от скорости")
@export var min_speed_for_shake := 200.0 
@export var max_speed_shake := 0.02      

@export_group("Плавность слежения (Мягкость камеры)")
@export var follow_speed := 8.0         
@export var look_speed := 12.0          
@export var fov_speed := 3.0            

var _shake_intensity := 0.0
var _shake_decay := 5.0
var follow_this: Node3D
var last_lookat: Vector3 = Vector3.ZERO
var _max_speed_kmh: float = 200.0

func _ready() -> void:
	var current = get_parent()
	while current != null and current is Node3D:
		if "linear_velocity" in current:
			follow_this = current
			break
		current = current.get_parent()
		
	if follow_this == null:
		follow_this = get_parent() as Node3D

	if follow_this == null:
		return

	top_level = true

	if follow_this.get("MAX_SPEED_KMH"):
		_max_speed_kmh = float(follow_this.MAX_SPEED_KMH)

	global_position = _get_target_pos(0.0)
	last_lookat = follow_this.global_transform.origin + Vector3.UP
	fov = base_fov

func _physics_process(delta: float) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return

	var speed_mps: float = 0.0
	if "linear_velocity" in follow_this:
		speed_mps = follow_this.linear_velocity.length()
	var speed_kmh := speed_mps * 5.4 # Используем аркадный множитель 5.4 для расчета %
	
	var speed_ratio := clampf(speed_kmh / _max_speed_kmh, 0.0, 1.0)

	var target_pos = _get_target_pos(speed_ratio)
	var fly_weight: float = clampf(delta * follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, fly_weight)

	var car_origin = follow_this.global_transform.origin
	var car_forward = -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	car_forward = car_forward.normalized()
	
	var look_ahead := speed_ratio * 4.0
	var look_target = car_origin + Vector3.UP * 1.2 + car_forward * look_ahead
	var look_weight: float = clampf(delta * look_speed, 0.0, 1.0)
	
	last_lookat = last_lookat.lerp(look_target, look_weight)
	look_at(last_lookat, Vector3.UP)

	var target_fov = lerpf(base_fov, speed_fov, speed_ratio * speed_ratio)
	fov = lerpf(fov, target_fov, delta * fov_speed)

	var current_speed_shake = 0.0
	if speed_kmh > min_speed_for_shake:
		var shake_ratio = clampf((speed_kmh - min_speed_for_shake) / 100.0, 0.0, 1.0)
		current_speed_shake = shake_ratio * max_speed_shake

	var total_shake = maxf(_shake_intensity, current_speed_shake)
	
	if total_shake > 0.001:
		var pitch_shake = randf_range(-total_shake, total_shake) * 0.10
		var yaw_shake = randf_range(-total_shake, total_shake) * 0.10
		var roll_shake = randf_range(-total_shake, total_shake) * 0.03
		rotation += Vector3(pitch_shake, yaw_shake, roll_shake)
		
		var pos_offset = Vector3(
			randf_range(-total_shake, total_shake) * 0.2,
			randf_range(-total_shake, total_shake) * 0.2,
			0.0
		)
		global_position += basis * pos_offset
		
		_shake_intensity = lerpf(_shake_intensity, 0.0, delta * _shake_decay)
	else:
		_shake_intensity = 0.0

func _get_target_pos(speed_ratio: float) -> Vector3:
	var car_origin = follow_this.global_transform.origin
	var car_forward = -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	car_forward = car_forward.normalized()

	var t := speed_ratio * speed_ratio
	var cur_height := lerpf(base_height, speed_height, t)
	var cur_distance := lerpf(base_distance, speed_distance, t)

	return car_origin - (car_forward * cur_distance) + (Vector3.UP * cur_height)

func add_shake(amount: float) -> void:
	_shake_intensity = clampf(_shake_intensity + amount, 0.0, 3.0)
