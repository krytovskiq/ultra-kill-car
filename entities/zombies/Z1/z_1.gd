extends CharacterBody3D

enum ZombieState { IDLE, CHASE, ATTACK, DEAD, FALLEN }
enum ZombieArchetype { SHAMBLER, CRAWLER_LIMP, BRUTE, SPRINTER, STALKER }

class ZombiePostureModifier extends SkeletonModifier3D:
	var owner_zombie: Node = null

	func _process_modification() -> void:
		if owner_zombie == null or not is_instance_valid(owner_zombie):
			return
		var sk: Skeleton3D = get_skeleton()
		if sk == null:
			return
		owner_zombie._apply_skeletal_animation_layer(sk)

@export_group("Zombie Settings")
@export var max_hp: float = 50.0
@export var walk_speed: float = 2.0
@export var run_speed: float = 7.0
@export var damage: int = 9
@export var attack_hull_range: float = 1.05
@export var attack_hull_hit_range: float = 1.42
@export var attack_hull_cancel_range: float = 2.30
@export var attack_max_car_speed_mps: float = 6.0
@export var attack_hit_max_car_speed_mps: float = 6.5
@export var attack_hit_delay: float = 0.42
@export var detection_radius: float = 300.0
@export var lose_target_radius: float = 310.0

@export_group("Timers")
@export var attack_cooldown: float = 1.35
@export var get_up_time: float = 1.5

@onready var anim_player: AnimationPlayer = $AnimationPlayer

var skeleton: Skeleton3D = null
var _bone_sim: PhysicalBoneSimulator3D = null
var _physical_bones: Array[PhysicalBone3D] = []
var _hips_bone: PhysicalBone3D = null
var _posture_mod: ZombiePostureModifier = null
var _dead_start_ms: int = 0

var _idx_spine: int = -1
var _idx_spine1: int = -1
var _idx_spine2: int = -1
var _idx_neck: int = -1
var _idx_head: int = -1
var _idx_l_arm: int = -1
var _idx_r_arm: int = -1

var player: Node3D
var state: ZombieState = ZombieState.IDLE
var current_hp: float = 0.0
var attack_timer: float = 0.0
var current_speed: float = 3.0
var _internal_velocity: Vector3 = Vector3.ZERO
var _knockback_target: Vector3 = Vector3.ZERO
var _chase_anim: String = "Walk"
var _generation: int = 0
var difficulty_tier: float = 0.0
var current_damage: int = 9
var ram_damage_mult: float = 1.0
var _current_attack_cooldown: float = 1.35

var _attack_hit_pending: bool = false
var _attack_elapsed: float = 0.0
var _lod_frame: int = 0
var _lod_anim_tick: int = 0
var _lod_anim_accum: float = 0.0
var _lod_anim_paused: bool = false
var _anim_clock: float = 0.0
var _phase_offset: float = 0.0
var _hunch_bias: float = 0.22
var _head_tilt_bias: float = 0.0
var _next_groan_time: float = 0.0
var _cached_sep: Vector2 = Vector2.ZERO
var _using_ragdoll: bool = false
var _ballistic_dead: bool = false
var _ballistic_vel: Vector3 = Vector3.ZERO
var _ballistic_ground_y: float = 0.0

var archetype: int = ZombieArchetype.SHAMBLER
var visual_variant: int = 0
var model_variant: int = 0
var _idle_anim: String = "Idle"
var _attack_anim: String = "Attack"
var _weave_amp: float = 0.35
var _weave_freq: float = 2.4
var _limp_pulse: float = 0.0
var _lead_time: float = 0.0
var _flank_offset: Vector2 = Vector2.ZERO
var _sprint_aggro_dist_sq: float = 0.0
var _ambush_triggered: bool = false
var _mesh_instances: Array[MeshInstance3D] = []
var _orig_surface_mats: Array = []
var _orig_model_parts: Array = []
var _run_xform: Transform3D = Transform3D.IDENTITY
var _burn_vfx: CPUParticles3D = null
var _burn_smoke_vfx: CPUParticles3D = null
var _is_burning: bool = false
static var _shared_burn_fire_mesh: QuadMesh = null
static var _shared_burn_smoke_mesh: QuadMesh = null

@onready var detection_radius_sq: float = detection_radius * detection_radius
@onready var lose_target_radius_sq: float = lose_target_radius * lose_target_radius

const ZOMBIE_BODY_RADIUS := 0.36
const HULL_CLEARANCE := 0.44
const ZOMBIE_MODEL_COUNT := 7

func _ready() -> void:
	_lod_frame = randi() % 4
	_lod_anim_tick = randi() % 6
	_phase_offset = randf_range(0.0, TAU)
	_hunch_bias = randf_range(0.16, 0.32)
	_head_tilt_bias = randf_range(-0.24, 0.24)
	_next_groan_time = randf_range(1.5, 6.0)

	var run_node: Node3D = get_node_or_null("Run") as Node3D
	if run_node:
		_run_xform = run_node.transform

	skeleton = get_node_or_null("Run/Skeleton3D")
	if skeleton:
		for child in skeleton.get_children():
			if child is MeshInstance3D:
				var mi := child as MeshInstance3D
				mi.extra_cull_margin = 1.5
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.visibility_range_end = 168.0
				mi.visibility_range_end_margin = 12.0
				_mesh_instances.append(mi)
				var surf_mats: Array[Material] = []
				if mi.mesh:
					for s: int in range(mi.mesh.get_surface_count()):
						var orig_mat: Material = mi.get_active_material(s)
						surf_mats.append(orig_mat)
						var shared_mat: ShaderMaterial = ZombiePool.get_shared_surface_material(orig_mat, 0, false)
						mi.set_surface_override_material(s, shared_mat)
				_orig_surface_mats.append(surf_mats)
				_orig_model_parts.append({
					"mesh": mi.mesh,
					"skin": mi.skin,
					"materials": surf_mats
				})
		# Ensure 4 pooled MeshInstance3D slots on Skeleton3D for multi-part GLB zombie models (e.g. cop, girl)
		while _mesh_instances.size() < 4:
			var extra_mi := MeshInstance3D.new()
			extra_mi.name = "ExtraZombiePart_%d" % _mesh_instances.size()
			extra_mi.skeleton = NodePath("..")
			extra_mi.extra_cull_margin = 1.5
			extra_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			extra_mi.visibility_range_end = 168.0
			extra_mi.visibility_range_end_margin = 12.0
			extra_mi.visible = false
			skeleton.add_child(extra_mi)
			_mesh_instances.append(extra_mi)
		_bone_sim = skeleton.get_node_or_null("PhysicalBoneSimulator3D")
		if _bone_sim:
			for child in _bone_sim.get_children():
				if child is PhysicalBone3D:
					var pb_ref := child as PhysicalBone3D
					_physical_bones.append(pb_ref)
					if pb_ref.name.ends_with("Hips"):
						_hips_bone = pb_ref
			_configure_ragdoll_bones()
			_set_ragdoll_collision(false)
			_bone_sim.active = false
			_bone_sim.process_mode = Node.PROCESS_MODE_DISABLED

		_idx_spine = skeleton.find_bone("mixamorig_Spine")
		_idx_spine1 = skeleton.find_bone("mixamorig_Spine1")
		_idx_spine2 = skeleton.find_bone("mixamorig_Spine2")
		_idx_neck = skeleton.find_bone("mixamorig_Neck")
		_idx_head = skeleton.find_bone("mixamorig_Head")
		_idx_l_arm = skeleton.find_bone("mixamorig_LeftArm")
		_idx_r_arm = skeleton.find_bone("mixamorig_RightArm")

		_posture_mod = ZombiePostureModifier.new()
		_posture_mod.name = "ZombiePostureModifier"
		_posture_mod.owner_zombie = self
		skeleton.add_child(_posture_mod)

	add_to_group("zombie")
	current_hp = max_hp
	current_speed = walk_speed

	if anim_player:
		anim_player.playback_default_blend_time = 0.16
		_ensure_custom_animations()
		for loop_anim in ["Run", "RunFeral", "RunStumble", "Walk", "WalkLimp", "WalkCreep", "Idle", "IdleTwitch"]:
			if anim_player.has_animation(loop_anim):
				var anim_res: Animation = anim_player.get_animation(loop_anim)
				if anim_res:
					anim_res.loop_mode = Animation.LOOP_LINEAR
		if not anim_player.animation_finished.is_connected(_on_animation_finished):
			anim_player.animation_finished.connect(_on_animation_finished)
		anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL

	_find_player()

