extends AudioStreamPlayer

const EARTH_MUSIC := preload("res://assets/music/basic.wav")
const MOON_MUSIC := preload("res://assets/music/chorus.wav")
const AMBIENT := preload("res://assets/sounds/ambient/ambient.wav")

@export var ambient_volume_db := 10.0

var moon := false
var ambient := AudioStreamPlayer.new()


func _ready() -> void:
	stream = EARTH_MUSIC
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient.stream = AMBIENT
	ambient.volume_db = ambient_volume_db
	add_child(ambient)
	play()


func set_moon(on: bool) -> void:
	if on == moon:
		return
	moon = on
	var position := get_playback_position()
	stream = MOON_MUSIC if on else EARTH_MUSIC
	play(position)
	if on:
		ambient.play()
	else:
		ambient.stop()
