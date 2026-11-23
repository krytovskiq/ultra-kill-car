extends Node

## VFX-менеджер. Autoload (CarVFX).
## Кэширует общие текстуры, материалы и меши, а также переиспользует пул CPUParticles3D.

const MAX_POOL_PER_TYPE := 24

var tex_smoke: GradientTexture2D
var tex_smoke_puff: ImageTexture
var tex_muzzle_fire: ImageTexture
var tex_blood: GradientTexture2D
var tex_spark_streak: ImageTexture
var tex_blood_splat: ImageTexture
var tex_blood_mist: ImageTexture
var tex_ash_flake: ImageTexture
var tex_rain_streak: ImageTexture

var _mat_smoke: StandardMaterial3D
var _mat_exhaust_smoke: StandardMaterial3D
var _mat_muzzle_smoke: StandardMaterial3D
var _mat_muzzle_fire: StandardMaterial3D
var _mat_sparks: StandardMaterial3D
var _mat_electric_sparks: StandardMaterial3D
var _mat_debris_chunks: StandardMaterial3D
var _mat_blood: StandardMaterial3D
var _mat_blood_mist: StandardMaterial3D

var _mesh_quad: QuadMesh
var _mesh_spark: ArrayMesh
var _mesh_chunk: ArrayMesh

var _grad_steam_smoke: Gradient
var _grad_oil_smoke: Gradient

var _impact_pools: Dictionary = {
	"blood": [],
	"blood_mist": [],
	"sparks": [],
	"landing_sparks": [],
	"dust": [],
	"muzzle_fire": [],
	"muzzle_smoke": [],
	"muzzle_sparks": [],
	"crash_chunks": [],
	"crash_dust": [],
	"electric_sparks": [],
	"car_wreck_shards": [],
}
var _pool_scene_id: int = 0
var _skid_manager: TireSkidManager = null
var _skid_scene_id: int = 0

func _ready() -> void:
	tex_smoke = GradientTexture2D.new()
	tex_smoke.width = 128
	tex_smoke.height = 128
	tex_smoke.fill = GradientTexture2D.FILL_RADIAL
	tex_smoke.fill_from = Vector2(0.5, 0.5)
	tex_smoke.fill_to = Vector2(0.9, 0.9)
	var grad_smoke := Gradient.new()
	grad_smoke.set_color(0, Color(1, 1, 1, 1))
	grad_smoke.set_color(1, Color(1, 1, 1, 0))
	tex_smoke.gradient = grad_smoke

	tex_smoke_puff = _build_smoke_puff_texture()
	tex_muzzle_fire = _build_fire_puff_texture()

	tex_blood = GradientTexture2D.new()
	tex_blood.width = 64
	tex_blood.height = 64
	tex_blood.fill = GradientTexture2D.FILL_RADIAL
	tex_blood.fill_from = Vector2(0.5, 0.5)
	tex_blood.fill_to = Vector2(0.8, 0.8)
	var grad_blood := Gradient.new()
	grad_blood.set_color(0, Color(1, 1, 1, 1))
	grad_blood.set_color(1, Color(1, 1, 1, 0.0))
	tex_blood.gradient = grad_blood
	tex_spark_streak = _build_spark_streak_texture()
	tex_blood_splat = _build_blood_splat_texture()
	tex_blood_mist = _build_blood_mist_texture()
	tex_ash_flake = _build_ash_flake_texture()
	tex_rain_streak = _build_rain_streak_texture()

	_mat_smoke = StandardMaterial3D.new()
	_mat_smoke.vertex_color_use_as_albedo = true
	_mat_smoke.vertex_color_is_srgb = true
	_mat_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_smoke.billboard_keep_scale = true
	_mat_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat_smoke.albedo_texture = tex_smoke_puff

	_mat_exhaust_smoke = StandardMaterial3D.new()
	_mat_exhaust_smoke.vertex_color_use_as_albedo = true
	_mat_exhaust_smoke.vertex_color_is_srgb = true
	_mat_exhaust_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_exhaust_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_exhaust_smoke.billboard_keep_scale = true
	_mat_exhaust_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_exhaust_smoke.albedo_texture = tex_smoke_puff

	_mat_muzzle_smoke = StandardMaterial3D.new()
	_mat_muzzle_smoke.vertex_color_use_as_albedo = true
	_mat_muzzle_smoke.vertex_color_is_srgb = true
	_mat_muzzle_smoke.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_muzzle_smoke.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_muzzle_smoke.billboard_keep_scale = true
	_mat_muzzle_smoke.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_muzzle_smoke.albedo_texture = tex_smoke_puff

	_mat_muzzle_fire = StandardMaterial3D.new()
	_mat_muzzle_fire.vertex_color_use_as_albedo = true
	_mat_muzzle_fire.vertex_color_is_srgb = true
	_mat_muzzle_fire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_muzzle_fire.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_muzzle_fire.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_muzzle_fire.billboard_keep_scale = true
	_mat_muzzle_fire.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_muzzle_fire.albedo_texture = tex_muzzle_fire

	_mat_sparks = StandardMaterial3D.new()
	_mat_sparks.vertex_color_use_as_albedo = true
	_mat_sparks.vertex_color_is_srgb = true
	_mat_sparks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_sparks.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_sparks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_sparks.albedo_texture = tex_spark_streak
	_mat_sparks.emission_enabled = true
	_mat_sparks.emission = Color(1.0, 0.72, 0.25)
	_mat_sparks.emission_energy_multiplier = 4.0

	_mat_electric_sparks = StandardMaterial3D.new()
	_mat_electric_sparks.vertex_color_use_as_albedo = true
	_mat_electric_sparks.vertex_color_is_srgb = true
	_mat_electric_sparks.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_electric_sparks.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat_electric_sparks.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_electric_sparks.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_electric_sparks.albedo_texture = tex_spark_streak
	_mat_electric_sparks.emission_enabled = true
	_mat_electric_sparks.emission = Color(0.55, 0.88, 1.0)
	_mat_electric_sparks.emission_energy_multiplier = 4.5

	_mat_debris_chunks = StandardMaterial3D.new()
	_mat_debris_chunks.vertex_color_use_as_albedo = true
	_mat_debris_chunks.vertex_color_is_srgb = true
	_mat_debris_chunks.roughness = 0.68
	_mat_debris_chunks.metallic = 0.25

	_mat_blood = StandardMaterial3D.new()
	_mat_blood.vertex_color_use_as_albedo = true
	_mat_blood.vertex_color_is_srgb = true
	_mat_blood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_blood.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_blood.billboard_keep_scale = true
	_mat_blood.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_blood.albedo_texture = tex_blood_splat

	_mat_blood_mist = StandardMaterial3D.new()
	_mat_blood_mist.vertex_color_use_as_albedo = true
	_mat_blood_mist.vertex_color_is_srgb = true
	_mat_blood_mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_blood_mist.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_mat_blood_mist.billboard_keep_scale = true
	_mat_blood_mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_blood_mist.albedo_texture = tex_blood_mist

	_mesh_quad = QuadMesh.new()
	_mesh_quad.size = Vector2(1.0, 1.0)

	_mesh_spark = _build_spark_streak_mesh()
	_mesh_chunk = _build_jagged_shard_mesh()

	_grad_steam_smoke = Gradient.new()
	_grad_steam_smoke.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	_grad_steam_smoke.colors = PackedColorArray([
		Color(0.76, 0.77, 0.79, 0.0),
		Color(0.68, 0.69, 0.71, 0.42),
		Color(0.58, 0.59, 0.61, 0.20),
		Color(0.55, 0.56, 0.58, 0.0)
	])

	_grad_oil_smoke = Gradient.new()
	_grad_oil_smoke.offsets = PackedFloat32Array([0.0, 0.15, 0.58, 1.0])
	_grad_oil_smoke.colors = PackedColorArray([
		Color(0.28, 0.20, 0.14, 0.0),
		Color(0.12, 0.11, 0.11, 0.78),
		Color(0.18, 0.17, 0.17, 0.44),
		Color(0.26, 0.25, 0.25, 0.0)
	])