func _apply_visual_variant(v_idx: int, m_idx: int = -1) -> void:
	visual_variant = 6 if v_idx == 6 else posmod(v_idx, 6)
	if m_idx >= 0:
		model_variant = posmod(m_idx, ZOMBIE_MODEL_COUNT)
	var parts: Array = ZombiePool.get_zombie_model_parts(model_variant, skeleton, _run_xform, _orig_model_parts)
	var is_ext: bool = (model_variant > 0 and parts != _orig_model_parts)
	for m_i in range(_mesh_instances.size()):
		var mi := _mesh_instances[m_i]
		if not is_instance_valid(mi):
			continue
		if m_i < parts.size():
			var part: Dictionary = parts[m_i]
			mi.mesh = part["mesh"] as Mesh
			mi.skin = part["skin"] as Skin
			mi.visible = true
			var surf_mats: Array = part["materials"]
			if mi.mesh:
				for s in range(mini(mi.mesh.get_surface_count(), surf_mats.size())):
					var shared_mat: ShaderMaterial = ZombiePool.get_shared_surface_material(surf_mats[s] as Material, visual_variant, is_ext)
					mi.set_surface_override_material(s, shared_mat)
		else:
			mi.visible = false
			mi.mesh = null

func _configure_ragdoll_bones() -> void:
	for pb: PhysicalBone3D in _physical_bones:
		if not is_instance_valid(pb):
			continue
		var b_name: String = pb.name
		pb.friction = 0.78
		pb.bounce = 0.10
		pb.gravity_scale = 1.65
		pb.linear_damp = 0.14
		pb.angular_damp = 1.05
		var mass_val: float = 2.2
		var swing_deg: float = 40.0
		var twist_deg: float = 22.0
		if b_name.ends_with("Hips"):
			pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
			mass_val = 6.2
			swing_deg = 32.0
			twist_deg = 28.0
			pb.angular_damp = 1.10
		elif b_name.contains("Spine"):
			mass_val = 4.4
			swing_deg = 24.0
			twist_deg = 16.0
			pb.angular_damp = 1.05
		elif b_name.ends_with("Neck") or b_name.ends_with("Head"):
			mass_val = 2.1
			swing_deg = 35.0
			twist_deg = 25.0
			pb.angular_damp = 0.85
		elif b_name.contains("Shoulder"):
			mass_val = 1.6
			swing_deg = 20.0
			twist_deg = 12.0
			pb.angular_damp = 0.95
		elif b_name.contains("ForeArm") or b_name.contains("Hand"):
			mass_val = 1.3
			swing_deg = 48.0
			twist_deg = 20.0
			pb.angular_damp = 0.65
		elif b_name.contains("Arm"):
			mass_val = 1.7
			swing_deg = 58.0
			twist_deg = 35.0
			pb.angular_damp = 0.78
		elif b_name.contains("UpLeg"):
			mass_val = 3.1
			swing_deg = 52.0
			twist_deg = 22.0
			pb.angular_damp = 0.92
		elif b_name.contains("Leg") or b_name.contains("Foot"):
			mass_val = 2.2
			swing_deg = 48.0
			twist_deg = 12.0
			pb.angular_damp = 0.80
		pb.mass = mass_val
		pb.set("joint_constraints/swing_span", swing_deg)
		pb.set("joint_constraints/twist_span", twist_deg)

func _build_rot_variant(src_anim: Animation, loop_on: bool, bone_offsets: Dictionary) -> Animation:
	var dup := src_anim.duplicate() as Animation
	dup.loop_mode = Animation.LOOP_LINEAR if loop_on else Animation.LOOP_NONE
	for t in range(dup.get_track_count()):
		if dup.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var p_str := String(dup.track_get_path(t))
		for b_key: String in bone_offsets.keys():
			if p_str.ends_with(":" + b_key):
				var q_off: Quaternion = bone_offsets[b_key]
				var k_cnt := dup.track_get_key_count(t)
				for k in range(k_cnt):
					var q_orig: Quaternion = dup.track_get_key_value(t, k)
					dup.track_set_key_value(t, k, (q_orig * q_off).normalized())
				break
	return dup

func _ensure_custom_animations() -> void:
	if anim_player == null:
		return
	var lib: AnimationLibrary = anim_player.get_animation_library("")
	if lib == null:
		return
	if lib.has_animation("WalkLimp"):
		return
	var walk_anim: Animation = anim_player.get_animation("Walk")
	if walk_anim == null:
		return

	if not lib.has_animation("Idle"):
		var idle := Animation.new()
		idle.length = 2.6
		idle.loop_mode = Animation.LOOP_LINEAR
		var idle_times: Array[float] = [0.0, 0.65, 1.30, 1.95, 2.60]
		for t in range(walk_anim.get_track_count()):
			if walk_anim.track_get_key_count(t) == 0:
				continue
			var t_type := walk_anim.track_get_type(t)
			var t_path := walk_anim.track_get_path(t)
			var p_str := String(t_path)
			var new_t := idle.add_track(t_type)
			idle.track_set_path(new_t, t_path)
			var val0 = walk_anim.track_get_key_value(t, 0)
			if t_type == Animation.TYPE_ROTATION_3D and val0 is Quaternion:
				var q0: Quaternion = val0
				for k_i in range(idle_times.size()):
					var tm := idle_times[k_i]
					var phase := (float(k_i) / 4.0) * TAU
					var q_off := Quaternion.IDENTITY
					if p_str.ends_with("mixamorig_Hips"):
						q_off = Quaternion(Vector3(0, 0, 1), 0.045 * sin(phase)) * Quaternion(Vector3(1, 0, 0), 0.03 * cos(phase))
					elif p_str.ends_with("mixamorig_Spine") or p_str.ends_with("mixamorig_Spine1"):
						q_off = Quaternion(Vector3(1, 0, 0), 0.10 + 0.065 * sin(phase)) * Quaternion(Vector3(0, 0, 1), 0.06 * sin(phase))
					elif p_str.ends_with("mixamorig_Spine2"):
						q_off = Quaternion(Vector3(1, 0, 0), 0.08 + 0.055 * cos(phase)) * Quaternion(Vector3(0, 1, 0), 0.07 * sin(phase))
					elif p_str.ends_with("mixamorig_Neck") or p_str.ends_with("mixamorig_Head"):
						q_off = Quaternion(Vector3(0, 1, 0), 0.19 * sin(phase)) * Quaternion(Vector3(1, 0, 0), -0.06 + 0.11 * cos(phase * 2.0)) * Quaternion(Vector3(0, 0, 1), 0.10 * sin(phase + 0.6))
					elif p_str.ends_with("mixamorig_LeftArm"):
						q_off = Quaternion(Vector3(1, 0, 0), 0.24 + 0.16 * sin(phase)) * Quaternion(Vector3(0, 0, 1), -0.06 + 0.06 * cos(phase))
					elif p_str.ends_with("mixamorig_RightArm"):
						q_off = Quaternion(Vector3(1, 0, 0), 0.20 + 0.16 * cos(phase + 0.5)) * Quaternion(Vector3(0, 0, 1), 0.06 - 0.06 * sin(phase))
					elif p_str.ends_with("mixamorig_LeftForeArm") or p_str.ends_with("mixamorig_RightForeArm"):
						q_off = Quaternion(Vector3(1, 0, 0), 0.18 + 0.12 * sin(phase + 0.8))
					idle.track_insert_key(new_t, tm, (q0 * q_off).normalized())
			else:
				for tm in idle_times:
					idle.track_insert_key(new_t, tm, val0)
		lib.add_animation("Idle", idle)

	if not lib.has_animation("IdleTwitch") and lib.has_animation("Idle"):
		var twitch := _build_rot_variant(lib.get_animation("Idle"), true, {
			"mixamorig_Spine": Quaternion(Vector3(1, 0, 0), 0.18) * Quaternion(Vector3(0, 0, 1), -0.14),
			"mixamorig_Head": Quaternion(Vector3(0, 0, 1), 0.26) * Quaternion(Vector3(0, 1, 0), -0.20),
			"mixamorig_LeftArm": Quaternion(Vector3(1, 0, 0), 0.34),
			"mixamorig_RightArm": Quaternion(Vector3(1, 0, 0), 0.14) * Quaternion(Vector3(0, 0, 1), 0.12),
		})
		lib.add_animation("IdleTwitch", twitch)

	# 1. WalkLimp: wounded dragging-leg shambler with tilted hip & lurching spine
	var walk_limp := _build_rot_variant(walk_anim, true, {
		"mixamorig_Hips": Quaternion(Vector3(0, 0, 1), 0.14),
		"mixamorig_Spine": Quaternion(Vector3(0, 0, 1), -0.22) * Quaternion(Vector3(1, 0, 0), 0.18),
		"mixamorig_Head": Quaternion(Vector3(0, 0, 1), -0.26),
		"mixamorig_RightUpLeg": Quaternion(Vector3(1, 0, 0), -0.22),
		"mixamorig_LeftArm": Quaternion(Vector3(1, 0, 0), 0.35),
	})
	lib.add_animation("WalkLimp", walk_limp)

	# 2. WalkCreep: hunched stalker with outstretched clawing arms
	var walk_creep := _build_rot_variant(walk_anim, true, {
		"mixamorig_Spine": Quaternion(Vector3(1, 0, 0), 0.26),
		"mixamorig_Spine1": Quaternion(Vector3(1, 0, 0), 0.20),
		"mixamorig_Head": Quaternion(Vector3(1, 0, 0), -0.28),
		"mixamorig_LeftArm": Quaternion(Vector3(1, 0, 0), 0.58),
		"mixamorig_RightArm": Quaternion(Vector3(1, 0, 0), 0.54),
	})
	lib.add_animation("WalkCreep", walk_creep)

	# 3. RunFeral & RunStumble: distinct sprint variants (fix animation "0" 180-deg +Z root rotation first!)
	var run_base: Animation = anim_player.get_animation("Run")
	if anim_player.has_animation("0"):
		var a0: Animation = anim_player.get_animation("0")
		var q_flip := Quaternion(Vector3(0.0, 0.0, 1.0), PI)
		for t in range(a0.get_track_count()):
			var p_str := String(a0.track_get_path(t))
			if p_str.ends_with(":mixamorig_Hips"):
				if a0.track_get_type(t) == Animation.TYPE_ROTATION_3D and a0.track_get_key_count(t) > 0:
					var q0: Quaternion = a0.track_get_key_value(t, 0)
					# In Z1.tscn, "0" has q0.x ~ 0.698 (facing +Z), whereas -Z facing animations have q0.y ~ 0.698
					if absf(q0.x) > 0.5:
						for k in range(a0.track_get_key_count(t)):
							var q_orig: Quaternion = a0.track_get_key_value(t, k)
							a0.track_set_key_value(t, k, (q_flip * q_orig).normalized())
				elif a0.track_get_type(t) == Animation.TYPE_POSITION_3D:
					for k in range(a0.track_get_key_count(t)):
						var p_orig: Vector3 = a0.track_get_key_value(t, k)
						a0.track_set_key_value(t, k, Vector3(2.123 - p_orig.x, 0.307 - p_orig.y, p_orig.z))
	var alt_run_base: Animation = anim_player.get_animation("0") if anim_player.has_animation("0") else run_base
	if alt_run_base:
		var run_feral := _build_rot_variant(alt_run_base, true, {
			"mixamorig_Spine": Quaternion(Vector3(1, 0, 0), 0.24),
			"mixamorig_Spine1": Quaternion(Vector3(1, 0, 0), 0.16),
			"mixamorig_Head": Quaternion(Vector3(1, 0, 0), -0.22) * Quaternion(Vector3(0, 0, 1), 0.15),
			"mixamorig_LeftArm": Quaternion(Vector3(1, 0, 0), 0.38),
			"mixamorig_RightArm": Quaternion(Vector3(1, 0, 0), 0.38),
		})
		lib.add_animation("RunFeral", run_feral)
	if run_base:
		var run_stumble := _build_rot_variant(run_base, true, {
			"mixamorig_Spine": Quaternion(Vector3(0, 0, 1), 0.22) * Quaternion(Vector3(1, 0, 0), 0.14),
			"mixamorig_Head": Quaternion(Vector3(0, 0, 1), -0.28) * Quaternion(Vector3(1, 0, 0), 0.14),
			"mixamorig_LeftArm": Quaternion(Vector3(0, 0, 1), -0.25),
			"mixamorig_RightArm": Quaternion(Vector3(1, 0, 0), 0.44),
		})
		lib.add_animation("RunStumble", run_stumble)

	# 4. AttackFrenzy: heavy overhead / lunging brute slam
	var atk_base: Animation = anim_player.get_animation("Attack")
	if atk_base:
		var atk_frenzy := _build_rot_variant(atk_base, false, {
			"mixamorig_Spine": Quaternion(Vector3(1, 0, 0), 0.24),
			"mixamorig_LeftArm": Quaternion(Vector3(1, 0, 0), 0.32),
			"mixamorig_RightArm": Quaternion(Vector3(1, 0, 0), 0.32),
		})
		lib.add_animation("AttackFrenzy", atk_frenzy)

