extends Node

var car_data = [
	{"path": "res://cars/pikap/pikap.tscn", "price": 0},
	{"path": "res://cars/BTR/btr.tscn", "price": 100000},
	{"path": "res://cars/Mustang/mustang.tscn", "price": 10000},
	{"path": "res://cars/Doge_Optimizado/Doge2.tscn", "price": 1000}
]
var money: int = 0
var selected_car_index: int = 0
var owned_cars: Array = [0]

func _ready() -> void:
	load_data()

func save_data():
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(money)
		file.store_var(selected_car_index)
		file.store_var(owned_cars)
		file.close()
		print("Игра сохранена")

func load_data():
	if FileAccess.file_exists("user://save.dat"):
		var file = FileAccess.open("user://save.dat", FileAccess.READ)
		if file:
			money = file.get_var()
			selected_car_index = file.get_var()
			owned_cars = file.get_var().duplicate() 
			file.close()
			print("Сохранения успешно загружены! Деньги:", money, " Машина:", selected_car_index)
	else:
		print("Файл сохранений не найден. Создаются новые данные.")
		save_data()

func buy_car(index: int, price: int) -> bool:
	if money >= price and not owned_cars.has(index):
		money -= price
		owned_cars.append(index)
		save_data()
		return true
	return false

func select_car(index: int) -> bool:
	if owned_cars.has(index):
		selected_car_index = index
		save_data()
		return true
	return false

func add_money(amount: int) -> void:
	money += amount
	save_data()
