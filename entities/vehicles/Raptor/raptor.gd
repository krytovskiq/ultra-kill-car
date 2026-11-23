extends "res://entities/vehicles/vehicle_base.gd"

const TEX_RUST_DIFF: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_diff_1k.jpg")
const TEX_RUST_NOR: Texture2D = preload("res://environment/model/decor/FuelStation/textures/rusty_metal_04/rusty_metal_04_nor_gl_1k.jpg")

static var _cached_model_template: Node3D = null
static var _cached_shadow_tex: ImageTexture = null

func _init() -> void:
	# ==============================================================================
	# НАСТРОЙКИ FORD RAPTOR — МОЖНО РЕДАКТИРОВАТЬ ПОД СЕБЯ
	# ==============================================================================

	# --- Руль и управление ---
	STEER_SPEED = 1.38                  ## Скорость поворота руля
	STEER_LIMIT = 0.35                  ## Макс. угол выворота колёс (рад)
	steer_inertia = 4.4                 ## Вес / инерция рулевой рейки
	high_speed_steer_min_ratio = 0.23   ## Ограничение угла руля на макс. скорости

	# --- Двигатель, разгон и максималка ---
	throttle_response = 3.5             ## Плавность набора тяги турбо-V6/V8
	throttle_release_rate = 4.8         ## Сброс газа при отпускании W
	engine_force_value = 10400          ## Сила двигателя
	MAX_SPEED_KMH = 192                 ## Макс. скорость в стоке (км/ч, качается в гараже)
	brake_force = 98.0                  ## Сила торможения
	max_brake_decel_mps2 = 7.8          ## Макс. тормозное замедление (м/с²)
	aero_drag_coeff = 0.56              ## Аэродинамическое сопротивление
	downforce_multiplier = 18.0         ## Прижимная сила на скорости
	gear_speed_ratios = [0.16, 0.31, 0.47, 0.65, 0.84, 1.04]
	gear_torque_multipliers = [1.76, 1.44, 1.16, 0.94, 0.76, 0.60]

	# --- Подвеска, колёса и устойчивость ---
	suspension_firmness = 0.94          ## Общая жёсткость подвески (выше = жёстче)
	compression_damping_ratio = 0.48    ## Сжатие амортизаторов при кочках и приземлении
	rebound_damping_ratio = 0.66        ## Отбой амортизаторов (гасит раскачку вверх)
	anti_roll_stiffness = 11200.0       ## Стабилизатор поперечной устойчивости (анти-крен)
	front_spring_stiffness = 82000.0    ## Жёсткость передних пружин (Н/м)
	rear_spring_stiffness = 76000.0     ## Жёсткость задних пружин (Н/м)
	front_rest_length_scale = 1.24      ## Ход / клиренс передней подвески (множитель)
	rear_rest_length_scale = 1.30       ## Ход / клиренс задней подвески (множитель)
	front_grip_bias = 0.95              ## Баланс сцепления передней оси
	rear_grip_bias = 1.12               ## Баланс сцепления задней оси
	suspension_travel_speed = 18.0      ## Скорость визуальной отработки хода колеса
	weight_transfer_long = 0.28         ## Перенос веса вперёд/назад при разгоне и торможении
	weight_transfer_lat = 0.28          ## Перенос веса в стороны в поворотах
	com_height = 0.48                   ## Высота центра масс (ниже = сложнее перевернуться)
	com_z_offset = -0.15                ## Смещение центра масс вперёд (отрицательное = вперёд)
	wheelbase_m = 3.38                  ## Колёсная база (расстояние между осями в метрах)
	steering_scrub_drag = 0.18          ## Сопротивление при крутом повороте руля
	impact_momentum_keep = 0.84         ## Сохранение скорости при таране препятствий (0..1)
	body_roll_torque_factor = 0.72      ## Сила бокового крена кузова в повороте
	body_pitch_torque_factor = 0.64     ## Клевки носом / приседания при газе и тормозе
	lateral_stiffness = 12.2            ## Боковая жёсткость шины против сноса
	tire_friction = 2.40                ## Общий коэффициент сцепления шин
	drift_grip_factor = 0.78            ## Остаточное сцепление при заносе (ниже = легче дрифт)
	yaw_stability_assist = 2.6          ## Помощь стабилизации курса (ESC)
	hull_half_extents = Vector2(1.22, 2.78) ## Габариты половины кузова (ширина, длина)

	# --- Звук и свет ---
	engine_sound_id = "raptor"
	engine_pitch_scale = 0.98
	has_exhaust_backfire = true
	gear_shift_pitch_base = 0.88
	shadow_texture = _get_raptor_shadow_tex()
	headlight_positions = [Vector3(-0.88, 1.04, -2.56), Vector3(0.88, 1.04, -2.56)]
	taillight_positions = [Vector3(-0.92, 1.06, 2.86), Vector3(0.92, 1.06, 2.86)]
	headlight_lens_size = Vector2(0.32, 0.34)
	taillight_lens_size = Vector2(0.24, 0.34)
	headlight_proj_size = Vector2(15.0, 35.0)
	headlight_proj_z_start = -2.58
	taillight_proj_size = Vector2(3.9, 2.3)
	taillight_proj_z_start = 2.82
	shadow_blob_size = Vector2(5.20, 9.65)
	shadow_offset = Vector2(0.0, 0.10)

	# --- Прочность и топливо ---
	health = 1850                       ## Базовая броня HP (качается в гараже)
	engine_hood_offset = Vector3(0.0, 1.18, -1.95)
	car_paint_color = Color(0.16, 0.19, 0.21) ## Мрачный тёмно-графитовый цвет осколков
	zombie_damage_taken = 4
	crash_death_speed_mps = 28.0
	max_fuel = 145                      ## Базовый объём бака (л)
	fuel_per_100m = 3.4
	idle_fuel_per_sec = 0.23
	exhaust_offset = Vector3(-0.68, 0.42, 2.88)
	exhaust_offsets = [Vector3(-0.68, 0.42, 2.88), Vector3(0.68, 0.42, 2.88)]
	exhaust_style = "muscle"

