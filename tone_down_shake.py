import re

tscn_path = "entities/camera/CameraFollow.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Reduce pitch/yaw shake multiplier from 0.15 to 0.10, and roll from 0.05 to 0.03
content = content.replace("var pitch_shake = randf_range(-total_shake, total_shake) * 0.15", "var pitch_shake = randf_range(-total_shake, total_shake) * 0.10")
content = content.replace("var yaw_shake = randf_range(-total_shake, total_shake) * 0.15", "var yaw_shake = randf_range(-total_shake, total_shake) * 0.10")
content = content.replace("var roll_shake = randf_range(-total_shake, total_shake) * 0.05", "var roll_shake = randf_range(-total_shake, total_shake) * 0.03")

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Toned down camera shake multipliers!")
