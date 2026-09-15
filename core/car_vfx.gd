extends Node

## VFX-менеджер. Autoload (CarVFX).

var tex_smoke: GradientTexture2D
var tex_blood: GradientTexture2D
var tex_spark: GradientTexture2D

func _ready() -> void:
	tex_smoke = GradientTexture2D.new()
	tex_smoke.width = 128
	tex_smoke.height = 128
	tex_smoke.fill = GradientTexture2D.FILL_RADIAL
	tex_smoke.fill_from = Vector2(0.5, 0.5)
	tex_smoke.fill_to = Vector2(0.9, 0.9)
	var grad_smoke = Gradient.new()
	grad_smoke.set_color(0, Color(1, 1, 1, 1))
	grad_smoke.set_color(1, Color(1, 1, 1, 0))
	tex_smoke.gradient = grad_smoke

	tex_blood = GradientTexture2D.new()
	tex_blood.width = 64
	tex_blood.height = 64
	tex_blood.fill = GradientTexture2D.FILL_RADIAL
	tex_blood.fill_from = Vector2(0.5, 0.5)
	tex_blood.fill_to = Vector2(0.8, 0.8)
	var grad_blood = Gradient.new()
	grad_blood.set_color(0, Color(1, 1, 1, 1))
	grad_blood.set_color(1, Color(1, 1, 1, 0.0))
	tex_blood.gradient = grad_blood


func _get_material(type: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	
	if type == "smoke" or type == "dust":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.albedo_texture = tex_smoke
	elif type == "sparks":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mat.emission_energy_multiplier = 4.0
	elif type == "blood":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		mat.roughness = 0.1
		mat.albedo_texture = tex_blood
	
	return mat

func _get_mesh(type: String) -> Mesh:
	if type == "sparks":
		# Для искр делаем 3D-палочки, чтобы они могли вращаться по ходу полета
		var b = BoxMesh.new()
		b.size = Vector3(0.04, 0.6, 0.04) 
		return b
	else:
		var q = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		return q

func spawn_impact(pos: Vector3, type: String = "sparks") -> void:
	var scene = get_tree().current_scene
	if not scene: return
	
	var p = CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.mesh = _get_mesh(type)
	p.material_override = _get_material(type)
	
	# Разброс позиций при спавне (искры спавнятся не из одной точки, а из небольшой сферы)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	
	match type:
		"blood":
			p.amount = 40
			p.lifetime = 0.5
			p.initial_velocity_min = 4.0
			p.initial_velocity_max = 12.0
			p.gravity = Vector3(0, -15, 0)
			p.spread = 70.0
			p.color = Color(0.8, 0.02, 0.02, 1.0)
			p.scale_amount_min = 0.3
			p.scale_amount_max = 1.0
			p.angle_min = 0.0
			p.angle_max = 360.0
		"sparks":
			p.amount = 35
			p.lifetime = 0.4
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector3(0, -20, 0)
			p.spread = 60.0
			p.color = Color(1.0, 0.8, 0.3, 1.0)
			p.scale_amount_min = 0.2    # Разные размеры искр!
			p.scale_amount_max = 1.5
			p.particle_flag_align_y = true # Искры поворачиваются по направлению полета!
		"dust":
			p.amount = 25
			p.lifetime = 1.2
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 6.0
			p.gravity = Vector3(0, -1, 0)
			p.spread = 90.0
			p.color = Color(0.5, 0.45, 0.4, 0.5)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 4.0
			p.angle_min = 0.0
			p.angle_max = 360.0

	scene.add_child(p)
	p.global_position = pos
	p.emitting = true
	
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(
		func(): if is_instance_valid(p): p.queue_free()
	)

func create_tire_smoke(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var smoke = CPUParticles3D.new()
	smoke.emitting = false
	smoke.amount = 16
	smoke.lifetime = 0.6
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.mesh = _get_mesh("smoke")
	smoke.material_override = _get_material("smoke")
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.0
	smoke.gravity = Vector3(0, 1.5, 0)
	smoke.spread = 45.0
	smoke.scale_amount_min = 1.0
	smoke.scale_amount_max = 2.5
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.color = Color(0.6, 0.6, 0.6, 0.3)
	
	parent.add_child(smoke)
	smoke.position = local_pos
	return smoke

func create_exhaust(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var exhaust = CPUParticles3D.new()
	exhaust.emitting = true
	exhaust.amount = 12
	exhaust.lifetime = 0.5
	exhaust.one_shot = false
	exhaust.explosiveness = 0.0
	exhaust.mesh = _get_mesh("smoke")
	exhaust.material_override = _get_material("smoke")
	exhaust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	exhaust.emission_sphere_radius = 0.1
	exhaust.initial_velocity_min = 1.0
	exhaust.initial_velocity_max = 3.0
	exhaust.direction = Vector3(0, 0, 1)
	exhaust.spread = 20.0
	exhaust.gravity = Vector3(0, 1.0, 0)
	exhaust.scale_amount_min = 0.1   # Разные размеры дыма
	exhaust.scale_amount_max = 1.0
	exhaust.angle_min = 0.0
	exhaust.angle_max = 360.0
	exhaust.color = Color(0.2, 0.2, 0.2, 0.4)
	
	parent.add_child(exhaust)
	exhaust.position = local_pos
	return exhaust
