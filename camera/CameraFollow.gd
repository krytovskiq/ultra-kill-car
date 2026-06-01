extends Camera3D

@export var follow_speed := 5.0      # Скорость полета вертолета за машиной
@export var look_speed := 7.0       # Насколько быстро объектив следит за кузовом

@export var height_above := 3.0      # Высота полета вертолета над машиной
@export var distance_behind := 5.0  # На сколько метров вертолет отстает от машины

var follow_this: Node3D
var last_lookat: Vector3 = Vector3.ZERO

func _ready() -> void:
	follow_this = get_parent() as Node3D
	if follow_this == null:
		return

	# Отвязываем от машины, чтобы вертолет летел свободно в мировом пространстве
	top_level = true 
	
	global_position = _get_helicopter_target_pos()
	last_lookat = follow_this.global_transform.origin + Vector3.UP

func _physics_process(delta: float) -> void:
	if follow_this == null or not is_instance_valid(follow_this):
		return

	# 1. ПЛАВНЫЙ ПОЛЕТ: Вертолет плавно летит к идеальной точке в небе
	var target_pos = _get_helicopter_target_pos()
	var fly_weight: float = clampf(delta * follow_speed, 0.0, 1.0)
	global_position = global_position.lerp(target_pos, fly_weight)

	# 2. ЖЕСТКИЙ ПРИЦЕЛ: Объектив камеры очень быстро наводится на машину, чтобы не потерять её
	var look_target = follow_this.global_transform.origin + Vector3.UP * 1.0
	var look_weight: float = clampf(delta * look_speed, 0.0, 1.0)
	last_lookat = last_lookat.lerp(look_target, look_weight)
	
	look_at(last_lookat, Vector3.UP)

func _get_helicopter_target_pos() -> Vector3:
	var car_origin = follow_this.global_transform.origin
	
	# Берем направление движения машины на плоскости (без кочек)
	var car_forward = -follow_this.global_transform.basis.z
	car_forward.y = 0.0
	car_forward = car_forward.normalized()
	
	# Вертолет летит строго сзади на расстоянии и высоко в небе
	return car_origin - (car_forward * distance_behind) + (Vector3.UP * height_above)
