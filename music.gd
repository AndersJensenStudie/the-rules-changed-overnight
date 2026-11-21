extends AudioStreamPlayer

@export var ambient_volume_db := 10.0

var ambient := AudioStreamPlayer.new()


func _ready() -> void:
	stream = preload("res://assets/music/basic.wav")
	process_mode = Node.PROCESS_MODE_ALWAYS
	ambient.volume_db = ambient_volume_db
	add_child(ambient)
	play()


func apply_mode(settings: ModeSettings) -> void:
	volume_db = settings.music_volume_db
	if settings.music and settings.music != stream:
		var position := get_playback_position()
		stream = settings.music
		play(fmod(position, stream.get_length()))
	if settings.ambient == null:
		ambient.stop()
	elif ambient.stream != settings.ambient or not ambient.playing:
		ambient.stream = settings.ambient
		ambient.play()


func set_speed_scale(scale: float) -> void:
	pitch_scale = scale
	ambient.pitch_scale = scale
