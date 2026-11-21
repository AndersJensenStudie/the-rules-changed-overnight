extends "res://obstacle.gd"

signal passed_over


func _ready() -> void:
	super()
	$PassZone.body_exited.connect(_on_pass_zone_exited)


func _on_pass_zone_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var zone_shape: CollisionShape2D = $PassZone/CollisionShape2D
	var zone_right: float = zone_shape.global_position.x + zone_shape.shape.size.x / 2.0
	if zone_right <= body.hitbox_rect().position.x + 1.0:
		passed_over.emit()
