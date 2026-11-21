extends CharacterBody2D

signal revived
signal hit_ground

@export var speed := 300.0

@export var default_mode: ModeSettings = preload("res://assets/modes/earth.tres")
@export var feet_y := 15.0
@export var jump_cut := 0.5 
@export var coyote_time := 0.1  
@export var jump_buffer_time := 0.1
@export var jump_volume_db := 12.0
@export var death_volume_db := 8.0
@export var blink_interval := 0.1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: CollisionShape2D = $CollisionShape2D

var jump_velocity := 0.0
var jump_gravity := 0.0
var fall_gravity := 0.0
var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var screen_size: Vector2
var jump_sounds: Array[AudioStream] = []
var jump_player := AudioStreamPlayer.new()
var death_sounds: Array[AudioStream] = []
var death_player := AudioStreamPlayer.new()
var mode: ModeSettings
var _home_x := 0.0
var _sound_cache := {}
var _invincible_time := 0.0
var _hover_time := 0.0


func _ready() -> void:
	add_to_group("player")
	$AnimatedSprite2D.play()
	screen_size = get_viewport_rect().size
	_home_x = position.x
	_setup_player(jump_player, jump_volume_db)
	_setup_player(death_player, death_volume_db)
	hitbox.shape = hitbox.shape.duplicate()
	apply_mode(default_mode)


func _recalc_jump(height: float, to_peak: float, to_fall: float) -> void:
	jump_velocity = -2.0 * height / to_peak
	jump_gravity = 2.0 * height / (to_peak * to_peak)
	fall_gravity = 2.0 * height / (to_fall * to_fall)


func apply_mode(settings: ModeSettings) -> void:
	if settings == mode:
		return
	mode = settings
	_recalc_jump(settings.jump_height, settings.time_to_peak, settings.time_to_fall)
	var animation := &"die" if sprite.animation == &"die" else settings.run_animation
	var playing := sprite.is_playing()
	sprite.sprite_frames = settings.sprite_frames
	sprite.position = settings.sprite_position
	sprite.animation = animation
	if playing:
		sprite.play()
	sprite.rotation = 0.0
	_hover_time = 0.0
	if settings.flight:
		velocity.y = 0.0
		_hover_time = settings.entry_hover_time
	hitbox.shape.size = settings.hitbox_size
	hitbox.position.y = feet_y - settings.hitbox_size.y / 2.0
	jump_sounds = _sounds_in(settings.jump_sounds_dir)
	death_sounds = _sounds_in(settings.death_sounds_dir)


func hitbox_rect() -> Rect2:
	var size: Vector2 = hitbox.shape.size
	return Rect2(hitbox.global_position - size / 2.0, size)


func _sounds_in(dir: String) -> Array[AudioStream]:
	if _sound_cache.has(dir):
		return _sound_cache[dir]
	var sounds: Array[AudioStream] = []
	for file in ResourceLoader.list_directory(dir):
		var stream := load(dir.path_join(file)) as AudioStream
		if stream:
			sounds.append(stream)
	_sound_cache[dir] = sounds
	return sounds


func _setup_player(audio_player: AudioStreamPlayer, volume_db: float) -> void:
	audio_player.volume_db = volume_db
	audio_player.bus = &"SFX"
	add_child(audio_player)


func idle() -> void:
	sprite.animation = mode.run_animation
	sprite.stop()
	sprite.frame = 0


func run() -> void:
	sprite.play(mode.run_animation)


func revive() -> void:
	velocity = Vector2.ZERO
	set_physics_process(false)
	sprite.play_backwards("die")
	await sprite.animation_finished
	set_physics_process(true)
	sprite.play(mode.run_animation)
	if mode.flight:
		_hover_time = mode.entry_hover_time
	revived.emit()


func start_invincibility(duration: float) -> void:
	_invincible_time = duration


func is_invincible() -> bool:
	return _invincible_time > 0.0


func _process(delta: float) -> void:
	if _invincible_time <= 0.0:
		return
	_invincible_time -= delta
	if _invincible_time <= 0.0:
		sprite.visible = true
	else:
		sprite.visible = fmod(_invincible_time, blink_interval * 2.0) > blink_interval


func die() -> void:
	$AnimatedSprite2D.play("die")
	_play_random(death_player, death_sounds)
	velocity = Vector2.ZERO
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if mode.flight:
		_fly(delta)
		return
	if not is_on_floor():
		var g := jump_gravity if velocity.y < 0.0 else fall_gravity
		velocity.y += g * delta

	if is_on_floor():
		coyote_timer = coyote_time
	else:
		coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer -= delta

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_play_random(jump_player, jump_sounds)

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	move_and_slide()
	position.x = _home_x


func _fly(delta: float) -> void:
	if _hover_time > 0.0:
		_hover_time -= delta
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + mode.flight_gravity * delta, mode.max_fall_speed)
	if Input.is_action_just_pressed("jump"):
		_hover_time = 0.0
		velocity.y = -mode.flap_velocity
		sprite.rotation_degrees = mode.flap_tilt_degrees
		_play_random(jump_player, jump_sounds)
	elif velocity.y > 0.0:
		sprite.rotation_degrees = move_toward(sprite.rotation_degrees, mode.dive_tilt_degrees, mode.dive_tilt_speed * delta)
	move_and_slide()
	position.x = _home_x
	if mode.floor_kills and is_on_floor() and not is_invincible():
		hit_ground.emit()


func _play_random(audio_player: AudioStreamPlayer, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	audio_player.stream = sounds.pick_random()
	audio_player.play()
