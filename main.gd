extends Node2D

enum State { READY, RUNNING, REVIVING, OVER }

const HIGH_SCORE_PATH := "user://highscore.save"

@export var start_speed := 200.0
@export var max_speed := 320.0
@export var acceleration := 4.0
@export var acceleration_delay := 5.0
@export var restart_delay := 0.4
@export var backdrop_fade_time := 0.3
@export var score_per_second := 1.0
@export var coin_score := 10
@export_dir var coin_sounds_dir := "res://assets/sounds/coins"
@export var popup_color := Color(1.0, 0.8, 0.1)
@export var popup_outline_color := Color(0.35, 0.22, 0.0)
@export var popup_time := 0.8
@export var popup_rise := 6.0
@export var reset_hold_time := 5.0
@export var max_lives := 1
@export var invincible_time := 1.5
@export var hp_color := Color(0.35, 0.8, 0.2)
@export var hp_outline_color := Color(0.05, 0.25, 0.0)
@export var hp_gap := 6.0
@export var modes: Array[ModeSettings] = [
	preload("res://assets/modes/earth.tres"),
	preload("res://assets/modes/moon.tres"),
	preload("res://assets/modes/mario.tres"),
	preload("res://assets/modes/flappy.tres"),
]

var state := State.READY
var mode_index := -1
var coins := 0
var score := 0.0
var high_score := 0
var lives := 0
var coin_sounds: Array[AudioStream] = []
var _reset_hold := 0.0
var speed := 0.0
var _run_time := 0.0
var _over_time := 0.0
var _backdrop_tween: Tween
var _still_backdrops := {}

@onready var player: CharacterBody2D = $Player
@onready var spawner: Node2D = $CactusSpawner
@onready var ground: Node2D = $Ground
@onready var message_label: Label = $HUD/MessageLabel
@onready var backdrop: AnimatedSprite2D = $Backdrop
@onready var decorations: Node2D = $Decorations
@onready var coin_sound: AudioStreamPlayer = $CoinSound
@onready var hit_sound: AudioStreamPlayer = $HitSound
@onready var score_label: Label = $HUD/ScoreLabel
@onready var high_score_label: Label = $HUD/HighScoreLabel
@onready var hp_label: Label = $HUD/HPLabel


func _ready() -> void:
	spawner.player_hit.connect(_game_over)
	player.hit_ground.connect(_game_over)
	spawner.moon_passed.connect(_on_moon_passed)
	spawner.coin_collected.connect(_on_coin_collected)
	for file in ResourceLoader.list_directory(coin_sounds_dir):
		var stream := load(coin_sounds_dir.path_join(file)) as AudioStream
		if stream:
			coin_sounds.append(stream)
	spawner.mushroom_collected.connect(_on_mushroom_collected)
	hp_label.add_theme_color_override("font_color", hp_color)
	hp_label.add_theme_color_override("font_outline_color", hp_outline_color)
	hp_label.add_theme_constant_override("outline_size", 2)
	high_score = _load_high_score()
	_update_score_labels()
	_set_mode(0, true)
	player.idle()
	message_label.text = "Press SPAcE to start"


func _process(delta: float) -> void:
	_check_high_score_reset(delta)
	match state:
		State.READY:
			if Input.is_action_just_pressed("jump"):
				_start()
		State.RUNNING:
			_run_time += delta
			if _run_time > acceleration_delay:
				speed = minf(speed + acceleration * delta, max_speed)
			spawner.speed = speed
			ground.speed = speed
			_add_score(score_per_second * delta)
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
	var others := range(modes.size()).filter(func(i: int) -> bool: return i != mode_index)
	_set_mode(others.pick_random())


func _on_coin_collected() -> void:
	coins += 1
	if not coin_sounds.is_empty():
		coin_sound.stream = coin_sounds.pick_random()
		coin_sound.play()
	_add_score(coin_score)
	_show_popup("+%d" % coin_score)


func _on_mushroom_collected() -> void:
	lives = mini(lives + 1, max_lives)
	_update_score_labels()


func _add_score(amount: float) -> void:
	score += amount
	if int(score) > high_score:
		high_score = int(score)
	_update_score_labels()