func _apply_skeletal_animation_layer(sk: Skeleton3D) -> void:
	if state == ZombieState.DEAD or state == ZombieState.FALLEN or _lod_anim_paused:
		return
	var t := _anim_clock + _phase_offset

	var hunch: float = _hunch_bias
	var sway_z: float = 0.0
	var head_nod: float = 0.0
	var head_roll: float = _head_tilt_bias
	var arm_reach: float = 0.0

	match state:
		ZombieState.IDLE:
			hunch += 0.06 + 0.05 * sin(t * 2.1)
			sway_z = 0.08 * sin(t * 1.4)
			head_nod = 0.12 * sin(t * 2.9)
			head_roll += 0.16 * sin(t * 1.9)
			arm_reach = 0.12
		ZombieState.ATTACK:
			hunch += 0.18 + 0.22 * sin(t * 7.5)
			sway_z = 0.10 * cos(t * 6.0)
			head_nod = -0.15 + 0.18 * sin(t * 9.0)
			arm_reach = 0.35
		ZombieState.CHASE:
			if _chase_anim == "Run":
				hunch += 0.22 + 0.07 * sin(t * 9.5)
				sway_z = 0.12 * sin(t * 6.5)
				head_nod = 0.10 * sin(t * 11.0)
				head_roll *= 0.65
				arm_reach = 0.30
			else:
				hunch += 0.12 + 0.08 * sin(t * 3.4)
				sway_z = 0.16 * sin(t * 2.6)
				head_nod = 0.14 * sin(t * 4.7)
				head_roll += 0.22 * sin(t * 3.1)
				arm_reach = 0.24

	if _idx_spine >= 0:
		var q_sp: Quaternion = sk.get_bone_pose_rotation(_idx_spine)
		sk.set_bone_pose_rotation(_idx_spine, q_sp * Quaternion(Vector3(1.0, 0.0, 0.0), hunch * 0.45) * Quaternion(Vector3(0.0, 0.0, 1.0), sway_z * 0.6))
	if _idx_spine1 >= 0:
		var q_s1: Quaternion = sk.get_bone_pose_rotation(_idx_spine1)
		sk.set_bone_pose_rotation(_idx_spine1, q_s1 * Quaternion(Vector3(1.0, 0.0, 0.0), hunch * 0.35))
	if _idx_spine2 >= 0:
		var q_s2: Quaternion = sk.get_bone_pose_rotation(_idx_spine2)
		sk.set_bone_pose_rotation(_idx_spine2, q_s2 * Quaternion(Vector3(1.0, 0.0, 0.0), hunch * 0.45) * Quaternion(Vector3(0.0, 0.0, 1.0), sway_z * 0.5))
	if _idx_head >= 0:
		var q_hd: Quaternion = sk.get_bone_pose_rotation(_idx_head)
		sk.set_bone_pose_rotation(_idx_head, q_hd * Quaternion(Vector3(1.0, 0.0, 0.0), head_nod - hunch * 0.35) * Quaternion(Vector3(0.0, 0.0, 1.0), head_roll))
	if _idx_l_arm >= 0 and arm_reach > 0.01:
		var q_la: Quaternion = sk.get_bone_pose_rotation(_idx_l_arm)
		sk.set_bone_pose_rotation(_idx_l_arm, q_la * Quaternion(Vector3(1.0, 0.0, 0.0), arm_reach + 0.08 * sin(t * 4.2)))
	if _idx_r_arm >= 0 and arm_reach > 0.01:
		var q_ra: Quaternion = sk.get_bone_pose_rotation(_idx_r_arm)
		sk.set_bone_pose_rotation(_idx_r_arm, q_ra * Quaternion(Vector3(1.0, 0.0, 0.0), arm_reach + 0.08 * cos(t * 4.0)))

func _set_ragdoll_collision(enabled: bool) -> void:
	var target_layer: int = 16 if enabled else 0
	var target_mask: int = 513 if enabled else 0
	for pb in _physical_bones:
		if is_instance_valid(pb):
			pb.collision_layer = target_layer
			pb.collision_mask = target_mask

func _find_player() -> void:
	if not is_inside_tree():
		return
	var st := get_tree()
	if st:
		player = st.get_first_node_in_group("player") as Node3D

func _get_player_horiz_speed_mps() -> float:
	if player is RigidBody3D:
		var v: Vector3 = (player as RigidBody3D).linear_velocity
		return Vector2(v.x, v.z).length()
	return 0.0

func _get_player_hull_extents() -> Vector2:
	if player:
		var ext = player.get("hull_half_extents")
		if ext is Vector2:
			return ext as Vector2
	return Vector2(1.12, 2.55)

