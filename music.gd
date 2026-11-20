extends AudioStreamPlayer

func _ready() -> void:
	stream = preload("res://assets/music/basic.wav")
	process_mode = Node.PROCESS_MODE_ALWAYS
	play()
