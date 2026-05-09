extends CharacterBody2D
class_name Player

enum Mode { MOVE_REPAIR, TRAP_NORMAL, TRAP_ELECTRIC, MOLOTOV }

const WALK_ANIMATION: StringName = &"walk"
const IDLE_ANIMATION: StringName = &"idle"
const CLICK_ACTION: StringName = &"click"
const FLIP_THRESHOLD: float = 0.01

const TARGET_MARKER_SCENE: PackedScene = preload("res://entities/fx/target_marker.tscn")
const BEAR_TRAP_SCENE: PackedScene = preload("res://entities/weapons/bear_trap.tscn")
const ELECTRIC_TRAP_SCENE: PackedScene = preload("res://entities/weapons/electric_trap.tscn")

const _FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://audio/footsteps/Footstep Concrete 01.wav"),
	preload("res://audio/footsteps/Footstep Concrete 02.wav"),
	preload("res://audio/footsteps/Footstep Concrete 03.wav"),
	preload("res://audio/footsteps/Footstep Concrete 04.wav"),
	preload("res://audio/footsteps/Footstep Concrete 05.wav"),
	preload("res://audio/footsteps/Footstep Concrete 06.wav"),
	preload("res://audio/footsteps/Footstep Concrete 07.wav"),
	preload("res://audio/footsteps/Footstep Concrete 08.wav"),
	preload("res://audio/footsteps/Footstep Concrete 09.wav"),
	preload("res://audio/footsteps/Footstep Concrete 10.wav"),
]

## How much health a single repair action restores.
const REPAIR_AMOUNT: int = 25
## Radius within which the player can repair a wall they are walking toward.
const REPAIR_REACH: float = 40.0

@export var speed: float = 400.0
@export var stop_distance: float = 10.0
## Stop trying to reach the click if we barely move for this long (e.g. blocked by a rock).
@export var stuck_timeout_seconds: float = 2.0
## Max squared distance moved in one physics tick to count as "no progress" (world units²).
@export var stuck_movement_epsilon_sq: float = 0.0625
## Time between footstep sounds while walking (only when actually moving).
@export var footstep_interval_seconds: float = 0.38
@export var footstep_volume_db: float = 8.0

signal mode_changed(mode: Mode)

var active_mode: Mode = Mode.MOVE_REPAIR
var target: Vector2

var _destination_marker: Node2D = null
var _pending_repair: Wall = null
## Set when the player clicked to place a trap; spawned on arrival.
var _pending_trap_electric: bool = false
var _has_pending_trap: bool = false
## Semi-transparent preview that follows the cursor while a trap mode is active.
var _trap_ghost: Node2D = null
var _stuck_time_seconds: float = 0.0
var _footstep_phase_seconds: float = 0.0
## False until the first real movement after idle/stuck/new click; then interval cadence.
var _footstep_in_walk_cadence: bool = false

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	target = global_position


func _exit_tree() -> void:
	_hide_trap_ghost()


func _process(_delta: float) -> void:
	# Follow cursor freely before a destination is confirmed; freeze in place after.
	if is_instance_valid(_trap_ghost) and not _has_pending_trap:
		_trap_ghost.global_position = get_global_mouse_position()


func reset_target() -> void:
	target = global_position
	_pending_repair = null
	_has_pending_trap = false
	_stuck_time_seconds = 0.0
	_footstep_phase_seconds = 0.0
	_footstep_in_walk_cadence = false
	_hide_destination_marker()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("slot_1"):
		_set_mode(Mode.MOVE_REPAIR)
		return
	if event.is_action_pressed("slot_2"):
		_set_mode(Mode.TRAP_NORMAL)
		return
	if event.is_action_pressed("slot_3"):
		_set_mode(Mode.TRAP_ELECTRIC)
		return
	if event.is_action_pressed("slot_4"):
		_set_mode(Mode.MOLOTOV)
		return
	if event.is_action_pressed("cancel_action"):
		_cancel_to_move_repair()
		return
	if event.is_action_pressed(CLICK_ACTION):
		_handle_click()


func _physics_process(delta: float) -> void:
	# Reached repair target — apply repair and stop.
	if _pending_repair != null:
		if not is_instance_valid(_pending_repair):
			_pending_repair = null
		elif global_position.distance_to(_pending_repair.global_position) <= REPAIR_REACH:
			if not _pending_repair.is_destroyed():
				_pending_repair.repair(REPAIR_AMOUNT)
			_pending_repair = null
			_abort_move_to_target()
			return

	if global_position.distance_to(target) <= stop_distance:
		velocity = Vector2.ZERO
		_stuck_time_seconds = 0.0
		_footstep_phase_seconds = 0.0
		_footstep_in_walk_cadence = false
		_hide_destination_marker()
		_play_animation(IDLE_ANIMATION)
		# Reached trap destination — spawn the trap here and clear pending.
		if _has_pending_trap:
			_has_pending_trap = false
			_spawn_trap(_pending_trap_electric, global_position)
		return

	var direction: Vector2 = global_position.direction_to(target)
	velocity = direction * speed
	var pos_before: Vector2 = global_position
	move_and_slide()

	var moved_sq: float = global_position.distance_squared_to(pos_before)
	if moved_sq <= stuck_movement_epsilon_sq:
		_stuck_time_seconds += delta
		_footstep_in_walk_cadence = false
		if _stuck_time_seconds >= stuck_timeout_seconds:
			_pending_repair = null
			_has_pending_trap = false
			_abort_move_to_target()
			return
	else:
		_stuck_time_seconds = 0.0
		if not _footstep_in_walk_cadence:
			_play_footstep()
			_footstep_in_walk_cadence = true
			_footstep_phase_seconds = 0.0
		else:
			_footstep_phase_seconds += delta
			if _footstep_phase_seconds >= footstep_interval_seconds:
				_footstep_phase_seconds -= footstep_interval_seconds
				_play_footstep()

	_play_animation(WALK_ANIMATION)
	_update_sprite_facing(direction)


