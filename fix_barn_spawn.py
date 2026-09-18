import re

tscn_path = "levels/main.gd"
with open(tscn_path, "r", encoding="utf-8") as f:
    content = f.read()

# Reset static counter
content = content.replace(
    'car.global_position = Vector3.ZERO',
    'car.global_position = Vector3.ZERO\n\t# Сброс счетчика сараев для нового заезда\n\tvar WorldChunk = load("res://levels/world_chunk.gd")\n\tWorldChunk.global_distance_counter = 0.0'
)

with open(tscn_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Reset global_distance_counter in main.gd.")
