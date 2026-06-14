extends Area3D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var main_node = get_tree().current_scene
		if main_node and main_node.has_method("advance_to_next_biome"):
			main_node.call("advance_to_next_biome")
		
		# БЕЗОПАСНОЕ отключение триггера: ищет любую коллизию внутри Area3D
		for child in get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", true)
func advance_to_next_biome() -> void:
	# Сюда можно вписать код для интерфейса или звуков при проезде моста
	pass
