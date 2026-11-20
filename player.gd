extends CharacterBody2D

@export var speed := 300.0

@export var jump_height := 84.0
@export var time_to_peak := 0.25
@export var time_to_fall := 0.26
@export var jump_cut := 0.5 
@export var coyote_time := 0.1  
@export var jump_buffer_time := 0.1

@onready var jump_velocity := -2.0 * jump_height / time_to_peak
@onready var jump_gravity := 2.0 * jump_height / (time_to_peak * time_to_peak)
@onready var fall_gravity := 2.0 * jump_height / (time_to_fall * time_to_fall)

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var screen_size: Vector2


func _ready() -> void:
	add_to_group("player")
	$AnimatedSprite2D.play()
	screen_size = get_viewport_rect().size


func idle() -> void:
	$AnimatedSprite2D.animation = &"walk"
	$AnimatedSprite2D.stop()
	$AnimatedSprite2D.frame = 0


func run() -> void:
	$AnimatedSprite2D.play("walk")


func die() -> void:
	$AnimatedSprite2D.play("die")
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

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut

	move_and_slide()
