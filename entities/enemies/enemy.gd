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
## is destroyed.
##
## To prevent stacking, intact walls have a small attacker capacity (Wall.ATTACKER_CAPACITY)
## and assign each claimant a slot offset along the wall's tangent. If every wall on
## this enemy's side is full, we fall back to the closest claimable wall on any side.

const WALK_ANIMATION: StringName = &"walk"
const ATTACK_ANIMATION: StringName = &"attack"
const KILLED_ANIMATION: StringName = &"killed"
const ELECTRIFIED_ANIMATION: StringName = &"electrified"
const FLIP_THRESHOLD: float = 0.01
const ATTACK_SHAKE_STRENGTH: float = 2.0
const ATTACK_SHAKE_DURATION_SECONDS: float = 0.07
const ATTACK_SFX_VOLUME_DB: float = -2.0
const ATTACK_SFX_CHANCE: float = 0.25
const SPAWN_SFX_VOLUME_DB: float = -1.0
const DEATH_SFX_PATH: String = "res://audio/zombie/zombie death.mp3"
const DEATH_SFX_VOLUME_DB: float = -1.0
const _ATTACK_SFX_PATHS: Array[String] = [
	"res://audio/zombie/zombie attack 1.mp3",
	"res://audio/zombie/zombie attack 2.mp3",
]
const _SPAWN_SFX_PATHS: Array[String] = [
	"res://audio/zombie/zombie inicial.mp3",
	"res://audio/zombie/zombie incial 2.mp3",
]

@export var speed: float = 60.0
## How close (px) to the chosen slot before we count as "arrived".
@export var arrival_distance: float = 12.0
## Time of near-zero progress before we re-pick a target wall.
@export var stuck_timeout_seconds: float = 1.5
@export var stuck_movement_epsilon_sq: float = 0.04
## Wall damage dealt when the attack animation reaches `attack_hit_frame`.
@export var wall_attack_damage: int = 8
## Frame index in the `attack` AnimatedSprite2D animation that should apply damage.
@export var attack_hit_frame: int = 1
## Player damage dealt when the attack animation reaches `attack_hit_frame`.
@export var player_attack_damage: int = 10
## Distance where enemy stops pathing and starts attacking the player.
@export var player_attack_range: float = 14.0

var _state: int = State.APPROACH
var _target_wall: Wall = null
## True when `_target_wall` is a destroyed wall we're walking through, so we use
## its center instead of a (non-existent) attacker slot.
var _target_is_breach: bool = false
var _spawn_side: int = Wall.Orientation.TOP
var _stuck_time: float = 0.0
var _attack_sfx_streams: Array[AudioStream] = []
var _spawn_sfx_streams: Array[AudioStream] = []
var _death_sfx_stream: AudioStream = null
var _is_dying: bool = false

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _nav_agent: NavigationAgent2D = $NavigationAgent2D


enum State { APPROACH, INSIDE, AT_WALL, AT_PLAYER }


func _ready() -> void:
	add_to_group("enemies")
	_spawn_side = _detect_spawn_side()
	_connect_wall_signals()
	if _animated_sprite != null:
		_animated_sprite.frame_changed.connect(_on_animated_sprite_frame_changed)
		_animated_sprite.animation_finished.connect(_on_animated_sprite_animation_finished)
	_play_spawn_sfx()
	_retarget()
	_play_animation(WALK_ANIMATION)


func _exit_tree() -> void:
	_release_current_claim()


func _physics_process(delta: float) -> void:
	if _is_dying:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	# Keep local crowd avoidance active only while chasing inside the shelter.
	_nav_agent.avoidance_enabled = _state == State.INSIDE
	match _state:
		State.APPROACH:
			_process_approach(delta)
		State.INSIDE:
			_process_inside()
		State.AT_WALL:
			velocity = Vector2.ZERO
			move_and_slide()
		State.AT_PLAYER:
			_process_at_player()


func _process_approach(delta: float) -> void:
	if not is_instance_valid(_target_wall):
		_retarget()
		return

	var target_pos: Vector2 = _current_target_position()
	var to_target: Vector2 = target_pos - global_position
	var distance: float = to_target.length()

	if distance <= arrival_distance:
		if _target_wall.is_destroyed():
			_release_current_claim()
			_state = State.INSIDE
			_play_animation(WALK_ANIMATION)
		else:
			_state = State.AT_WALL
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
	if global_position.distance_to(player_node.global_position) <= player_attack_range:
		_state = State.AT_PLAYER
		velocity = Vector2.ZERO
		move_and_slide()
		_play_animation(ATTACK_ANIMATION)
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
	_play_animation(WALK_ANIMATION)
	_update_sprite_facing(direction)


