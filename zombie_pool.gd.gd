extends Node

var zombie_scene: PackedScene = preload("res://Zombie/Z1/Z1.tscn")
var pool: Array[Node3D] = []

func _ready() -> void:
	pass

# Нам больше не нужно забивать память на старте игры 500 зомби!
func init_pool() -> void:
	pass

func spawn_zombie_at(global_pos: Vector3) -> Node3D:
	if zombie_scene == null:
		push_error("ZombiePool: Сцена зомби не задана!")
		return null
		
	var zombie = zombie_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(zombie)
	zombie.global_position = global_pos
	
	# ИДЕАЛЬНАЯ СИНХРОНИЗАЦИЯ: узнаем у main, красная ли сейчас зона тумана
	var main_node = get_tree().current_scene
	var should_run: bool = false
	if main_node and "is_fog_red" in main_node:
		should_run = main_node.is_fog_red # Бегут только когда туман красный!
	
	if zombie.has_method("reset_zombie"):
		zombie.reset_zombie(should_run)
		
	return zombie
	
func return_zombie(zombie: Node3D):
	if is_instance_valid(zombie):
		# Полностью, бесследно удаляем зомби из памяти, физики и отладчика!
		zombie.queue_free()
