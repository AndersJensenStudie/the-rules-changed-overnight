extends "res://obstacle.gd"

@export var extra_speed := 80.0


func _physics_process(delta: float) -> void:
	if speed > 0.0:
		position.x -= extra_speed * delta
	super(delta)