func _hash2(ix: int, iy: int, seed_val: int) -> float:
	var n: int = (ix * 374761393 + iy * 668265263 + seed_val * 1442695041) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) * 1274126177
	n = n & 0x7FFFFFFF
	return float(n % 10000) / 10000.0

func _vnoise2(x: float, y: float, seed_val: int) -> float:
	var ix: int = int(floor(x))
	var iy: int = int(floor(y))
	var fx: float = x - float(ix)
	var fy: float = y - float(iy)
	var ux: float = fx * fx * (3.0 - 2.0 * fx)
	var uy: float = fy * fy * (3.0 - 2.0 * fy)
	var a: float = _hash2(ix, iy, seed_val)
	var b: float = _hash2(ix + 1, iy, seed_val)
	var c: float = _hash2(ix, iy + 1, seed_val)
	var d: float = _hash2(ix + 1, iy + 1, seed_val)
	return lerpf(lerpf(a, b, ux), lerpf(c, d, ux), uy)

func _fbm2(x: float, y: float, seed_val: int, octaves: int = 4) -> float:
	var sum := 0.0
	var amp := 0.5
	var freq := 1.0
	var norm := 0.0
	for _o in range(octaves):
		sum += _vnoise2(x * freq, y * freq, seed_val + _o * 97) * amp
		norm += amp
		amp *= 0.5
		freq *= 2.03
	return sum / maxf(norm, 0.001)

func _build_smoke_puff_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var lobes: Array[Vector3] = [
		Vector3(0.50, 0.48, 0.35),
		Vector3(0.35, 0.52, 0.27),
		Vector3(0.65, 0.50, 0.26),
		Vector3(0.45, 0.34, 0.25),
		Vector3(0.57, 0.63, 0.25),
	]
	for y in range(size):
		var v := (float(y) + 0.5) / float(size)
		for x in range(size):
			var u := (float(x) + 0.5) / float(size)
			var fbm := _fbm2(u * 6.5, v * 6.5, 19, 4)
			var fine := _fbm2(u * 14.0, v * 14.0, 73, 3)
			var density := 0.0
			for lobe: Vector3 in lobes:
				var dx: float = u - lobe.x
				var dy: float = v - lobe.y
				var d: float = sqrt(dx * dx + dy * dy) / (lobe.z * (0.86 + 0.28 * fbm))
				if d < 1.0:
					var w: float = 1.0 - d
					density = maxf(density, w * w * (3.0 - 2.0 * w))
			var edge_r := sqrt((u - 0.5) * (u - 0.5) + (v - 0.5) * (v - 0.5)) * 2.0
			var outer_fade := clampf(1.0 - pow(clampf(edge_r, 0.0, 1.0), 2.3), 0.0, 1.0)
			var wisp := clampf(0.62 + 0.55 * fbm - 0.18 * (1.0 - fine), 0.0, 1.15)
			var alpha := clampf(density * wisp * outer_fade, 0.0, 1.0)
			var lit := clampf(0.66 + (0.50 - v) * 0.28 + fbm * 0.22 + density * 0.08, 0.58, 1.0)
			img.set_pixel(x, y, Color(lit, lit, lit, alpha))
	return ImageTexture.create_from_image(img)

func _build_fire_puff_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		var v := (float(y) + 0.5) / float(size)
		for x in range(size):
			var u := (float(x) + 0.5) / float(size)
			var dx := u - 0.5
			var dy := (v - 0.55) * 0.92
			var r := sqrt(dx * dx + dy * dy) * 2.0
			var turb := _fbm2(u * 8.5, v * 9.5 - u * 1.4, 131, 4)
			var tongue := 0.65 + 0.52 * turb
			var falloff := clampf(1.0 - r / maxf(tongue, 0.28), 0.0, 1.0)
			var val := pow(falloff, 1.45)
			var core := clampf(1.0 - r * 1.45, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, lerpf(0.78, 0.99, core), lerpf(0.45, 0.94, core * core), val))
	return ImageTexture.create_from_image(img)

func _build_spark_streak_texture() -> ImageTexture:
	var w := 48
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v := (float(y) + 0.5) / float(h)
		var dv := (v - 0.5) * 2.0
		var profile_y := clampf(1.0 - dv * dv, 0.0, 1.0)
		var half_w := maxf(0.10, 0.85 * profile_y)
		for x in range(w):
			var u := (float(x) + 0.5) / float(w)
			var du := absf((u - 0.5) * 2.0) / half_w
			var radial := clampf(1.0 - du, 0.0, 1.0)
			var a := clampf(pow(radial, 2.0) * pow(profile_y, 0.85), 0.0, 1.0)
			var core := clampf(1.0 - du * 1.9, 0.0, 1.0) * profile_y
			img.set_pixel(x, y, Color(1.0, lerpf(0.84, 0.99, core), lerpf(0.48, 0.96, core * core), a))
	return ImageTexture.create_from_image(img)

func _build_blood_splat_texture() -> ImageTexture:
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	# Единый органический рваный сгусток крови с тремя близкими сателлитами
	var droplets: Array[Vector3] = [
		Vector3(0.50, 0.50, 0.25),
		Vector3(0.41, 0.44, 0.17),
		Vector3(0.59, 0.54, 0.16),
		Vector3(0.28, 0.40, 0.065),
		Vector3(0.71, 0.62, 0.058),
		Vector3(0.45, 0.27, 0.055),
	]
	for y in range(size):
		var v := (float(y) + 0.5) / float(size)
		for x in range(size):
			var u := (float(x) + 0.5) / float(size)
			var n_edge := _fbm2(u * 9.5, v * 9.5, 409, 4)
			var n_fine := _fbm2(u * 21.0, v * 21.0, 521, 3)
			var d_max := 0.0
			for d_p: Vector3 in droplets:
				var dx := u - d_p.x
				var dy := v - d_p.y
				var r := sqrt(dx * dx + dy * dy) / (d_p.z * (0.72 + 0.54 * n_edge))
				if r < 1.0:
					d_max = maxf(d_max, 1.0 - r * r)
			var a := clampf((d_max - 0.18) * 3.6, 0.0, 1.0)
			var core_shade := clampf(0.84 + 0.16 * n_fine, 0.78, 1.0)
			img.set_pixel(x, y, Color(core_shade, core_shade * 0.90, core_shade * 0.90, a))
	return ImageTexture.create_from_image(img)

func _build_blood_mist_texture() -> ImageTexture:
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		var v := (float(y) + 0.5) / float(size)
		for x in range(size):
			var u := (float(x) + 0.5) / float(size)
			var r := sqrt((u - 0.5) * (u - 0.5) + (v - 0.5) * (v - 0.5)) * 2.0
			var fbm := _fbm2(u * 7.0, v * 7.0, 517, 4)
			var radial := clampf(1.0 - pow(clampf(r, 0.0, 1.0), 1.8), 0.0, 1.0)
			var a := clampf(radial * (0.35 + 0.78 * fbm), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.95, 0.88, 0.88, a))
	return ImageTexture.create_from_image(img)

func _build_ash_flake_texture() -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		var v := (float(y) + 0.5) / float(size)
		for x in range(size):
			var u := (float(x) + 0.5) / float(size)
			var dx := (u - 0.5) * 1.15
			var dy := (v - 0.5) * 1.45
			var ang := atan2(dy, dx)
			var r := sqrt(dx * dx + dy * dy) * 2.0
			var n := _fbm2(u * 10.0, v * 10.0, 613, 3)
			var rag := 0.54 + 0.24 * n + 0.16 * sin(ang * 5.0 + 0.8) + 0.12 * cos(ang * 9.0 - u * 6.0)
			var a := clampf((rag - r) * 3.8, 0.0, 1.0)
			img.set_pixel(x, y, Color(0.92, 0.90, 0.88, a))
	return ImageTexture.create_from_image(img)

func _build_rain_streak_texture() -> ImageTexture:
	var w := 16
	var h := 96
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v := (float(y) + 0.5) / float(h)
		var profile_y := clampf(sin(v * PI), 0.0, 1.0)
		for x in range(w):
			var u := (float(x) + 0.5) / float(w)
			var du := absf((u - 0.5) * 2.0)
			var profile_x := clampf(1.0 - du * du, 0.0, 1.0)
			var a := clampf(pow(profile_x, 2.2) * pow(profile_y, 0.65), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.96, 1.0, 0.94, a))
	return ImageTexture.create_from_image(img)

