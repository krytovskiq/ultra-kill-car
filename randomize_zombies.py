import re

tscn_path = "core/zombie_pool.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Randomize zombie scale on spawn
new_spawn = """
	if zombie != null:
		zombie.process_mode = Node.PROCESS_MODE_INHERIT
		zombie.show()
		zombie.set_process(true)
		zombie.set_physics_process(true)
		zombie.set_collision_layer_value(3, true)
		zombie.set_collision_mask_value(1, true)
	else:
		zombie = zombie_scene.instantiate() as Node3D
		var current_scene = get_tree().current_scene
		if current_scene:
			current_scene.add_child(zombie)
		
	zombie.global_position = global_pos
	
	# Разнообразие: рандомный размер зомби (от маленьких до здоровяков)
	var random_scale = randf_range(0.75, 1.25)
	zombie.scale = Vector3(random_scale, random_scale, random_scale)
"""

content = re.sub(
    r'\tif zombie \!= null:.*?zombie\.global_position = global_pos',
    new_spawn.strip(),
    content,
    flags=re.DOTALL
)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Zombie Pool updated with random scaling.")
