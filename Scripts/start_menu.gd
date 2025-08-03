extends Control

@onready var start_button_sound: AudioStreamPlayer = $start_button_sound
@onready var transition: Timer = $transition

func _on_start_button_pressed() -> void:
	start_button_sound.play()
	transition.start()

func _on_transition_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/level1.tscn")
