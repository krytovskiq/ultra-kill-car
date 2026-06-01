extends Area3D

func _ready() -> void:
	# Автоматически подключаем сигнал соприкосновения к самой себе
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not is_instance_valid(body):
		return
		
	# 1. Если это зомби — безопасно возвращаем его в пул
	if body.is_in_group("zombie") or body.name.to_lower().contains("zombie"):
		ZombiePool.return_zombie(body)
		return
		
	# 2. Если это машина игрока — игнорируем, чтобы случайно её не удалить
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		return
		
	# 3. Все остальные объекты (коробки, препятствия и т.д.) просто удаляем
	body.queue_free()
