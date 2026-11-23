extends Node

signal money_changed(new_amount: int)
signal upgrades_changed(car_index: int)

# === СПИСОК ТЕХНИКИ В ИГРЕ ===
# Чтобы изменить цену машины — поменяйте значение "price".
var car_data: Array[Dictionary] = [
	{"name": "Pikap", "path": "res://entities/vehicles/pikap/pikap.tscn", "price": 0},
	{"name": "Dodge", "path": "res://entities/vehicles/Doge_Optimizado/Doge2.tscn", "price": 1000},
	{"name": "UAZ Buhanka", "path": "res://entities/vehicles/Buhanka/buhanka.tscn", "price": 2500},
	{"name": "GMC Vandura", "path": "res://entities/vehicles/Vandura/vandura.tscn", "price": 4500},
	{"name": "Carson Grand Sicilian", "path": "res://entities/vehicles/Carson/carson.tscn", "price": 7500},
	{"name": "Plymouth Barracuda '70", "path": "res://entities/vehicles/Barracuda/barracuda.tscn", "price": 10000},
	{"name": "DeLorean V6 Turbo", "path": "res://entities/vehicles/DeLorean/delorean.tscn", "price": 18000},
	{"name": "GMC K-2500", "path": "res://entities/vehicles/GMC_K2500/gmc_k2500.tscn", "price": 22000},
	{"name": "Ford Raptor", "path": "res://entities/vehicles/Raptor/raptor.tscn", "price": 25000},
	{"name": "PAZ-3205 Apocalypse", "path": "res://entities/vehicles/PAZ_3205/paz_3205.tscn", "price": 65000},
	{"name": "BTR", "path": "res://entities/vehicles/BTR/btr.tscn", "price": 100000}
]

# === НАСТРОЙКИ ПРОКАЧКИ ТРАНСПОРТА ===
# Индивидуальный максимальный уровень для каждого узла:
#   fuel = 20 уровней (больше бак), остальные = 10 уровней (чуть сильнее прежних 5/5).
const UPGRADE_MAX_LEVELS: Dictionary = {
	"fuel": 20,     ## Топливный бак: 20 уровней прокачки (макс. +250% объёма)
	"engine": 10,   ## Двигатель и КПП: 10 уровней (чуть мощнее прежних 5/5)
	"armor": 10,    ## Броня кузова: 10 уровней (чуть прочнее прежних 5/5)
	"chassis": 10,  ## Ходовая / турель: 10 уровней (чуть лучше прежних 5/5)
}
const MAX_UPGRADE_LEVEL := 10 # оставлено для совместимости; используйте get_max_upgrade_level(stat_key)
const UPGRADE_KEYS: Array[String] = ["fuel", "engine", "armor", "chassis"]

# Прирост характеристик за 1 уровень прокачки (например 0.125 = +12.5% за уровень):
const UPGRADE_FUEL_BONUS_PER_LVL := 0.125     ## +12.5% к объёму бака за ур. (+250% на 20/20 = x3.5)
const UPGRADE_SPEED_BONUS_PER_LVL := 0.044    ## +4.4% к макс. скорости за ур. (+44% на 10/10)
const UPGRADE_POWER_BONUS_PER_LVL := 0.060    ## +6.0% к силе и разгону мотора за ур. (+60% на 10/10)
const UPGRADE_ARMOR_HP_BONUS_PER_LVL := 0.130 ## +13.0% к прочности (HP) за ур. (+130% на 10/10)
const UPGRADE_CHASSIS_BONUS_PER_LVL := 0.038  ## +3.8% к управляемости и сцеплению за ур. (+38% на 10/10)

# Базовая стоимость уровней для 10-уровневых и 20-уровневых узлов (умножается на коэффициент класса):
const UPGRADE_BASE_COSTS_10: Array[int] = [250, 350, 500, 700, 950, 1250, 1650, 2150, 2800, 3600]
const UPGRADE_BASE_COSTS_20: Array[int] = [
	150, 200, 250, 320, 400, 500, 620, 760, 920, 1100,
	1300, 1550, 1850, 2200, 2600, 3050, 3550, 4100, 4750, 5500
]
const CAR_TIER_COST_MULTS: Array[float] = [1.0, 1.8, 2.0, 2.4, 3.0, 3.6, 4.4, 5.0, 5.5, 7.5, 9.0]

# Стартовые деньги при первом запуске игры (можно поменять под себя)
const STARTING_MONEY := 10000000

var money: int = STARTING_MONEY
var selected_car_index: int = 0
var owned_cars: Array = [0]
var car_upgrades: Dictionary = {}

const SAVE_PATH := "user://save.dat"

func _ready() -> void:
	load_data()

func save_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(money)
		file.store_var(selected_car_index)
		file.store_var(owned_cars)
		file.store_var(car_upgrades)
		file.close()

