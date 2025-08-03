extends Control

@onready var quit_button_sound: AudioStreamPlayer = $quit_button_sound
@onready var transition: Timer = $transition

func _on_quit_button_pressed() -> void:
	quit_button_sound.play()
	transition.start()

func _on_transition_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/start_menu.tscn")
