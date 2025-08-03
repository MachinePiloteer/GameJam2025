extends Node2D

@export var next_level: PackedScene = null

# Optional: configure a small delay before switching (e.g., to play death VFX)
@export var transition_delay: float = 0.3

func _ready():
	# Assume enemy is a child named "Enemy"; adjust path as needed
	var enemy = $Enemy
	if enemy and enemy.has_signal("died"):
		enemy.connect("died", Callable(self, "_on_enemy_died"))
	else:
		push_warning("Enemy node missing or doesn't have 'died' signal.")

func _on_hurtbox_got_hit() -> void:
	# You can put in animation/sound logic here first
	if next_level:
		# Optional delay so player sees the death
		await get_tree().create_timer(transition_delay).timeout
		get_tree().change_scene_to_packed(next_level)
	else:
		print("No next_level assigned for this level. End of flow?")
		# handle end of game, retry, etc.
