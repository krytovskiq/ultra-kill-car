import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # In _on_kill_zone_body_entered, they usually have:
    # var speed_kmh := speed_mps * 3.6
    # Or var speed_kmh = speed_mps * 3.6
    # Let's change them to use 5.4 so the impact thresholds match the arcade speedometer!
    
    content = re.sub(r'var speed_kmh\s*[:=]\s*speed_mps\s*\*\s*3\.6', r'var speed_kmh = speed_mps * 5.4', content)
    content = re.sub(r'var speed_kmh\s*[:=]\s*int\(speed_mps\s*\*\s*3\.6\)', r'var speed_kmh: int = int(speed_mps * 5.4)', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("Normalized all speed_kmh calculations to 5.4 for consistency with the UI.")
