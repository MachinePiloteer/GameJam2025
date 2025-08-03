extends Node

@onready var player: AudioStreamPlayer = $AudioStreamPlayer

func _ready():
	if player.playing:
		return  # already running (defensive if something re-calls _ready)
	player.play()
	player.connect("finished", Callable(self, "_on_finished"))

func _on_finished():
	player.play()
