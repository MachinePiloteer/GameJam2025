extends CharacterBody2D

@onready var player: CharacterBody2D = $"."
@onready var player_sprite: Sprite2D = $player_sprite
@onready var player_ghost: Sprite2D = $player_ghost
@onready var player_collision: CollisionShape2D = $player_collision
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var player_hurtbox_shape: CollisionShape2D = $Hurtbox/player_hurtbox_shape
@onready var hitbox: Hitbox = $bones/Skeleton2D/upperarm/forearm/sword/Hitbox
@onready var player_sword_hitbox_shape: CollisionShape2D = $bones/Skeleton2D/upperarm/forearm/sword/Hitbox/player_sword_hitbox_shape


@onready var swordtip: Node2D = $swordtip  
@onready var clash_location: Node2D = $player_sprite/clash_location
@onready var cooldown_timer: Timer = $cooldown_timer
@onready var shock_timer: Timer = $shock_timer

@onready var clash_sound: AudioStreamPlayer = $clash_sound
@onready var death_sound: AudioStreamPlayer = $death_sound
@onready var rewind_sound: AudioStreamPlayer = $rewind_sound
@onready var transition: Timer = $transition


const SPEED: float = 300.0  

var replay_duration: float = 3.0  
var rewinding: bool = false  
var max_frames: int = 0  

var is_on_cooldown: bool = false

var rewind_values = {
	"position": [],
	"mouse_pos": [],
	"velocity": [],
	"rotation": []
}

signal rewind_started
signal rewind_ended

func _ready() -> void:
	max_frames = int(replay_duration * Engine.get_physics_ticks_per_second())

func _physics_process(delta: float) -> void:
	if rewinding:
		compute_rewind(delta)
		move_and_slide()
		player_ghost.visible = false
		return

	move()
	move_sword()

	if Input.is_action_just_pressed("rewind"):
		rewind()

	# Keep rewind buffers capped
	if rewind_values["position"].size() >= max_frames:
		for key in rewind_values.keys():
			rewind_values[key].pop_front()

	# Record current state
	rewind_values["position"].append(global_position)
	rewind_values["mouse_pos"].append(get_local_mouse_position())
	rewind_values["velocity"].append(velocity)
	rewind_values["rotation"].append(player_sprite.rotation)

	# Update ghost preview to oldest rewind state
	if rewind_values["position"].size() > 0:
		player_ghost.global_position = rewind_values["position"][0]
		player_ghost.rotation = rewind_values["rotation"][0]
		player_ghost.visible = true
	else:
		player_ghost.visible = false

	move_and_slide()

func move() -> void:
	var input_vector = Vector2(
		Input.get_axis("movement_left", "movement_right"),
		Input.get_axis("movement_up", "movement_down")
	)
	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
	
	var target_velocity = input_vector * SPEED
	velocity = velocity.lerp(target_velocity, 0.2)

func move_sword() -> void:
	var mouse_pos = get_local_mouse_position()
	if not is_on_cooldown:
		swordtip.position = mouse_pos
	
	# Rotate player sprite to face mouse in local space (only if not rewinding)
	if not rewinding:
		player_sprite.rotation = mouse_pos.angle()

func compute_rewind(_delta: float) -> void:
	if rewind_values["position"].is_empty():
		player_collision.set_deferred("disabled", false)
		hurtbox.set_deferred("disabled", false)
		hitbox.set_deferred("disabled", false)
		hurtbox.monitoring = true
		player_hurtbox_shape.disabled = false
		hitbox.monitoring = true
		player_sword_hitbox_shape.disabled = false
		rewinding = false
		if rewind_values["velocity"].size() > 0:
			velocity = rewind_values["velocity"][0]
		return

	# Speed multiplier: how many frames to rewind per physics tick
	var rewind_speed: int = 5

	# Pop up to rewind_speed frames each physics tick
	for i in range(rewind_speed):
		if rewind_values["position"].is_empty():
			break
		
		var pos = rewind_values["position"].pop_back()
		var mouse_pos = rewind_values["mouse_pos"].pop_back()
		var rot = rewind_values["rotation"].pop_back()
		var vel = rewind_values["velocity"].pop_back()
		
		global_position = pos
		swordtip.position = mouse_pos
		player_sprite.rotation = rot
		velocity = vel

	if rewind_values["position"].is_empty():
		player_collision.set_deferred("disabled", false)
		hurtbox.set_deferred("disabled", false)
		hitbox.set_deferred("disabled", false)
		hurtbox.monitoring = true
		player_hurtbox_shape.disabled = false
		hitbox.monitoring = true
		player_sword_hitbox_shape.disabled = false
		rewinding = false
		shock_timer.start()

func rewind() -> void:
	if rewinding or rewind_values["position"].is_empty():
		return
	rewinding = true
	rewind_sound.play()
	player_collision.set_deferred("disabled", true)
	hurtbox.set_deferred("disabled", true)
	hitbox.set_deferred("disabled", true)
	hurtbox.monitoring = false
	player_hurtbox_shape.disabled = true
	hitbox.monitoring = false
	player_sword_hitbox_shape.disabled = true
	emit_signal("rewind_started")

func _on_hurtbox_got_hit() -> void:
	death_sound.play()
	transition.start()

func _on_hitbox_clash() -> void:
	swordtip.global_position = clash_location.global_position
	clash_sound.play()
	is_on_cooldown = true
	cooldown_timer.start()

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false

func _on_shock_timer_timeout() -> void:
	emit_signal("rewind_ended")

func _on_transition_timeout() -> void:
	get_tree().change_scene_to_file("res://Scenes/game_over.tscn")
