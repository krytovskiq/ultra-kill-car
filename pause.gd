extends CanvasLayer


func _on_contiue_pressed() -> void:
	get_tree().paused = false
	hide()
	
func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")
