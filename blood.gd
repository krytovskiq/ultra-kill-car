extends GPUParticles3D

func _ready():
	# 1. Основные настройки частиц
	emitting = false
	one_shot = true
	explosiveness = 1.0 # Все частицы вылетают мгновенно
	amount = 40 # Количество капель
	lifetime = 0.8 # Как долго живет капля
	
	# 2. Настройка физики (ParticleProcessMaterial)
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(0, 0.5, -1) # Летит немного вверх и вперед
	material.spread = 35.0 # Разброс брызг
	material.initial_velocity_min = 8.0
	material.initial_velocity_max = 14.0
	material.gravity = Vector3(0, -25, 0) # Тяжелая кровь, быстро падает
	material.damping_min = 2.0 # Сопротивление воздуха
	material.damping_max = 5.0
	
	# Цвет (от ярко-красного к темно-бордовому)
	material.color = Color(0.8, 0, 0)
	
	# Размер (капли уменьшаются в полете)
	var scale_curve = CurveTexture.new()
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1)) # В начале большая
	curve.add_point(Vector2(1, 0)) # В конце исчезает
	scale_curve.curve = curve
	material.scale_curve = scale_curve
	
	process_material = material
	
	# 3. Настройка внешнего вида (Mesh)
	var sphere = SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	
	var sphere_mat = StandardMaterial3D.new()
	sphere_mat.albedo_color = Color(1.0, 0.125, 0.086, 1.0) # Темная кровь
	sphere_mat.roughness = 0.0 # Блестящая, как жидкость
	sphere.material = sphere_mat
	
	draw_pass_1 = sphere
	
	# Запуск и удаление
	restart()
	emitting = true
	
	# Удаляем узел через 1.5 секунды, когда частицы исчезнут
	await get_tree().create_timer(1.5).timeout
	queue_free()
	func spawn_blood(pos: Vector3, impulse: Vector3):
	var particles = GPUParticles3D.new()
	get_tree().current_scene.add_child(particles)
	particles.global_position = pos + Vector3.UP * 0.5
	
	# 1. Настройка физики частиц
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = impulse.normalized() + Vector3.UP * 0.5
	p_mat.spread = 45.0
	p_mat.initial_velocity_min = 8.0
	p_mat.initial_velocity_max = 15.0
	p_mat.gravity = Vector3(0, -25, 0)
	p_mat.scale_min = 0.4
	p_mat.scale_max = 1.2
	# Цвет в процессе жизни (опционально)
	p_mat.color = Color(0.7, 0, 0) 
	
	particles.process_material = p_mat
	particles.amount = 30
	particles.lifetime = 0.6
	particles.one_shot = true
	particles.explosiveness = 1.0
	
	# 2. НАСТРОЙКА ВНЕШНЕГО ВИДА (чтобы кровь была КРАСНОЙ)
	var mesh = SphereMesh.new()
	mesh.radius = 0.07
	mesh.height = 0.14
	
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.6, 0, 0) # ТЕМНО-КРАСНЫЙ ЦВЕТ
	m_mat.roughness = 0.1 # Чтобы капли блестели на свету
	mesh.material = m_mat # Назначаем материал мешу
	
	particles.draw_pass_1 = mesh
	
	# 3. Запуск
	particles.emitting = true
	get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
