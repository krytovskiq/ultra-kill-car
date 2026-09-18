import re

tscn_path = "core/zombie_pool.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove the random scale logic
content = re.sub(
    r'\s*# Разнообразие: рандомный размер зомби.*?zombie\.scale = Vector3\(random_scale, random_scale, random_scale\)',
    '',
    content,
    flags=re.DOTALL
)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Removed random scaling from ZombiePool.")
