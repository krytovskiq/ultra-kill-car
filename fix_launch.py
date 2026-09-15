import os, re

# 1. Fix vehicle initial velocity (remove it so car doesn't launch)
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
    
    # Remove the linear_velocity lines
    content = re.sub(r'\tvar _fwd = -global_transform\.basis\.z\n\t_fwd\.y = 0\.0\n\tlinear_velocity = _fwd\.normalized\(\) \* \([\d\.]+ / [\d\.]+\)\n', '', content)
    # Just in case the old line is still there
    content = re.sub(r'\tlinear_velocity = -global_transform\.basis\.z \* \([\d\.]+ / [\d\.]+\)\n', '', content)
    
    with open(vf, "w", encoding="utf-8") as f:
        f.write(content)


# 2. Fix z_1.gd ragdoll simulator reference
z_script = "entities/zombies/Z1/z_1.gd"
with open(z_script, "r", encoding="utf-8") as f:
    content = f.read()

# Replace the die logic
old_die_snippet = r'if skeleton and skeleton\.get_child_count\(\) > 1:\n\t\tanim_player\.stop\(\)\n\t\tskeleton\.physical_bones_start_simulation\(\)\n\t\t\n.*?for child in skeleton\.get_children\(\):'

new_die_snippet = """var sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
\tif sim:
\t\tanim_player.stop()
\t\tsim.physical_bones_start_simulation()
\t\t
\t\tvar force = impact_force * 5.0 + Vector3(0, 10.0, 0)
\t\tfor child in sim.get_children():"""

content = re.sub(old_die_snippet, new_die_snippet, content, flags=re.DOTALL)

# In reset_zombie
old_reset_snippet = r'if skeleton:\n\t\tskeleton\.physical_bones_stop_simulation\(\)'
new_reset_snippet = """if skeleton:
\t\tvar sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
\t\tif sim:
\t\t\tsim.physical_bones_stop_simulation()"""

content = re.sub(old_reset_snippet, new_reset_snippet, content)

with open(z_script, "w", encoding="utf-8") as f:
    f.write(content)

print("Fixed ragdoll and vehicle start velocity")