func _get_locomotion_speed_scale(anim_name: String) -> float:
	match anim_name:
		"Run", "RunFeral":
			return clampf(current_speed / 4.4, 1.0, 2.35)
		"RunStumble":
			return clampf(current_speed / 4.1, 0.95, 2.25)
		"Walk", "WalkCreep":
			return clampf(current_speed / 1.4, 1.10, 2.35)
		"WalkLimp":
			return clampf(current_speed / 1.25, 0.95, 2.15)
		"Attack":
			return 2.15
		"AttackFrenzy":
			return 2.45
		"Idle", "IdleTwitch":
			return 1.0
		"Death":
			return 1.3
	return 1.0

func _ensure_locomotion_anim() -> void:
	if anim_player and not _lod_anim_paused:
		play_anim(_chase_anim)

func _compute_car_hull_info() -> Dictionary:
	var ext: Vector2 = _get_player_hull_extents()
	var car_pos := player.global_position
	var b := player.global_transform.basis
	var car_r := Vector2(b.x.x, b.x.z)
	if car_r.length_squared() > 0.0001:
		car_r = car_r.normalized()
	else:
		car_r = Vector2.RIGHT
	var car_f := Vector2(-b.z.x, -b.z.z)
	if car_f.length_squared() > 0.0001:
		car_f = car_f.normalized()
	else:
		car_f = Vector2(0.0, 1.0)

	var rel := Vector2(global_position.x - car_pos.x, global_position.z - car_pos.z)
	var lx: float = rel.dot(car_r)
	var lz: float = rel.dot(car_f)

	var cx: float = clampf(lx, -ext.x, ext.x)
	var cz: float = clampf(lz, -ext.y, ext.y)
	var dx_out: float = lx - cx
	var dz_out: float = lz - cz
	var hull_dist: float = sqrt(dx_out * dx_out + dz_out * dz_out)
	var nearest_xz := Vector2(car_pos.x, car_pos.z) + car_r * cx + car_f * cz

	return {
		"ext": ext,
		"car_r": car_r,
		"car_f": car_f,
		"lx": lx,
		"lz": lz,
		"hull_dist": hull_dist,
		"nearest_xz": nearest_xz,
	}

func _push_outside_car_hull(info: Dictionary) -> float:
	if _get_player_horiz_speed_mps() >= 2.0:
		return float(info["hull_dist"])
	var ext: Vector2 = info["ext"]
	var car_r: Vector2 = info["car_r"]
	var car_f: Vector2 = info["car_f"]
	var lx: float = info["lx"]
	var lz: float = info["lz"]

	var pad_x: float = ext.x + HULL_CLEARANCE
	var pad_z: float = ext.y + HULL_CLEARANCE
	if absf(lx) < pad_x and absf(lz) < pad_z:
		var pen_x: float = pad_x - absf(lx)
		var pen_z: float = pad_z - absf(lz)
		var push_xz := Vector2.ZERO
		var normal_xz := Vector2.ZERO

		# Bias lateral push around front bumper so slow cars shove zombies smoothly aside
		if pen_x < pen_z + 0.18:
			var sx: float = 1.0 if lx >= 0.0 else -1.0
			if absf(lx) < 0.02:
				sx = 1.0 if _phase_offset > PI else -1.0
			normal_xz = car_r * sx
			push_xz = normal_xz * pen_x
		else:
			var sz: float = 1.0 if lz >= 0.0 else -1.0
			normal_xz = car_f * sz
			push_xz = normal_xz * pen_z

		global_position.x += push_xz.x
		global_position.z += push_xz.y

		var vel_2d := Vector2(_internal_velocity.x, _internal_velocity.z)
		var v_into := vel_2d.dot(normal_xz)
		if v_into < 0.0:
			vel_2d -= normal_xz * v_into
			_internal_velocity.x = vel_2d.x
			_internal_velocity.z = vel_2d.y

		return HULL_CLEARANCE
	return float(info["hull_dist"])

func _release_ragdoll_slot() -> void:
	if _using_ragdoll:
		_using_ragdoll = false
		ZombiePool.release_ragdoll()

func _advance_lod_animation(delta: float, horiz_dist_sq: float) -> void:
	if not anim_player or not anim_player.active or _lod_anim_paused:
		return
	if state == ZombieState.ATTACK or state == ZombieState.FALLEN or state == ZombieState.DEAD or horiz_dist_sq < 676.0:
		anim_player.advance(delta + _lod_anim_accum)
		_lod_anim_accum = 0.0
		return
	_lod_anim_accum += delta
	if horiz_dist_sq < 3844.0:
		if (_lod_anim_tick % 3) == 0:
			anim_player.advance(_lod_anim_accum)
			_lod_anim_accum = 0.0
	elif horiz_dist_sq < 16384.0:
		if _lod_anim_tick == 0:
			anim_player.advance(_lod_anim_accum)
			_lod_anim_accum = 0.0

func get_visual_world_position() -> Vector3:
	if _using_ragdoll and is_instance_valid(_hips_bone):
		return _hips_bone.global_position
	return global_position

func _physics_process(delta: float) -> void:
	_anim_clock += delta
	_lod_anim_tick = (_lod_anim_tick + 1) % 6
	if state == ZombieState.DEAD:
		if _ballistic_dead:
			_ballistic_vel.y -= 16.5 * delta
			global_position += _ballistic_vel * delta
			if global_position.y <= _ballistic_ground_y:
				global_position.y = _ballistic_ground_y
				_ballistic_vel.y = 0.0
				_ballistic_vel.x = move_toward(_ballistic_vel.x, 0.0, 22.0 * delta)
				_ballistic_vel.z = move_toward(_ballistic_vel.z, 0.0, 22.0 * delta)
			if anim_player and anim_player.active and not _lod_anim_paused:
				anim_player.advance(delta)
		if _is_burning and _using_ragdoll and is_instance_valid(_hips_bone):
			if is_instance_valid(_burn_vfx):
				_burn_vfx.global_position = _hips_bone.global_position + Vector3(0.0, 0.18, 0.0)
			if is_instance_valid(_burn_smoke_vfx):
				_burn_smoke_vfx.global_position = _hips_bone.global_position + Vector3(0.0, 0.42, 0.0)
		return
	if state == ZombieState.FALLEN:
		global_position = global_position.move_toward(_knockback_target, 8.0 * delta)
		if anim_player and anim_player.active:
			anim_player.advance(delta)
		return

	if player == null or not is_instance_valid(player) or player.get("destroyed") == true:
		_find_player()
		if state != ZombieState.IDLE:
			state = ZombieState.IDLE
			play_anim("Idle")
		_attack_hit_pending = false
		_internal_velocity = Vector3.ZERO
		if _posture_mod:
			_posture_mod.active = false
		if anim_player and anim_player.active and not _lod_anim_paused:
			anim_player.advance(delta)
		return

	var dx: float = player.global_position.x - global_position.x
	var dz: float = player.global_position.z - global_position.z
	var dy: float = absf(player.global_position.y - global_position.y)
	var horiz_dist_sq: float = dx * dx + dz * dz

	if horiz_dist_sq > 30625.0:
		if not _lod_anim_paused and anim_player:
			anim_player.active = false
			_lod_anim_paused = true
		if _posture_mod:
			_posture_mod.active = false
		return

	if attack_timer > 0.0:
		attack_timer -= delta

	if _posture_mod:
		_posture_mod.active = (horiz_dist_sq < 676.0)

	if state != ZombieState.ATTACK:
		if horiz_dist_sq > 16384.0:
			if not _lod_anim_paused and anim_player:
				anim_player.active = false
				_lod_anim_paused = true
		elif _lod_anim_paused and horiz_dist_sq < 14400.0:
			_lod_anim_paused = false
			_lod_anim_accum = 0.0
			if anim_player:
				anim_player.active = true
				_ensure_locomotion_anim()

	# Stepped AI cadence for distant hordes; < 55m (3025) runs every physics tick
	_lod_frame = (_lod_frame + 1) % 4
	if state == ZombieState.CHASE and horiz_dist_sq > 3025.0:
		var skip_ai: bool = (_lod_frame != 0) if horiz_dist_sq > 16384.0 else ((_lod_frame % 2) != 0)
		if skip_ai:
			global_position += _internal_velocity * delta
			_advance_lod_animation(delta, horiz_dist_sq)
			return

	var hull_info := _compute_car_hull_info()
	var hull_dist: float = float(hull_info["hull_dist"])
	if horiz_dist_sq < 1600.0:
		hull_dist = _push_outside_car_hull(hull_info)
		hull_info = _compute_car_hull_info()
		hull_dist = float(hull_info["hull_dist"])

	_update_state_and_movement(delta, dy, horiz_dist_sq, hull_info, hull_dist)
	_advance_lod_animation(delta, horiz_dist_sq)

	# Within 16m (256): full Jolt collision sweeps + O(1) spatial hash separation; beyond 16m fast translate
	if horiz_dist_sq < 256.0:
		if _internal_velocity.length_squared() > 0.0004:
			var sep := _clamp_separation_forward(_compute_neighbor_separation(), _internal_velocity)
			var net_vx: float = _internal_velocity.x + sep.x
			var net_vz: float = _internal_velocity.z + sep.y
			velocity = Vector3(net_vx, 0.0, net_vz)
			_face_direction_horizontal(Vector2(net_vx, net_vz))
			move_and_slide()
		var after_info := _compute_car_hull_info()
		_push_outside_car_hull(after_info)
	else:
		if (_lod_frame % 2) == 0 and horiz_dist_sq < 3025.0:
			_cached_sep = _clamp_separation_forward(_compute_neighbor_separation(), _internal_velocity)
		elif horiz_dist_sq >= 3025.0:
			_cached_sep = Vector2.ZERO
		var step_vel := _internal_velocity + Vector3(_cached_sep.x * 0.4, 0.0, _cached_sep.y * 0.4)
		if step_vel.length_squared() > 0.001:
			_face_direction_horizontal(Vector2(step_vel.x, step_vel.z))
		global_position += step_vel * delta

	# Occasional spatial zombie groans near the vehicle with archetype voice
	if horiz_dist_sq < 1225.0 and _anim_clock >= _next_groan_time:
		_next_groan_time = _anim_clock + randf_range(3.2, 7.8)
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_zombie_sound"):
			sm.call("play_zombie_sound", global_position, state == ZombieState.ATTACK, archetype, false)

