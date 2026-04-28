extends Node

# ВАЖНО: car_data должна быть здесь, в самом верху!
var car_data = [
	{"path": "res://cars/ZAporochec/Zaziktazik.tscn", "price": 0},
	{"path": "res://cars/Doge/Doge.tscn", "price": 500}
]

var money: int = 11111
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
