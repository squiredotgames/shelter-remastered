extends CharacterBody2D
class_name Enemy
## Mutant navigation. Two states:
##   APPROACH — straight-line steer toward a chosen wall (intact = ram it; breached = walk through).
##   INSIDE   — once past the wall ring, chase the player via NavigationAgent2D so we route around
##              interior walls / rocks rather than getting stuck.
##
## Wall picking is constrained to the side of the shelter the enemy spawned on
## (north spawns target north walls, etc.) and prefers existing breaches on that
## side, picking the one closest to the player. Re-evaluated whenever any wall
## on this enemy's side is destroyed.

const WALK_ANIMATION: StringName = &"walk"
const ATTACK_ANIMATION: StringName = &"attack"
const FLIP_THRESHOLD: float = 0.01

@export var speed: float = 60.0
## How close (px) to the chosen wall before we count as "arrived".
@export var arrival_distance: float = 12.0
## Time of near-zero progress before we re-pick a target wall.
@export var stuck_timeout_seconds: float = 1.5
@export var stuck_movement_epsilon_sq: float = 0.04

var _state: int = State.APPROACH
var _target_wall: Wall = null
var _spawn_side: int = Wall.Orientation.TOP
var _stuck_time: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D


enum State { APPROACH, INSIDE, IDLE_AT_WALL }


func _ready() -> void:
	add_to_group("enemies")
	_spawn_side = _detect_spawn_side()
	_connect_wall_signals()
	_retarget()
	_play_animation(WALK_ANIMATION)


func _physics_process(delta: float) -> void:
	match _state:
		State.APPROACH:
			_process_approach(delta)
		State.INSIDE:
			_process_inside()
		State.IDLE_AT_WALL:
			velocity = Vector2.ZERO
			move_and_slide()


func _process_approach(delta: float) -> void:
	if not is_instance_valid(_target_wall):
		_retarget()
		return

	var to_target: Vector2 = _target_wall.global_position - global_position
	var distance: float = to_target.length()

	if distance <= arrival_distance:
		if _target_wall.is_destroyed():
			_state = State.INSIDE
		else:
			_state = State.IDLE_AT_WALL
			_play_animation(ATTACK_ANIMATION)
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var direction: Vector2 = to_target / distance
	velocity = direction * speed
	var pos_before: Vector2 = global_position
	move_and_slide()
	_update_sprite_facing(direction)

	var moved_sq: float = global_position.distance_squared_to(pos_before)
	if moved_sq <= stuck_movement_epsilon_sq:
		_stuck_time += delta
		if _stuck_time >= stuck_timeout_seconds:
			_stuck_time = 0.0
			_retarget()
	else:
		_stuck_time = 0.0


func _process_inside() -> void:
	var player_node: Node2D = _get_player()
	if player_node == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_nav_agent.target_position = player_node.global_position
	if _nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var next_pos: Vector2 = _nav_agent.get_next_path_position()
	var direction: Vector2 = global_position.direction_to(next_pos)
	velocity = direction * speed
	move_and_slide()
	_update_sprite_facing(direction)


func _retarget() -> void:
	var candidates: Array[Wall] = _walls_on_my_side()
	if candidates.is_empty():
		_target_wall = null
		_state = State.INSIDE
		return

	var breaches: Array[Wall] = candidates.filter(func(w: Wall) -> bool: return w.is_destroyed())
	var pool: Array[Wall] = breaches if not breaches.is_empty() else candidates.filter(
		func(w: Wall) -> bool: return not w.is_destroyed()
	)
	if pool.is_empty():
		_target_wall = null
		_state = State.INSIDE
		return

	var player_pos: Vector2 = _get_player_position()
	pool.sort_custom(func(a: Wall, b: Wall) -> bool:
		return a.global_position.distance_squared_to(player_pos) \
			< b.global_position.distance_squared_to(player_pos))

	_target_wall = pool[0]
	_state = State.APPROACH
	_play_animation(WALK_ANIMATION)


func _walls_on_my_side() -> Array[Wall]:
	var result: Array[Wall] = []
	for node: Node in get_tree().get_nodes_in_group("walls"):
		var wall: Wall = node as Wall
		if wall == null:
			continue
		if wall.orientation != _spawn_side:
			continue
		result.append(wall)
	return result


func _detect_spawn_side() -> int:
	var walls: Array[Node] = get_tree().get_nodes_in_group("walls")
	if walls.is_empty():
		return Wall.Orientation.TOP
	var sum: Vector2 = Vector2.ZERO
	for node: Node in walls:
		sum += (node as Node2D).global_position
	var center: Vector2 = sum / float(walls.size())
	var delta: Vector2 = global_position - center
	if absf(delta.x) > absf(delta.y):
		return Wall.Orientation.RIGHT if delta.x > 0.0 else Wall.Orientation.LEFT
	return Wall.Orientation.BOTTOM if delta.y > 0.0 else Wall.Orientation.TOP


func _connect_wall_signals() -> void:
	for node: Node in get_tree().get_nodes_in_group("walls"):
		var wall: Wall = node as Wall
		if wall == null:
			continue
		if wall.orientation != _spawn_side:
			continue
		wall.wall_destroyed.connect(_on_wall_destroyed_on_my_side)


func _on_wall_destroyed_on_my_side() -> void:
	if _state == State.APPROACH or _state == State.IDLE_AT_WALL:
		_retarget()


func _get_player() -> Node2D:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	return players[0] as Node2D


func _get_player_position() -> Vector2:
	var p: Node2D = _get_player()
	if p == null:
		return global_position
	return p.global_position


func _play_animation(animation_name: StringName) -> void:
	if _animated_sprite == null or _animated_sprite.animation == animation_name:
		return
	_animated_sprite.play(animation_name)


func _update_sprite_facing(direction: Vector2) -> void:
	if _animated_sprite == null or absf(direction.x) <= FLIP_THRESHOLD:
		return
	_animated_sprite.flip_h = direction.x < 0.0