func _compute_neighbor_separation() -> Vector2:
	var push := Vector2.ZERO
	var checked: int = 0
	var my_x := global_position.x
	var my_z := global_position.z
	var cx: int = floori(my_x * 0.25)
	var cz: int = floori(my_z * 0.25)
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var bucket: Array = ZombiePool.get_grid_cell(cx + dx, cz + dz)
			for item in bucket:
				var other := item as Node3D
				if other == null or other == self or not is_instance_valid(other) or not other.visible:
					continue
				var ox: float = my_x - other.global_position.x
				var oz: float = my_z - other.global_position.z
				var d2: float = ox * ox + oz * oz
				if d2 > 0.0001 and d2 < 0.72:
					var d: float = sqrt(d2)
					var w: float = (0.85 - d) * 3.5
					push.x += (ox / d) * w
					push.y += (oz / d) * w
					checked += 1
					if checked >= 6:
						return push
	return push

func _clamp_separation_forward(sep: Vector2, fwd_vel: Vector3) -> Vector2:
	var fwd_xz := Vector2(fwd_vel.x, fwd_vel.z)
	var fwd_len: float = fwd_xz.length()
	if fwd_len < 0.05:
		return Vector2.ZERO
	var fwd_dir: Vector2 = fwd_xz / fwd_len
	var out_sep: Vector2 = sep
	# Never let crowd separation push the zombie backwards against its movement vector
	var along: float = out_sep.dot(fwd_dir)
	if along < -fwd_len * 0.35:
		out_sep -= fwd_dir * (along + fwd_len * 0.35)
	var max_sep: float = fwd_len * 0.65
	var s_len: float = out_sep.length()
	if s_len > max_sep and s_len > 0.0001:
		out_sep *= (max_sep / s_len)
	return out_sep

func _face_direction_horizontal(dir_xz: Vector2) -> void:
	if dir_xz.length_squared() > 0.0004:
		var look_target := Vector3(global_position.x + dir_xz.x, global_position.y, global_position.z + dir_xz.y)
		if not global_position.is_equal_approx(look_target):
			look_at(look_target, Vector3.UP)

func _face_point_horizontal(target_xz: Vector2) -> void:
	var tdx := target_xz.x - global_position.x
	var tdz := target_xz.y - global_position.z
	if tdx * tdx + tdz * tdz > 0.0001:
		var look_target := Vector3(target_xz.x, global_position.y, target_xz.y)
		if not global_position.is_equal_approx(look_target):
			look_at(look_target, Vector3.UP)

func _update_state_and_movement(
	delta: float,
	dy: float,
	horiz_dist_sq: float,
	hull_info: Dictionary,
	hull_dist: float
) -> void:
	var nearest_xz: Vector2 = hull_info["nearest_xz"]
	var car_speed: float = _get_player_horiz_speed_mps()

	if state == ZombieState.ATTACK:
		_internal_velocity = Vector3.ZERO
		if _lod_anim_paused and anim_player:
			_lod_anim_paused = false
			anim_player.active = true
		_face_point_horizontal(nearest_xz)
		_attack_elapsed += delta
		if hull_dist > attack_hull_cancel_range or dy > 2.5 or car_speed >= 8.5:
			_attack_hit_pending = false
			state = ZombieState.CHASE
			_ensure_locomotion_anim()
			return
		if _attack_hit_pending and _attack_elapsed >= attack_hit_delay:
			_attack_hit_pending = false
			attack_timer = _current_attack_cooldown
		return

	# Stopped / creeping car hull engagement (never walk through car during attack cooldown!)
	if hull_dist <= attack_hull_range and dy < 2.2 and car_speed < attack_max_car_speed_mps:
		_internal_velocity = Vector3.ZERO
		_face_point_horizontal(nearest_xz)
		_lod_anim_paused = false
		if anim_player:
			anim_player.active = true
		if attack_timer <= 0.0:
			state = ZombieState.ATTACK
			_attack_hit_pending = true
			_attack_elapsed = 0.0
			play_anim(_attack_anim, true)
			var sm: Node = get_node_or_null("/root/SoundManager")
			if sm and sm.has_method("play_zombie_sound"):
				sm.call("play_zombie_sound", global_position, true, archetype, false)
		else:
			state = ZombieState.IDLE
			play_anim(_idle_anim)
		return

	if horiz_dist_sq <= detection_radius_sq or (state == ZombieState.CHASE and horiz_dist_sq <= lose_target_radius_sq):
		state = ZombieState.CHASE
		# Stalkers ambush-sprint when vehicle enters their inner aggro ring
		if archetype == ZombieArchetype.STALKER and not _ambush_triggered and horiz_dist_sq < _sprint_aggro_dist_sq:
			_ambush_triggered = true
			current_speed = maxf(current_speed * 1.65, 6.2)
			_chase_anim = "RunFeral"
			play_anim(_chase_anim, true)
		else:
			_ensure_locomotion_anim()

		var goal_xz := nearest_xz
		if _lead_time > 0.01 and player is RigidBody3D and hull_dist > 3.5:
			var pv: Vector3 = (player as RigidBody3D).linear_velocity
			var lead_scale := clampf((hull_dist - 3.5) / 18.0, 0.0, 1.0)
			goal_xz += Vector2(pv.x, pv.z) * (_lead_time * lead_scale)
		if hull_dist > 2.4:
			var flank_fade := clampf((hull_dist - 2.4) / 12.0, 0.0, 1.0)
			goal_xz += _flank_offset * flank_fade

		var tx: float = goal_xz.x - global_position.x
		var tz: float = goal_xz.y - global_position.z
		var t_len2: float = tx * tx + tz * tz
		if t_len2 > 0.002:
			var inv_len: float = 1.0 / sqrt(t_len2)
			var dir_x: float = tx * inv_len
			var dir_z: float = tz * inv_len
			# Individual serpentine weave & limping gait rhythm so no two zombies move alike
			if _weave_amp > 0.02 and hull_dist > 2.2:
				var perp_x: float = -dir_z
				var perp_z: float = dir_x
				var w_factor: float = sin(_anim_clock * _weave_freq + _phase_offset) * _weave_amp * clampf((hull_dist - 2.2) / 10.0, 0.0, 1.0)
				dir_x += perp_x * w_factor * 0.28
				dir_z += perp_z * w_factor * 0.28
				var d_norm := sqrt(dir_x * dir_x + dir_z * dir_z)
				if d_norm > 0.001:
					dir_x /= d_norm
					dir_z /= d_norm
			var spd_mod: float = 1.0
			if _limp_pulse > 0.01:
				spd_mod = 1.0 - _limp_pulse * 0.35 + _limp_pulse * 0.65 * maxf(sin(_anim_clock * 4.4 + _phase_offset), -0.4)
			_internal_velocity = Vector3(dir_x, 0.0, dir_z) * (current_speed * spd_mod)
			_face_direction_horizontal(Vector2(dir_x, dir_z))
		else:
			_internal_velocity = Vector3.ZERO
			state = ZombieState.IDLE
			play_anim(_idle_anim)
	else:
		state = ZombieState.IDLE
		play_anim(_idle_anim)
		_internal_velocity = _internal_velocity.move_toward(Vector3.ZERO, current_speed * delta)

func _on_animation_finished(anim_name: String) -> void:
	if (anim_name == "Attack" or anim_name == "AttackFrenzy") and state == ZombieState.ATTACK:
		_attack_hit_pending = false
		state = ZombieState.IDLE
		play_anim(_idle_anim)
	elif anim_name == "Death" and state == ZombieState.DEAD and not _ballistic_dead and not _using_ragdoll:
		ZombiePool.return_zombie(self)