func _build_spark_streak_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := 0.065
	var hh := 0.34
	for rot_y: float in [0.0, PI * 0.5]:
		var b := Basis(Vector3.UP, rot_y)
		var v0 := b * Vector3(-hw, -hh, 0.0)
		var v1 := b * Vector3(hw, -hh, 0.0)
		var v2 := b * Vector3(hw, hh, 0.0)
		var v3 := b * Vector3(-hw, hh, 0.0)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(v1)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(v0)
		st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(v2)
		st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(v3)
	st.generate_normals()
	return st.commit()

func _build_jagged_shard_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p_top := Vector3(0.04, 0.20, -0.02)
	var p_bot := Vector3(-0.03, -0.18, 0.03)
	var ring := [
		Vector3(0.18, 0.02, 0.04),
		Vector3(-0.06, 0.05, 0.16),
		Vector3(-0.17, -0.03, -0.05),
		Vector3(0.05, -0.02, -0.15),
	]
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		st.add_vertex(p_top); st.add_vertex(a); st.add_vertex(b)
		st.add_vertex(p_bot); st.add_vertex(b); st.add_vertex(a)
	st.generate_normals()
	return st.commit()

func _get_material(type: String) -> StandardMaterial3D:
	match type:
		"sparks", "landing_sparks", "muzzle_sparks", "he_sparks":
			return _mat_sparks
		"electric_sparks":
			return _mat_electric_sparks
		"crash_chunks", "car_wreck_shards":
			return _mat_debris_chunks
		"blood":
			return _mat_blood
		"blood_mist":
			return _mat_blood_mist
		"muzzle_fire", "he_fire":
			return _mat_muzzle_fire
		"muzzle_smoke", "he_smoke", "crash_dust":
			return _mat_muzzle_smoke
		_:
			return _mat_smoke

func _get_mesh(type: String) -> Mesh:
	if type == "sparks" or type == "landing_sparks" or type == "muzzle_sparks" or type == "he_sparks" or type == "electric_sparks":
		return _mesh_spark
	if type == "crash_chunks" or type == "car_wreck_shards":
		return _mesh_chunk
	return _mesh_quad

func _get_vfx_scale() -> float:
	var sm: Node = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_method("get_vfx_scale"):
		return float(sm.call("get_vfx_scale"))
	return 1.0