func _process_at_player() -> void:
	var player_node: Node2D = _get_player()
	if player_node == null:
		_state = State.INSIDE
		_play_animation(WALK_ANIMATION)
		return
	var to_player: Vector2 = player_node.global_position - global_position
	var distance: float = to_player.length()
	if distance > player_attack_range:
		_state = State.INSIDE
		_play_animation(WALK_ANIMATION)
		return
	velocity = Vector2.ZERO
	move_and_slide()
	_play_animation(ATTACK_ANIMATION)
	if distance > 0.001:
		_update_sprite_facing(to_player / distance)


func _current_target_position() -> Vector2:
	if not is_instance_valid(_target_wall):
		return global_position
	if _target_is_breach:
		return _target_wall.global_position
	return _target_wall.slot_position_for(self)


func _retarget() -> void:
	_release_current_claim()

	var same_side: Array[Wall] = _walls_on_my_side()
	var player_pos: Vector2 = _get_player_position()

	# 1. Prefer breaches on my side (walk through them, no claim needed).
	var breaches: Array[Wall] = same_side.filter(
		func(w: Wall) -> bool: return w.is_destroyed() and not w._is_corner()
	)
	if not breaches.is_empty():
		_target_wall = _closest_to(breaches, player_pos)
		_target_is_breach = true
		_state = State.APPROACH
		_play_animation(WALK_ANIMATION)
		return

	# 2. Claimable wall on my side, closest to player.
	var same_side_open: Array[Wall] = same_side.filter(
		func(w: Wall) -> bool: return w.can_be_claimed()
	)
	if not same_side_open.is_empty():
		var w: Wall = _closest_to(same_side_open, player_pos)
		w.claim(self)
		_target_wall = w
		_target_is_breach = false
		_state = State.APPROACH
		_play_animation(WALK_ANIMATION)
		return

	# 3. Surplus: any claimable wall on any side, closest to player.
	var any_open: Array[Wall] = _all_walls().filter(
		func(w: Wall) -> bool: return w.can_be_claimed()
	)
	if not any_open.is_empty():
		var w: Wall = _closest_to(any_open, player_pos)
		w.claim(self)
		_target_wall = w
		_target_is_breach = false
		_state = State.APPROACH
		_play_animation(WALK_ANIMATION)
		return

	# 4. Nothing to attack — push toward the player directly.
	_target_wall = null
	_target_is_breach = false
	_state = State.INSIDE


func _release_current_claim() -> void:
	if is_instance_valid(_target_wall) and not _target_is_breach:
		_target_wall.release(self)


func _all_walls() -> Array[Wall]:
	var result: Array[Wall] = []
	for node: Node in get_tree().get_nodes_in_group("walls"):
		var wall: Wall = node as Wall
		if wall != null:
			result.append(wall)
	return result


func _walls_on_my_side() -> Array[Wall]:
	var result: Array[Wall] = []
	for wall: Wall in _all_walls():
		if wall.orientation == _spawn_side:
			result.append(wall)
	return result


func _closest_to(walls: Array[Wall], pos: Vector2) -> Wall:
	var best: Wall = walls[0]
	var best_d: float = best.global_position.distance_squared_to(pos)
	for i: int in range(1, walls.size()):
		var d: float = walls[i].global_position.distance_squared_to(pos)
		if d < best_d:
			best = walls[i]
			best_d = d
	return best


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
	# Listen to ALL walls so we can react to breaches anywhere (surplus targets,
	# preferred-side breaches opening mid-approach, current target dying, etc.).
	for wall: Wall in _all_walls():
		wall.wall_destroyed.connect(_on_any_wall_destroyed)


func _on_any_wall_destroyed() -> void:
	if _state == State.APPROACH or _state == State.AT_WALL:
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
	if _animated_sprite == null:
		return
	if _animated_sprite.animation == animation_name and _animated_sprite.is_playing():
		return
	_animated_sprite.play(animation_name)


func _update_sprite_facing(direction: Vector2) -> void:
	if _animated_sprite == null or absf(direction.x) <= FLIP_THRESHOLD:
		return
	_animated_sprite.flip_h = direction.x < 0.0


