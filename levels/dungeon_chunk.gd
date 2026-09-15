extends "res://levels/world_chunk.gd"

@export var is_tunnel: bool = true
@export var wall_height: float = 40.0
@export var tunnel_color: Color = Color(0.1, 0.1, 0.12)

func _ready() -> void:
	super()
	if is_tunnel:
		_build_tunnel()
		
func _build_tunnel() -> void:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = tunnel_color
	mat.roughness = 0.9
	
	# Left wall
	var left_wall = MeshInstance3D.new()
	var left_mesh = BoxMesh.new()
	left_mesh.size = Vector3(20.0, wall_height, chunk_length)
	left_wall.mesh = left_mesh
	left_wall.material_override = mat
	left_wall.position = Vector3(-chunk_width / 2.0 + 10.0, wall_height / 2.0, 0.0)
	
	var left_col = CollisionShape3D.new()
	var left_shape = BoxShape3D.new()
	left_shape.size = left_mesh.size
	left_col.shape = left_shape
	left_col.position = left_wall.position
	
	$GroundBody.add_child(left_wall)
	$GroundBody.add_child(left_col)
	
	# Right wall
	var right_wall = MeshInstance3D.new()
	var right_mesh = BoxMesh.new()
	right_mesh.size = Vector3(20.0, wall_height, chunk_length)
	right_wall.mesh = right_mesh
	right_wall.material_override = mat
	right_wall.position = Vector3(chunk_width / 2.0 - 10.0, wall_height / 2.0, 0.0)
	
	var right_col = CollisionShape3D.new()
	var right_shape = BoxShape3D.new()
	right_shape.size = right_mesh.size
	right_col.shape = right_shape
	right_col.position = right_wall.position
	
	$GroundBody.add_child(right_wall)
	$GroundBody.add_child(right_col)
	
	# Roof
	var roof = MeshInstance3D.new()
	var roof_mesh = BoxMesh.new()
	roof_mesh.size = Vector3(chunk_width, 2.0, chunk_length)
	roof.mesh = roof_mesh
	roof.material_override = mat
	roof.position = Vector3(0.0, wall_height, 0.0)
	$GroundBody.add_child(roof)
	
	# Change floor material
	if _mesh_instance:
		var floor_mat = StandardMaterial3D.new()
		floor_mat.albedo_color = tunnel_color * 0.8
		floor_mat.roughness = 0.95
		_mesh_instance.material_override = floor_mat

