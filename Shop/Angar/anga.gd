extends Node3D

var current_idx = 0 
var car_instance = null 

# СЛОВАРЬ ДЛЯ КЭША: Сюда мы сохраним уже загруженные файлы сцен при старте
var loaded_car_scenes: Dictionary = {}

func _ready():
	$CanvasLayer/Money.text = str(Game.money) + " $"
	current_idx = Game.selected_car_index
	preload_all_cars()
	update_shop_ui()

func preload_all_cars():
	for info in Game.car_data:
		var path = info["path"]
		var scene = load(path) 
		if scene:
			loaded_car_scenes[path] = scene

func update_shop_ui():
	$CanvasLayer/Money.text = str(Game.money) + " $"
	
	var car_info = Game.car_data[current_idx]
	$CanvasLayer/CarName.text = "Машина #" + str(current_idx + 1)
	
	if current_idx in Game.owned_cars:
		$CanvasLayer/Price.text = "КУПЛЕНО"
		$CanvasLayer/Buy.text = "ВЫБРАТЬ"
		
		if current_idx == Game.selected_car_index:
			$CanvasLayer/Buy.text = "ВЫБРАНО"
			$CanvasLayer/Buy.disabled = true
		else:
			$CanvasLayer/Buy.disabled = false
	else:
		$CanvasLayer/Price.text = "ЦЕНА: " + str(car_info.price) + " $"
		$CanvasLayer/Buy.text = "КУПИТЬ"
		$CanvasLayer/Buy.disabled = false

	# Мгновенный спавн превью без чтения диска
	spawn_car_preview(car_info.path)

func spawn_car_preview(path):
	if car_instance:
		car_instance.queue_free()
	
	# ОПТИМИЗАЦИЯ: Вместо тяжелого load(path) берем готовую сцену из словаря
	if loaded_car_scenes.has(path):
		var car_scene = loaded_car_scenes[path]
		car_instance = car_scene.instantiate()
		add_child(car_instance)
		
		# --- ОТКЛЮЧАЕМ КАМЕРУ МАШИНЫ ДЛЯ АНГАРА ---
		var car_camera = car_instance.find_child("*Camera*", true, false) as Camera3D
		if car_camera:
			car_camera.current = false
		
		# Ставим машину в узел Spawn
		car_instance.global_position = $Spawn.global_position
		
		# Замораживаем физику
		if car_instance is RigidBody3D:
			car_instance.freeze = true
		car_instance.set_physics_process(false)

func _process(delta):
	if car_instance:
		car_instance.rotate_y(delta * 0.5)

# --- СИГНАЛЫ КНОПОК ---

func _on_next_pressed():
	current_idx = (current_idx + 1) % Game.car_data.size()
	update_shop_ui()

func _on_back_pressed():
	current_idx = (current_idx - 1 + Game.car_data.size()) % Game.car_data.size()
	update_shop_ui()

func _on_buy_pressed():
	var car_info = Game.car_data[current_idx]
	
	if current_idx in Game.owned_cars:
		Game.selected_car_index = current_idx
		Game.save_data() 
	else:
		if Game.money >= car_info.price:
			Game.money -= car_info.price
			Game.owned_cars.append(current_idx)
			Game.selected_car_index = current_idx
			Game.save_data()
		else:
			print("Мало денег!")
	
	update_shop_ui()

func _on_back_menu_pressed():
	get_tree().change_scene_to_file("res://menu.tscn")
