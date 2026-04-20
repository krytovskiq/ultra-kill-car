extends CanvasLayer

func _ready():
	$Money.text = str(Game.money) + " $"
