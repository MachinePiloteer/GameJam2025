extends CharacterBody2D

const NORMAL_SPEED = 150.0
const CHARGE_SPEED = 250.0
const ATTACK_RADIUS = 150.0
const CHARGE_DURATION = 0.5

@export var LOS_OBSTACLE_MASK: int = 1 << 0  # adjust to the layer(s) your walls/cover live on
@export var LOST_SIGHT_MEMORY_DURATION: float = 1.0  # seconds to keep pursuing last seen position

@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var nav_timer: Timer = $nav_timer
@onready var charge_timer: Timer = $charge_timer

@onready var enemy_sprite: Sprite2D = $enemy_sprite
@onready var swordtip: Node2D = $swordtip
@onready var clash_location: Node2D = $enemy_sprite/clash_location
@onready var cooldown_timer: Timer = $cooldown_timer

@export var Goal: Node = null  # player node reference

var is_charging: bool = false
var is_on_cooldown: bool = false
var player_is_rewinding: bool = false

# Lost sight memory
var last_seen_position: Vector2 = Vector2.ZERO
var lost_sight_time: float = 0.0
var has_current_los: bool = false

func _ready() -> void:
	if Goal == null:
		push_warning("Goal (player node) is not assigned! Please assign it in the inspector or via code.")
		return

	navigation_agent_2d.target_position = Goal.global_position

	# Pathfinding updater
	nav_timer.one_shot = false
	nav_timer.wait_time = 0.2
	nav_timer.start()

	# Charge duration timer
	charge_timer.one_shot = true
	charge_timer.wait_time = CHARGE_DURATION

	# Cooldown timer
	cooldown_timer.one_shot = true

func _physics_process(delta: float) -> void:
	if Goal == null:
		return

	# Suspend everything if player is rewinding
	if player_is_rewinding:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# BLOCK movement while on cooldown (from clash)
	if is_on_cooldown and not is_charging:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Update line-of-sight / memory
	has_current_los = has_line_of_sight_to_goal()
	if has_current_los:
		last_seen_position = Goal.global_position
		lost_sight_time = 0.0
	else:
		lost_sight_time += delta

	# Determine the effective target for pathfinding: either player if visible or last seen while within memory
	var effective_target: Vector2
	var distance_to_player = global_position.distance_to(Goal.global_position)
	if has_current_los:
		effective_target = Goal.global_position
	elif lost_sight_time <= LOST_SIGHT_MEMORY_DURATION:
		effective_target = last_seen_position
	else:
		effective_target = navigation_agent_2d.target_position

	# Rotate to face goal only if we currently have LOS and not on cooldown
	if has_current_los and not is_on_cooldown:
		var to_goal = (Goal.global_position - global_position).normalized()
		enemy_sprite.rotation = to_goal.angle()

	# Charge decision: only if within attack radius, have LOS, not rewinding/cooldown
	if not is_charging and not is_on_cooldown and not player_is_rewinding and has_current_los and distance_to_player <= ATTACK_RADIUS:
		is_charging = true
		charge_timer.start()

	if is_charging:
		var direction = (Goal.global_position - global_position).normalized()
		velocity = direction * CHARGE_SPEED
		move_and_slide()
		swordtip.global_position = Goal.global_position
	else:
		# Chase / path toward effective target
		if effective_target != Vector2.ZERO:
			if navigation_agent_2d.target_position != effective_target:
				navigation_agent_2d.target_position = effective_target
			if not navigation_agent_2d.is_target_reached():
				var nav_point_direction = (navigation_agent_2d.get_next_path_position() - global_position).normalized()
				velocity = nav_point_direction * NORMAL_SPEED
			else:
				velocity = Vector2.ZERO
			move_and_slide()


func has_line_of_sight_to_goal() -> bool:
	if Goal == null:
		return false

	var from_pos = global_position
	var to_pos = Goal.global_position

	var params = PhysicsRayQueryParameters2D.new()
	params.from = from_pos
	params.to = to_pos
	params.exclude = [self]
	params.collision_mask = LOS_OBSTACLE_MASK

	var result = get_world_2d().direct_space_state.intersect_ray(params)

	# nothing hit -> clear LOS
	if result.is_empty():
		return true

	# If the ray hit the player (or a child of the player), that's fine too
	var collider = result.get("collider")
	if collider == Goal or _is_descendant_of(collider, Goal) or _is_descendant_of(Goal, collider):
		return true

	# blocked by something else
	return false

# helper to check parent/child relationship
func _is_descendant_of(node_a: Node, node_b: Node) -> bool:
	var current = node_a
	while current != null:
		if current == node_b:
			return true
		current = current.get_parent()
	return false

func _on_nav_timer_timeout() -> void:
	if Goal == null:
		return
	if player_is_rewinding:
		return
	# Update base navigation target only if player is visible or within memory window
	if has_current_los:
		navigation_agent_2d.target_position = Goal.global_position
	elif lost_sight_time <= LOST_SIGHT_MEMORY_DURATION:
		navigation_agent_2d.target_position = last_seen_position

func _on_charge_timer_timeout() -> void:
	is_charging = false

func _on_cooldown_timer_timeout() -> void:
	is_on_cooldown = false

func _on_hurtbox_got_hit() -> void:
	print("enemy dead")

func _on_hitbox_clash() -> void:
	swordtip.global_position = clash_location.global_position
	if is_charging:
		is_charging = false
	is_on_cooldown = true
	cooldown_timer.start()

func _on_player_rewind_started() -> void:
	player_is_rewinding = true

func _on_player_rewind_ended() -> void:
	player_is_rewinding = false
