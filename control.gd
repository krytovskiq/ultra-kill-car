extends Control

func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Shop/Angar/Shop_Hungar.tscn")


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main.tscn")
	#ZombiePool.init_pool()
	
