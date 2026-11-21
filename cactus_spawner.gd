extends Node2D

signal player_hit(obstacle: Node2D)
signal moon_passed
signal coin_collected
signal mushroom_collected
signal obstacle_spawned
signal hourglass_collected
signal feather_collected

@export var default_mode: ModeSettings = preload("res://assets/modes/earth.tres")
@export var obstacle_scene: PackedScene = preload("res://obstacle.tscn")
@export var spawn_x := 280.0 
@export var cactus_width := 14.0  
@export var min_gap_pixels := 90.0 
@export var max_group_size := 3
@export var night_scene: PackedScene = preload("res://night.tscn")
@export var night_every := 10
@export var night_width := 28.0
@export var asteroid_scene: PackedScene = preload("res://asteroid.tscn")
@export var max_asteroid_group_size := 2
@export var asteroid_spacing := 2.0
@export var floor_y := 242.0
@export var low_air_bottom_y := 214.0
@export var high_air_bottom_y_range := Vector2(132.0, 152.0)
@export var ground_band_weight := 0.5
@export var low_air_band_weight := 0.3
@export var high_air_band_weight := 0.2
@export var pipe_scene: PackedScene = preload("res://pipe.tscn")
@export var coin_scene: PackedScene = preload("res://coin.tscn")
@export var mushroom_scene: PackedScene = preload("res://mushroom.tscn")
@export var mushroom_chance := 1.0 / 3.0
@export var pipe_height_range := Vector2(30.0, 60.0)
@export var coin_above_pipe_chance := 0.5
@export var coin_arc_chance := 0.4
@export var coin_above_pipe_offset := 14.0
@export var coin_arc_heights: Array[float] = [34.0, 50.0, 34.0]
@export var coin_arc_spacing := 18.0
@export var ceiling_y := 0.0
@export var pipe_pair_gap := 70.0
@export var pipe_pair_center_range := Vector2(60.0, 195.0)
@export var pipe_pair_max_shift := 60.0
@export var player_x := 40.0
@export var flyer_scene: PackedScene = preload("res://flyer.tscn")
@export var flyer_low_y := 230.0
@export var flyer_high_y := 204.0
@export var flyer_width := 24.0
@export var goomba_scene: PackedScene = preload("res://goomba.tscn")
@export var goomba_chance := 1.0 / 3.0
@export var goomba_width := 14.0
@export var hourglass_scene: PackedScene = preload("res://hourglass.tscn")
@export var hourglass_chance := 0.1
@export var hourglass_margin := 8.0
@export var hourglass_half_height := 10.0
@export var hourglass_min_y := 30.0
@export var feather_scene: PackedScene = preload("res://feather.tscn")
@export var feather_chance := 0.125
@export var feather_height_spread := 10.0

var speed := 0.0:
	set(value):
		speed = value
		for cactus in get_children():
			cactus.speed = value

var running := false
var mode: ModeSettings
var _distance_to_next := 0.0
var _rolls_since_night := 0
var _last_gap_center := 130.0
var _spawned_total := 0
var world_time_scale := 1.0


func start() -> void:
	running = true
	_distance_to_next = 0.0


func stop() -> void:
	running = false


func apply_mode(settings: ModeSettings) -> void:
	mode = settings


func _ready() -> void:
	add_to_group("spawner")
	if mode == null:
		apply_mode(default_mode)


func _physics_process(delta: float) -> void:
	if not running:
		return
	_distance_to_next -= speed * delta
	if _distance_to_next <= 0.0:
		var group_width := _spawn_group()
		_spawned_total += 1
		obstacle_spawned.emit()
		var gap := randf_range(speed * mode.min_gap_seconds, speed * mode.max_gap_seconds)
		_distance_to_next = maxf(gap, min_gap_pixels) + group_width

func _spawn_group() -> float:
	_rolls_since_night += 1
	if _rolls_since_night >= night_every:
		_rolls_since_night = 0
		return _spawn_night()

	if mode.flyer_chance > 0.0 and _spawned_total >= mode.flyer_min_obstacles and randf() < mode.flyer_chance:
		return _spawn_flyer()

	match mode.obstacles:
		ModeSettings.Obstacles.ASTEROIDS:
			return _spawn_asteroids()
		ModeSettings.Obstacles.PIPES:
			return _spawn_pipe()
		ModeSettings.Obstacles.PIPE_PAIRS:
			return _spawn_pipe_pair()
	return _spawn_cacti()


func _spawn_night() -> float:
	var y := randf_range(mode.night_y_range.x, mode.night_y_range.y)
	var night := _spawn(night_scene, Vector2(spawn_x, y))
	night.passed_over.connect(moon_passed.emit)
	return night_width


func _spawn_flyer() -> float:
	var flyer := flyer_scene.instantiate()
	var y := flyer_low_y if randf() < 0.5 else flyer_high_y
	var x := spawn_x
	if speed > 0.0:
		x = player_x + (spawn_x - player_x) * (speed + flyer.extra_speed) / speed
	_add_obstacle(flyer, Vector2(x, y))
	return flyer_width


