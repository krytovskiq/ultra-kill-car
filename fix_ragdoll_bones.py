import re

z_script = "entities/zombies/Z1/z_1.gd"
with open(z_script, "r", encoding="utf-8") as f:
    content = f.read()

new_ready = """func _ready() -> void:
\tskeleton = get_node_or_null("Run/Skeleton3D")
\t
\t# === ОПТИМИЗАЦИЯ РЭГДОЛЛА ===
\t# Удаляем мелкие кости, чтобы они не мешали и не сворачивали труп в "пакет"
\tif skeleton:
\t\tvar sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
\t\tif sim:
\t\t\tfor child in sim.get_children():
\t\t\t\tif child is PhysicalBone3D:
\t\t\t\t\tvar n = child.name
\t\t\t\t\t# Удаляем пальцы, стопы, плечи, шею и кисти
\t\t\t\t\tif "Index" in n or "Toe" in n or "Hand" in n or "Neck" in n or "Shoulder" in n or "Foot" in n:
\t\t\t\t\t\tchild.queue_free()
\t\t\t\t\telse:
\t\t\t\t\t\t# Настраиваем нормальную физику для оставшихся крупных костей
\t\t\t\t\t\tchild.collision_layer = 0
\t\t\t\t\t\tchild.collision_mask = 1 | 2 | 4
\t\t\t\t\t\tchild.mass = 2.0
\t\t\t\t\t\tchild.linear_damp = 1.0
\t\t\t\t\t\tchild.angular_damp = 4.0
\t\t\t\t\t\tchild.friction = 0.8
\t\t\t\t\t\tchild.bounce = 0.0
\t# ============================

\tadd_to_group("zombie")"""

content = re.sub(r'func _ready\(\) -> void:\n\tskeleton = get_node_or_null\("Run/Skeleton3D"\)\n\tadd_to_group\("zombie"\)', new_ready, content)

# Now remove the redundant physical setup in `die()` since we did it in `_ready()`
old_loop = r'for child in sim\.get_children\(\):\n\t\t\tif child is PhysicalBone3D:\n\t\t\t\tchild\.collision_layer = 0\n\t\t\t\t# Маска 1 \(земля\) \+ 2 \(стены\) \+ 4 \(объекты\)\n\t\t\t\tchild\.collision_mask = 1 \| 2 \| 4\n\t\t\t\t\n\t\t\t\t# Возвращаем массу в норму, чтобы суставы не растягивались \(из-за этого они проваливались сквозь пол\)\n\t\t\t\tchild\.mass = 1\.0\n\t\t\t\t\n\t\t\t\t# Добавляем сопротивление, чтобы они не болтались как желе\n\t\t\t\tchild\.linear_damp = 1\.5\n\t\t\t\tchild\.angular_damp = 5\.0\n\t\t\t\t\n\t\t\t\t# Трение, чтобы они не скользили бесконечно\n\t\t\t\tchild\.friction = 1\.0\n\t\t\t\tchild\.bounce = 0\.0\n\t\t\t\t\n\t\t\t\tif "Hips" in child\.name or "Spine" in child\.name:\n\t\t\t\t\tchild\.apply_central_impulse\(core_force\)'

new_loop = """for child in sim.get_children():
\t\t\tif child is PhysicalBone3D:
\t\t\t\t# Импульс даем только туловищу (Грудь и Таз), чтобы руки и ноги просто летели за ним по инерции
\t\t\t\tif "Hips" in child.name or "Spine" in child.name:
\t\t\t\t\tchild.apply_central_impulse(core_force)"""

content = re.sub(old_loop, new_loop, content)

with open(z_script, "w", encoding="utf-8") as f:
    f.write(content)

print("Zombie ragdoll cleaned up")
