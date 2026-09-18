import re

tscn_path = "core/zombie_pool.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Make the cleanup distance much further (-150.0 instead of -40.0)
content = content.replace("dist_along_forward < -40.0", "dist_along_forward < -150.0")

# Stop skipping dead zombies for distance cleanup! If they are 150 meters behind, remove them anyway!
content = content.replace("""		if zombie.get("state") == 3:
			continue""", "")

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Zombie pool cleanup distance updated.")
