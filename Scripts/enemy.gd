extends CharacterBody2D

@export var path_recalc_interval: float = 0.25
@export var node_reach_threshold: float = 16.0  # smaller threshold for precise node arrival
@export var jump_height_threshold: float = 30.0
@export var speed := 300.0
@export var jump_velocity := -400.0
@export var jump_horizontal_boost := 1.0

@export var player_path: NodePath
@export var pathfinder_path: NodePath

var path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0
var recalc_timer: float = 0.0

var player: CharacterBody2D
var pathfinder

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

func _recalc_path():
	if not player or not pathfinder:
		return
	var raw_path = pathfinder.get_path_world(global_position, player.global_position)
	if raw_path.size() == 0:
		path = PackedVector2Array()
		return
	path = raw_path
	path_index = 0

func _follow_path(delta):
	if path.is_empty():
		var dir = sign(player.global_position.x - global_position.x)
		velocity.x = lerp(velocity.x, dir * speed, 0.2)
		return

	var target_pos = path[path_index]
	var to_target = target_pos - global_position

	var dir = sign(to_target.x)
	velocity.x = lerp(velocity.x, dir * speed, 0.2 if is_on_floor() else 0.1)

	var can_jump_now = is_on_floor() or abs(velocity.y) < 5.0  # small tolerance

	# Check horizontal collision before jump
	var colliding_horizontally = false
	var space_state = get_world_2d().direct_space_state
	var from_pos = global_position
	var to_pos = global_position + Vector2(dir * 5, 0)  # small horizontal probe
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collision_mask = collision_mask
	var result = space_state.intersect_ray(query)
	if result != {}:
		colliding_horizontally = true

	# Jump if next node is higher and can jump now OR
	# if stuck against a wall horizontally and near floor
	if ((to_target.y < -jump_height_threshold and can_jump_now) or (colliding_horizontally and can_jump_now)):
		velocity.y = jump_velocity

	# Only advance path index if close and on floor
	if global_position.distance_to(target_pos) < node_reach_threshold and is_on_floor():
		if path_index < path.size() - 1:
			path_index += 1



func _can_jump_to(target_pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var from_pos = global_position
	var to_pos = Vector2(target_pos.x, global_position.y)

	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.exclude = [self]
	query.collision_mask = self.collision_mask

	var result = space_state.intersect_ray(query)
	return result == {}  # True if no collision detected


func _apply_gravity(delta):
	if not is_on_floor():
		if velocity.y > 0:
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * 2.0 * delta  # fall multiplier
		else:
			velocity.y += ProjectSettings.get_setting("physics/2d/default_gravity") * delta
