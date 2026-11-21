extends Node2D

@export var x := 222.0
@export var top_y := 133.0
@export var bottom_y := 230.0
@export var period := 4.0
@export var obstacles_per_attack := 3
@export var flashes := 3
@export var flash_time := 0.1
@export var flash_color := Color(4.0, 4.0, 4.0)
@export var laser_scene: PackedScene = preload("res://laser.tscn")
@export var muzzle_offset := Vector2(-14.0, 0.0)

var _time := 0.0
var _obstacles_seen := 0
var _attacking := false
var _spawner: Node

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_update_position()
	_spawner = get_tree().get_first_node_in_group("spawner")
	if _spawner:
		_spawner.obstacle_spawned.connect(_on_obstacle_spawned)


func _process(delta: float) -> void:
	if _attacking:
		return
	_time += delta
	_update_position()


func _update_position() -> void:
	var middle := (top_y + bottom_y) / 2.0
	var amplitude := (bottom_y - top_y) / 2.0
	position = Vector2(x, middle - amplitude * cos(_time * TAU / period))


func _on_obstacle_spawned() -> void:
	_obstacles_seen += 1
	if _obstacles_seen % obstacles_per_attack == 0 and not _attacking:
		_attack()


func _attack() -> void:
	_attacking = true
	for i in flashes:
		sprite.self_modulate = flash_color
		await get_tree().create_timer(flash_time, false).timeout
		sprite.self_modulate = Color.WHITE
		await get_tree().create_timer(flash_time, false).timeout
	if is_instance_valid(_spawner) and _spawner.running:
		_spawner.add_projectile(laser_scene.instantiate(), global_position + muzzle_offset)
	_attacking = false
