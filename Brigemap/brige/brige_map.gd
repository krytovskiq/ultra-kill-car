extends Node3D
@onready var anim_player = $AnimationPlayer
func _ready():
	var anim = anim_player.get_animation("Object_0")
	anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play("Object_0")
