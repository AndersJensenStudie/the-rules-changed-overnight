extends Node2D

@export var color := Color(0.08, 0.08, 0.08)
@export var thickness := 1.0

var _target: Node2D
var _copies: Array[Node2D] = []


func _ready() -> void:
	_target = get_parent() as Node2D
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var copy: Node2D = ClassDB.instantiate(_target.get_class())
		copy.show_behind_parent = true
		copy.self_modulate = color
		copy.position = direction * thickness / _target.scale
		_target.add_child.call_deferred(copy)
		_copies.append(copy)
	_sync()


func _process(_delta: float) -> void:
	_sync()


func _sync() -> void:
	for copy in _copies:
		if _target is AnimatedSprite2D:
			copy.sprite_frames = _target.sprite_frames
			copy.animation = _target.animation
			copy.frame = _target.frame
		elif _target is Sprite2D:
			copy.texture = _target.texture
			copy.region_enabled = _target.region_enabled
			copy.region_rect = _target.region_rect
			copy.hframes = _target.hframes
			copy.vframes = _target.vframes
			copy.frame = _target.frame
		copy.centered = _target.centered
		copy.offset = _target.offset
		copy.flip_h = _target.flip_h
		copy.flip_v = _target.flip_v
