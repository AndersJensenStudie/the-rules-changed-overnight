extends "res://obstacle.gd"

const VARIANTS: Array[SpriteFrames] = [
	preload("res://assets/animations/laser_red_frames.tres"),
	preload("res://assets/animations/laser_blue_frames.tres"),
	preload("res://assets/animations/laser_yellow_frames.tres"),
]

static var _hitboxes := {}

@export var laser_speed := 400.0
@export var hitbox_inset := 2.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	var frames: SpriteFrames = VARIANTS.pick_random()
	sprite.sprite_frames = frames
	sprite.flip_h = true
	sprite.play(&"default")
	var rect := _hitbox_for(frames)
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	add_child(collision)


func _physics_process(delta: float) -> void:
	if speed > 0.0:
		position.x -= laser_speed * get_parent().world_time_scale * delta
	if global_position.x < -40.0:
		queue_free()


func _hitbox_for(frames: SpriteFrames) -> Rect2:
	if _hitboxes.has(frames):
		return _hitboxes[frames]
	var used := Rect2()
	for i in frames.get_frame_count(&"default"):
		var image := frames.get_frame_texture(&"default", i).get_image()
		var frame_used := Rect2(image.get_used_rect())
		used = frame_used if used.size == Vector2.ZERO else used.merge(frame_used)
	var half := Vector2(16, 16)
	var rect := Rect2(Vector2(half.x * 2.0 - used.end.x, used.position.y) - half, used.size)
	rect = rect.grow(-hitbox_inset)
	_hitboxes[frames] = rect
	return rect