func _create_impact_particles(type: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.95
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_range_end = 110.0
	p.mesh = _get_mesh(type)
	p.material_override = _get_material(type)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.4
	var vfx_scale: float = _get_vfx_scale()

	match type:
		"blood":
			p.amount = maxi(roundi(46.0 * vfx_scale), 10)
			p.lifetime = 0.62
			p.explosiveness = 0.94
			p.local_coords = false
			p.emission_sphere_radius = 0.32
			p.initial_velocity_min = 5.5
			p.initial_velocity_max = 17.5
			p.damping_min = 1.6
			p.damping_max = 3.2
			p.gravity = Vector3(0, -21, 0)
			p.spread = 78.0
			p.scale_amount_min = 0.16
			p.scale_amount_max = 0.50
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
			var bl_sc := Curve.new()
			bl_sc.add_point(Vector2(0.0, 0.55))
			bl_sc.add_point(Vector2(0.22, 1.15))
			bl_sc.add_point(Vector2(1.0, 0.45))
			p.scale_amount_curve = bl_sc
			var bl_ramp := Gradient.new()
			bl_ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.78, 1.0])
			bl_ramp.colors = PackedColorArray([
				Color(0.72, 0.04, 0.03, 0.96),
				Color(0.48, 0.02, 0.02, 0.90),
				Color(0.24, 0.01, 0.01, 0.55),
				Color(0.12, 0.005, 0.005, 0.0),
			])
			p.color_ramp = bl_ramp
		"blood_mist":
			p.amount = maxi(roundi(14.0 * vfx_scale), 4)
			p.lifetime = 0.56
			p.explosiveness = 0.88
			p.local_coords = false
			p.emission_sphere_radius = 0.45
			p.initial_velocity_min = 1.8
			p.initial_velocity_max = 5.8
			p.damping_min = 4.0
			p.damping_max = 7.0
			p.gravity = Vector3(0, -2.8, 0)
			p.spread = 95.0
			p.scale_amount_min = 0.65
			p.scale_amount_max = 1.75
			p.angle_min = 0.0
			p.angle_max = 360.0
			var bm_sc := Curve.new()
			bm_sc.add_point(Vector2(0.0, 0.45))
			bm_sc.add_point(Vector2(0.35, 1.15))
			bm_sc.add_point(Vector2(1.0, 1.85))
			p.scale_amount_curve = bm_sc
			var bm_ramp := Gradient.new()
			bm_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.72, 1.0])
			bm_ramp.colors = PackedColorArray([
				Color(0.34, 0.016, 0.018, 0.52),
				Color(0.22, 0.010, 0.012, 0.34),
				Color(0.12, 0.006, 0.007, 0.14),
				Color(0.08, 0.004, 0.005, 0.0),
			])
			p.color_ramp = bm_ramp
		"sparks":
			p.amount = maxi(roundi(35.0 * vfx_scale), 6)
			p.lifetime = 0.4
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 30.0
			p.gravity = Vector3(0, -20, 0)
			p.spread = 60.0
			p.color = Color(1.0, 0.8, 0.3, 1.0)
			p.scale_amount_min = 0.2
			p.scale_amount_max = 1.5
			p.particle_flag_align_y = true
		"landing_sparks":
			p.amount = maxi(roundi(68.0 * vfx_scale), 18)
			p.lifetime = 0.55
			p.explosiveness = 0.92
			p.local_coords = false
			p.emission_sphere_radius = 0.52
			p.direction = Vector3(0.0, 0.42, 1.0)
			p.spread = 56.0
			p.initial_velocity_min = 11.0
			p.initial_velocity_max = 28.0
			p.gravity = Vector3(0.0, -22.0, 0.0)
			p.color = Color(1.0, 0.86, 0.38, 1.0)
			p.scale_amount_min = 0.65
			p.scale_amount_max = 1.95
			p.particle_flag_align_y = true
			var ls_ramp := Gradient.new()
			ls_ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.80, 1.0])
			ls_ramp.colors = PackedColorArray([
				Color(1.0, 0.98, 0.82, 1.0),
				Color(1.0, 0.72, 0.22, 0.98),
				Color(0.98, 0.32, 0.05, 0.75),
				Color(0.60, 0.10, 0.0, 0.0)
			])
			p.color_ramp = ls_ramp
		"dust":
			p.amount = maxi(roundi(25.0 * vfx_scale), 6)
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
		"muzzle_fire":
			p.amount = maxi(roundi(16.0 * vfx_scale), 6)
			p.lifetime = 0.16
			p.explosiveness = 0.96
			p.local_coords = false
			p.emission_sphere_radius = 0.08
			p.direction = Vector3(0, 0, -1)
			p.spread = 18.0
			p.initial_velocity_min = 1.8
			p.initial_velocity_max = 5.8
			p.gravity = Vector3(0, 1.0, 0)
			p.scale_amount_min = 0.78
			p.scale_amount_max = 1.50
			p.angle_min = 0.0
			p.angle_max = 360.0
			var f_ramp := Gradient.new()
			f_ramp.offsets = PackedFloat32Array([0.0, 0.35, 0.75, 1.0])
			f_ramp.colors = PackedColorArray([
				Color(1.0, 0.96, 0.78, 1.0),
				Color(1.0, 0.56, 0.12, 0.92),
				Color(0.88, 0.18, 0.02, 0.45),
				Color(0.5, 0.08, 0.0, 0.0)
			])
			p.color_ramp = f_ramp
		"muzzle_smoke":
			p.amount = maxi(roundi(22.0 * vfx_scale), 8)
			p.lifetime = 1.35
			p.explosiveness = 0.88
			p.local_coords = false
			p.emission_sphere_radius = 0.18
			p.direction = Vector3(0, 0.10, -1)
			p.spread = 34.0
			p.initial_velocity_min = 3.5
			p.initial_velocity_max = 9.0
			p.damping_min = 4.5
			p.damping_max = 6.8
			p.gravity = Vector3(0, 1.85, 0)
			p.scale_amount_min = 0.60
			p.scale_amount_max = 1.25
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -65.0
			p.angular_velocity_max = 65.0
			var sc := Curve.new()
			sc.add_point(Vector2(0.0, 0.45))
			sc.add_point(Vector2(0.30, 1.25))
			sc.add_point(Vector2(1.0, 2.70))
			p.scale_amount_curve = sc
			var s_ramp := Gradient.new()
			s_ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.55, 1.0])
			s_ramp.colors = PackedColorArray([
				Color(0.88, 0.64, 0.40, 0.56),
				Color(0.34, 0.34, 0.36, 0.52),
				Color(0.52, 0.52, 0.54, 0.22),
				Color(0.58, 0.58, 0.60, 0.0)
			])
			p.color_ramp = s_ramp
		"muzzle_sparks":
			p.amount = maxi(roundi(18.0 * vfx_scale), 6)
			p.lifetime = 0.28
			p.explosiveness = 0.96
			p.local_coords = false
			p.emission_sphere_radius = 0.12
			p.direction = Vector3(0, 0, -1)
			p.spread = 22.0
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 28.0
			p.gravity = Vector3(0, -14.0, 0)
			p.color = Color(1.0, 0.78, 0.30, 1.0)
			p.scale_amount_min = 0.25
			p.scale_amount_max = 0.95
			p.particle_flag_align_y = true
		"he_fire":
			p.amount = maxi(roundi(24.0 * vfx_scale), 10)
			p.lifetime = 0.36
			p.explosiveness = 0.95
			p.local_coords = false
			p.emission_sphere_radius = 1.15
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 3.5
			p.initial_velocity_max = 11.5
			p.damping_min = 4.5
			p.damping_max = 7.5
			p.gravity = Vector3(0, 3.2, 0)
			p.scale_amount_min = 1.6
			p.scale_amount_max = 3.4
			p.angle_min = 0.0
			p.angle_max = 360.0
			var hf_sc := Curve.new()
			hf_sc.add_point(Vector2(0.0, 0.45))
			hf_sc.add_point(Vector2(0.28, 1.35))
			hf_sc.add_point(Vector2(1.0, 0.20))
			p.scale_amount_curve = hf_sc
			var hf_ramp := Gradient.new()
			hf_ramp.offsets = PackedFloat32Array([0.0, 0.28, 0.68, 1.0])
			hf_ramp.colors = PackedColorArray([
				Color(1.0, 0.96, 0.80, 1.0),
				Color(1.0, 0.55, 0.10, 0.94),
				Color(0.86, 0.16, 0.02, 0.50),
				Color(0.35, 0.05, 0.01, 0.0)
			])
			p.color_ramp = hf_ramp
		"he_smoke":
			p.amount = maxi(roundi(26.0 * vfx_scale), 10)
			p.lifetime = 1.65
			p.explosiveness = 0.90
			p.local_coords = false
			p.emission_sphere_radius = 1.65
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 3.2
			p.initial_velocity_max = 10.5
			p.damping_min = 4.2
			p.damping_max = 6.5
			p.gravity = Vector3(0, 2.2, 0)
			p.scale_amount_min = 1.85
			p.scale_amount_max = 4.10
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -55.0
			p.angular_velocity_max = 55.0
			var hs_sc := Curve.new()
			hs_sc.add_point(Vector2(0.0, 0.55))
			hs_sc.add_point(Vector2(0.32, 1.35))
			hs_sc.add_point(Vector2(1.0, 2.40))
			p.scale_amount_curve = hs_sc
			var hs_ramp := Gradient.new()
			hs_ramp.offsets = PackedFloat32Array([0.0, 0.14, 0.52, 1.0])
			hs_ramp.colors = PackedColorArray([
				Color(0.90, 0.55, 0.25, 0.62),
				Color(0.26, 0.25, 0.24, 0.58),
				Color(0.45, 0.44, 0.43, 0.24),
				Color(0.55, 0.54, 0.52, 0.0)
			])
			p.color_ramp = hs_ramp
		"he_sparks":
			p.amount = maxi(roundi(30.0 * vfx_scale), 10)
			p.lifetime = 0.52
			p.explosiveness = 0.96
			p.local_coords = false
			p.emission_sphere_radius = 0.75
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 16.0
			p.initial_velocity_max = 36.0
			p.gravity = Vector3(0, -18.0, 0)
			p.color = Color(1.0, 0.76, 0.24, 1.0)
			p.scale_amount_min = 0.35
			p.scale_amount_max = 1.45
			p.particle_flag_align_y = true
		"electric_sparks":
			p.amount = maxi(roundi(36.0 * vfx_scale), 10)
			p.lifetime = 0.55
			p.explosiveness = 0.94
			p.local_coords = false
			p.emission_sphere_radius = 0.55
			p.direction = Vector3(0, 0.55, 0.85)
			p.spread = 72.0
			p.initial_velocity_min = 12.0
			p.initial_velocity_max = 28.0
			p.gravity = Vector3(0, -19.0, 0)
			p.color = Color(0.65, 0.92, 1.0, 1.0)
			p.scale_amount_min = 0.45
			p.scale_amount_max = 1.55
			p.particle_flag_align_y = true
		"crash_chunks":
			p.amount = maxi(roundi(18.0 * vfx_scale), 6)
			p.lifetime = 1.15
			p.explosiveness = 0.94
			p.local_coords = false
			p.emission_sphere_radius = 0.65
			p.direction = Vector3(0, 0.55, 0.65)
			p.spread = 75.0
			p.initial_velocity_min = 6.5
			p.initial_velocity_max = 18.5
			p.gravity = Vector3(0, -16.0, 0)
			p.scale_amount_min = 0.55
			p.scale_amount_max = 1.65
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -420.0
			p.angular_velocity_max = 420.0
			p.color = Color(0.38, 0.36, 0.34, 1.0)
		"crash_dust":
			p.amount = maxi(roundi(16.0 * vfx_scale), 6)
			p.lifetime = 1.25
			p.explosiveness = 0.86
			p.local_coords = false
			p.emission_sphere_radius = 0.85
			p.direction = Vector3(0, 0.65, 0.4)
			p.spread = 70.0
			p.initial_velocity_min = 2.2
			p.initial_velocity_max = 7.5
			p.damping_min = 3.2
			p.damping_max = 5.4
			p.gravity = Vector3(0, 0.85, 0)
			p.scale_amount_min = 1.15
			p.scale_amount_max = 2.85
			p.angle_min = 0.0
			p.angle_max = 360.0
			var cd_sc := Curve.new()
			cd_sc.add_point(Vector2(0.0, 0.48))
			cd_sc.add_point(Vector2(0.40, 1.20))
			cd_sc.add_point(Vector2(1.0, 2.05))
			p.scale_amount_curve = cd_sc
		"car_wreck_shards":
			p.amount = maxi(roundi(28.0 * vfx_scale), 10)
			p.lifetime = 1.85
			p.explosiveness = 0.96
			p.local_coords = false
			p.emission_sphere_radius = 1.05
			p.direction = Vector3(0, 1.0, 0)
			p.spread = 155.0
			p.initial_velocity_min = 9.0
			p.initial_velocity_max = 24.0
			p.gravity = Vector3(0, -15.0, 0)
			p.scale_amount_min = 0.75
			p.scale_amount_max = 2.25
			p.angle_min = 0.0
			p.angle_max = 360.0
			p.angular_velocity_min = -520.0
			p.angular_velocity_max = 520.0
			p.color = Color(0.28, 0.24, 0.22, 1.0)

	return p