# ── Mode switching ────────────────────────────────────────────────────────────

func _set_mode(mode: Mode) -> void:
	if active_mode == mode:
		return
	active_mode = mode
	_has_pending_trap = false
	match mode:
		Mode.TRAP_NORMAL:
			_show_trap_ghost(false)
		Mode.TRAP_ELECTRIC:
			_show_trap_ghost(true)
		_:
			_hide_trap_ghost()
	mode_changed.emit(mode)


func _cancel_to_move_repair() -> void:
	_pending_repair = null
	_has_pending_trap = false
	_abort_move_to_target()
	_set_mode(Mode.MOVE_REPAIR)


# ── Click routing ─────────────────────────────────────────────────────────────

func _handle_click() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	match active_mode:
		Mode.MOVE_REPAIR:
			var wall := _wall_at(mouse_pos)
			if wall:
				_begin_repair(wall)
			else:
				_move_to(mouse_pos)
		Mode.TRAP_NORMAL:
			_begin_place_trap(false, mouse_pos)
		Mode.TRAP_ELECTRIC:
			_begin_place_trap(true, mouse_pos)
		Mode.MOLOTOV:
			_throw_molotov(mouse_pos)


func _wall_at(world_pos: Vector2) -> Wall:
	var space := get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collision_mask = 1  # "world" layer
	query.collide_with_bodies = true
	var results := space.intersect_point(query, 4)
	for r: Dictionary in results:
		var body: Object = r.get("collider")
		if body is Wall and not (body as Wall).is_destroyed():
			return body as Wall
	return null


func _begin_repair(wall: Wall) -> void:
	if GameState.phase != GameState.Phase.DAY:
		return
	_move_to(wall.global_position)
	_pending_repair = wall


func _move_to(world_pos: Vector2) -> void:
	_pending_repair = null
	_stuck_time_seconds = 0.0
	_footstep_in_walk_cadence = false
	target = world_pos
	_show_destination_marker_at(target)


## Walk to world_pos; drop a trap when arriving.
func _begin_place_trap(electric: bool, world_pos: Vector2) -> void:
	if GameState.phase != GameState.Phase.DAY:
		return
	_move_to(world_pos)
	_pending_trap_electric = electric
	_has_pending_trap = true


func _spawn_trap(electric: bool, world_pos: Vector2) -> void:
	var scene: PackedScene = ELECTRIC_TRAP_SCENE if electric else BEAR_TRAP_SCENE
	var trap: Node2D = scene.instantiate() as Node2D
	get_parent().add_child(trap)
	trap.global_position = world_pos
	# Respawn the ghost so it's ready to preview the next placement.
	_show_trap_ghost(electric)


# ── Trap ghost ────────────────────────────────────────────────────────────────

func _show_trap_ghost(electric: bool) -> void:
	_hide_trap_ghost()
	var scene: PackedScene = ELECTRIC_TRAP_SCENE if electric else BEAR_TRAP_SCENE
	_trap_ghost = scene.instantiate() as Node2D
	_trap_ghost.modulate = Color(1.0, 1.0, 1.0, 0.5)
	get_parent().add_child(_trap_ghost)
	if _trap_ghost is Area2D:
		(_trap_ghost as Area2D).monitoring = false
		(_trap_ghost as Area2D).monitorable = false
	for child: Node in _trap_ghost.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = true
	_trap_ghost.global_position = get_global_mouse_position()


func _hide_trap_ghost() -> void:
	if is_instance_valid(_trap_ghost):
		_trap_ghost.queue_free()
	_trap_ghost = null


func _throw_molotov(_world_pos: Vector2) -> void:
	# TODO: instantiate molotov projectile and launch toward world_pos.
	pass


# ── Animation ─────────────────────────────────────────────────────────────────

func _play_animation(animation_name: StringName) -> void:
	if _animated_sprite.animation == animation_name:
		return
	_animated_sprite.play(animation_name)


func _update_sprite_facing(direction: Vector2) -> void:
	if abs(direction.x) <= FLIP_THRESHOLD:
		return
	_animated_sprite.flip_h = direction.x > 0.0


# ── Destination marker ────────────────────────────────────────────────────────

func _ensure_destination_marker() -> void:
	if is_instance_valid(_destination_marker):
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	_destination_marker = TARGET_MARKER_SCENE.instantiate() as Node2D
	parent_node.add_child(_destination_marker)


func _show_destination_marker_at(world_pos: Vector2) -> void:
	_ensure_destination_marker()
	if not is_instance_valid(_destination_marker):
		return
	_destination_marker.global_position = world_pos
	_destination_marker.visible = true
	_destination_marker.queue_redraw()


func _hide_destination_marker() -> void:
	if is_instance_valid(_destination_marker):
		_destination_marker.visible = false


func _abort_move_to_target() -> void:
	velocity = Vector2.ZERO
	target = global_position
	_stuck_time_seconds = 0.0
	_footstep_phase_seconds = 0.0
	_footstep_in_walk_cadence = false
	_hide_destination_marker()
	_play_animation(IDLE_ANIMATION)


# ── Audio ─────────────────────────────────────────────────────────────────────

func _play_footstep() -> void:
	var stream: AudioStream = _FOOTSTEP_STREAMS[randi_range(0, _FOOTSTEP_STREAMS.size() - 1)]
	AudioManager.play_sfx_2d(stream, global_position, footstep_volume_db)
