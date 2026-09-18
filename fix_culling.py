import re

tscn_path = "entities/zombies/Z1/z_1.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Add extra_cull_margin to _ready()
cull_fix = """
	if skeleton:
		for child in skeleton.get_children():
			if child is MeshInstance3D:
				child.extra_cull_margin = 250.0 # Предотвращает мгновенное исчезновение при рэгдолле!
"""
content = content.replace("	if skeleton:", cull_fix)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

pool_path = "core/zombie_pool.gd"
with open(pool_path, "r", encoding="utf-8") as f:
    pool_content = f.read()

# Make zombies smaller as requested (0.6 to 0.95)
pool_content = pool_content.replace("randf_range(0.75, 1.25)", "randf_range(0.6, 0.95)")

with open(pool_path, "w", encoding="utf-8") as f:
    f.write(pool_content)

print("Applied culling fix and scale adjustments.")
