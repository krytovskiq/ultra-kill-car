import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Increase the speedometer multiplier from 3.6 to 5.4 (1.5x arcade fake multiplier)
    # This makes the speedometer show 200 km/h when the car is physically going 133 km/h.
    # It's a standard trick in racing games to make speeds feel realistic to the player.
    content = content.replace("int(speed_mps * 3.6)", "int(speed_mps * 5.4)")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("Applied arcade speedometer multiplier to all vehicles!")