func on_pooled() -> void:
	_generation += 1
	_dead_start_ms = 0
	_release_ragdoll_slot()
	for mi: MeshInstance3D in _mesh_instances:
		if is_instance_valid(mi):
			mi.extra_cull_margin = 2.5
	set_burning(false)
	_ballistic_dead = false
	_ballistic_vel = Vector3.ZERO
	_attack_hit_pending = false
	_attack_elapsed = 0.0
	_lod_anim_accum = 0.0
	_lod_anim_paused = true
	_internal_velocity = Vector3.ZERO
	if _posture_mod:
		_posture_mod.active = false
	_set_ragdoll_collision(false)
	if _bone_sim:
		if _bone_sim.active:
			_bone_sim.physical_bones_stop_simulation()
		_bone_sim.active = false
		_bone_sim.process_mode = Node.PROCESS_MODE_DISABLED
	if anim_player:
		anim_player.stop()
		anim_player.active = false

func reset_zombie(is_running: bool = false, difficulty: float = 0.0) -> void:
	_generation += 1
	_dead_start_ms = 0
	_release_ragdoll_slot()
	for mi: MeshInstance3D in _mesh_instances:
		if is_instance_valid(mi):
			mi.extra_cull_margin = 2.5
	set_burning(false)
	_ballistic_dead = false
	_ballistic_vel = Vector3.ZERO
	_cached_sep = Vector2.ZERO
	_lod_anim_accum = 0.0
	difficulty_tier = maxf(difficulty, 0.0)
	var d01: float = clampf(difficulty_tier, 0.0, 1.0)
	var over: float = minf(maxf(difficulty_tier - 1.0, 0.0), 1.8)
	var threat_t: float = clampf(difficulty_tier / 2.2, 0.0, 1.0)

	state = ZombieState.IDLE
	current_hp = max_hp * (1.0 + over * 0.22)
	attack_timer = 0.0
	_attack_hit_pending = false
	_attack_elapsed = 0.0
	_lod_anim_paused = false
	_internal_velocity = Vector3.ZERO
	_knockback_target = global_position
	rotation = Vector3.ZERO
	if _posture_mod:
		_posture_mod.active = true
	set_physics_process(true)

	# Layer 4 = 8 (zombie), Mask = 5 (World/Car layer 1 + Obstacles/Trees layer 4; excludes floor layer 512)
	collision_layer = 8
	collision_mask = 5

	_set_ragdoll_collision(false)
	if _bone_sim:
		if _bone_sim.active:
			_bone_sim.physical_bones_stop_simulation()
		_bone_sim.active = false
		_bone_sim.process_mode = Node.PROCESS_MODE_DISABLED
	if skeleton:
		skeleton.reset_bone_poses()

	var scaled_walk: float = lerpf(2.0, 4.0, d01)
	var scaled_run: float = lerpf(4.8, 11.8, d01) + over * 1.8
	current_damage = roundi(lerpf(6.0, 22.0, d01) + over * 5.0)
	ram_damage_mult = lerpf(0.65, 1.85, d01) + over * 0.25
	_current_attack_cooldown = lerpf(1.45, 0.80, d01)

	# Roll individual archetype, visual outfit palette, silhouette scale & behavior traits
	var roll: float = randf()
	if is_running:
		var p_sprinter: float = lerpf(0.56, 0.44, threat_t)
		var p_stalker_run: float = p_sprinter + lerpf(0.26, 0.24, threat_t)
		archetype = ZombieArchetype.SPRINTER if roll < p_sprinter else (ZombieArchetype.STALKER if roll < p_stalker_run else ZombieArchetype.BRUTE)
	else:
		var p_shambler: float = lerpf(0.36, 0.12, threat_t)
		var p_crawler: float = p_shambler + lerpf(0.28, 0.12, threat_t)
		var p_stalker: float = p_crawler + lerpf(0.18, 0.24, threat_t)
		var p_brute: float = p_stalker + lerpf(0.10, 0.26, threat_t)
		if roll < p_shambler:
			archetype = ZombieArchetype.SHAMBLER
		elif roll < p_crawler:
			archetype = ZombieArchetype.CRAWLER_LIMP
		elif roll < p_stalker:
			archetype = ZombieArchetype.STALKER
		elif roll < p_brute:
			archetype = ZombieArchetype.BRUTE
		else:
			archetype = ZombieArchetype.SPRINTER

	_apply_visual_variant(randi() % 6, randi() % ZOMBIE_MODEL_COUNT)
	_phase_offset = randf_range(0.0, TAU)
	_idle_anim = "IdleTwitch" if (randi() % 2) == 0 else "Idle"
	_attack_anim = "Attack"
	_ambush_triggered = false
	_flank_offset = Vector2(randf_range(-2.4, 2.4), randf_range(-2.0, 2.0))
	_weave_freq = randf_range(2.0, 4.2)
	_limp_pulse = 0.0
	_lead_time = 0.0
	_sprint_aggro_dist_sq = 0.0

	match archetype:
		ZombieArchetype.SHAMBLER:
			var sc := randf_range(0.93, 1.06)
			scale = Vector3.ONE * sc
			_hunch_bias = randf_range(0.14, 0.28)
			_head_tilt_bias = randf_range(-0.22, 0.22)
			_weave_amp = randf_range(0.25, 0.65)
			current_speed = scaled_walk * randf_range(0.88, 1.15)
			_chase_anim = "Walk" if (randi() % 2) == 0 else "WalkCreep"
		ZombieArchetype.CRAWLER_LIMP:
			var sc_w := randf_range(0.85, 0.94)
			scale = Vector3.ONE * sc_w
			_hunch_bias = randf_range(0.26, 0.40)
			_head_tilt_bias = randf_range(0.20, 0.36) * (-1.0 if (randi() % 2) == 0 else 1.0)
			_weave_amp = randf_range(0.45, 0.85)
			_limp_pulse = randf_range(0.28, 0.42)
			current_speed = (scaled_run * 0.78 if is_running else scaled_walk * 0.92)
			_chase_anim = "RunStumble" if is_running else "WalkLimp"
		ZombieArchetype.BRUTE:
			var sc_b := randf_range(1.18, 1.32)
			scale = Vector3.ONE * sc_b
			current_hp *= 1.75
			current_damage = roundi(float(current_damage) * 1.35)
			ram_damage_mult *= 1.25
			_hunch_bias = randf_range(0.20, 0.32)
			_head_tilt_bias = randf_range(-0.15, 0.15)
			_weave_amp = randf_range(0.12, 0.30)
			_attack_anim = "AttackFrenzy"
			current_speed = (scaled_run * 0.84 if is_running else scaled_walk * 0.95)
			_chase_anim = "RunStumble" if is_running else "Walk"
		ZombieArchetype.SPRINTER:
			var sc_s := randf_range(0.90, 0.98)
			scale = Vector3.ONE * sc_s
			_hunch_bias = randf_range(0.22, 0.34)
			_head_tilt_bias = randf_range(-0.20, 0.20)
			_weave_amp = randf_range(0.75, 1.35)
			_lead_time = randf_range(0.15, 0.38)
			current_speed = scaled_run * randf_range(0.94, 1.14)
			_chase_anim = "RunFeral" if (randi() % 2) == 0 else "Run"
			_attack_anim = "AttackFrenzy"
		ZombieArchetype.STALKER:
			var sc_k := randf_range(0.95, 1.05)
			scale = Vector3.ONE * sc_k
			_hunch_bias = randf_range(0.26, 0.38)
			_head_tilt_bias = randf_range(-0.28, 0.28)
			_weave_amp = randf_range(0.55, 1.05)
			_lead_time = randf_range(0.35, 0.72)
			_sprint_aggro_dist_sq = randf_range(20.0 * 20.0, 32.0 * 32.0)
			current_speed = (scaled_run * 0.95 if is_running else scaled_walk * 1.18)
			_chase_anim = "RunFeral" if is_running else "WalkCreep"

	if anim_player and not anim_player.has_animation(_chase_anim):
		_chase_anim = "Run" if is_running else "Walk"
	if anim_player and not anim_player.has_animation(_idle_anim):
		_idle_anim = "Idle"
	if anim_player and not anim_player.has_animation(_attack_anim):
		_attack_anim = "Attack"

	_find_player()
	if anim_player:
		anim_player.active = true
		play_anim(_chase_anim, true)
		var anim_res: Animation = anim_player.get_animation(_chase_anim)
		if anim_res and anim_res.length > 0.05:
			anim_player.seek(randf_range(0.0, anim_res.length), true)
		anim_player.advance(0.0)