func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		car_upgrades = {}
		save_data()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var loaded_money = file.get_var() if file.get_position() < file.get_length() else null
	var loaded_index = file.get_var() if file.get_position() < file.get_length() else null
	var loaded_owned = file.get_var() if file.get_position() < file.get_length() else null
	var loaded_upgrades = file.get_var() if file.get_position() < file.get_length() else null
	file.close()

	if typeof(loaded_money) == TYPE_INT or typeof(loaded_money) == TYPE_FLOAT:
		money = maxi(int(loaded_money), 0)

	if typeof(loaded_owned) == TYPE_ARRAY:
		var clean_owned: Array = []
		for item in loaded_owned:
			if typeof(item) == TYPE_INT or typeof(item) == TYPE_FLOAT:
				var idx := int(item)
				if idx >= 0 and idx < car_data.size() and not clean_owned.has(idx):
					clean_owned.append(idx)
		if clean_owned.is_empty():
			clean_owned.append(0)
		owned_cars = clean_owned
	else:
		owned_cars = [0]

	if typeof(loaded_index) == TYPE_INT or typeof(loaded_index) == TYPE_FLOAT:
		var idx := clampi(int(loaded_index), 0, car_data.size() - 1)
		selected_car_index = idx if owned_cars.has(idx) else int(owned_cars[0])
	else:
		selected_car_index = int(owned_cars[0])

	var clean_upgrades: Dictionary = {}
	if typeof(loaded_upgrades) == TYPE_DICTIONARY:
		for raw_k in (loaded_upgrades as Dictionary).keys():
			var ci := int(raw_k)
			if ci < 0 or ci >= car_data.size():
				continue
			var raw_stats = (loaded_upgrades as Dictionary)[raw_k]
			if typeof(raw_stats) == TYPE_DICTIONARY:
				var entry: Dictionary = {}
				for uk: String in UPGRADE_KEYS:
					var cap_lvl: int = get_max_upgrade_level(uk)
					entry[uk] = clampi(int((raw_stats as Dictionary).get(uk, 0)), 0, cap_lvl)
				clean_upgrades[ci] = entry
	car_upgrades = clean_upgrades

	money_changed.emit(money)

func get_max_upgrade_level(stat_key: String) -> int:
	return int(UPGRADE_MAX_LEVELS.get(stat_key, 10))

func is_stat_maxed(car_idx: int, stat_key: String) -> bool:
	return get_upgrade_level(car_idx, stat_key) >= get_max_upgrade_level(stat_key)

func get_maxed_upgrade_stages(car_idx: int) -> Dictionary:
	return {
		"fuel": is_stat_maxed(car_idx, "fuel"),
		"engine": is_stat_maxed(car_idx, "engine"),
		"armor": is_stat_maxed(car_idx, "armor"),
		"chassis": is_stat_maxed(car_idx, "chassis"),
	}

func get_upgrade_level(car_idx: int, stat_key: String) -> int:
	if car_idx < 0 or car_idx >= car_data.size():
		return 0
	var entry = car_upgrades.get(car_idx, null)
	if typeof(entry) != TYPE_DICTIONARY:
		return 0
	var max_lvl: int = get_max_upgrade_level(stat_key)
	return clampi(int((entry as Dictionary).get(stat_key, 0)), 0, max_lvl)

func get_upgrade_cost(car_idx: int, stat_key: String) -> int:
	var lvl: int = get_upgrade_level(car_idx, stat_key)
	var max_lvl: int = get_max_upgrade_level(stat_key)
	if lvl >= max_lvl:
		return 0
	var cost_table: Array[int] = UPGRADE_BASE_COSTS_20 if max_lvl >= 20 else UPGRADE_BASE_COSTS_10
	var base_c: int = cost_table[clampi(lvl, 0, cost_table.size() - 1)]
	var tier_mult: float = CAR_TIER_COST_MULTS[clampi(car_idx, 0, CAR_TIER_COST_MULTS.size() - 1)]
	return roundi(float(base_c) * tier_mult / 50.0) * 50

func buy_upgrade(car_idx: int, stat_key: String) -> bool:
	if not UPGRADE_KEYS.has(stat_key) or not owned_cars.has(car_idx):
		return false
	var lvl: int = get_upgrade_level(car_idx, stat_key)
	var max_lvl: int = get_max_upgrade_level(stat_key)
	if lvl >= max_lvl:
		return false
	var cost: int = get_upgrade_cost(car_idx, stat_key)
	if money < cost:
		return false
	money -= cost
	var entry: Dictionary = {}
	var existing = car_upgrades.get(car_idx, null)
	if typeof(existing) == TYPE_DICTIONARY:
		entry = (existing as Dictionary).duplicate()
	entry[stat_key] = lvl + 1
	car_upgrades[car_idx] = entry
	save_data()
	money_changed.emit(money)
	upgrades_changed.emit(car_idx)
	return true

func get_upgrade_progress(car_idx: int) -> Vector2i:
	var total: int = 0
	var max_total: int = 0
	for uk: String in UPGRADE_KEYS:
		total += get_upgrade_level(car_idx, uk)
		max_total += get_max_upgrade_level(uk)
	return Vector2i(total, max_total)

func is_car_max_upgraded(car_idx: int) -> bool:
	var prog := get_upgrade_progress(car_idx)
	return prog.x >= prog.y

func buy_car(index: int, price: int) -> bool:
	if index < 0 or index >= car_data.size():
		return false
	if money >= price and not owned_cars.has(index):
		money -= price
		owned_cars.append(index)
		selected_car_index = index
		save_data()
		money_changed.emit(money)
		return true
	return false

func select_car(index: int) -> bool:
	if owned_cars.has(index):
		selected_car_index = index
		save_data()
		return true
	return false

func add_money(amount: int) -> void:
	if amount == 0:
		return
	money = maxi(money + amount, 0)
	save_data()
	money_changed.emit(money)

func reset_progress(starting_money: int = STARTING_MONEY) -> void:
	money = maxi(starting_money, 0)
	selected_car_index = 0
	owned_cars = [0]
	car_upgrades = {}
	save_data()
	money_changed.emit(money)
	upgrades_changed.emit(0)
