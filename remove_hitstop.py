import os, re

vehicle_files = [
    "entities/vehicles/Mustang/mustang.gd",
    "entities/vehicles/pikap/pikap.gd",
    "entities/vehicles/Doge_Optimizado/doge_2.gd",
    "entities/vehicles/BTR/btr.gd"
]

for vf in vehicle_files:
    if not os.path.exists(vf): continue
    with open(vf, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove hit_stop calls completely
    content = re.sub(r'\t\t\t\thit_stop\([\d\.]+\)\n', '', content)
    content = re.sub(r'\t\t\thit_stop\([\d\.]+\)\n', '', content)
    
    with open(vf, "w", encoding="utf-8") as f:
        f.write(content)

print("Removed hit_stop from all vehicles")
