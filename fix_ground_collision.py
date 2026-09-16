import re

tscn_path = "entities/zombies/Z1/Z1.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

def replace_mask(match):
    block = match.group(0)
    
    # Replace any collision_mask with 513 (Layer 1 and Layer 10)
    # Layer 1 = World generic, Layer 10 (512) = City Map/Chunks
    if "collision_mask =" in block:
        block = re.sub(r'collision_mask = \d+', 'collision_mask = 513', block)
    else:
        block += "\ncollision_mask = 513"
            
    return block

# The regex matches PhysicalBone3D nodes
content = re.sub(r'\[node name="Physical Bone [^\]]+\]\n(?:(?!\n\[node).*\n)*', replace_mask, content)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Updated PhysicalBone3D collision masks to 513 to hit the floor (Layer 10)!")
