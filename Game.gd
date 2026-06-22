extends Node

# ВАЖНО: car_data должна быть здесь, в самом верху!
var car_data = [
	{"path": "res://cars/Doge_Optimizado/Doge2.tscn", "price": 0},
	{"path": "res://cars/BTR/btr.tscn", "price": 0},
	{"path": "res://cars/pikap/pikap.tscn", "price": 0},
	{"path": "res://cars/Mustang/mustang.tscn", "price": 0}
]

var money: int = 0
var selected_car_index: int = 0
var owned_cars: Array = [0] # Индекс 0 (первая машина) куплен сразу

func _ready() -> void:
	# Автоматически загружаем сохранения при старте игры
	load_data()

func save_data():
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	if file:
		file.store_var(money)
		file.store_var(selected_car_index)
		file.store_var(owned_cars)
		file.close() # Обязательно закрываем файл после записи
		print("Игра успешно сохранена!")

func load_data():
	if FileAccess.file_exists("user://save.dat"):
		var file = FileAccess.open("user://save.dat", FileAccess.READ)
		if file:
			money = file.get_var()
			selected_car_index = file.get_var()
			# Используем .duplicate(), чтобы массив не ссылался на старые данные в памяти
			owned_cars = file.get_var().duplicate() 
			file.close() # Обязательно закрываем файл после чтения
			print("Сохранения успешно загружены! Деньги:", money, " Машина:", selected_car_index)
	else:
		# Если файла нет (первый запуск), создаем стандартные значения
		print("Файл сохранений не найден. Создаются новые данные.")
		save_data()

# --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ СЦЕНЫ ГАРАЖА ---

# Функция для покупки машины
func buy_car(index: int, price: int) -> bool:
	if money >= price and not owned_cars.has(index):
		money -= price
		owned_cars.append(index)
		save_data() # Сохраняем после покупки
		return true
	return false

# Функция для выбора (экипировки) машины
func select_car(index: int) -> bool:
	# Проверяем, куплена ли машина перед тем как её выбрать
	if owned_cars.has(index):
		selected_car_index = index
		save_data() # Сохраняем выбор
		return true
	return false

# Функция для добавления денег (например, за сбитых зомби в конце заезда)
func add_money(amount: int) -> void:
	money += amount
	save_data() # Сохраняем новый баланс