func _acquire_impact(type: String, scene: Node) -> CPUParticles3D:
	var scene_id := scene.get_instance_id()
	if _pool_scene_id != scene_id:
		_pool_scene_id = scene_id
		for k in _impact_pools.keys():
			_impact_pools[k].clear()

	if not _impact_pools.has(type):
		_impact_pools[type] = []

	var pool: Array = _impact_pools[type]
	while pool.size() > 0:
		var candidate = pool.pop_back()
		if is_instance_valid(candidate) and candidate.is_inside_tree():
			return candidate as CPUParticles3D

	var created := _create_impact_particles(type)
	scene.add_child(created)
	return created

func _recycle_after(p: CPUParticles3D, type: String, scene_id: int) -> void:
	var wr_p: WeakRef = weakref(p)
	var wr_self: WeakRef = weakref(self)
	get_tree().create_timer(p.lifetime + 0.35).timeout.connect(
		func():
			var node_p = wr_p.get_ref()
			var self_ref = wr_self.get_ref()
			if not node_p or not is_instance_valid(node_p):
				return
			node_p.emitting = false
			node_p.visible = false
			if self_ref and self_ref.get("_pool_scene_id") == scene_id and self_ref.get("_impact_pools").has(type) and self_ref.get("_impact_pools")[type].size() < MAX_POOL_PER_TYPE:
				self_ref.get("_impact_pools")[type].append(node_p)
			else:
				node_p.queue_free()
	)

func spawn_impact(pos: Vector3, type: String = "sparks") -> void:
	var scene := get_tree().current_scene
	if not scene:
		return

	var p := _acquire_impact(type, scene)
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true
	_recycle_after(p, type, scene.get_instance_id())
	if type == "blood":
		var pm := _acquire_impact("blood_mist", scene)
		pm.global_position = pos
		pm.visible = true
		pm.restart()
		pm.emitting = true
		_recycle_after(pm, "blood_mist", scene.get_instance_id())

func spawn_landing_sparks(contact_points: Array[Vector3], car_vel: Vector3 = Vector3.ZERO, intensity: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if not scene or contact_points.is_empty():
		return
	var scene_id := scene.get_instance_id()
	var horiz_vel := Vector3(car_vel.x, 0.0, car_vel.z)
	var spray_back: Vector3 = (-horiz_vel.normalized() if horiz_vel.length_squared() > 0.25 else Vector3.BACK)
	var spray_dir: Vector3 = (spray_back + Vector3(0.0, 0.38, 0.0)).normalized()
	var up_ref := Vector3.UP if absf(spray_dir.y) < 0.95 else Vector3.RIGHT
	var v_scale: float = clampf(intensity, 0.55, 1.65)

	for i in range(contact_points.size()):
		var pt: Vector3 = contact_points[i]
		var sp := _acquire_impact("landing_sparks", scene)
		sp.global_position = pt
		sp.look_at(pt + spray_dir, up_ref)
		sp.initial_velocity_min = 8.5 * v_scale
		sp.initial_velocity_max = 24.0 * v_scale
		sp.visible = true
		sp.restart()
		sp.emitting = true
		_recycle_after(sp, "landing_sparks", scene_id)

	var center_pt: Vector3 = contact_points[0]
	if contact_points.size() > 1:
		var sum_pt := Vector3.ZERO
		for pt in contact_points:
			sum_pt += pt
		center_pt = sum_pt / float(contact_points.size())
	var dust := _acquire_impact("dust", scene)
	dust.global_position = center_pt + Vector3(0.0, 0.12, 0.0)
	dust.visible = true
	dust.restart()
	dust.emitting = true
	_recycle_after(dust, "dust", scene_id)

func spawn_muzzle_blast(world_pos: Vector3, forward_dir: Vector3, inherit_vel: Vector3 = Vector3.ZERO) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return

	var dir := forward_dir.normalized() if forward_dir.length_squared() > 0.0001 else Vector3.FORWARD
	var up_ref := Vector3.UP if absf(dir.y) < 0.96 else Vector3.RIGHT
	var fwd_lead := maxf(inherit_vel.dot(dir), 0.0) * 0.04
	var spawn_pos := world_pos + dir * fwd_lead
	var scene_id := scene.get_instance_id()

	for mtype: String in ["muzzle_fire", "muzzle_smoke", "muzzle_sparks"]:
		var p := _acquire_impact(mtype, scene)
		p.global_position = spawn_pos
		p.look_at(spawn_pos + dir, up_ref)
		p.visible = true
		p.restart()
		p.emitting = true
		_recycle_after(p, mtype, scene_id)

func spawn_he_explosion(world_pos: Vector3, blast_radius: float = 7.5) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var scene_id := scene.get_instance_id()
	var center := world_pos + Vector3(0.0, 0.45, 0.0)
	var r_scale := clampf(blast_radius / 7.5, 0.6, 1.8)
	for etype: String in ["he_fire", "he_smoke", "he_sparks"]:
		var p := _acquire_impact(etype, scene)
		p.global_position = center
		p.emission_sphere_radius = (1.15 if etype == "he_fire" else (1.65 if etype == "he_smoke" else 0.75)) * r_scale
		match etype:
			"he_fire":
				p.scale_amount_min = 1.6
				p.scale_amount_max = 3.4
			"he_smoke":
				p.scale_amount_min = 1.85
				p.scale_amount_max = 4.10
			_:
				p.scale_amount_min = 0.35
				p.scale_amount_max = 1.45
		p.visible = true
		p.restart()
		p.emitting = true
		_recycle_after(p, etype, scene_id)

func spawn_barrel_explosion(world_pos: Vector3, blast_radius: float = 12.5) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var scene_id := scene.get_instance_id()
	var center := world_pos + Vector3(0.0, 0.55, 0.0)
	var vfx_scale: float = _get_vfx_scale()
	var r_scale := clampf(blast_radius / 11.0, 0.8, 1.75)

	# 1. Core HE blast fireball + billowing black smoke + flying sparks
	for etype: String in ["he_fire", "he_smoke", "he_sparks"]:
		var p := _acquire_impact(etype, scene)
		p.global_position = center
		p.emission_sphere_radius = (1.55 if etype == "he_fire" else (2.25 if etype == "he_smoke" else 1.05)) * r_scale
		match etype:
			"he_fire":
				p.scale_amount_min = 2.1 * r_scale
				p.scale_amount_max = 4.6 * r_scale
			"he_smoke":
				p.scale_amount_min = 2.4 * r_scale
				p.scale_amount_max = 5.4 * r_scale
			_:
				p.scale_amount_min = 0.50 * r_scale
				p.scale_amount_max = 1.95 * r_scale
		p.visible = true
		p.restart()
		p.emitting = true
		_recycle_after(p, etype, scene_id)

	# 2. Ground shockwave dust ring + hot jagged barrel shrapnel + transient blast flash light
	var ring := CPUParticles3D.new()
	ring.name = "BarrelShockDust"
	ring.one_shot = true
	ring.explosiveness = 0.96
	ring.local_coords = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.amount = maxi(roundi(24.0 * vfx_scale), 8)
	ring.lifetime = 1.35
	ring.mesh = _mesh_quad
	ring.material_override = _mat_muzzle_smoke
	ring.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	ring.emission_ring_radius = 1.8 * r_scale
	ring.emission_ring_inner_radius = 0.4
	ring.emission_ring_height = 0.2
	ring.emission_ring_axis = Vector3.UP
	ring.direction = Vector3(0.0, 0.16, 1.0)
	ring.spread = 180.0
	ring.gravity = Vector3(0.0, 1.6, 0.0)
	ring.damping_min = 4.5
	ring.damping_max = 7.0
	ring.initial_velocity_min = 10.0 * r_scale
	ring.initial_velocity_max = 20.0 * r_scale
	ring.scale_amount_min = 1.9
	ring.scale_amount_max = 3.8
	ring.angle_min = 0.0
	ring.angle_max = 360.0
	var rg := Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.18, 0.55, 1.0])
	rg.colors = PackedColorArray([
		Color(0.95, 0.56, 0.22, 0.65),
		Color(0.24, 0.21, 0.19, 0.62),
		Color(0.38, 0.35, 0.32, 0.26),
		Color(0.45, 0.43, 0.40, 0.0),
	])
	ring.color_ramp = rg
	scene.add_child(ring)
	ring.global_position = world_pos + Vector3(0.0, 0.22, 0.0)
	ring.emitting = true
	ring.restart()

	var shards := CPUParticles3D.new()
	shards.name = "BarrelShrapnel"
	shards.one_shot = true
	shards.explosiveness = 0.98
	shards.local_coords = false
	shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shards.amount = maxi(roundi(20.0 * vfx_scale), 8)
	shards.lifetime = 1.45
	shards.mesh = _mesh_chunk
	shards.material_override = _mat_debris_chunks
	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shards.emission_sphere_radius = 0.65
	shards.direction = Vector3(0.0, 1.0, 0.0)
	shards.spread = 165.0
	shards.gravity = Vector3(0.0, -21.0, 0.0)
	shards.initial_velocity_min = 9.0 * r_scale
	shards.initial_velocity_max = 22.0 * r_scale
	shards.scale_amount_min = 0.75
	shards.scale_amount_max = 1.95
	shards.angle_min = 0.0
	shards.angle_max = 360.0
	shards.angular_velocity_min = -480.0
	shards.angular_velocity_max = 480.0
	shards.color = Color(0.56, 0.14, 0.08, 1.0)
	scene.add_child(shards)
	shards.global_position = center
	shards.emitting = true
	shards.restart()

	var flash := OmniLight3D.new()
	flash.name = "BarrelBlastFlash"
	flash.light_color = Color(1.0, 0.56, 0.18)
	flash.light_energy = 11.0
	flash.omni_range = 18.0
	flash.omni_attenuation = 1.5
	flash.shadow_enabled = false
	scene.add_child(flash)
	flash.global_position = center + Vector3(0.0, 1.1, 0.0)
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var wr_r: WeakRef = weakref(ring)
	var wr_s: WeakRef = weakref(shards)
	var wr_l: WeakRef = weakref(flash)
	get_tree().create_timer(1.75, true, false, true).timeout.connect(
		func():
			var r_ref := wr_r.get_ref() as Node
			if r_ref and is_instance_valid(r_ref):
				r_ref.queue_free()
			var s_ref := wr_s.get_ref() as Node
			if s_ref and is_instance_valid(s_ref):
				s_ref.queue_free()
			var l_ref := wr_l.get_ref() as Node
			if l_ref and is_instance_valid(l_ref):
				l_ref.queue_free()
	)