func _spawn_cacti() -> float:
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
	var count := randi_range(1, max_asteroid_group_size)
	var bottom_y := _pick_band_bottom()
	var x := spawn_x
	var tallest := 0.0
	for i in count:
		var asteroid := _spawn(asteroid_scene, Vector2(x, 0.0))
		var extent: Rect2 = asteroid.extent
		asteroid.global_position = Vector2(x - extent.position.x, bottom_y - extent.end.y)
		x += extent.size.x + asteroid_spacing
		tallest = maxf(tallest, extent.size.y)
	if randf() < hourglass_chance:
		_spawn_hourglass((spawn_x + x) / 2.0, bottom_y - tallest, bottom_y)
	return x - spawn_x


func _spawn_hourglass(center_x: float, top_y: float, bottom_y: float) -> void:
	var options: Array[float] = [maxf(top_y - hourglass_margin - hourglass_half_height, hourglass_min_y)]
	var below := bottom_y + hourglass_margin + hourglass_half_height
	if below + hourglass_half_height <= floor_y - 2.0:
		options.append(below)
	_spawn_pickup(hourglass_scene, Vector2(center_x, options.pick_random()), hourglass_collected)


func _spawn_pipe() -> float:
	var pipe := pipe_scene.instantiate()
	pipe.height = randf_range(pipe_height_range.x, pipe_height_range.y)
	var center_x: float = spawn_x + pipe.width / 2.0
	_add_obstacle(pipe, Vector2(center_x, floor_y))
	var roll := randf()
	if roll < coin_above_pipe_chance:
		var above := Vector2(center_x, floor_y - pipe.height - coin_above_pipe_offset)
		if randf() < mushroom_chance:
			_spawn_pickup(mushroom_scene, above, mushroom_collected)
		else:
			_spawn_coin(above)
	elif roll < coin_above_pipe_chance + coin_arc_chance:
		var arc_center: float = spawn_x + pipe.width + speed * mode.min_gap_seconds / 2.0
		var first := arc_center - coin_arc_spacing * (coin_arc_heights.size() - 1) / 2.0
		for i in coin_arc_heights.size():
			_spawn_coin(Vector2(first + i * coin_arc_spacing, floor_y - coin_arc_heights[i]))
	if randf() < goomba_chance:
		var goomba := goomba_scene.instantiate()
		var goomba_x: float = spawn_x + pipe.width + (speed + goomba.walk_speed) * mode.min_gap_seconds
		_add_obstacle(goomba, Vector2(goomba_x, floor_y))
		return goomba_x - spawn_x + goomba_width
	return pipe.width


func _spawn_pipe_pair() -> float:
	var low := maxf(pipe_pair_center_range.x, _last_gap_center - pipe_pair_max_shift)
	var high := minf(pipe_pair_center_range.y, _last_gap_center + pipe_pair_max_shift)
	var center := randf_range(low, high)
	_last_gap_center = center
	var bottom := pipe_scene.instantiate()
	bottom.height = floor_y - (center + pipe_pair_gap / 2.0)
	bottom.solid_top = false
	var top := pipe_scene.instantiate()
	top.height = (center - pipe_pair_gap / 2.0) - ceiling_y
	top.solid_top = false
	top.flipped = true
	var center_x: float = spawn_x + bottom.width / 2.0
	for pipe in [bottom, top]:
		pipe.add_to_group("pipe_pair")
		pipe.set_meta("gap_center", center)
	_add_obstacle(bottom, Vector2(center_x, floor_y))
	_add_obstacle(top, Vector2(center_x, ceiling_y))
	if randf() < feather_chance:
		var feather_y := center + randf_range(-feather_height_spread, feather_height_spread)
		_spawn_pickup(feather_scene, Vector2(center_x, feather_y), feather_collected)
	return bottom.width


func clear_pipe_pairs_ahead(x: float) -> void:
	for pipe in get_tree().get_nodes_in_group("pipe_pair"):
		if pipe.get_parent() == self and pipe.global_position.x - pipe.width / 2.0 > x:
			pipe.queue_free()


func _spawn_coin(pos: Vector2) -> void:
	_spawn_pickup(coin_scene, pos, coin_collected)


func _spawn_pickup(scene: PackedScene, pos: Vector2, on_collected: Signal) -> void:
	var pickup := scene.instantiate()
	pickup.collected.connect(on_collected.emit)
	_add_obstacle(pickup, pos)


func resume() -> void:
	running = true


func _pick_band_bottom() -> float:
	var total := ground_band_weight + low_air_band_weight + high_air_band_weight
	var roll := randf() * total
	if roll < ground_band_weight:
		return floor_y
	if roll < ground_band_weight + low_air_band_weight:
		return low_air_bottom_y
	return randf_range(high_air_bottom_y_range.x, high_air_bottom_y_range.y)


func _spawn(scene: PackedScene, pos: Vector2) -> Node2D:
	return _add_obstacle(scene.instantiate(), pos)


func _add_obstacle(obstacle: Node2D, pos: Vector2) -> Node2D:
	obstacle.speed = speed
	add_child(obstacle)
	obstacle.global_position = pos
	obstacle.hit.connect(player_hit.emit)
	return obstacle


func add_projectile(projectile: Node2D, pos: Vector2) -> void:
	_add_obstacle(projectile, pos)


func clear() -> void:
	for cactus in get_children():
		cactus.queue_free()
