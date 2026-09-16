import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix delta warning
    content = content.replace("func _handle_zombie_overlapping_damage(delta: float)", "func _handle_zombie_overlapping_damage(_delta: float)")
    
    # Fix float to int narrowing conversion
    content = re.sub(r'var speed_kmh: int = speed_mps \* 3\.6', r'var speed_kmh: int = int(speed_mps * 3.6)', content)
    content = re.sub(r'var speed_kmh: int = speed_mps \* 2\.6', r'var speed_kmh: int = int(speed_mps * 2.6)', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("Warnings fixed!")
