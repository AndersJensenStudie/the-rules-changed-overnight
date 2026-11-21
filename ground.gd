extends Node2D

@export var width := 250.0
@export var color := Color(0.33, 0.33, 0.33)

var speed := 0.0
var _offset := 0.0
var _pebbles: Array[Vector2] = []


func _ready() -> void:
	for i in 24:
		_pebbles.append(Vector2(randf() * width, randf_range(3.0, 8.0)))


func apply_mode(settings: ModeSettings) -> void:
	color = settings.ground_color
	queue_redraw()


func _process(delta: float) -> void:
	if speed == 0.0:
		return
	_offset = fmod(_offset + speed * delta, width)
	queue_redraw()


func _draw() -> void:
	draw_line(Vector2(0, 0), Vector2(width, 0), color, 1.0)
	for p in _pebbles:
		var x := fposmod(p.x - _offset, width)
		draw_rect(Rect2(x, p.y, 2, 1), color)
