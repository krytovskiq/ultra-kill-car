extends Node

var zombie_scene: PackedScene = preload("res://entities/zombies/Z1/Z1.tscn")
var pool: Array[Node3D] = []
var active_zombies: Array[Node3D] = []

# Timer for cleaning up distant zombies
var cleanup_timer: float = 0.0

func _process(delta: float) -> void:
	cleanup_timer += delta
	if cleanup_timer > 1.0:
		cleanup_timer = 0.0
		_cleanup_distant_zombies()

func _cleanup_distant_zombies() -> void:
	var main_node = get_tree().current_scene
	if not main_node or not "car" in main_node or not is_instance_valid(main_node.car):
		return
		
	var car = main_node.car
	var forward_vector: Vector3 = main_node.get("_forward") if "_forward" in main_node else Vector3.BACK
	
	# We iterate backwards to allow safe removal from array
	for i in range(active_zombies.size() - 1, -1, -1):
		var zombie = active_zombies[i]
		if not is_instance_valid(zombie):
			active_zombies.remove_at(i)
			continue
			
		# 3 = ZombieState.DEAD
		if zombie.get("state") == 3:
			continue
			
		var rel_pos = zombie.global_position - car.global_position
		var dist_along_forward = rel_pos.dot(forward_vector)
		
		if dist_along_forward < -40.0:
			return_zombie(zombie)

func spawn_zombie_at(global_pos: Vector3) -> Node3D:
	if zombie_scene == null:
		push_error("ZombiePool: Сцена зомби не задана!")
		return null
		
	var zombie: Node3D = null
	
	if pool.size() > 0:
		zombie = pool.pop_back()
		zombie.show()
		zombie.set_process(true)
		zombie.set_physics_process(true)
		
		# Only reset collision if we previously disabled it, but die() does it anyway.
		# Let's re-enable standard layers. 
		zombie.set_collision_layer_value(3, true)
		zombie.set_collision_mask_value(1, true)
	else:
		zombie = zombie_scene.instantiate() as Node3D
		get_tree().current_scene.add_child(zombie)
		
	zombie.global_position = global_pos
	
	var main_node = get_tree().current_scene
	var should_run: bool = false
	if main_node and "is_fog_red" in main_node:
		should_run = main_node.is_fog_red 
	
	if zombie.has_method("reset_zombie"):
		zombie.reset_zombie(should_run)
		
	if not zombie in active_zombies:
		active_zombies.append(zombie)
		
	return zombie
	
func return_zombie(zombie: Node3D):
	if is_instance_valid(zombie) and not zombie in pool:
		zombie.hide()
		zombie.set_process(false)
		zombie.set_physics_process(false)
		zombie.set_collision_layer_value(3, false)
		zombie.set_collision_mask_value(1, false)
		active_zombies.erase(zombie)
		pool.append(zombie)
