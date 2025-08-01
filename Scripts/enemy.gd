extends CharacterBody2D

@export var path_recalc_interval: float = 0.2
@export var node_reach_threshold: float = 8.0
@export var jump_height_threshold: float = 10.0  # how much higher next node is to trigger jump
@export var speed := 300.0
@export var jump_velocity := -450.0
var gravity_magnitude : int = ProjectSettings.get_setting("physics/2d/default_gravity")

# Tweak these to match your scene structure
@export_node_path("NodePath") var player_path: NodePath
@export_node_path("NodePath") var pathfinder_path: NodePath



var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var recalc_timer: float = 0.0


#@export var player: CharacterBody2D = get_node(player_path)
#@export var pathfinder = get_node(pathfinder_path)  # script with get_path_world()



func _physics_process(delta):
	# Recalculate path on interval
	recalc_timer -= delta
	if recalc_timer <= 0.0:
		_recalc_path()
		recalc_timer = path_recalc_interval

	_follow_path(delta)
	_apply_gravity(delta)
	move_and_slide()

func _recalc_path():
	if not player or not pathfinder:
		return
	# Get path in world/global coordinates
	var raw = pathfinder.get_path_world(global_position, player.global_position)
	if raw.size() == 0:
		return
	path = raw
	path_index = 0

func _follow_path(delta):
	if path.is_empty():
		# Simple fallback: direct horizontal chase
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = lerp(velocity.x, dir * speed, 0.2)
		return

	var target_pos: Vector2 = path[path_index]
	var to_target = target_pos - global_position

	# Horizontal movement toward next node
	var dir = sign(to_target.x)
	velocity.x = lerp(velocity.x, dir * speed, 0.2)

	# Jump if next node is noticeably above and we're grounded
	if to_target.y < -jump_height_threshold and is_on_floor():
		velocity.y = jump_velocity

	# Advance path index if close enough
	if global_position.distance_to(target_pos) < node_reach_threshold:
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