func create_tire_smoke(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.local_coords = false
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.amount = maxi(roundi(18.0 * _get_vfx_scale()), 6)
	smoke.lifetime = 0.75
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.mesh = _mesh_quad
	smoke.material_override = _mat_exhaust_smoke
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 2.4
	smoke.gravity = Vector3(0, 1.4, 0)
	smoke.spread = 45.0
	smoke.scale_amount_min = 0.75
	smoke.scale_amount_max = 1.85
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.72, 0.72, 0.74, 0.0),
		Color(0.68, 0.68, 0.70, 0.36),
		Color(0.65, 0.65, 0.68, 0.0)
	])
	smoke.color_ramp = ramp

	parent.add_child(smoke)
	smoke.position = local_pos
	return smoke

func create_exhaust(parent: Node3D, local_pos: Vector3, style: String = "gasoline") -> CPUParticles3D:
	var exhaust := CPUParticles3D.new()
	var vfx_scale := _get_vfx_scale()
	exhaust.emitting = true
	exhaust.local_coords = false
	exhaust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	exhaust.visibility_range_end = 110.0
	exhaust.one_shot = false
	exhaust.explosiveness = 0.0
	exhaust.mesh = _mesh_quad
	exhaust.material_override = _mat_exhaust_smoke
	exhaust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	exhaust.emission_sphere_radius = 0.09
	exhaust.direction = Vector3(0.0, 0.22, 1.0)
	exhaust.spread = 22.0
	exhaust.initial_velocity_min = 2.0
	exhaust.initial_velocity_max = 4.2
	exhaust.damping_min = 2.2
	exhaust.damping_max = 3.5
	exhaust.angle_min = 0.0
	exhaust.angle_max = 360.0
	exhaust.angular_velocity_min = -70.0
	exhaust.angular_velocity_max = 70.0

	var size_curve := Curve.new()
	size_curve.add_point(Vector2(0.0, 0.34))
	size_curve.add_point(Vector2(0.35, 0.92))
	size_curve.add_point(Vector2(1.0, 1.95))
	exhaust.scale_amount_curve = size_curve

	var ramp := Gradient.new()
	match style:
		"diesel":
			exhaust.amount = maxi(roundi(24.0 * vfx_scale), 8)
			exhaust.lifetime = 1.25
			exhaust.gravity = Vector3(0.0, 2.5, 0.0)
			exhaust.scale_amount_min = 0.48
			exhaust.scale_amount_max = 0.95
			ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.60, 1.0])
			ramp.colors = PackedColorArray([
				Color(0.42, 0.42, 0.44, 0.0),
				Color(0.34, 0.34, 0.36, 0.26),
				Color(0.44, 0.44, 0.46, 0.14),
				Color(0.52, 0.52, 0.54, 0.0)
			])
		"muscle":
			exhaust.amount = maxi(roundi(26.0 * vfx_scale), 8)
			exhaust.lifetime = 0.92
			exhaust.gravity = Vector3(0.0, 1.65, 0.0)
			exhaust.scale_amount_min = 0.36
			exhaust.scale_amount_max = 0.75
			ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
			ramp.colors = PackedColorArray([
				Color(0.60, 0.59, 0.58, 0.0),
				Color(0.48, 0.48, 0.49, 0.55),
				Color(0.54, 0.54, 0.56, 0.25),
				Color(0.58, 0.58, 0.60, 0.0)
			])
		_:
			exhaust.amount = maxi(roundi(22.0 * vfx_scale), 8)
			exhaust.lifetime = 0.85
			exhaust.gravity = Vector3(0.0, 1.50, 0.0)
			exhaust.scale_amount_min = 0.32
			exhaust.scale_amount_max = 0.68
			ramp.offsets = PackedFloat32Array([0.0, 0.16, 0.58, 1.0])
			ramp.colors = PackedColorArray([
				Color(0.74, 0.74, 0.76, 0.0),
				Color(0.64, 0.65, 0.67, 0.46),
				Color(0.60, 0.61, 0.63, 0.20),
				Color(0.58, 0.59, 0.61, 0.0)
			])
	exhaust.color_ramp = ramp

	parent.add_child(exhaust)
	exhaust.position = local_pos
	return exhaust

func create_barrel_linger_smoke(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.emitting = false
	smoke.local_coords = false
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.amount = maxi(roundi(16.0 * _get_vfx_scale()), 6)
	smoke.lifetime = 1.4
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.mesh = _mesh_quad
	smoke.material_override = _mat_muzzle_smoke
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.08
	smoke.direction = Vector3(0.0, 0.65, -0.45)
	smoke.spread = 28.0
	smoke.initial_velocity_min = 0.45
	smoke.initial_velocity_max = 1.15
	smoke.gravity = Vector3(0.0, 1.35, 0.0)
	smoke.scale_amount_min = 0.26
	smoke.scale_amount_max = 0.55
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.35))
	sc.add_point(Vector2(0.5, 1.15))
	sc.add_point(Vector2(1.0, 2.0))
	smoke.scale_amount_curve = sc
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.45, 0.45, 0.47, 0.0),
		Color(0.48, 0.48, 0.50, 0.34),
		Color(0.56, 0.56, 0.58, 0.0)
	])
	smoke.color_ramp = ramp

	parent.add_child(smoke)
	smoke.position = local_pos
	return smoke

