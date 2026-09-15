import re

z_script = "entities/zombies/Z1/z_1.gd"
with open(z_script, "r", encoding="utf-8") as f:
    content = f.read()

# I need to fix the _ready() function to NOT delete Shoulder, Neck, Hand, Foot.
# Because deleting intermediate bones breaks the physical joints and makes the limbs tear off (stretching the mesh like a plastic bag).

old_if = r'if "Index" in n or "Toe" in n or "Hand" in n or "Neck" in n or "Shoulder" in n or "Foot" in n:'
new_if = r'if "Index" in n or "Thumb" in n or "Middle" in n or "Ring" in n or "Pinky" in n or "Toe" in n:'

content = content.replace(old_if, new_if)

# Also increase angular_damp slightly just to be safe
content = content.replace("child.angular_damp = 4.0", "child.angular_damp = 8.0")

with open(z_script, "w", encoding="utf-8") as f:
    f.write(content)

print("Restored broken joints")
