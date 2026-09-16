import re

tscn_path = "levels/main.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the incorrect bridge reference (which is actually the Hangar!) with the real bridge
old_ext = r'\[ext_resource type="PackedScene" uid="uid://pgf4w1lj2g5g" path="res://scene/Brige\.tscn" id="4_brvut"\]'
new_ext = '[ext_resource type="PackedScene" uid="uid://bbs788x153n6p" path="res://environment/Brigemap/brige/Brige.tscn" id="4_brvut"]'

content = re.sub(old_ext, new_ext, content)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed main.tscn to point to the correct Bridge scene!")
