import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace the zombie shake logic
    # Old: shake_camera(clampf(speed_mps / 20.0, 0.2, 1.5))
    # New: shake_camera(clampf(speed_mps / 50.0, 0.05, 0.3))
    content = content.replace("shake_camera(clampf(speed_mps / 20.0, 0.2, 1.5))", "shake_camera(clampf(speed_mps / 50.0, 0.05, 0.3))")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

print("Made zombie shake much smaller!")
