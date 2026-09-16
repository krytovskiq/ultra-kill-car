import re

tscn_path = "entities/zombies/Z1/Z1.tscn"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove all lines containing joint_constraints/bias
content = re.sub(r'\n\s*joint_constraints/bias\s*=\s*[0-9\.]+', '', content)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Removed all bias constraints from Z1.tscn to fix Jolt Physics warnings!")
