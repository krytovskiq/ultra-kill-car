extends Node3D

# Поле для перетаскивания сцены врага в Инспекторе
@export var enemy_scene: PackedScene 

# Настройка размера (0.5 — это в 2 раза меньше, 0.2 — в 5 раз)
@export var enemy_scale: float = 0.5

@onready var timer = $Timer

var enemy_count = 0

func _ready():
	# Проверка настроек при запуске
	if enemy_scene == null:
		print("!!! ОШИБКА: Забыли прикрепить Enemy Scene в Инспекторе!")
		return
		
	# Подключаем таймер программно, если не сделали это в интерфейсе
	if not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	
	print("--- Спавнер запущен! Враги будут размером: ", enemy_scale, " ---")

func _on_timer_timeout():
	spawn_enemy()

func spawn_enemy():
	if enemy_scene:
		# 1. Создаем экземпляр врага
		var enemy = enemy_scene.instantiate()
		
		# 2. УМЕНЬШАЕМ РАЗМЕР по всем трем осям (X, Y, Z)
		enemy.scale = Vector3(enemy_scale, enemy_scale, enemy_scale)
		
		# 3. Добавляем в мир (к родителю спавнера)
		get_parent().add_child(enemy)
		
		# 4. Устанавливаем позицию спавнера + небольшой разброс
		var spawn_pos = global_position
		spawn_pos.x += randf_range(-3, 3)
		spawn_pos.z += randf_range(-3, 3)
		enemy.global_position = spawn_pos
		
		# 5. Вывод в консоль для отладки
		enemy_count += 1
		print("Создан враг №", enemy_count, " | Позиция: ", spawn_pos)