func _ready() -> void:
	mass = 2850.0                       ## Масса внедорожника (кг)
	_assemble_raptor_visuals()
	super()

static func _get_raptor_shadow_tex() -> ImageTexture:
	if _cached_shadow_tex != null:
		return _cached_shadow_tex
	var w := 128
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var v: float = (float(y) + 0.5) / float(h) * 2.0 - 1.0
		for x in range(w):
			var u: float = (float(x) + 0.5) / float(w) * 2.0 - 1.0
			var half_w: float = 0.54
			# Wide Raptor off-road fender flares at front & rear axles
			var front_flare: float = exp(-pow((v + 0.56) / 0.18, 2.0)) * 0.08
			var rear_flare: float = exp(-pow((v - 0.56) / 0.18, 2.0)) * 0.08
			var mirror_bump: float = exp(-pow((v + 0.24) / 0.05, 2.0)) * 0.11
			var eff_w: float = half_w + front_flare + rear_flare + mirror_bump
			var dx: float = absf(u) / maxf(eff_w, 0.1)
			var dz: float = absf(v) / 0.66
			var d: float = pow(pow(dx, 3.4) + pow(dz, 4.2), 0.25)
			var alpha: float = clampf(1.0 - smoothstep(0.76, 1.05, d), 0.0, 1.0)
			img.set_pixel(x, y, Color(0.0, 0.0, 0.0, alpha))
	_cached_shadow_tex = ImageTexture.create_from_image(img)
	return _cached_shadow_tex

func _assemble_raptor_visuals() -> void:
	if get_node_or_null("RaptorModelRoot") != null:
		return
	if _cached_model_template == null:
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var glb_path: String = ProjectSettings.globalize_path("res://entities/vehicles/Raptor/raptor_model.glb")
		var err: int = doc.append_from_file(glb_path, state)
		if err == OK:
			_cached_model_template = doc.generate_scene(state) as Node3D
	if _cached_model_template == null:
		return

	var model_root: Node3D = _cached_model_template.duplicate() as Node3D
	model_root.name = "RaptorModelRoot"
	model_root.position = Vector3(0.0, 0.33, 0.0)
	add_child(model_root)
	_apply_apocalyptic_paint(model_root)

	var wheel_map: Dictionary = {
		"Wheel_98": get_node_or_null("VehicleWheelFL") as RaycastWheel,
		"Wheel (2)_107": get_node_or_null("VehicleWheelFR") as RaycastWheel,
		"Wheel (1)_116": get_node_or_null("VehicleWheelRL") as RaycastWheel,
		"Wheel (3)_125": get_node_or_null("VehicleWheelRR") as RaycastWheel,
	}
	for w_name: String in wheel_map.keys():
		var rc_w: RaycastWheel = wheel_map[w_name] as RaycastWheel
		var w_mesh: Node3D = model_root.find_child(w_name, true, false) as Node3D
		if rc_w == null or w_mesh == null:
			continue
		rc_w._setup_visual_pivots()
		var orig_scale: Vector3 = w_mesh.scale
		var orig_rot: Vector3 = w_mesh.rotation
		var target_parent: Node3D = rc_w._spin_pivot if rc_w._spin_pivot != null else rc_w
		w_mesh.reparent(target_parent, false)
		w_mesh.position = Vector3.ZERO
		w_mesh.rotation = orig_rot
		w_mesh.scale = orig_scale

func _apply_apocalyptic_paint(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for s in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(s) as StandardMaterial3D
				if mat == null:
					continue
				var rname := mat.resource_name
				if rname == "F-150_Paint":
					var dark_mat := mat.duplicate() as StandardMaterial3D
					dark_mat.albedo_color = Color(0.17, 0.20, 0.22)
					dark_mat.metallic = 0.30
					dark_mat.roughness = 0.64
					dark_mat.clearcoat = 0.08
					dark_mat.detail_enabled = true
					dark_mat.detail_uv_layer = BaseMaterial3D.DETAIL_UV_1
					dark_mat.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
					dark_mat.detail_albedo = TEX_RUST_DIFF
					dark_mat.detail_normal = TEX_RUST_NOR
					mi.set_surface_override_material(s, dark_mat)
				elif rname == "Gloss_Black":
					var matte_blk := mat.duplicate() as StandardMaterial3D
					matte_blk.albedo_color = Color(0.10, 0.10, 0.11)
					matte_blk.roughness = 0.62
					matte_blk.metallic = 0.14
					mi.set_surface_override_material(s, matte_blk)
				elif rname == "Chrome":
					var worn_chr := mat.duplicate() as StandardMaterial3D
					worn_chr.albedo_color = Color(0.56, 0.54, 0.50)
					worn_chr.roughness = 0.44
					worn_chr.metallic = 0.62
					mi.set_surface_override_material(s, worn_chr)
	for child in node.get_children():
		_apply_apocalyptic_paint(child)
