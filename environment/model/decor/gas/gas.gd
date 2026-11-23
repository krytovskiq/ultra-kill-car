extends Area3D

@export var fuel_amount: float = 100.0
@export var fuel_fraction: float = 1.0
var _consumed: bool = false
var _spin_time: float = 0.0
var _visual_mesh: MeshInstance3D = null
var _ring_mesh: MeshInstance3D = null
var _base_mesh_y: float = 0.0

func _ready() -> void:
	var orig_col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if orig_col and orig_col.shape is BoxShape3D:
		(orig_col.shape as BoxShape3D).size = Vector3(220.0, 190.0, 220.0)
		orig_col.position = Vector3(0.0, 0.0, 36.0)
	else:
		var pickup_col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(220.0, 190.0, 220.0)
		pickup_col.shape = box
		add_child(pickup_col)

	_visual_mesh = get_node_or_null("kanistr_Material #253_0") as MeshInstance3D
	if _visual_mesh:
		_base_mesh_y = _visual_mesh.position.y

	# Unshaded subtle glowing beacon ring on the ground (safe on gl_compatibility)
	_ring_mesh = MeshInstance3D.new()
	_ring_mesh.name = "FuelRingBeacon"
	_ring_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var torus := TorusMesh.new()
	torus.inner_radius = 65.0
	torus.outer_radius = 88.0
	torus.rings = 16
	torus.ring_segments = 6
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(1.0, 0.56, 0.16, 0.65)
	_ring_mesh.mesh = torus
	_ring_mesh.material_override = rmat
	_ring_mesh.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_ring_mesh.position = Vector3(0.0, 0.0, 4.0)
	add_child(_ring_mesh)

func _process(delta: float) -> void:
	if _consumed:
		return
	_spin_time += delta
	if is_instance_valid(_visual_mesh):
		_visual_mesh.position.z = 8.0 + sin(_spin_time * 2.8) * 5.0
		_visual_mesh.rotation.z += delta * 1.4
	if is_instance_valid(_ring_mesh):
		var pulse := 1.0 + 0.08 * sin(_spin_time * 4.2)
		_ring_mesh.scale = Vector3(pulse, 1.0, pulse)

func _on_body_entered(body: Node) -> void:
	if _consumed or body == null or not body.is_in_group("player"):
		return
	_consumed = true
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_sfx"):
		sm.call("play_sfx", "fuel_pickup", -1.5, randf_range(0.96, 1.05))
	# Refuel ONLY — NEVER repair car HP on canister/station pickup!
	if body.has_method("refuel_from_canister"):
		body.call("refuel_from_canister", fuel_fraction)
	elif body.has_method("refuel"):
		var max_f_var = body.get("max_fuel")
		var target_refuel: float = maxf(fuel_amount * fuel_fraction, float(max_f_var) * fuel_fraction) if max_f_var != null else fuel_amount * fuel_fraction
		body.refuel(target_refuel)
	queue_free()
