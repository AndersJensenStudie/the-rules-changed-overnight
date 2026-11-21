extends CharacterBody2D

@export var speed := 300.0

@export var jump_height := 84.0
@export var time_to_peak := 0.25
@export var time_to_fall := 0.26
@export var jump_cut := 0.5 
@export var coyote_time := 0.1  
@export var jump_buffer_time := 0.1
@export var jump_volume_db := 12.0
@export_dir var jump_sounds_dir := "res://assets/sounds/jump_sounds"
@export var death_volume_db := 8.0
@export_dir var death_sounds_dir := "res://assets/sounds/death"
@export var moon_jump_height := 135.0
@export var moon_time_to_peak := 0.6
@export var moon_time_to_fall := 0.65
@export var moon_frames: SpriteFrames = preload("res://assets/animations/spaceman_frames.tres")
@export var moon_sprite_position := Vector2(0, 2)
@export var moon_hitbox_size := Vector2(10, 26)

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
var moon := false
var _earth_frames: SpriteFrames
var _earth_sprite_position: Vector2
var _earth_hitbox_size: Vector2


func _ready() -> void:
	add_to_group("player")
	$AnimatedSprite2D.play()
	screen_size = get_viewport_rect().size
	jump_sounds = _load_sounds(jump_sounds_dir)
	death_sounds = _load_sounds(death_sounds_dir)
	_setup_player(jump_player, jump_volume_db)
	_setup_player(death_player, death_volume_db)
	hitbox.shape = hitbox.shape.duplicate()
	_earth_frames = sprite.sprite_frames
	_earth_sprite_position = sprite.position
	_earth_hitbox_size = hitbox.shape.size
	_recalc_jump(jump_height, time_to_peak, time_to_fall)


func _recalc_jump(height: float, to_peak: float, to_fall: float) -> void:
	jump_velocity = -2.0 * height / to_peak
	jump_gravity = 2.0 * height / (to_peak * to_peak)
	fall_gravity = 2.0 * height / (to_fall * to_fall)


func set_moon(on: bool) -> void:
	if on == moon:
		return
	moon = on
	var animation := sprite.animation
	var playing := sprite.is_playing()
	if on:
		_recalc_jump(moon_jump_height, moon_time_to_peak, moon_time_to_fall)
		sprite.sprite_frames = moon_frames
		sprite.position = moon_sprite_position
		hitbox.shape.size = moon_hitbox_size
	else:
		_recalc_jump(jump_height, time_to_peak, time_to_fall)
		sprite.sprite_frames = _earth_frames
		sprite.position = _earth_sprite_position
		hitbox.shape.size = _earth_hitbox_size
	sprite.animation = animation
	if playing:
		sprite.play()


func hitbox_rect() -> Rect2:
	var size: Vector2 = hitbox.shape.size
	return Rect2(hitbox.global_position - size / 2.0, size)


func _load_sounds(dir: String) -> Array[AudioStream]:
	var sounds: Array[AudioStream] = []
	for file in ResourceLoader.list_directory(dir):
		var stream := load(dir.path_join(file)) as AudioStream
		if stream:
			sounds.append(stream)
	return sounds


func _setup_player(audio_player: AudioStreamPlayer, volume_db: float) -> void:
	audio_player.volume_db = volume_db
	audio_player.bus = &"SFX"
	add_child(audio_player)


func idle() -> void:
	$AnimatedSprite2D.animation = &"walk"
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = 0


func run() -> void:
	$AnimatedSprite2D.play("walk")


func die() -> void:
	$AnimatedSprite2D.play("die")
	_play_random(death_player, death_sounds)
	velocity = Vector2.ZERO
	set_physics_process(false)


func _physics_process(delta: float) -> void:
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


func _play_random(audio_player: AudioStreamPlayer, sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	audio_player.stream = sounds.pick_random()
	audio_player.play()
