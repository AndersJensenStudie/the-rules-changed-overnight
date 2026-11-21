class_name ModeSettings
extends Resource

enum Obstacles { CACTI, ASTEROIDS, PIPES, PIPE_PAIRS }

@export var mode_name := ""
@export_group("Jump")
@export var jump_height := 84.0
@export var time_to_peak := 0.25
@export var time_to_fall := 0.26
@export_group("Player")
@export var sprite_frames: SpriteFrames
@export var sprite_position := Vector2(4, -1)
@export var run_animation := &"walk"
@export var hitbox_size := Vector2(24, 26)
@export var hitbox_rects: Array[Rect2] = []
@export_dir var jump_sounds_dir := "res://assets/sounds/jump_sounds"
@export_dir var death_sounds_dir := "res://assets/sounds/death"
@export_group("Obstacles")
@export var obstacles := Obstacles.CACTI
@export var min_gap_seconds := 0.8
@export var max_gap_seconds := 1.8
@export var night_y_range := Vector2(200.0, 200.0)
@export_group("Flight")
@export var flight := false
@export var flap_velocity := 190.0
@export var flap_stack_boost := 0.0
@export var max_rise_speed := 190.0
@export var flight_gravity := 700.0
@export var max_fall_speed := 300.0
@export var floor_kills := false
@export var entry_hover_time := 0.5
@export var flap_tilt_degrees := -25.0
@export var dive_tilt_degrees := 70.0
@export var dive_tilt_speed := 200.0
@export_group("Look")
@export var backdrop: Texture2D
@export var backdrop_frames: SpriteFrames
@export var decorations: Array[PackedScene] = []
@export var ground_color := Color(0.33, 0.33, 0.33)
@export var label_color := Color(0.33, 0.33, 0.33)
@export_group("Sound")
@export var music: AudioStream
@export var ambient: AudioStream
