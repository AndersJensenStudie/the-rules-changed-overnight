extends Node2D

enum State { READY, RUNNING, OVER }
enum Mode { EARTH, MOON }

@export var start_speed := 120.0
@export var max_speed := 320.0
@export var acceleration := 4.0
@export var restart_delay := 0.4
@export var backdrop_fade_time := 0.3
@export var moon_label_color := Color(0.85, 0.85, 0.9)

var state := State.READY
var mode := Mode.EARTH
var speed := 0.0
var _over_time := 0.0
var _backdrop_tween: Tween
var _earth_label_color: Color

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $CactusSpawner
@onready var ground: Node2D = $Ground
@onready var message_label: Label = $HUD/MessageLabel
@onready var backdrop: Sprite2D = $Backdrop


func _ready() -> void:
	spawner.player_hit.connect(_game_over)
	spawner.moon_passed.connect(_on_moon_passed)
	_earth_label_color = message_label.get_theme_color("font_color")
	Music.set_moon(false)
	player.idle()
	message_label.text = "Press SPACE to start"


func _process(delta: float) -> void:
	match state:
		State.READY:
			if Input.is_action_just_pressed("jump"):
				_start()
		State.RUNNING:
			speed = minf(speed + acceleration * delta, max_speed)
			spawner.speed = speed
			ground.speed = speed
		State.OVER:
			_over_time += delta
			if _over_time > restart_delay and Input.is_action_just_pressed("jump"):
				get_tree().reload_current_scene()


func _start() -> void:
	state = State.RUNNING
	speed = start_speed
	message_label.text = ""
	player.run()
	spawner.start()


func _on_moon_passed() -> void:
	if state != State.RUNNING:
		return
	_set_mode(Mode.EARTH if mode == Mode.MOON else Mode.MOON)


func enter_moon_mode() -> void:
	if state == State.RUNNING:
		_set_mode(Mode.MOON)


func _set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	var on := mode == Mode.MOON
	player.set_moon(on)
	spawner.set_moon(on)
	ground.set_moon(on)
	message_label.add_theme_color_override("font_color", moon_label_color if on else _earth_label_color)
	if _backdrop_tween:
		_backdrop_tween.kill()
	if not backdrop.visible:
		backdrop.modulate.a = 0.0
	backdrop.visible = true
	_backdrop_tween = create_tween()
	_backdrop_tween.tween_property(backdrop, "modulate:a", 1.0 if on else 0.0, backdrop_fade_time)
	if not on:
		_backdrop_tween.tween_callback(backdrop.hide)
	Music.set_moon(on)


func _game_over() -> void:
	if state != State.RUNNING:
		return
	state = State.OVER
	_over_time = 0.0
	speed = 0.0
	spawner.stop()
	spawner.speed = 0.0
	ground.speed = 0.0
	player.die()
	message_label.text = "GAME OVER\nPress SPACE to restart"
