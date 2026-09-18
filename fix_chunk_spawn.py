import re

tscn_path = "levels/world_chunk.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove _spawn_random_objects from _ready
content = content.replace("	_spawn_random_objects()\n", "")

# Add configure_chunk method
configure_chunk_code = """
func configure_chunk(c_width: float, c_length: float, c_thickness: float, c_road_y: float) -> void:
	self.chunk_width = c_width
	self.chunk_length = c_length
	self.chunk_thickness = c_thickness
	self.surface_y = c_road_y
	
	_apply_chunk_geometry()
	
	# Если это стартовый кусок (близко к z=0), не спавним препятствия перед носом
	if abs(global_position.z) < 150.0:
		return
		
	_spawn_random_objects()
"""

# We'll just append it to the end of the file or after init_chunk_zombies
content = content.replace("func init_chunk_zombies() -> void:\n\tpass", "func init_chunk_zombies() -> void:\n\tpass\n" + configure_chunk_code)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Updated world_chunk.gd to spawn objects safely.")
