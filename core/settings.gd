extends Node

enum GraphicsQuality { POTATO, LOW, MEDIUM, HIGH, VERY_HIGH, MAXIMUM }
var current_quality: GraphicsQuality = GraphicsQuality.HIGH

const SAVE_PATH = "user://settings.dat"

func _ready() -> void:
	load_settings()
	call_deferred("apply_settings")

func set_quality(q: GraphicsQuality) -> void:
	current_quality = q
	apply_settings()
	save_settings()

func apply_settings() -> void:
	var viewport = get_viewport()
	var env: Environment = null
	if get_tree().current_scene:
		var we = get_tree().current_scene.get_node_or_null("WorldEnvironment")
		if we and we is WorldEnvironment:
			env = we.environment
	
	if current_quality == GraphicsQuality.POTATO:
		viewport.scaling_3d_scale = 0.35
		if env:
			env.glow_enabled = false
			env.adjustment_enabled = false
			env.fog_enabled = false
			
	elif current_quality == GraphicsQuality.LOW:
		viewport.scaling_3d_scale = 0.55
		if env:
			env.glow_enabled = false
			env.adjustment_enabled = false
			env.fog_enabled = true
			
	elif current_quality == GraphicsQuality.MEDIUM:
		viewport.scaling_3d_scale = 0.75
		if env:
			env.glow_enabled = true
			env.glow_intensity = 0.5
			env.glow_bloom = 0.05
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.adjustment_enabled = false
			env.fog_enabled = true
			
	elif current_quality == GraphicsQuality.HIGH:
		viewport.scaling_3d_scale = 1.0
		if env:
			env.glow_enabled = true
			env.glow_intensity = 1.0
			env.glow_bloom = 0.1
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.adjustment_enabled = false
			env.fog_enabled = true

	elif current_quality == GraphicsQuality.VERY_HIGH:
		viewport.scaling_3d_scale = 1.0
		if env:
			env.glow_enabled = true
			env.glow_intensity = 1.5
			env.glow_bloom = 0.15
			env.glow_blend_mode = 1
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.0
			env.adjustment_enabled = true
			env.adjustment_contrast = 1.1
			env.adjustment_saturation = 1.1
			env.fog_enabled = true

	elif current_quality == GraphicsQuality.MAXIMUM:
		viewport.scaling_3d_scale = 1.2
		if env:
			env.glow_enabled = true
			env.glow_intensity = 2.0
			env.glow_bloom = 0.2
			env.glow_blend_mode = 1
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.15
			env.adjustment_enabled = true
			env.adjustment_contrast = 1.15
			env.adjustment_saturation = 1.2
			env.fog_enabled = true
			
func save_settings() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_8(current_quality)
		file.close()

func load_settings() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var val = file.get_8()
			if val >= 0 and val <= 5:
				current_quality = val as GraphicsQuality
			file.close()
