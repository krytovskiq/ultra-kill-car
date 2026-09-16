import re

with open('entities/zombies/Z1/Z1.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

bones = re.findall(r'\[node name="Physical Bone ([^"]+)"', content)
print("\n".join(bones))
