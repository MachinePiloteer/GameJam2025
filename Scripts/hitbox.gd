class_name Hitbox
extends Area2D

signal clash

func _ready() -> void:
	connect("area_entered", Callable(self, "_on_area_entered"))

func _on_area_entered(area: Area2D) -> void:
	# only emit clash if the other area is also a Hitbox (avoid self / unrelated)
	if area is Hitbox:
		emit_signal("clash")
