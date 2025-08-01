extends CharacterBody2D

@export var path_recalc_interval: float = 0.2
@export var node_reach_threshold: float = 8.0
@export var jump_height_threshold: float = 10.0  # how much higher next node is to trigger jump
@export var speed := 300.0
@export var jump_velocity := -450.0
var gravity_magnitude : int = ProjectSettings.get_setting("physics/2d/default_gravity")

@export var player_path: NodePath
@export var pathfinder_path: NodePath

var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var recalc_timer: float = 0.0

var player: CharacterBody2D
var pathfinder

# Stuck detection variables
var last_position: Vector2 = Vector2.INF
var stuck_timer: float = 0.0
var stuck_threshold_time: float = 0.5  # seconds

func _ready():
	player = get_node(player_path)
	pathfinder = get_node(pathfinder_path)


func _physics_process(delta):
	recalc_timer -= delta
	if recalc_timer <= 0.0:
		_recalc_path()
		recalc_timer = path_recalc_interval

	_follow_path(delta)
	_apply_gravity(delta)
	move_and_slide()

	# Stuck detection
	if global_position.distance_to(last_position) < 1.0:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_position

	if stuck_timer > stuck_threshold_time:
		if is_on_floor():
			velocity.y = jump_velocity  # Try to jump over obstacle if stuck
		stuck_timer = 0.0


func _recalc_path():
	if not player or not pathfinder:
		return

	var raw = pathfinder.get_path_world(global_position, player.global_position)
	if raw.size() == 0:
		return
	path = raw
	path_index = 0


func _follow_path(delta):
	if path.is_empty():
		# fallback: direct horizontal chase
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = lerp(velocity.x, dir * speed, 0.2)
		return

	var target_pos: Vector2 = path[path_index]
	var to_target = target_pos - global_position

	var dir = sign(to_target.x)

	# More responsive on ground, less mid-air to reduce wiggle
	var lerp_amount = 0.2 if is_on_floor() else 0.05
	velocity.x = lerp(velocity.x, dir * speed, lerp_amount)

	# Jump if next node is above and grounded
	if to_target.y < -jump_height_threshold and is_on_floor():
		velocity.y = jump_velocity

	# Only advance path index if close and on floor
	if global_position.distance_to(target_pos) < node_reach_threshold and is_on_floor():
		if path_index < path.size() - 1:
			path_index += 1


func _apply_gravity(delta):
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += gravity_magnitude * 2.0 * delta  # fall multiplier
		elif velocity.y < 0:
			velocity.y += gravity_magnitude * delta
		else:
			velocity.y += gravity_magnitude * delta
