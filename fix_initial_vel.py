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
    
    # Replace the initial linear_velocity to be strictly horizontal
    old_line = r'linear_velocity = -global_transform.basis.z \* \(([\d\.]+) / ([\d\.]+)\)'
    new_line = r'var _fwd = -global_transform.basis.z\n\t_fwd.y = 0.0\n\tlinear_velocity = _fwd.normalized() * (\1 / \2)'
    
    content = re.sub(old_line, new_line, content)
    
    with open(vf, "w", encoding="utf-8") as f:
        f.write(content)

print("Fixed initial velocity vectors")
