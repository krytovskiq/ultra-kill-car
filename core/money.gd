extends Label

func _ready():
	$CanvasLayer/Money.text = str(Game.money) + " $"
