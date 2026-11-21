extends "res://obstacle.gd"

@export var walk_speed := 30.0
@export var head_height := 4.0
@export var kill_inset := 2.0
@export var squash_time := 0.3
@export var squash_scale_y := 0.4

var _squashed := false
var _head: StaticBody2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	super()
	var size: Vector2 = hitbox.shape.size
	var top := hitbox.position.y - size.y / 2.0
	var kill_shape := RectangleShape2D.new()
	kill_shape.size = Vector2(size.x, size.y - kill_inset)
	hitbox.shape = kill_shape
	hitbox.position.y = top + kill_inset + kill_shape.size.y / 2.0
	_head = StaticBody2D.new()
	var head_shape := RectangleShape2D.new()
	head_shape.size = Vector2(size.x, head_height)
	var head_collision := CollisionShape2D.new()
	head_collision.shape = head_shape
	head_collision.position = Vector2(hitbox.position.x, top + head_height / 2.0)
	head_collision.one_way_collision = true
	_head.add_child(head_collision)
	add_child(_head)


func _physics_process(delta: float) -> void:
	if speed > 0.0 and not _squashed:
		position.x -= walk_speed * delta
	super(delta)


func _on_body_entered(body: Node2D) -> void:
	if _squashed:
		return
	super(body)


func stomp(player: Node2D) -> void:
	if _squashed:
		return
	_squashed = true
	set_deferred("monitoring", false)
	_head.queue_free()
	sprite.stop()
	var bottom := sprite.position.y + sprite.scale.y * 16.0
	sprite.scale.y *= squash_scale_y
	sprite.position.y = bottom - sprite.scale.y * 16.0
	player.bounce()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, squash_time)
	tween.tween_callback(queue_free)
