extends "res://obstacle.gd"

const TEXTURE := preload("res://assets/images/pipe.png")
const LIP_REGION := Rect2(11, 14, 11, 3)
const BODY_TOP_REGION := Rect2(13, 17, 7, 1)
const BODY_REGION := Rect2(13, 18, 7, 1)
const BODY_BOTTOM_REGION := Rect2(13, 30, 7, 1)
const SCALE := 2.0

@export var height := 40.0
@export var kill_inset := 2.0
@export var flipped := false
@export var solid_top := true

var width := LIP_REGION.size.x * SCALE


func _ready() -> void:
	super()
	var lip_height := LIP_REGION.size.y * SCALE
	var body_width := BODY_REGION.size.x * SCALE
	var edge := SCALE
	_add_sprite(LIP_REGION, Vector2(-width / 2.0, -height), Vector2(SCALE, SCALE))
	_add_sprite(BODY_TOP_REGION, Vector2(-body_width / 2.0, -height + lip_height), Vector2(SCALE, SCALE))
	_add_sprite(BODY_REGION, Vector2(-body_width / 2.0, -height + lip_height + edge), Vector2(SCALE, height - lip_height - edge * 2.0))
	_add_sprite(BODY_BOTTOM_REGION, Vector2(-body_width / 2.0, -edge), Vector2(SCALE, SCALE))
	var inset := kill_inset if solid_top else 0.0
	_add_rect(self, Rect2(-width / 2.0, -height + inset, width, lip_height - inset))
	_add_rect(self, Rect2(-body_width / 2.0, -height + lip_height, body_width, height - lip_height))
	if solid_top:
		var top := StaticBody2D.new()
		add_child(top)
		var surface := _add_rect(top, Rect2(-width / 2.0, -height, width, lip_height))
		surface.one_way_collision = true


func _mirror(rect: Rect2) -> Rect2:
	if flipped:
		rect.position.y = -rect.position.y - rect.size.y
	return rect


func _add_sprite(region: Rect2, pos: Vector2, scale_factor: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.centered = false
	sprite.flip_v = flipped
	sprite.position = _mirror(Rect2(pos, region.size * scale_factor)).position
	sprite.scale = scale_factor
	add_child(sprite)


func _add_rect(parent: Node, rect: Rect2) -> CollisionShape2D:
	rect = _mirror(rect)
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = rect.get_center()
	parent.add_child(collision)
	return collision
