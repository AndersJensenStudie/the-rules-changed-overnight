extends "res://coin.gd"

@export var flip_time := 0.3

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	sprite.animation_finished.connect(_flip)
	sprite.play(&"default")


func _flip() -> void:
	var tween := create_tween()
	tween.tween_property(sprite, "rotation_degrees", 180.0, flip_time)
	tween.tween_callback(_restart)


func _restart() -> void:
	sprite.rotation_degrees = 0.0
	sprite.frame = 0
	sprite.play(&"default")
