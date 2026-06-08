# Скрипт вешается прямо на узел Area3D внутри сцены моста
extends Area3D

func _ready() -> void:
	# Подключаем сигнал касания к собственной функции
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	# Проверяем, что в триггер въехала именно машина игрока
	if body.is_in_group("player"):
		# Ищем главный узел генератора (main) в сцене и вызываем метод переключения
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("advance_to_next_biome"):
			main_node.call("advance_to_next_biome")
		
		# Отключаем коллизию, чтобы триггер не сработал дважды, если машина дернется
		$CollisionShape3D.set_deferred("disabled", true)
