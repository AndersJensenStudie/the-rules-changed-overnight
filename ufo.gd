extends Node2D

@export var x := 222.0
@export var top_y := 24.0
@export var bottom_y := 230.0
@export var period := 4.0

var _time := 0.0


func _ready() -> void:
	_update_position()


func _process(delta: float) -> void:
	_time += delta
	_update_position()


func _update_position() -> void:
	var middle := (top_y + bottom_y) / 2.0
	var amplitude := (bottom_y - top_y) / 2.0
	position = Vector2(x, middle - amplitude * cos(_time * TAU / period))
