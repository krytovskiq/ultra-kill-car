#extends Area3D
#var death_shader = preload("res://cars/Death_shader.gdshader")
#func _on_body_entered(body: Node3D) -> void:
	#if body.is_in_group("player"):
		#_destroy_car()
		#
#func _destroy_car() -> void:
	#if has_node("Hud/ColorRect"):
		#var effect_rect = $Hud/ColorRect as ColorRect
		#effect_rect.show()
		#var mat = effect_rect.material as ShaderMaterial
		#var tween_blood = create_tween()
		#tween_blood.tween_property(mat, "shader_parameter/effect_strength", 1.0, 0.0)
		#var tween_time = create_tween()
		#tween_time.tween_property(Engine, "time_scale", 0.1, 0.2).set_trans(Tween.TRANS_SINE)
	#await get_tree().create_timer(1.0).timeout
	#Engine.time_scale = 1.0
	#get_tree().reload_current_scene()
	
