extends CharacterBody2D

@onready var player: CharacterBody2D = $"."
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var swordtip: Node2D = $swordtip
@onready var sword: Bone2D = $bones/Skeleton2D/upperarm/forearm/sword

const SPEED: float = 300.0
const JUMP_VELOCITY: float = -450.0
const FALL_MULTIPLIER: float = 2.0
const LOW_JUMP_MULTIPLIER: float = 2.5
const COYOTE_TIME: float = 0.1
const JUMP_BUFFER: float = 0.08
const WALL_SLIDE_MODIFIER: float = 0.0
const WALL_JUMP_PUSH: float = 400.0

var gravity_magnitude : int = ProjectSettings.get_setting("physics/2d/default_gravity")

var coyote_timer: float = 0.0
var jump_buffer: float = 0.0

var is_wall_sliding: bool = false

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
	jump(delta)
	wall_slide(delta)
	wall_jump()
	gravity(delta)
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
	var direction := Input.get_axis("movement_left", "movement_right")
	if direction:
		velocity.x = lerp(velocity.x, direction * SPEED, 0.2)
	else:
		velocity.x = lerp(velocity.x, 0.0, 0.2)

func jump(delta) -> void:
	if is_on_floor():
		coyote_timer = COYOTE_TIME
	else:
		coyote_timer = max(coyote_timer - delta, 0)

	if Input.is_action_just_pressed("movement_jump"):
		jump_buffer = JUMP_BUFFER
	else:
		jump_buffer = max(jump_buffer - delta, 0)

	# Jump execution: if we have a buffered jump and are allowed by coyote time / on floor
	if jump_buffer > 0 and (is_on_floor() or coyote_timer > 0):
		velocity.y = JUMP_VELOCITY
		jump_buffer = 0
		coyote_timer = 0  # consume coyote

func wall_jump() -> void:
	if is_on_wall() and Input.is_action_pressed("movement_left") and Input.is_action_just_pressed("movement_jump"):
		velocity.y = JUMP_VELOCITY
		velocity.x = WALL_JUMP_PUSH
	if is_on_wall() and Input.is_action_pressed("movement_right") and Input.is_action_just_pressed("movement_jump"):
		velocity.y = JUMP_VELOCITY
		velocity.x = -WALL_JUMP_PUSH

func wall_slide(delta) -> void:
	if is_on_wall() and not is_on_floor():
		if Input.is_action_pressed("movement_left") or Input.is_action_pressed("movement_right"):
			is_wall_sliding = true
		else:
			is_wall_sliding = false
	else:
		is_wall_sliding = false

	if is_wall_sliding:
		velocity.y += gravity_magnitude * WALL_SLIDE_MODIFIER * delta
		velocity.y = min(velocity.y, gravity_magnitude * WALL_SLIDE_MODIFIER)

func gravity(delta) -> void:
	if not is_on_floor():
		#var gravity_vec = get_gravity()
		var jump_pressed = Input.is_action_pressed("movement_jump")

		if velocity.y > 0:
			# Falling: stronger gravity
			velocity.y += gravity_magnitude * FALL_MULTIPLIER * delta
		elif velocity.y < 0 and not jump_pressed:
			# Rising but jump released early
			velocity.y += gravity_magnitude * LOW_JUMP_MULTIPLIER * delta
		else:
			velocity.y += gravity_magnitude * delta

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
