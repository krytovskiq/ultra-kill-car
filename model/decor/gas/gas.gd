extends Area3D
@export var fuel_amount: float = 100.0

func _on_body_entered(body: Node) -> void:
	if body.has_method("refuel"):
		body.refuel(fuel_amount)
		queue_free() 
