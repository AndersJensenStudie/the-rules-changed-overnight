extends Node2D

signal player_hit

@export var obstacle_scene: PackedScene = preload("res://obstacle.tscn")
@export var spawn_x := 280.0 
@export var cactus_width := 14.0  
@export var min_gap_seconds := 0.8 
@export var max_gap_seconds := 1.8 
@export var min_gap_pixels := 90.0 
@export var max_group_size := 3
@export var night_scene: PackedScene = preload("res://night.tscn")
@export var night_chance := 0.01
@export var night_y := 200.0
@export var night_min_speed := 200.0
@export var night_width := 28.0

var speed := 0.0:
	set(value):
		speed = value
		for cactus in get_children():
			cactus.speed = value

var running := false
var _distance_to_next := 0.0


func start() -> void:
	running = true
	_distance_to_next = 0.0


func stop() -> void:
	running = false


func _physics_process(delta: float) -> void:
	if not running:
		return
	_distance_to_next -= speed * delta
	if _distance_to_next <= 0.0:
		var group_width := _spawn_group()
		var gap := randf_range(speed * min_gap_seconds, speed * max_gap_seconds)
		_distance_to_next = maxf(gap, min_gap_pixels) + group_width

func _spawn_group() -> float:
	if speed >= night_min_speed and randf() < night_chance:
		_spawn(night_scene, Vector2(spawn_x, night_y))
		return night_width

	var allowed := 1
	if speed > 160.0:
		allowed = 2
	if speed > 220.0:
		allowed = max_group_size
	var count := randi_range(1, allowed)

	for i in count:
		_spawn(obstacle_scene, Vector2(spawn_x + i * cactus_width, global_position.y))
	return count * cactus_width


func _spawn(scene: PackedScene, pos: Vector2) -> void:
	var obstacle := scene.instantiate()
	obstacle.speed = speed
	add_child(obstacle)
	obstacle.global_position = pos
	obstacle.hit.connect(player_hit.emit)


func clear() -> void:
	for cactus in get_children():
		cactus.queue_free()
