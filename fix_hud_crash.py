import os
import glob
import re

for filepath in glob.glob("entities/vehicles/**/*.gd", recursive=True):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    for i in range(len(lines)):
        if "Hud/Metr.text =" in lines[i]:
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            lines[i] = indent + "var _m = get_node_or_null(\"Hud/Metr\")\n" + indent + "if is_instance_valid(_m): _m.text = " + lines[i].split(".text = ")[1]
        
        if "Hud/speed.text =" in lines[i]:
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            lines[i] = indent + "var _s = get_node_or_null(\"Hud/speed\")\n" + indent + "if is_instance_valid(_s): _s.text = " + lines[i].split(".text = ")[1]
            
        if "$Hud/Pause.visible" in lines[i]:
            indent = lines[i][:len(lines[i]) - len(lines[i].lstrip())]
            lines[i] = indent + "var _p = get_node_or_null(\"Hud/Pause\")\n" + indent + "if is_instance_valid(_p): _p.visible = get_tree().paused\n"
            
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(lines)
        
print("Successfully hardened HUD access in vehicle scripts!")