func _on_animated_sprite_frame_changed() -> void:
	if _is_dying:
		return
	if _animated_sprite == null:
		return
	if _animated_sprite.animation != ATTACK_ANIMATION:
		return
	if _animated_sprite.frame != attack_hit_frame:
		return
	if _state == State.AT_WALL:
		_attack_wall()
	elif _state == State.AT_PLAYER:
		_attack_player()


func _attack_wall() -> void:
	if _target_is_breach:
		return
	if not is_instance_valid(_target_wall):
		return
	if _target_wall.is_destroyed():
		return
	_play_attack_feedback()
	_target_wall.take_damage(wall_attack_damage)


func _attack_player() -> void:
	var player_node: Node2D = _get_player()
	if player_node == null:
		return
	if global_position.distance_to(player_node.global_position) > player_attack_range:
		return
	if not player_node.has_method("take_damage"):
		return
	_play_attack_feedback()
	player_node.call("take_damage", player_attack_damage)


func _play_attack_feedback() -> void:
	_play_attack_sfx()
	_apply_attack_screenshake()


func _play_attack_sfx() -> void:
	if randf() > ATTACK_SFX_CHANCE:
		return
	if _attack_sfx_streams.is_empty():
		for path: String in _ATTACK_SFX_PATHS:
			var loaded_stream: AudioStream = load(path) as AudioStream
			if loaded_stream != null:
				_attack_sfx_streams.append(loaded_stream)
	if _attack_sfx_streams.is_empty():
		return
	var stream: AudioStream = _attack_sfx_streams[randi_range(0, _attack_sfx_streams.size() - 1)]
	AudioManager.play_sfx_2d(stream, global_position, ATTACK_SFX_VOLUME_DB)


func _apply_attack_screenshake() -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return
	# The camera follows the player in the physics loop with physics interpolation
	# on, so the shake must also run in physics. An idle-loop tween updates the
	# offset at render rate and beats against the interpolated camera follow,
	# which makes the shake jitter while the player is moving.
	var impulse: Vector2 = Vector2(
		randf_range(-ATTACK_SHAKE_STRENGTH, ATTACK_SHAKE_STRENGTH),
		randf_range(-ATTACK_SHAKE_STRENGTH, ATTACK_SHAKE_STRENGTH)
	)
	camera.offset = impulse
	var tween: Tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(camera, "offset", Vector2.ZERO, ATTACK_SHAKE_DURATION_SECONDS)


func _play_spawn_sfx() -> void:
	if _spawn_sfx_streams.is_empty():
		for path: String in _SPAWN_SFX_PATHS:
			var loaded_stream: AudioStream = load(path) as AudioStream
			if loaded_stream != null:
				_spawn_sfx_streams.append(loaded_stream)
	if _spawn_sfx_streams.is_empty():
		return
	var stream: AudioStream = _spawn_sfx_streams[randi_range(0, _spawn_sfx_streams.size() - 1)]
	AudioManager.play_sfx_2d(stream, global_position, SPAWN_SFX_VOLUME_DB)


func _play_death_sfx() -> void:
	if _death_sfx_stream == null:
		_death_sfx_stream = load(DEATH_SFX_PATH) as AudioStream
	if _death_sfx_stream == null:
		return
	AudioManager.play_sfx_2d(_death_sfx_stream, global_position, DEATH_SFX_VOLUME_DB)


func die_from_trap(electric: bool) -> void:
	if _is_dying:
		return
	_is_dying = true
	_play_death_sfx()
	_release_current_claim()
	_target_wall = null
	_target_is_breach = false
	velocity = Vector2.ZERO
	collision_layer = 0
	collision_mask = 0
	if has_node("CollisionShape2D"):
		var shape: CollisionShape2D = get_node("CollisionShape2D") as CollisionShape2D
		if shape != null:
			shape.disabled = true
	var death_animation: StringName = ELECTRIFIED_ANIMATION if electric else KILLED_ANIMATION
	if _animated_sprite == null or not _animated_sprite.sprite_frames.has_animation(death_animation):
		queue_free()
		return
	_animated_sprite.sprite_frames.set_animation_loop(death_animation, false)
	_animated_sprite.play(death_animation)


func _on_animated_sprite_animation_finished() -> void:
	if not _is_dying:
		return
	if _animated_sprite == null:
		queue_free()
		return
	if _animated_sprite.animation == KILLED_ANIMATION or _animated_sprite.animation == ELECTRIFIED_ANIMATION:
		queue_free()
