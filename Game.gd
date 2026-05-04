extends Node

# ВАЖНО: car_data должна быть здесь, в самом верху!
var car_data = [
	{"path": "res://cars/Doge_Optimizado/Doge2.tscn", "price": 0},
	{"path": "res://cars/BTR/btr.tscn", "price": 0}
]
var money: int = 10000
var selected_car_index: int = 0
var owned_cars: Array = [0] # Индекс 0 (первая машина) куплен сразу

func save_data():
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	file.store_var(money)
	file.store_var(selected_car_index)
	file.store_var(owned_cars)

func load_data():
	if FileAccess.file_exists("user://save.dat"):
		var file = FileAccess.open("user://save.dat", FileAccess.READ)
		money = file.get_var()
		selected_car_index = file.get_var()
		owned_cars = file.get_var()
