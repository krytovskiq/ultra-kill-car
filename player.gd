extends Marker3D

func _ready():
	print("Маркер запущен!") # Если этого нет в консоли — скрипт не на маркере
	
	Game.load_data()
	
	# Проверка: есть ли данные
	if Game.car_data.size() == 0:
		print("ОШИБКА: Список car_data в Game.gd пуст!")
		return
		
	var selected_idx = Game.selected_car_index
	var car_path = Game.car_data[selected_idx].path
	print("Пытаюсь создать машину: ", car_path)

	if not FileAccess.file_exists(car_path):
		print("ОШИБКА: Файл не найден по пути: ", car_path)
		return

	var car_scene = load(car_path)
	if car_scene:
		var car_instance = car_scene.instantiate()
		
		# Важно: добавляем в родительский узел (в корень сцены)
		get_parent().add_child.call_deferred(car_instance)
		
		# Ставим в позицию маркера
		car_instance.global_position = global_position
		car_instance.global_rotation = global_rotation
		print("Машина успешно создана!")
		
		# Пытаемся найти камеру и привязать её
		var camera = get_viewport().get_camera_3d()
		if camera:
			print("Камера найдена, привязываю к машине...")
			# Если у тебя камера должна следовать за машиной:
			# camera.reparent(car_instance) 
	else:
		print("ОШИБКА: Не удалось загрузить сцену (load failed)")