func spawn_crash_debris(
	world_pos: Vector3,
	dir_hint: Vector3 = Vector3.UP,
	impact_speed: float = 14.0,
	mat_kind: String = "metal",
	paint_color: Color = Color(0.45, 0.45, 0.48)
) -> void:
	var scene := get_tree().current_scene
	if not scene:
		return
	var scene_id := scene.get_instance_id()
	var v_scale: float = clampf(impact_speed / 15.0, 0.55, 2.2)
	var dir := dir_hint.normalized() if dir_hint.length_squared() > 0.001 else Vector3.UP
	var aim := (dir + Vector3(0.0, 0.42, 0.0)).normalized()
	var up_ref := Vector3.UP if absf(aim.y) < 0.94 else Vector3.RIGHT

	var chunks := _acquire_impact("crash_chunks", scene)
	chunks.global_position = world_pos
	chunks.look_at(world_pos + aim, up_ref)
	chunks.initial_velocity_min = 5.5 * v_scale
	chunks.initial_velocity_max = 15.0 * v_scale
	match mat_kind:
		"wood":
			chunks.color = Color(0.36, 0.23, 0.13, 1.0)
		"concrete":
			chunks.color = Color(0.48, 0.47, 0.44, 1.0)
		_:
			chunks.color = paint_color.lerp(Color(0.24, 0.22, 0.20, 1.0), 0.35)
	chunks.visible = true
	chunks.restart()
	chunks.emitting = true
	_recycle_after(chunks, "crash_chunks", scene_id)

	var dust := _acquire_impact("crash_dust", scene)
	dust.global_position = world_pos
	dust.look_at(world_pos + aim, up_ref)
	var dust_tint := Color(0.55, 0.53, 0.49, 0.52) if mat_kind == "concrete" else (Color(0.44, 0.35, 0.24, 0.44) if mat_kind == "wood" else Color(0.30, 0.30, 0.33, 0.45))
	var dust_ramp := Gradient.new()
	dust_ramp.offsets = PackedFloat32Array([0.0, 0.22, 1.0])
	dust_ramp.colors = PackedColorArray([Color(dust_tint.r, dust_tint.g, dust_tint.b, 0.0), dust_tint, Color(dust_tint.r, dust_tint.g, dust_tint.b, 0.0)])
	dust.color_ramp = dust_ramp
	dust.visible = true
	dust.restart()
	dust.emitting = true
	_recycle_after(dust, "crash_dust", scene_id)

	if mat_kind == "metal" or mat_kind == "metal_electric":
		var sp_type: String = "electric_sparks" if mat_kind == "metal_electric" else "landing_sparks"
		var sp := _acquire_impact(sp_type, scene)
		sp.global_position = world_pos
		sp.look_at(world_pos + aim, up_ref)
		sp.initial_velocity_min = 9.0 * v_scale
		sp.initial_velocity_max = 24.0 * v_scale
		sp.visible = true
		sp.restart()
		sp.emitting = true
		_recycle_after(sp, sp_type, scene_id)

func create_engine_damage_smoke(parent: Node3D, local_pos: Vector3) -> CPUParticles3D:
	var smoke := CPUParticles3D.new()
	smoke.name = "EngineDamageSmoke"
	smoke.emitting = false
	smoke.local_coords = false
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.amount = maxi(roundi(28.0 * _get_vfx_scale()), 10)
	smoke.lifetime = 1.45
	smoke.one_shot = false
	smoke.explosiveness = 0.0
	smoke.mesh = _mesh_quad
	smoke.material_override = _mat_muzzle_smoke
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	smoke.emission_box_extents = Vector3(0.48, 0.10, 0.45)
	smoke.direction = Vector3(0.0, 1.0, 0.15)
	smoke.spread = 28.0
	smoke.initial_velocity_min = 1.8
	smoke.initial_velocity_max = 3.8
	smoke.damping_min = 1.6
	smoke.damping_max = 2.8
	smoke.gravity = Vector3(0.0, 3.4, 0.0)
	smoke.scale_amount_min = 0.50
	smoke.scale_amount_max = 1.15
	smoke.angle_min = 0.0
	smoke.angle_max = 360.0
	smoke.angular_velocity_min = -60.0
	smoke.angular_velocity_max = 60.0
	var sc := Curve.new()
	sc.add_point(Vector2(0.0, 0.40))
	sc.add_point(Vector2(0.35, 1.15))
	sc.add_point(Vector2(1.0, 2.25))
	smoke.scale_amount_curve = sc
	smoke.color_ramp = _grad_steam_smoke
	parent.add_child(smoke)
	smoke.position = local_pos
	return smoke

func create_engine_damage_fire(parent: Node3D, local_pos: Vector3) -> Node3D:
	var container := Node3D.new()
	container.name = "EngineDamageFire"
	container.position = local_pos
	parent.add_child(container)

	var vfx_scale := _get_vfx_scale()
	var flames := CPUParticles3D.new()
	flames.name = "HoodFlames"
	flames.emitting = false
	flames.local_coords = false
	flames.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.amount = maxi(roundi(24.0 * vfx_scale), 8)
	flames.lifetime = 0.42
	flames.one_shot = false
	flames.mesh = _mesh_quad
	flames.material_override = _mat_muzzle_fire
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(0.45, 0.08, 0.42)
	flames.direction = Vector3(0.0, 1.0, 0.22)
	flames.spread = 24.0
	flames.initial_velocity_min = 2.0
	flames.initial_velocity_max = 4.6
	flames.gravity = Vector3(0.0, 4.8, 0.0)
	flames.scale_amount_min = 0.65
	flames.scale_amount_max = 1.25
	flames.angle_min = 0.0
	flames.angle_max = 360.0
	var f_sc := Curve.new()
	f_sc.add_point(Vector2(0.0, 0.50))
	f_sc.add_point(Vector2(0.32, 1.15))
	f_sc.add_point(Vector2(1.0, 0.18))
	flames.scale_amount_curve = f_sc
	var f_ramp := Gradient.new()
	f_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.68, 1.0])
	f_ramp.colors = PackedColorArray([
		Color(1.0, 0.96, 0.72, 0.95),
		Color(1.0, 0.56, 0.10, 0.92),
		Color(0.88, 0.18, 0.02, 0.62),
		Color(0.35, 0.04, 0.0, 0.0)
	])
	flames.color_ramp = f_ramp
	container.add_child(flames)

	var embers := CPUParticles3D.new()
	embers.name = "HoodEmbers"
	embers.emitting = false
	embers.local_coords = false
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.amount = maxi(roundi(18.0 * vfx_scale), 6)
	embers.lifetime = 0.65
	embers.one_shot = false
	embers.mesh = _mesh_spark
	embers.material_override = _mat_sparks
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(0.50, 0.08, 0.45)
	embers.direction = Vector3(0.0, 1.0, 0.45)
	embers.spread = 48.0
	embers.initial_velocity_min = 3.5
	embers.initial_velocity_max = 8.5
	embers.gravity = Vector3(0.0, -4.5, 0.0)
	embers.scale_amount_min = 0.22
	embers.scale_amount_max = 0.58
	embers.particle_flag_align_y = true
	embers.color = Color(1.0, 0.72, 0.22, 1.0)
	container.add_child(embers)

	return container

func update_engine_damage_fx(smoke: CPUParticles3D, fire_root: Node3D, hp_ratio: float, is_destroyed: bool) -> float:
	var fire_level := 0.0
	var flames := fire_root.get_node_or_null("HoodFlames") as CPUParticles3D if is_instance_valid(fire_root) else null
	var embers := fire_root.get_node_or_null("HoodEmbers") as CPUParticles3D if is_instance_valid(fire_root) else null

	if not is_destroyed and hp_ratio > 0.55:
		if is_instance_valid(smoke):
			smoke.emitting = false
		if flames:
			flames.emitting = false
		if embers:
			embers.emitting = false
		return 0.0

	var critical_fire: bool = is_destroyed or hp_ratio <= 0.18
	var heavy_smoke: bool = critical_fire or hp_ratio <= 0.34
	if is_instance_valid(smoke):
		smoke.emitting = true
		if heavy_smoke:
			smoke.color_ramp = _grad_oil_smoke
			smoke.initial_velocity_min = 2.8 if not critical_fire else 3.4
			smoke.initial_velocity_max = 5.4 if not critical_fire else 6.8
			smoke.scale_amount_min = 0.78 if not critical_fire else 0.95
			smoke.scale_amount_max = 1.45 if not critical_fire else 1.85
		else:
			smoke.color_ramp = _grad_steam_smoke
			smoke.initial_velocity_min = 1.7
			smoke.initial_velocity_max = 3.3
			smoke.scale_amount_min = 0.46
			smoke.scale_amount_max = 0.88

	if critical_fire:
		fire_level = 1.0 if is_destroyed else clampf(0.60 + (0.18 - hp_ratio) / 0.18 * 0.40, 0.60, 1.0)
		if flames:
			flames.emitting = true
			flames.scale_amount_min = lerpf(0.65, 1.05, fire_level)
			flames.scale_amount_max = lerpf(1.15, 1.85, fire_level)
		if embers:
			embers.emitting = true
	else:
		if flames:
			flames.emitting = false
		if embers:
			embers.emitting = false

	return fire_level

