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

@onready var jump_velocity := -2.0 * jump_height / time_to_peak
@onready var jump_gravity := 2.0 * jump_height / (time_to_peak * time_to_peak)
@onready var fall_gravity := 2.0 * jump_height / (time_to_fall * time_to_fall)

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var screen_size: Vector2
var jump_sounds: Array[AudioStream] = []
var jump_player := AudioStreamPlayer.new()
var death_sounds: Array[AudioStream] = []
var death_player := AudioStreamPlayer.new()


func _ready() -> void:
	add_to_group("player")
	$AnimatedSprite2D.play()
	screen_size = get_viewport_rect().size
	jump_sounds = _load_sounds(jump_sounds_dir)
	death_sounds = _load_sounds(death_sounds_dir)
	_setup_player(jump_player, jump_volume_db)
	_setup_player(death_player, death_volume_db)


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
