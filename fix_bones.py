import re
import os

tscn_path = "entities/zombies/Z1/Z1.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# We need to scale down the radius and height of all CapsuleShape3D by 100
# But only those that are absurdly large (e.g. radius > 0.5 or height > 3.0)
# Wait, some small bones might have radius = 0.72. If we divide by 100 it becomes 0.0072 which is fine.
# Let's just divide every radius and height inside the CapsuleShape3D blocks that belong to the skeleton.
# Actually, it's easier to just divide ALL CapsuleShape3D radius/height by 100 IF they are part of the PhysicalBone generation.
# We know the main collision shapes are CapsuleShape3D_25gfb (radius 0.8) and CapsuleShape3D_igjkd (radius 0.41).
# We can skip those specific IDs, or just check if radius > 1.0 or height > 3.0, but some bone shapes might be radius 0.72.
# Let's use a regex to find all CapsuleShape3D sub_resources and divide their radius and height by 100 if they are > 0.5.

def replacer(match):
    full_block = match.group(0)
    
    # We don't want to shrink the main character collision shape which is usually around radius=0.4, height=1.7
    # Physical bones got scaled up by 100, so their heights are usually > 5.0
    
    def scale_down(m_val):
        val = float(m_val.group(1))
        # If the value is suspiciously large (e.g., radius > 0.5 or height > 4.0), it's a bone
        if val > 0.5:
            return f"{val / 100.0:.6f}"
        return str(val)

    # Process radius
    new_block = re.sub(r'radius = ([\d\.]+)', lambda m: f"radius = {scale_down(m)}", full_block)
    # Process height
    new_block = re.sub(r'height = ([\d\.]+)', lambda m: f"height = {scale_down(m)}", new_block)
    
    return new_block

# Find sub_resource blocks for CapsuleShape3D
pattern = r'\[sub_resource type="CapsuleShape3D" id="[^"]+"\]\nradius = [\d\.]+\nheight = [\d\.]+'
new_content = re.sub(pattern, replacer, content)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(new_content)

print("Fixed bone sizes in Z1.tscn")
