extends Node

## Плавный пост-апокалиптический переход между сценами (дымка + затемнение + раскрытие без рывков).

const TRANSITION_SHADER: Shader = preload("res://ui/shaders/scene_transition.gdshader")

var _layer: CanvasLayer = null
var _overlay: ColorRect = null
var _mat: ShaderMaterial = null
var _is_transitioning: bool = false
var _shader_time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_overlay()


func _process(delta: float) -> void:
	if _layer != null and _layer.visible and _mat != null:
		_shader_time += delta
		_mat.set_shader_parameter("time_sec", _shader_time)


func _ensure_overlay() -> void:
	if _layer != null and is_instance_valid(_layer):
		return
	_layer = CanvasLayer.new()
	_layer.name = "SceneTransitionLayer"
	_layer.layer = 128
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_layer.visible = false
	add_child(_layer)

	_overlay = ColorRect.new()
	_overlay.name = "TransitionVeil"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(1.0, 1.0, 1.0, 1.0)

	_mat = ShaderMaterial.new()
	_mat.shader = TRANSITION_SHADER
	_mat.set_shader_parameter("progress", 0.0)
	_mat.set_shader_parameter("time_sec", 0.0)
	_overlay.material = _mat
	_layer.add_child(_overlay)


func is_transitioning() -> bool:
	return _is_transitioning


func set_tint_for_scene(scene_path: String) -> void:
	_ensure_overlay()
	if _mat == null:
		return
	if scene_path.find("Shop_Hungar") >= 0:
		_mat.set_shader_parameter("fog_color_dark", Color(0.035, 0.038, 0.044, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.14, 0.13, 0.125, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.95, 0.42, 0.16, 1.0))
	elif scene_path.find("main.tscn") >= 0:
		_mat.set_shader_parameter("fog_color_dark", Color(0.045, 0.042, 0.04, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.16, 0.145, 0.13, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.92, 0.36, 0.14, 1.0))
	else:
		_mat.set_shader_parameter("fog_color_dark", Color(0.04, 0.042, 0.046, 1.0))
		_mat.set_shader_parameter("fog_color_mid", Color(0.145, 0.138, 0.13, 1.0))
		_mat.set_shader_parameter("ember_color", Color(0.88, 0.36, 0.14, 1.0))


func _set_progress(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("progress", clampf(v, 0.0, 1.0))


func transition_to_scene(scene_path: String, fade_out_sec: float = 0.36, fade_in_sec: float = 0.48, hold_sec: float = 0.05) -> void:
	if _is_transitioning or scene_path.is_empty():
		return
	_is_transitioning = true
	_ensure_overlay()
	set_tint_for_scene(scene_path)

	_layer.visible = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_progress(0.0)

	if fade_out_sec > 0.01:
		var tw_out := create_tween()
		tw_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_out.set_ignore_time_scale(true)
		tw_out.tween_method(Callable(self, "_set_progress"), 0.0, 1.0, fade_out_sec)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tw_out.finished
	else:
		_set_progress(1.0)

	if not is_inside_tree():
		_is_transitioning = false
		return

	if hold_sec > 0.0:
		await get_tree().create_timer(hold_sec, true, false, true).timeout

	if not is_inside_tree():
		_is_transitioning = false
		return

	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("stop_transient_sfx"):
		sm.call("stop_transient_sfx")

	get_tree().paused = false
	Engine.time_scale = 1.0
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("SceneTransition: change_scene_to_file failed (%s): %d" % [scene_path, err])

	await get_tree().process_frame
	if is_inside_tree():
		await get_tree().process_frame

	if fade_in_sec > 0.01 and is_inside_tree():
		var tw_in := create_tween()
		tw_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw_in.set_ignore_time_scale(true)
		tw_in.tween_method(Callable(self, "_set_progress"), 1.0, 0.0, fade_in_sec)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tw_in.finished

	_set_progress(0.0)
	if is_instance_valid(_overlay):
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_instance_valid(_layer):
		_layer.visible = false
	_is_transitioning = false
