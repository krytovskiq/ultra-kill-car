import os, re

# Restore stable suspension settings
suspension = {
    "Mustang": {
        "suspension_travel": "0.15",
        "suspension_stiffness": "100.0",
        "suspension_max_force": "20000.0",
        "damping_compression": "12.0",
        "damping_relaxation": "14.0",
        "wheel_friction_slip": "4.5"
    },
    "pikap": {
        "suspension_travel": "0.2",
        "suspension_stiffness": "80.0",
        "suspension_max_force": "20000.0",
        "damping_compression": "10.0",
        "damping_relaxation": "12.0",
        "wheel_friction_slip": "4.0"
    },
    "Doge_Optimizado": {
        "suspension_travel": "0.15",
        "suspension_stiffness": "120.0",
        "suspension_max_force": "20000.0",
        "damping_compression": "14.0",
        "damping_relaxation": "16.0",
        "wheel_friction_slip": "4.5"
    },
    "BTR": {
        "suspension_travel": "0.25",
        "suspension_stiffness": "150.0",
        "suspension_max_force": "40000.0",
        "damping_compression": "15.0",
        "damping_relaxation": "18.0",
        "wheel_friction_slip": "3.5"
    }
}

tscn_files = [
    ("entities/vehicles/Mustang/mustang.tscn", "Mustang"),
    ("entities/vehicles/pikap/pikap.tscn", "pikap"),
    ("entities/vehicles/Doge_Optimizado/Doge2.tscn", "Doge_Optimizado"),
    ("entities/vehicles/BTR/BTR.tscn", "BTR"),
]

for tscn_path, vehicle_key in tscn_files:
    if not os.path.exists(tscn_path):
        continue
    with open(tscn_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    s = suspension[vehicle_key]
    
    content = re.sub(r'suspension_travel = [\d\.]+', f'suspension_travel = {s["suspension_travel"]}', content)
    content = re.sub(r'suspension_stiffness = [\d\.]+', f'suspension_stiffness = {s["suspension_stiffness"]}', content)
    content = re.sub(r'suspension_max_force = [\d\.]+', f'suspension_max_force = {s["suspension_max_force"]}', content)
    content = re.sub(r'damping_compression = [\d\.]+', f'damping_compression = {s["damping_compression"]}', content)
    content = re.sub(r'damping_relaxation = [\d\.]+', f'damping_relaxation = {s["damping_relaxation"]}', content)
    content = re.sub(r'wheel_friction_slip = [\d\.]+', f'wheel_friction_slip = {s["wheel_friction_slip"]}', content)

    with open(tscn_path, "w", encoding="utf-8") as f:
        f.write(content)
print("Restored stable suspension")
