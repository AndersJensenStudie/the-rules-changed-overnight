extends Node2D

enum State { READY, RUNNING, OVER }

@export var start_speed := 120.0
@export var max_speed := 320.0
@export var acceleration := 4.0
@export var restart_delay := 0.4

var state := State.READY
var speed := 0.0
var _over_time := 0.0

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $CactusSpawner
@onready var ground: Node2D = $Ground
@onready var message_label: Label = $HUD/MessageLabel


func _ready() -> void:
	spawner.player_hit.connect(_game_over)
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