func die(impact_force: Vector3 = Vector3.ZERO, impact_speed: float = 0.0, launch_override: Vector3 = Vector3.INF, side_override: float = 0.0) -> void:
	if state == ZombieState.DEAD:
		return
	_generation += 1
	_dead_start_ms = Time.get_ticks_msec()
	var my_gen := _generation
	state = ZombieState.DEAD
	_attack_hit_pending = false
	_attack_elapsed = 0.0
	_internal_velocity = Vector3.ZERO
	if _posture_mod:
		_posture_mod.active = false

	collision_layer = 0
	collision_mask = 0

	var near_player := true
	if player and is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		var dz := player.global_position.z - global_position.z
		near_player = (dx * dx + dz * dz) < 900.0

	if near_player:
		var sm: Node = get_node_or_null("/root/SoundManager")
		if sm and sm.has_method("play_zombie_sound") and (randi() % 2) == 0:
			sm.call("play_zombie_sound", global_position, false, archetype, true)

	var use_override: bool = launch_override.is_finite() and launch_override.length_squared() > 0.25

	if near_player and _bone_sim and ZombiePool.try_acquire_ragdoll():
		_using_ragdoll = true
		_ballistic_dead = false
		for mi: MeshInstance3D in _mesh_instances:
			if is_instance_valid(mi):
				mi.extra_cull_margin = 65.0
		if anim_player:
			anim_player.stop()
			anim_player.active = false
		_lod_anim_paused = true
		_bone_sim.process_mode = Node.PROCESS_MODE_INHERIT
		_bone_sim.active = true
		_set_ragdoll_collision(true)
		_bone_sim.physical_bones_start_simulation()
		set_physics_process(false)

		var push_dir: Vector3 = Vector3.BACK
		var side_dir: Vector3 = Vector3.RIGHT
		var base_horiz: float = 4.0
		var base_up: float = 2.6
		var side_sign: float = -1.0 if (randi() % 2) == 0 else 1.0
		var lat_whip: float = 0.0
		if use_override:
			var ov_xz := Vector3(launch_override.x, 0.0, launch_override.z)
			base_horiz = ov_xz.length()
			push_dir = (ov_xz / base_horiz) if base_horiz > 0.01 else (-global_transform.basis.z)
			side_dir = Vector3(-push_dir.z, 0.0, push_dir.x)
			base_up = launch_override.y
			if absf(side_override) > 0.05:
				side_sign = signf(side_override)
			lat_whip = 0.45 * side_sign
		else:
			var push_xz := Vector3(impact_force.x, 0.0, impact_force.z)
			var push_len: float = push_xz.length()
			push_dir = (push_xz / push_len) if push_len > 0.01 else (-global_transform.basis.z)
			side_dir = Vector3(-push_dir.z, 0.0, push_dir.x)
			var eff_speed: float = clampf(maxf(impact_speed, push_len * 0.78), 4.5, 28.0)
			base_horiz = clampf(eff_speed * 0.56, 3.0, 15.0)
			base_up = clampf(1.8 + eff_speed * 0.16, 2.2, 6.4)
			lat_whip = randf_range(0.6, 1.9) * side_sign

		for child in _physical_bones:
			if not is_instance_valid(child):
				continue
			var b_name: String = child.name
			var h_mult: float = 1.0
			var u_mult: float = 1.0
			var l_mult: float = 0.45
			if b_name.contains("UpLeg") or b_name.contains("Leg") or b_name.contains("Foot"):
				# Bumper sweeps legs forward sharply so torso pitches over the hood cleanly
				h_mult = 1.22
				u_mult = 0.85
				l_mult = 0.35
			elif b_name.ends_with("Hips"):
				h_mult = 1.06
				u_mult = 1.00
				l_mult = 0.45
			elif b_name.contains("Spine"):
				h_mult = 0.94
				u_mult = 1.10
				l_mult = 0.60
			elif b_name.ends_with("Head") or b_name.ends_with("Neck"):
				h_mult = 0.84
				u_mult = 1.15
				l_mult = 0.72
			elif b_name.contains("Arm") or b_name.contains("Hand") or b_name.contains("Shoulder"):
				h_mult = 0.88
				u_mult = 1.08
				l_mult = 0.55 + randf_range(-0.20, 0.25)
			var bone_vel: Vector3 = push_dir * (base_horiz * h_mult) + Vector3(0.0, base_up * u_mult, 0.0) + side_dir * (lat_whip * l_mult)
			var spin_k: float = clampf(base_horiz / 20.0, 0.28, 1.15)
			child.linear_velocity = bone_vel
			child.angular_velocity = (side_dir * randf_range(6.0, 12.0) + push_dir * (side_sign * randf_range(2.2, 5.2)) + Vector3(0.0, side_sign * randf_range(1.5, 4.0), 0.0)) * spin_k

		var st_rag := get_tree()
		if st_rag:
			var wr_rag: WeakRef = weakref(self)
			st_rag.create_timer(6.0).timeout.connect(
				func():
					var z_ref = wr_rag.get_ref()
					if z_ref and is_instance_valid(z_ref) and z_ref.get("_generation") == my_gen and z_ref.get("state") == ZombieState.DEAD:
						ZombiePool.return_zombie(z_ref)
			)
	else:
		_ballistic_dead = true
		_ballistic_ground_y = minf(global_position.y, 0.05)
		if use_override:
			_ballistic_vel = launch_override
		else:
			var push_xz := Vector3(impact_force.x, 0.0, impact_force.z)
			var push_len := push_xz.length()
			var push_dir := (push_xz / push_len) if push_len > 0.01 else Vector3.BACK
			var launch_horiz := clampf(impact_speed * 0.48 + push_len * 0.35, 3.0, 20.0)
			var launch_up := clampf(1.8 + impact_speed * 0.15 + push_len * 0.10, 1.8, 6.4)
			_ballistic_vel = Vector3(push_dir.x * launch_horiz, launch_up, push_dir.z * launch_horiz)
		_lod_anim_paused = false
		if anim_player:
			anim_player.active = true
		play_anim("Death", true)
		var st_bal := get_tree()
		if st_bal:
			var wr_bal: WeakRef = weakref(self)
			st_bal.create_timer(5.2).timeout.connect(
				func():
					var z_ref = wr_bal.get_ref()
					if z_ref and is_instance_valid(z_ref) and z_ref.get("_generation") == my_gen and z_ref.get("state") == ZombieState.DEAD:
						ZombiePool.return_zombie(z_ref)
			)

func knockdown(impact_force: Vector3) -> void:
	if state == ZombieState.DEAD or state == ZombieState.FALLEN:
		return
	var my_gen := _generation
	state = ZombieState.FALLEN
	_attack_hit_pending = false
	_attack_elapsed = 0.0
	_internal_velocity = Vector3.ZERO

	var speed_mps := impact_force.length()
	var push_dir := Vector3(impact_force.x, 0.0, impact_force.z)
	push_dir = push_dir.normalized() if push_dir.length_squared() > 0.001 else Vector3.BACK
	var push_dist := clampf(remap(speed_mps, 0.0, 20.0, 0.5, 2.5), 0.5, 2.5)
	_knockback_target = global_position + push_dir * push_dist

	_lod_anim_paused = false
	if anim_player:
		anim_player.active = true
	play_anim("Death", true)

	await get_tree().create_timer(get_up_time).timeout
	if not is_instance_valid(self) or _generation != my_gen or state != ZombieState.FALLEN:
		return
	await _get_up(my_gen)

func _get_up(my_gen: int) -> void:
	if state == ZombieState.DEAD or _generation != my_gen:
		return

	if anim_player and anim_player.has_animation("Death"):
		anim_player.active = true
		_lod_anim_paused = false
		anim_player.speed_scale = _get_locomotion_speed_scale("Death")
		anim_player.play("Death", -1, -1.0, true)
		await anim_player.animation_finished
		if not is_instance_valid(self) or _generation != my_gen or state == ZombieState.DEAD:
			return

	state = ZombieState.CHASE
	_ensure_locomotion_anim()

func play_anim(anim_name: String, force_restart: bool = false) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		anim_player.speed_scale = _get_locomotion_speed_scale(anim_name)
		if force_restart or anim_player.current_animation != anim_name or not anim_player.is_playing():
			anim_player.play(anim_name)

func setup_menu_showcase(v_idx: int, m_idx: int, anim_name: String = "Idle", start_phase: float = 0.0) -> void:
	state = ZombieState.IDLE
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	_lod_anim_paused = false
	_phase_offset = start_phase
	_anim_clock = start_phase
	_hunch_bias = 0.16 + fmod(start_phase * 0.11, 0.14)
	_head_tilt_bias = sin(start_phase * 1.7) * 0.20
	_apply_visual_variant(v_idx, m_idx)
	if _posture_mod:
		_posture_mod.active = true
	if anim_player:
		anim_player.active = true
		var target_anim := anim_name if anim_player.has_animation(anim_name) else "Idle"
		play_anim(target_anim, true)
		var anim_res: Animation = anim_player.get_animation(target_anim)
		if anim_res and anim_res.length > 0.05:
			anim_player.seek(fmod(start_phase, anim_res.length), true)
		anim_player.advance(0.0)

