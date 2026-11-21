extends "res://obstacle.gd"

signal collected

var _taken := false


func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	collected.emit()
	queue_free()
