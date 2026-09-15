import re

z_script = "entities/zombies/Z1/z_1.gd"
with open(z_script, "r", encoding="utf-8") as f:
    content = f.read()

# I need to change the inner loop for PhysicalBone3D setup
old_loop = r'(\t\t\t\tchild\.collision_layer = 0\n\t\t\t\tchild\.collision_mask = 1[^\n]*\n\s*# Увеличиваем массу[^\n]*\n\t\t\t\tchild\.mass = 3\.0)'
new_loop = """\t\t\t\tchild.collision_layer = 0
\t\t\t\t# Маска 1 (земля) + 2 (стены) + 4 (объекты)
\t\t\t\tchild.collision_mask = 1 | 2 | 4
\t\t\t\t
\t\t\t\t# Возвращаем массу в норму, чтобы суставы не растягивались (из-за этого они проваливались сквозь пол)
\t\t\t\tchild.mass = 1.0
\t\t\t\t
\t\t\t\t# Добавляем сопротивление, чтобы они не болтались как желе
\t\t\t\tchild.linear_damp = 1.5
\t\t\t\tchild.angular_damp = 5.0
\t\t\t\t
\t\t\t\t# Трение, чтобы они не скользили бесконечно
\t\t\t\tchild.friction = 1.0
\t\t\t\tchild.bounce = 0.0"""

content = re.sub(old_loop, new_loop, content)

with open(z_script, "w", encoding="utf-8") as f:
    f.write(content)

print("Ragdoll physics refined")