func _update_score_labels() -> void:
	score_label.text = "%05d" % int(score)
	high_score_label.text = "HI %05d" % high_score
	hp_label.text = "+%d HP" % lives if lives > 0 else ""
	var font := high_score_label.get_theme_font("font")
	var font_size := high_score_label.get_theme_font_size("font_size")
	var high_score_width := font.get_string_size(high_score_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	hp_label.position.x = high_score_label.position.x + high_score_label.size.x - high_score_width - hp_gap - hp_label.size.x


func _show_popup(text: String) -> void:
	var popup := Label.new()
	popup.text = text
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	popup.add_theme_font_size_override("font_size", 12)
	popup.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	popup.add_theme_color_override("font_color", popup_color)
	popup.add_theme_color_override("font_outline_color", popup_outline_color)
	popup.add_theme_constant_override("outline_size", 2)
	popup.position = Vector2(score_label.position.x, score_label.position.y + score_label.size.y)
	popup.size = Vector2(score_label.size.x, score_label.size.y)
	score_label.get_parent().add_child(popup)
	var tween := popup.create_tween().set_parallel()
	tween.tween_property(popup, "position:y", popup.position.y + popup_rise, popup_time)
	tween.tween_property(popup, "modulate:a", 0.0, popup_time).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(popup.queue_free)


func _check_high_score_reset(delta: float) -> void:
	if not Input.is_action_pressed("reset_high_score"):
		_reset_hold = 0.0
		return
	if _reset_hold >= reset_hold_time:
		return
	_reset_hold += delta
	if _reset_hold >= reset_hold_time:
		_reset_high_score()


func _reset_high_score() -> void:
	high_score = 0
	if FileAccess.file_exists(HIGH_SCORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(HIGH_SCORE_PATH))
	_update_score_labels()
	_show_popup("HI RESET")


func _load_high_score() -> int:
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.READ)
	if file == null:
		return 0
	return file.get_32()


func _save_high_score() -> void:
	var file := FileAccess.open(HIGH_SCORE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func _set_mode(index: int, instant := false) -> void:
	if index == mode_index:
		return
	var leaving_pipe_pairs := mode_index >= 0 and modes[mode_index].obstacles == ModeSettings.Obstacles.PIPE_PAIRS
	mode_index = index
	var settings := modes[index]
	if leaving_pipe_pairs and settings.obstacles != ModeSettings.Obstacles.PIPE_PAIRS:
		spawner.clear_pipe_pairs_ahead(player.hitbox_rect().end.x)
	player.apply_mode(settings)
	spawner.apply_mode(settings)
	ground.apply_mode(settings)
	for label in [message_label, score_label, high_score_label]:
		label.add_theme_color_override("font_color", settings.label_color)
	_show_backdrop(_backdrop_frames_for(settings), instant)
	_show_decorations(settings.decorations)
	Music.apply_mode(settings)


func _show_decorations(scenes: Array[PackedScene]) -> void:
	for child in decorations.get_children():
		child.queue_free()
	for scene in scenes:
		decorations.add_child(scene.instantiate())


func _backdrop_frames_for(settings: ModeSettings) -> SpriteFrames:
	if settings.backdrop_frames:
		return settings.backdrop_frames
	if settings.backdrop == null:
		return null
	if not _still_backdrops.has(settings.backdrop):
		var frames := SpriteFrames.new()
		frames.add_frame(&"default", settings.backdrop)
		_still_backdrops[settings.backdrop] = frames
	return _still_backdrops[settings.backdrop]


func _show_backdrop(frames: SpriteFrames, instant: bool) -> void:
	if _backdrop_tween:
		_backdrop_tween.kill()
	if frames and frames != backdrop.sprite_frames:
		backdrop.sprite_frames = frames
		backdrop.play(&"default")
	if instant:
		backdrop.visible = frames != null
		backdrop.modulate.a = 1.0
		return
	_backdrop_tween = create_tween()
	if frames:
		if not backdrop.visible:
			backdrop.modulate.a = 0.0
		backdrop.visible = true
		_backdrop_tween.tween_property(backdrop, "modulate:a", 1.0, backdrop_fade_time)
	elif backdrop.visible:
		_backdrop_tween.tween_property(backdrop, "modulate:a", 0.0, backdrop_fade_time)
		_backdrop_tween.tween_callback(backdrop.hide)


func _game_over(obstacle: Node2D = null) -> void:
	if state != State.RUNNING or player.is_invincible():
		return
	if obstacle and obstacle.hit_sound:
		hit_sound.stream = obstacle.hit_sound
		hit_sound.play()
	if lives > 0:
		_revive()
		return
	state = State.OVER
	_over_time = 0.0
	speed = 0.0
	spawner.stop()
	spawner.speed = 0.0
	ground.speed = 0.0
	player.die()
	_save_high_score()
	message_label.text = "GAME OVER\nPress SPAcE to restart"


func _revive() -> void:
	lives -= 1
	_update_score_labels()
	state = State.REVIVING
	spawner.stop()
	spawner.speed = 0.0
	ground.speed = 0.0
	player.revive()
	await player.revived
	if state != State.REVIVING:
		return
	state = State.RUNNING
	spawner.speed = speed
	ground.speed = speed
	spawner.resume()
	player.start_invincibility(invincible_time)
