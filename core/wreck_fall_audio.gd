class_name WreckFallAudio
extends Node

const INITIAL_GRACE_MS: int = 120
const COOLDOWN_MS: int = 160
const MAX_FALL_HITS: int = 5
const MAX_LIFETIME_MS: int = 9000

var mat_kind: String = "metal"
var _start_ms: int = 0
var _last_sfx_ms: int = 0
var _hit_count: int = 0
var _prev_vel: Vector3 = Vector3.ZERO


func _ready() -> void:
	name = "WreckFallAudio"
	reset_tracking()


func reset_tracking() -> void:
	_start_ms = Time.get_ticks_msec()
	_last_sfx_ms = 0
	_hit_count = 0
	var rb := get_parent() as RigidBody3D
	_prev_vel = rb.linear_velocity if rb != null else Vector3.ZERO


func _physics_process(_delta: float) -> void:
	var rb := get_parent() as RigidBody3D
	if rb == null or rb.freeze:
		queue_free()
		return

	var now_ms: int = Time.get_ticks_msec()
	var vel: Vector3 = rb.linear_velocity
	var dv: float = (_prev_vel - vel).length()
	var vert_bounce: float = vel.y - _prev_vel.y

	if now_ms - _start_ms >= INITIAL_GRACE_MS and now_ms - _last_sfx_ms >= COOLDOWN_MS and _hit_count < MAX_FALL_HITS:
		if (dv >= 2.6 or (_prev_vel.y < -1.8 and vert_bounce >= 1.8)) and rb.global_position.y < 18.0:
			_last_sfx_ms = now_ms
			_hit_count += 1
			var impact_spd: float = maxf(dv, absf(_prev_vel.y))
			if SoundManager != null and SoundManager.has_method("play_prop_fall"):
				SoundManager.play_prop_fall(mat_kind, impact_spd, rb.global_position, true)

	_prev_vel = vel

	if _hit_count >= MAX_FALL_HITS:
		queue_free()
	elif now_ms - _start_ms > 500 and (rb.sleeping or (now_ms - _start_ms > MAX_LIFETIME_MS and vel.length_squared() < 0.09)):
		queue_free()
