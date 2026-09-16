extends Control

func _on_texture_button_pressed() -> void:
	get_tree().change_scene_to_file("res://ui/shop/Angar/Shop_Hungar.tscn")

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://levels/main.tscn")

func _on_settings_pressed() -> void:
	if has_node("SettingsPanel"):
		$SettingsPanel.show()

func _on_btn_close_pressed() -> void:
	if has_node("SettingsPanel"):
		$SettingsPanel.hide()

func _on_btn_potato_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.POTATO)

func _on_btn_low_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.LOW)

func _on_btn_medium_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.MEDIUM)

func _on_btn_high_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.HIGH)

func _on_btn_very_high_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.VERY_HIGH)

func _on_btn_maximum_pressed() -> void:
	SettingsManager.set_quality(SettingsManager.GraphicsQuality.MAXIMUM)
