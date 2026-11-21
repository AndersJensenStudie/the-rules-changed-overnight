extends Node2D

signal player_hit
signal moon_passed

@export var obstacle_scene: PackedScene = preload("res://obstacle.tscn")
@export var spawn_x := 280.0 
@export var cactus_width := 14.0  
@export var min_gap_seconds := 0.8 
@export var max_gap_seconds := 1.8 
@export var min_gap_pixels := 90.0 
@export var max_group_size := 3
@export var night_scene: PackedScene = preload("res://night.tscn")
@export var night_chance := 0.2
@export var night_y := 200.0
@export var night_min_speed := 200.0
@export var night_width := 28.0
@export var asteroid_scene: PackedScene = preload("res://asteroid.tscn")
@export var moon_min_gap_seconds := 1.4
@export var moon_max_gap_seconds := 2.4
@export var moon_max_group_size := 2
@export var asteroid_spacing := 2.0
@export var floor_y := 242.0
@export var low_air_bottom_y := 214.0
@export var high_air_bottom_y_range := Vector2(132.0, 152.0)
@export var ground_band_weight := 0.5
@export var low_air_band_weight := 0.3
@export var high_air_band_weight := 0.2

var speed := 0.0:
	set(value):
		speed = value
		for cactus in get_children():
			cactus.speed = value

var running := false
var moon := false
var _distance_to_next := 0.0


func start() -> void:
	running = true
	_distance_to_next = 0.0


func stop() -> void:
	running = false


func set_moon(on: bool) -> void:
	moon = on


func _physics_process(delta: float) -> void:
	if not running:
		return
	_distance_to_next -= speed * delta
	if _distance_to_next <= 0.0:
		var group_width := _spawn_group()
		var gap_range := Vector2(moon_min_gap_seconds, moon_max_gap_seconds) if moon else Vector2(min_gap_seconds, max_gap_seconds)
		var gap := randf_range(speed * gap_range.x, speed * gap_range.y)
		_distance_to_next = maxf(gap, min_gap_pixels) + group_width

func _spawn_group() -> float:
	if speed >= night_min_speed and randf() < night_chance:
		var night := _spawn(night_scene, Vector2(spawn_x, night_y))
		night.passed_over.connect(moon_passed.emit)
		return night_width

	if moon:
		return _spawn_asteroids()

	var allowed := 1
	if speed > 160.0:
		allowed = 2
	if speed > 220.0:
		allowed = max_group_size
	var count := randi_range(1, allowed)

	for i in count:
		_spawn(obstacle_scene, Vector2(spawn_x + i * cactus_width, global_position.y))
	return count * cactus_width


func _spawn_asteroids() -> float:
	var count := randi_range(1, moon_max_group_size)
	var bottom_y := _pick_band_bottom()
	var x := spawn_x
	for i in count:
		var asteroid := _spawn(asteroid_scene, Vector2(x, 0.0))
		var extent: Rect2 = asteroid.extent
		asteroid.global_position = Vector2(x - extent.position.x, bottom_y - extent.end.y)
		x += extent.size.x + asteroid_spacing
	return x - spawn_x


func _pick_band_bottom() -> float:
	var total := ground_band_weight + low_air_band_weight + high_air_band_weight
	var roll := randf() * total
	if roll < ground_band_weight:
		return floor_y
	if roll < ground_band_weight + low_air_band_weight:
		return low_air_bottom_y
	return randf_range(high_air_bottom_y_range.x, high_air_bottom_y_range.y)


func _spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	var obstacle := scene.instantiate()
	obstacle.speed = speed
	add_child(obstacle)
	obstacle.global_position = pos
	obstacle.hit.connect(player_hit.emit)
	return obstacle


func clear() -> void:
	for cactus in get_children():
		cactus.queue_free()
