extends CharacterBody2D

@onready var player: CharacterBody2D = $"."
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var swordtip: Node2D = $swordtip
@onready var sword: Bone2D = $bones/Skeleton2D/upperarm/forearm/sword
@onready var player_ghost: Sprite2D = $player_ghost


const SPEED: float = 300.0

var replay_duration: float = 3.0
var rewinding: bool = false
var max_frames: int = 0

var rewind_values = {
	"position": [],
	"mouse_pos": [],
	"velocity": []
}

func _ready() -> void:
	# Compute once: # of physics ticks to store
	max_frames = int(replay_duration * Engine.get_physics_ticks_per_second())

func _physics_process(delta: float) -> void:
	if rewinding:
		compute_rewind(delta)
		move_and_slide()
		return

	move()
	move_sword()

	if Input.is_action_just_pressed("rewind"):
		rewind()

	if rewind_values["position"].size() >= max_frames:
		for key in rewind_values.keys():
			rewind_values[key].pop_front()

	if not rewinding:
		if replay_duration * Engine.physics_ticks_per_second == rewind_values["position"].size():
			for key in rewind_values.keys():
				rewind_values[key].pop_front()
				
		rewind_values["position"].append(global_position)
		rewind_values["mouse_pos"].append(get_local_mouse_position())
		rewind_values["velocity"].append(velocity)
	else:
		compute_rewind(delta)

	move_and_slide()

func move() -> void:
	var horizontal_direction := Input.get_axis("movement_left", "movement_right")
	if horizontal_direction:
		velocity.x = lerp(velocity.x, horizontal_direction * SPEED, 0.2)
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.2)
	
	var vertical_direction := Input.get_axis("movement_up", "movement_down")
	if vertical_direction:
		velocity.y = lerp(velocity.y, vertical_direction * SPEED, 0.2)
	else:
		velocity.y = lerp(velocity.y, 0.0, 0.2)

func move_sword():
	var mouse_pos = get_local_mouse_position()
	swordtip.position = mouse_pos

func compute_rewind(_delta: float) -> void:
	# We dont have any position left, we stop rewinding
	if rewind_values["position"].is_empty():
		collision_shape_2d.set_deferred("disabled", false)
		rewinding = false
		velocity = rewind_values["velocity"][0]
		return
	
	var pos = rewind_values["position"].pop_back()
	var mouse_pos = rewind_values["mouse_pos"].pop_back()
	
	global_position = pos
	swordtip.position = mouse_pos
	
	if not rewind_values["velocity"].is_empty():
		velocity = rewind_values["velocity"][0]
	else:
		velocity = Vector2.ZERO
		
	if rewind_values["position"].is_empty():
		collision_shape_2d.set_deferred("disabled", false)
		rewinding = false

func rewind() -> void:
	if rewinding:
		return
	rewinding = true
	collision_shape_2d.set_deferred("disabled", true)
