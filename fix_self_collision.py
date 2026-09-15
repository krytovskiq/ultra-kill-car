import re

z_script = "entities/zombies/Z1/z_1.gd"
with open(z_script, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the collision setup to enable self-collision
old_col = r'child\.collision_layer = 0\n\s*child\.collision_mask = 1 \| 2 \| 4'
new_col = """\t\t\t\t\t\t# Выделяем рэгдоллам отдельный слой 5 (значение 16), который не видит машина.
\t\t\t\t\t\t# Маска: 1 (земля) + 2 (стены) + 4 (объекты) + 16 (САМИ РЭГДОЛЛЫ)
\t\t\t\t\t\tchild.collision_layer = 16
\t\t\t\t\t\tchild.collision_mask = 1 | 2 | 4 | 16"""

content = re.sub(old_col, new_col, content)

with open(z_script, "w", encoding="utf-8") as f:
    f.write(content)

print("Ragdoll self-collision enabled")
