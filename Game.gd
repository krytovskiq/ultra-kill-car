extends Node

var money: int = 0:
	set(value):
		money = value
		# Каждый раз, когда деньги меняются, ищем лейбл и обновляем его
		var label = get_tree().root.find_child("Money", true, false)
		if label:
			label.text = str(money) + " $"

func _ready():
	load_money() # Загружаем баланс при запуске игры

func save_money():
	var file = FileAccess.open("user://save.dat", FileAccess.WRITE)
	file.store_var(money)

func load_money():
	if FileAccess.file_exists("user://save.dat"):
		var file = FileAccess.open("user://save.dat", FileAccess.READ)
		money = file.get_var()
