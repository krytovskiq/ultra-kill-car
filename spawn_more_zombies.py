import re

tscn_path = "levels/main.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Add Prewarm call
content = content.replace(
    'car.add_to_group("player") \n\t',
    'car.add_to_group("player") \n\tZombiePool.prewarm_zombies(250, self)\n\t'
)
content = content.replace(
    'car.add_to_group("player")',
    'car.add_to_group("player")\n\tZombiePool.prewarm_zombies(250, self)'
)

# 2. Update _spawn_single_zombie_ahead to spawn clusters
old_spawn = """func _spawn_single_zombie_ahead() -> void:
	var safe_fog_distance: float = 320.0
	
	var spawn_pos: Vector3 = car.global_position + _forward * safe_fog_distance
	
	spawn_pos.x += randf_range(-road_spawn_width * 0.5, road_spawn_width * 0.5)
	spawn_pos.y = road_y
	
	ZombiePool.spawn_zombie_at(spawn_pos)"""

new_spawn = """func _spawn_single_zombie_ahead() -> void:
	var safe_fog_distance: float = 320.0
	
	# Спавним не по 1 зомби, а сразу группами от 2 до 5 штук (в 3 раза больше зомби!)
	var cluster_size = randi() % 4 + 2 # от 2 до 5
	for i in range(cluster_size):
		var spawn_pos: Vector3 = car.global_position + _forward * safe_fog_distance
		spawn_pos.x += randf_range(-road_spawn_width * 0.5, road_spawn_width * 0.5)
		spawn_pos.z += randf_range(-15.0, 15.0) # разброс вперед/назад
		spawn_pos.y = road_y
		
		ZombiePool.spawn_zombie_at(spawn_pos)"""

# Also lower base_spawn_cooldown slightly
content = content.replace("@export var base_spawn_cooldown: float = 0.25", "@export var base_spawn_cooldown: float = 0.15")

if "func _spawn_single_zombie_ahead()" in content:
    # We will use regex to replace the function entirely
    content = re.sub(
        r'func _spawn_single_zombie_ahead\(\) -> void:.*?ZombiePool\.spawn_zombie_at\(spawn_pos\)',
        new_spawn,
        content,
        flags=re.DOTALL
    )

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Main.gd updated with huge zombie clusters and prewarm!")
