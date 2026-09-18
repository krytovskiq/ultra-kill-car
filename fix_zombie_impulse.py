import re

tscn_path = "entities/zombies/Z1/z_1.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Change the launch velocity for ragdolls
old_launch = "var launch_vel = impact_force * 1.2 + Vector3(0, 8.0, 0)"
new_launch = "var launch_vel = impact_force * 0.4 + Vector3(0, 10.0, 0)"
content = content.replace(old_launch, new_launch)

# Also ensure they don't immediately get removed if they fly too fast.
# Wait, let's keep the 5.0 second timer, but the reduced impulse will keep them on screen.

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Zombie impulse reduced.")
