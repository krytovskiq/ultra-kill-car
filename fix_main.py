import re

tscn_path = "levels/main.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove duplicate prewarms and set to 150
content = re.sub(r'ZombiePool\.prewarm_zombies\(\d+,\s*self\)\s*', '', content)

# Inject exactly one prewarm right after car.add_to_group("player")
content = content.replace(
    'car.add_to_group("player")',
    'car.add_to_group("player")\n\tZombiePool.prewarm_zombies(150, self)'
)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed main.gd duplicate prewarm")