func spawn_car_destruction_explosion(world_pos: Vector3, car_vel: Vector3 = Vector3.ZERO, paint_color: Color = Color(0.35, 0.35, 0.38)) -> void:
	spawn_he_explosion(world_pos, 9.5)
	var scene := get_tree().current_scene
	if not scene:
		return
	var scene_id := scene.get_instance_id()
	var shards := _acquire_impact("car_wreck_shards", scene)
	shards.global_position = world_pos + Vector3(0.0, 0.45, 0.0)
	var dir_bias := Vector3(car_vel.x, maxf(absf(car_vel.length()) * 0.45, 9.0), car_vel.z).normalized()
	shards.look_at(shards.global_position + dir_bias, Vector3.UP if absf(dir_bias.y) < 0.9 else Vector3.RIGHT)
	shards.color = paint_color.lerp(Color(0.18, 0.16, 0.15, 1.0), 0.38)
	shards.visible = true
	shards.restart()
	shards.emitting = true
	_recycle_after(shards, "car_wreck_shards", scene_id)


func get_skid_manager(scene_override: Node = null) -> TireSkidManager:
	var scene: Node = scene_override if scene_override != null else get_tree().current_scene
	if scene == null:
		return null
	var sid := scene.get_instance_id()
	if not is_instance_valid(_skid_manager) or _skid_scene_id != sid:
		_skid_scene_id = sid
		_skid_manager = TireSkidManager.new()
		scene.add_child(_skid_manager)
	return _skid_manager


func add_tire_skid(
	wheel_id: int,
	contact_pos: Vector3,
	normal: Vector3,
	fwd_dir: Vector3,
	width: float,
	intensity: float,
	mark_color: Color = Color(0.035, 0.035, 0.04, 0.86)
) -> void:
	var mgr := get_skid_manager()
	if mgr != null:
		mgr.emit_wheel_mark(wheel_id, contact_pos, normal, fwd_dir, width, intensity, mark_color)


func break_tire_skid(wheel_id: int) -> void:
	if is_instance_valid(_skid_manager):
		_skid_manager.break_wheel_trail(wheel_id)

func spawn_water_splash(world_pos: Vector3, impact_speed: float = 16.0) -> void:
	var scene := get_tree().current_scene if get_tree() else null
	if scene == null:
		return
	var vfx_scale := _get_vfx_scale()
	var spd_k := clampf(impact_speed / 16.0, 0.7, 1.8)

	var plume := CPUParticles3D.new()
	plume.name = "WaterSplashPlume"
	plume.one_shot = true
	plume.explosiveness = 0.94
	plume.local_coords = false
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plume.amount = maxi(roundi(42.0 * vfx_scale), 12)
	plume.lifetime = 1.35
	plume.mesh = _mesh_quad
	plume.material_override = _mat_exhaust_smoke
	plume.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	plume.emission_ring_radius = 1.6
	plume.emission_ring_inner_radius = 0.2
	plume.emission_ring_height = 0.25
	plume.emission_ring_axis = Vector3.UP
	plume.direction = Vector3.UP
	plume.spread = 36.0
	plume.gravity = Vector3(0.0, -16.0, 0.0)
	plume.initial_velocity_min = 6.5 * spd_k
	plume.initial_velocity_max = 15.0 * spd_k
	plume.scale_amount_min = 1.25
	plume.scale_amount_max = 2.85
	plume.angle_min = 0.0
	plume.angle_max = 360.0
	var p_ramp := Gradient.new()
	p_ramp.offsets = PackedFloat32Array([0.0, 0.22, 0.72, 1.0])
	p_ramp.colors = PackedColorArray([
		Color(0.95, 0.98, 1.0, 0.88),
		Color(0.84, 0.94, 0.98, 0.72),
		Color(0.68, 0.86, 0.94, 0.34),
		Color(0.60, 0.80, 0.90, 0.0),
	])
	plume.color_ramp = p_ramp
	scene.add_child(plume)
	plume.global_position = world_pos
	plume.emitting = true
	plume.restart()

	var foam := CPUParticles3D.new()
	foam.name = "WaterSplashFoam"
	foam.one_shot = true
	foam.explosiveness = 0.90
	foam.local_coords = false
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	foam.amount = maxi(roundi(28.0 * vfx_scale), 10)
	foam.lifetime = 1.95
	foam.mesh = _mesh_quad
	foam.material_override = _mat_exhaust_smoke
	foam.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	foam.emission_ring_radius = 2.4
	foam.emission_ring_inner_radius = 0.8
	foam.emission_ring_height = 0.15
	foam.emission_ring_axis = Vector3.UP
	foam.direction = Vector3(0.0, 0.18, 1.0)
	foam.spread = 180.0
	foam.gravity = Vector3(0.0, -0.4, 0.0)
	foam.initial_velocity_min = 2.6
	foam.initial_velocity_max = 6.4
	foam.damping_min = 2.5
	foam.damping_max = 4.2
	foam.scale_amount_min = 1.65
	foam.scale_amount_max = 3.60
	var f_ramp := Gradient.new()
	f_ramp.offsets = PackedFloat32Array([0.0, 0.30, 1.0])
	f_ramp.colors = PackedColorArray([
		Color(0.90, 0.96, 0.98, 0.70),
		Color(0.74, 0.88, 0.92, 0.42),
		Color(0.60, 0.78, 0.85, 0.0),
	])
	foam.color_ramp = f_ramp
	scene.add_child(foam)
	foam.global_position = world_pos + Vector3(0.0, 0.10, 0.0)
	foam.emitting = true
	foam.restart()

	var wr_p: WeakRef = weakref(plume)
	var wr_f: WeakRef = weakref(foam)
	get_tree().create_timer(2.6, true, false, true).timeout.connect(
		func():
			var p_ref := wr_p.get_ref() as Node
			if p_ref and is_instance_valid(p_ref):
				p_ref.queue_free()
			var f_ref := wr_f.get_ref() as Node
			if f_ref and is_instance_valid(f_ref):
				f_ref.queue_free()
	)

func create_water_bubbles(parent: Node3D) -> CPUParticles3D:
	var bubbles := CPUParticles3D.new()
	bubbles.name = "WaterSinkBubbles"
	bubbles.local_coords = false
	bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubbles.amount = maxi(roundi(34.0 * _get_vfx_scale()), 12)
	bubbles.lifetime = 1.65
	bubbles.one_shot = false
	bubbles.mesh = _mesh_quad
	bubbles.material_override = _mat_exhaust_smoke
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(1.3, 0.35, 2.2)
	bubbles.direction = Vector3.UP
	bubbles.spread = 22.0
	bubbles.gravity = Vector3(0.0, 2.8, 0.0)
	bubbles.initial_velocity_min = 1.2
	bubbles.initial_velocity_max = 3.2
	bubbles.scale_amount_min = 0.14
	bubbles.scale_amount_max = 0.38
	var b_ramp := Gradient.new()
	b_ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.82, 1.0])
	b_ramp.colors = PackedColorArray([
		Color(0.86, 0.96, 1.0, 0.0),
		Color(0.88, 0.97, 1.0, 0.80),
		Color(0.75, 0.92, 0.98, 0.56),
		Color(0.70, 0.90, 0.98, 0.0),
	])
	bubbles.color_ramp = b_ramp
	parent.add_child(bubbles)
	bubbles.emitting = true
	return bubbles
