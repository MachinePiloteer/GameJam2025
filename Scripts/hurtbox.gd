class_name Hurtbox
extends Area2D

signal got_hit

func _ready() -> void:
	connect("area_entered", _on_area_entered)

func _on_area_entered(hitbox: Hitbox) -> void:
	if hitbox != null:
		got_hit.emit()
