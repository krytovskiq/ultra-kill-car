import re
import math

def normalize(v):
    length = math.sqrt(v[0]**2 + v[1]**2 + v[2]**2)
    if length == 0:
        return [0.0, 0.0, 0.0]
    return [v[0]/length, v[1]/length, v[2]/length]

tscn_path = "entities/zombies/Z1/Z1.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

def fix_transform(match):
    block = match.group(0)
    # Find the transform line
    def replace_transform(t_match):
        nums = [float(x) for x in t_match.group(1).split(', ')]
        if len(nums) == 12:
            x = normalize(nums[0:3])
            y = normalize(nums[3:6])
            z = normalize(nums[6:9])
            # Reconstruct the string
            # Format nicely
            def fmt(f):
                # if it's very close to 0, 1, or -1, round it
                if abs(f) < 1e-5: return "0"
                if abs(f - 1.0) < 1e-5: return "1"
                if abs(f + 1.0) < 1e-5: return "-1"
                return str(round(f, 6))
            
            new_nums = x + y + z + nums[9:12]
            new_str = ", ".join(fmt(n) if i < 9 else str(n) for i, n in enumerate(new_nums))
            return f"transform = Transform3D({new_str})"
        return t_match.group(0)
        
    block = re.sub(r'transform = Transform3D\((.*?)\)', replace_transform, block)
    return block

# The regex matches CollisionShape3D blocks
content = re.sub(r'\[node name="CollisionShape3D".*?\n(?:.*\n){1,3}', fix_transform, content)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Normalized all CollisionShape3D transforms in Z1.tscn to fix warnings")
