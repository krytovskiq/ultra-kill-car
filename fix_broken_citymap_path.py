import re

def fix_path(filepath):
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        if "res://scripts/city_map.gd" in content:
            content = content.replace("res://scripts/city_map.gd", "res://levels/city_map.gd")
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"Fixed script path in {filepath}")
    except Exception as e:
        print(f"Error checking {filepath}: {e}")

fix_path("scene/City_MAP.tscn")
fix_path("levels/City_MAP.tscn")