func step_menu_idle(delta: float, speed_scale: float = 1.0) -> void:
	var dt := maxf(delta, 0.0) * maxf(speed_scale, 0.0)
	_anim_clock += dt
	if anim_player and anim_player.active and not _lod_anim_paused:
		anim_player.advance(dt)

func set_burning(active: bool) -> void:
	_is_burning = active
	if active:
		_apply_visual_variant(6, -1)
		if _burn_vfx == null:
			var vfx := get_node_or_null("/root/CarVFX")
			if _shared_burn_fire_mesh == null:
				var fire_tex: Texture2D = vfx.get("tex_muzzle_fire") as Texture2D if vfx else null
				var qm := QuadMesh.new()
				qm.size = Vector2(0.86, 1.08)
				var mat := StandardMaterial3D.new()
				mat.vertex_color_use_as_albedo = true
				mat.vertex_color_is_srgb = true
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
				mat.billboard_keep_scale = true
				mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if fire_tex:
					mat.albedo_texture = fire_tex
				qm.material = mat
				_shared_burn_fire_mesh = qm
			var cp := CPUParticles3D.new()
			cp.name = "ZombieBurnVFX"
			cp.position = Vector3(0.0, 1.05, 0.0)
			cp.mesh = _shared_burn_fire_mesh
			cp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cp.visibility_range_end = 155.0
			cp.amount = 11
			cp.lifetime = 0.62
			cp.local_coords = false
			cp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			cp.emission_box_extents = Vector3(0.26, 0.48, 0.22)
			cp.direction = Vector3(0.0, 1.0, 0.0)
			cp.spread = 24.0
			cp.gravity = Vector3(0.0, 2.8, 0.0)
			cp.initial_velocity_min = 0.7
			cp.initial_velocity_max = 1.9
			cp.scale_amount_min = 0.62
			cp.scale_amount_max = 1.25
			var ramp := Gradient.new()
			ramp.offsets = PackedFloat32Array([0.0, 0.22, 0.68, 1.0])
			ramp.colors = PackedColorArray([
				Color(1.0, 0.96, 0.58, 0.0),
				Color(1.0, 0.52, 0.08, 0.92),
				Color(0.88, 0.16, 0.02, 0.52),
				Color(0.35, 0.04, 0.01, 0.0),
			])
			cp.color_ramp = ramp
			add_child(cp)
			_burn_vfx = cp
		if _burn_smoke_vfx == null:
			var vfx2 := get_node_or_null("/root/CarVFX")
			if _shared_burn_smoke_mesh == null:
				var smoke_tex: Texture2D = vfx2.get("tex_smoke_puff") as Texture2D if vfx2 else null
				var sqm := QuadMesh.new()
				sqm.size = Vector2(0.95, 0.95)
				var smat := StandardMaterial3D.new()
				smat.vertex_color_use_as_albedo = true
				smat.vertex_color_is_srgb = true
				smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				smat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
				smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
				smat.billboard_keep_scale = true
				smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if smoke_tex:
					smat.albedo_texture = smoke_tex
				sqm.material = smat
				_shared_burn_smoke_mesh = sqm
			var scp := CPUParticles3D.new()
			scp.name = "ZombieBurnSmokeVFX"
			scp.position = Vector3(0.0, 1.32, 0.0)
			scp.mesh = _shared_burn_smoke_mesh
			scp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			scp.visibility_range_end = 155.0
			scp.amount = 8
			scp.lifetime = 1.08
			scp.local_coords = false
			scp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			scp.emission_box_extents = Vector3(0.24, 0.36, 0.22)
			scp.direction = Vector3(0.0, 1.0, 0.0)
			scp.spread = 28.0
			scp.gravity = Vector3(0.0, 3.0, 0.0)
			scp.initial_velocity_min = 0.55
			scp.initial_velocity_max = 1.35
			scp.scale_amount_min = 0.72
			scp.scale_amount_max = 1.65
			scp.angle_min = 0.0
			scp.angle_max = 360.0
			var sramp := Gradient.new()
			sramp.offsets = PackedFloat32Array([0.0, 0.20, 0.65, 1.0])
			sramp.colors = PackedColorArray([
				Color(0.06, 0.055, 0.05, 0.0),
				Color(0.05, 0.045, 0.04, 0.64),
				Color(0.08, 0.075, 0.07, 0.34),
				Color(0.10, 0.095, 0.09, 0.0),
			])
			scp.color_ramp = sramp
			add_child(scp)
			_burn_smoke_vfx = scp
		if is_instance_valid(_burn_vfx):
			_burn_vfx.position = Vector3(0.0, 1.05, 0.0)
			_burn_vfx.visible = true
			_burn_vfx.emitting = true
		if is_instance_valid(_burn_smoke_vfx):
			_burn_smoke_vfx.position = Vector3(0.0, 1.32, 0.0)
			_burn_smoke_vfx.visible = true
			_burn_smoke_vfx.emitting = true
	else:
		if is_instance_valid(_burn_vfx):
			_burn_vfx.position = Vector3(0.0, 1.05, 0.0)
			_burn_vfx.emitting = false
			_burn_vfx.visible = false
		if is_instance_valid(_burn_smoke_vfx):
			_burn_smoke_vfx.position = Vector3(0.0, 1.32, 0.0)
			_burn_smoke_vfx.emitting = false
			_burn_smoke_vfx.visible = false

func trigger_menu_ragdoll(impact_force: Vector3, impact_speed: float = 22.0) -> void:
	if state == ZombieState.DEAD:
		return
	_generation += 1
	state = ZombieState.DEAD
	_attack_hit_pending = false
	_attack_elapsed = 0.0
	_internal_velocity = Vector3.ZERO
	_ballistic_dead = false
	if _posture_mod:
		_posture_mod.active = false
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	var col_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if col_shape:
		col_shape.disabled = true

	if _bone_sim:
		_using_ragdoll = false
		if anim_player:
			anim_player.stop()
			anim_player.active = false
		_lod_anim_paused = true
		_bone_sim.process_mode = Node.PROCESS_MODE_INHERIT
		_bone_sim.active = true
		for pb: PhysicalBone3D in _physical_bones:
			if is_instance_valid(pb):
				pb.collision_layer = 0
				pb.collision_mask = 1
				pb.linear_damp = 0.18
				pb.angular_damp = 0.55
		_bone_sim.physical_bones_start_simulation()

		var push_xz := Vector3(impact_force.x, 0.0, impact_force.z)
		var push_len: float = push_xz.length()
		var push_dir: Vector3 = (push_xz / push_len) if push_len > 0.01 else Vector3.FORWARD
		var side_dir := Vector3(-push_dir.z, 0.0, push_dir.x)
		var eff_speed: float = clampf(maxf(impact_speed, push_len * 0.85), 8.0, 32.0)
		var base_horiz: float = clampf(eff_speed * 0.62, 5.0, 18.0)
		var base_up: float = clampf(3.2 + eff_speed * 0.22, 4.0, 9.2)
		var side_sign: float = -1.0 if (randi() % 2) == 0 else 1.0
		var lat_whip: float = randf_range(1.6, 4.4) * side_sign

		for child in _physical_bones:
			if not is_instance_valid(child):
				continue
			var b_name: String = child.name
			var h_mult: float = 1.0
			var u_mult: float = 1.0
			var l_mult: float = 0.65
			if b_name.contains("UpLeg") or b_name.contains("Leg") or b_name.contains("Foot"):
				h_mult = 1.28
				u_mult = 0.82
				l_mult = 0.42
			elif b_name.ends_with("Hips"):
				h_mult = 1.12
				u_mult = 1.02
				l_mult = 0.52
			elif b_name.contains("Spine"):
				h_mult = 0.94
				u_mult = 1.16
				l_mult = 0.72
			elif b_name.ends_with("Head") or b_name.ends_with("Neck"):
				h_mult = 0.84
				u_mult = 1.26
				l_mult = 0.90
			elif b_name.contains("Arm") or b_name.contains("Hand") or b_name.contains("Shoulder"):
				h_mult = 0.88
				u_mult = 1.20
				l_mult = 0.78 + randf_range(-0.35, 0.35)
			var bone_vel: Vector3 = push_dir * (base_horiz * h_mult) + Vector3(0.0, base_up * u_mult, 0.0) + side_dir * (lat_whip * l_mult)
			child.linear_velocity = bone_vel
			child.angular_velocity = side_dir * randf_range(7.0, 14.0) + push_dir * (side_sign * randf_range(2.5, 6.5)) + Vector3(0.0, randf_range(-4.5, 4.5), 0.0)
