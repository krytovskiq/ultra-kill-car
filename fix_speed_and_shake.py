import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Make speedometer physically accurate (3.6) everywhere
    content = re.sub(r'int\(speed_mps \* 2\.6\)', r'int(speed_mps * 3.6)', content)
    content = re.sub(r'floori\(speed_mps \* 2\.6\)', r'int(speed_mps * 3.6)', content)
    content = re.sub(r'var speed_kmh: int = floori\(speed_mps \* [0-9\.]+\)', r'var speed_kmh: int = int(speed_mps * 3.6)', content)
    content = re.sub(r'var speed_kmh: int = int\(speed_mps \* [0-9\.]+\)', r'var speed_kmh: int = int(speed_mps * 3.6)', content)

    # Now fix the camera shake in _on_kill_zone_body_entered
    # Old logic:
    # if body.is_in_group("dead_wall"):
    #     if speed_mps >= crash_death_speed_mps:
    #         take_damage(current_hp)
    #         shake_camera(2.0)
    #
    # We want to replace shake_camera(X) with a dynamic formula:
    # shake_camera(clampf(speed_mps / X, min, max))
    
    # We will just write a custom replacer for shake_camera in _on_kill_zone_body_entered.
    # A simpler way: just replace shake_camera(2.0) with shake_camera(clampf(speed_mps / 10.0, 1.0, 4.0))
    # and shake_camera(0.5) with shake_camera(clampf(speed_mps / 20.0, 0.2, 1.5))
    
    content = content.replace("shake_camera(2.0)", "shake_camera(clampf(speed_mps / 10.0, 1.0, 4.0))")
    content = content.replace("shake_camera(0.5)", "shake_camera(clampf(speed_mps / 20.0, 0.2, 1.5))")
    
    # BTR has shake_camera(0.5) when hitting zombies, and shake_camera(1.0)? Let's replace any fixed floats.
    # Actually, BTR also has shake_camera(0.5).
    # Let's replace shake_camera(1.0) with shake_camera(clampf(speed_mps / 15.0, 0.5, 2.0))
    content = content.replace("shake_camera(1.0)", "shake_camera(clampf(speed_mps / 15.0, 0.5, 2.0))")

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
print("Updated speed multipliers and dynamic shake amounts in vehicle scripts.")
