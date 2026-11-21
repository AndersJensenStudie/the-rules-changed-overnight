extends Node

const DT := 1.0 / 60.0
const MAX_HORIZON := 120
const WAIT_STEPS := 90
const WAIT_STRIDE := 2

@export var laser_speed := 400.0
@export var laser_box := Vector2(24, 26)
@export var flap_offset := 8.0

var _main: Node
var _holding := false
var _press_frame := -1
var _release_frame := -1


func _ready() -> void:
	_main = get_parent()
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if not _main.bot_enabled:
		_release()
		return
	var player: CharacterBody2D = _main.player
	var mode: ModeSettings = _main.modes[_main.mode_index]
	if _holding and Engine.get_physics_frames() > _press_frame + 1:
		if mode.flight or player.velocity.y >= 0.0:
			_release()
	if _main.state != _main.State.RUNNING:
		return
	if mode.flight:
		_fly(player)
	else:
		_plan(player)


func _press() -> void:
	if Engine.get_physics_frames() <= _release_frame:
		return
	Input.action_press("jump")
	_holding = true
	_press_frame = Engine.get_physics_frames()


func _release() -> void:
	if _holding:
		Input.action_release("jump")
		_holding = false
		_release_frame = Engine.get_physics_frames()


func _fly(player: CharacterBody2D) -> void:
	if _holding:
		return
	var body: Rect2 = player.hitbox_rect()
	var target := 130.0
	var nearest := INF
	for obstacle in _main.spawner.get_children():
		if obstacle.has_signal("collected") or obstacle.is_queued_for_deletion():
			continue
		var x: float = obstacle.global_position.x
		if x + 16.0 < body.position.x - 2.0 or x >= nearest:
			continue
		nearest = x
		if obstacle.is_in_group("pipe_pair"):
			target = obstacle.get_meta("gap_center")
		elif obstacle.has_signal("passed_over"):
			target = obstacle.global_position.y - 32.0
		else:
			target = 120.0
	if body.get_center().y > target + flap_offset and player.velocity.y >= 0.0:
		_press()


func _plan(player: CharacterBody2D) -> void:
	if _holding or not player.is_on_floor():
		return
	var body: Rect2 = player.hitbox_rect()
	var threats := _threats(body)
	var airtime := _airtime_steps(player)
	if _safe(-1.0, threats, body, player, airtime + 2):
		if _jump_clears_moon(threats, body, player, airtime + 2):
			_press()
		return
	for step in range(0, WAIT_STEPS, WAIT_STRIDE):
		if _safe(step * DT, threats, body, player, step + airtime + 2):
			if step == 0:
				_press()
			return
	_press()


func _threats(body: Rect2) -> Array:
	var spawner: Node = _main.spawner
	var threats := []
	for obstacle in spawner.get_children():
		if obstacle.has_signal("collected") or obstacle.is_queued_for_deletion():
			continue
		var rect := _rect_of(obstacle)
		if rect.size == Vector2.ZERO or rect.end.x < body.position.x - 2.0:
			continue
		var velocity: float = spawner.speed
		if "laser_speed" in obstacle:
			velocity = obstacle.laser_speed * spawner.world_time_scale
		elif "extra_speed" in obstacle:
			velocity += obstacle.extra_speed
		elif "walk_speed" in obstacle and not obstacle._squashed:
			velocity += obstacle.walk_speed
		threats.append([rect, velocity, 0.0, obstacle.has_signal("passed_over")])
	for decoration in _main.decorations.get_children():
		if decoration.has_method("time_until_fire") and decoration._attacking:
			var muzzle: Vector2 = decoration.global_position + decoration.muzzle_offset
			threats.append([Rect2(muzzle - laser_box / 2.0, laser_box), laser_speed * spawner.world_time_scale, decoration.time_until_fire(), false])
	return threats


func _rect_of(obstacle: Node) -> Rect2:
	var bounds := Rect2()
	var found := false
	for child in obstacle.get_children():
		var rect := Rect2()
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			rect = Rect2(child.global_position - child.shape.size / 2.0, child.shape.size)
		elif child is CollisionPolygon2D and child.polygon.size() > 0:
			rect = Rect2(child.polygon[0], Vector2.ZERO)
			for point in child.polygon:
				rect = rect.expand(point)
			rect.position += child.global_position
		else:
			continue
		bounds = rect if not found else bounds.merge(rect)
		found = true
	return bounds


func _airtime_steps(player: CharacterBody2D) -> int:
	var rise: float = -player.jump_velocity
	var to_peak: float = rise / player.jump_gravity
	var peak: float = rise * to_peak - 0.5 * player.jump_gravity * to_peak * to_peak
	var to_land := sqrt(2.0 * peak / player.fall_gravity)
	return mini(int((to_peak + to_land) / DT) + 1, MAX_HORIZON)


func _height(time: float, player: CharacterBody2D) -> float:
	if time < 0.0:
		return 0.0
	var rise: float = -player.jump_velocity
	var to_peak: float = rise / player.jump_gravity
	if time <= to_peak:
		return rise * time - 0.5 * player.jump_gravity * time * time
	var peak: float = rise * to_peak - 0.5 * player.jump_gravity * to_peak * to_peak
	var falling := time - to_peak
	return maxf(0.0, peak - 0.5 * player.fall_gravity * falling * falling)


func _body_at(step: int, jump_at: float, body: Rect2, player: CharacterBody2D) -> Rect2:
	var lift := _height(step * DT - jump_at, player) if jump_at >= 0.0 else 0.0
	return Rect2(body.position.x, body.position.y - lift, body.size.x, body.size.y)


func _threat_at(threat: Array, step: int) -> Rect2:
	var time: float = step * DT - threat[2]
	if time < 0.0:
		return Rect2()
	var rect: Rect2 = threat[0]
	rect.position.x -= threat[1] * time
	return rect


func _safe(jump_at: float, threats: Array, body: Rect2, player: CharacterBody2D, horizon: int) -> bool:
	for step in horizon:
		var player_rect := _body_at(step, jump_at, body, player)
		for threat in threats:
			var rect := _threat_at(threat, step)
			if rect.size != Vector2.ZERO and rect.intersects(player_rect):
				return false
	return true


func _jump_clears_moon(threats: Array, body: Rect2, player: CharacterBody2D, horizon: int) -> bool:
	var moons := threats.filter(func(threat: Array) -> bool: return threat[3])
	if moons.is_empty() or not _safe(0.0, threats, body, player, horizon):
		return false
	for moon in moons:
		var overlapped := false
		for step in horizon:
			var player_rect := _body_at(step, 0.0, body, player)
			var rect := _threat_at(moon, step)
			if rect.end.x < player_rect.position.x or rect.position.x > player_rect.end.x:
				continue
			if player_rect.end.y > rect.position.y:
				return false
			overlapped = true
		if overlapped:
			return true
	return false
