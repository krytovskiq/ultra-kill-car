extends Node3D

var current_idx = 0 
var car_instance = null 

func _ready():
	$CanvasLayer/Money.text = str(Game.money) + " $"
	# Берем индекс выбранной машины из твоего Game.gd
	current_idx = Game.selected_car_index
	update_shop_ui()

func update_shop_ui():
	# Проверяем, есть ли данные в Game.gd
	var car_data = [
	{"path": "res://cars/ZAporochec/Zaziktazik.tscn", "price": 0},
	{"path": "res://cars/Doge/Doge.tscn", "price": 0},
	{"path": "res://cars/Toyota_Apocalipsys/apocalipsys_car.tscn", "price": 0}
]
	
	var car_info = Game.car_data[current_idx]
	
	# Обновляем текст (пути к узлам согласно твоему скриншоту)
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

	# Спавним 3D модель для предпросмотра
	spawn_car_preview(car_info.path)

func spawn_car_preview(path):
	if car_instance:
		car_instance.queue_free()
	
	var car_scene = load(path)
	if car_scene:
		car_instance = car_scene.instantiate()
		add_child(car_instance)
		
		# Ставим машину в твой узел Spawn
		car_instance.global_position = $Spawn.global_position
		
		# Замораживаем физику, чтобы машина не улетела
		if car_instance is RigidBody3D:
			car_instance.freeze = true
		car_instance.set_physics_process(false)

func _process(delta):
	# Вращаем машину для красоты
	if car_instance:
		car_instance.rotate_y(delta * 0.5)

# --- СИГНАЛЫ КНОПОК (Подключи их во вкладке "Узел"!) ---

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
	# Проверь, чтобы файл назывался именно menu.tscn
	get_tree().change_scene_to_file("res://menu.tscn") 
