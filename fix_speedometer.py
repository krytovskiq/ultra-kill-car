import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find the linear_velocity.length() calculation and replace it with a 2D horizontal speed
    # Old: var speed_mps: float = linear_velocity.length()
    # New: 
    # var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)
    # var speed_mps: float = horizontal_vel.length()
    
    content = content.replace(
        "var speed_mps: float = linear_velocity.length()",
        "var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)\n\tvar speed_mps: float = horizontal_vel.length()"
    )
    
    # Just to be safe if someone used a slightly different spacing:
    content = content.replace(
        "var speed_mps := linear_velocity.length()",
        "var horizontal_vel := Vector2(linear_velocity.x, linear_velocity.z)\n\tvar speed_mps := horizontal_vel.length()"
    )

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("Updated speedometer logic to horizontal velocity in vehicle scripts.")
