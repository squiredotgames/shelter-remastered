extends CharacterBody2D
class_name Player

enum Mode { MOVE_REPAIR, TRAP_NORMAL, TRAP_ELECTRIC, MOLOTOV }

const WALK_ANIMATION: StringName = &"walk"
const IDLE_ANIMATION: StringName = &"idle"
const CLICK_ACTION: StringName = &"click"
const FLIP_THRESHOLD: float = 0.01
const HP_COLOR_GREEN: Color = Color(0.2, 0.85, 0.35, 1.0)
const HP_COLOR_YELLOW: Color = Color(0.95, 0.8, 0.2, 1.0)
const HP_COLOR_RED: Color = Color(0.9, 0.2, 0.2, 1.0)
const HP_YELLOW_THRESHOLD: float = 0.6
const HP_RED_THRESHOLD: float = 0.3

const TARGET_MARKER_SCENE: PackedScene = preload("res://entities/fx/target_marker.tscn")
const BEAR_TRAP_SCENE: PackedScene = preload("res://entities/weapons/bear_trap.tscn")
const ELECTRIC_TRAP_SCENE: PackedScene = preload("res://entities/weapons/electric_trap.tscn")
const MOLOTOV_SCENE: PackedScene = preload("res://entities/weapons/molotov.tscn")

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
const _HIT_VOCAL_PATHS: Array[String] = [
	"res://audio/player/Male vocalization - restrained pain - grunting 3.mp3",
	"res://audio/player/Male vocalization - restrained pain - grunting 5.mp3",
]

## How much health a single repair action restores.
const REPAIR_AMOUNT: int = 25
## Radius within which the player can repair a wall they are walking toward.
const REPAIR_REACH: float = 40.0
const DEAD_ANIMATION: StringName = &"dead"

@export var speed: float = 400.0
@export var stop_distance: float = 10.0
## Stop trying to reach the click if we barely move for this long (e.g. blocked by a rock).
@export var stuck_timeout_seconds: float = 2.0
## Max squared distance moved in one physics tick to count as "no progress" (world units²).
@export var stuck_movement_epsilon_sq: float = 0.0625
## Time between footstep sounds while walking (only when actually moving).
@export var footstep_interval_seconds: float = 0.38
@export var footstep_volume_db: float = 8.0
@export var max_hp: int = 100
@export var damage_cooldown_seconds: float = 0.6
@export var molotov_capacity: int = 3
@export var molotov_throw_max_radius: float = 160.0

signal mode_changed(mode: Mode)
signal molotov_count_changed(count: int)
signal action_warning_requested(message: String)

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
var _hp: int = 100
var _damage_cooldown_left: float = 0.0
var _is_dead: bool = false
var _hit_vocal_streams: Array[AudioStream] = []
var _molotov_count: int = 0
var _has_pending_molotov_throw: bool = false
var _pending_molotov_target: Vector2 = Vector2.ZERO

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _head_health_bar: ProgressBar = $HeadHealthBar


func _ready() -> void:
	add_to_group("player")
	target = global_position
	_hp = max_hp
	_update_head_health_bar()
	_molotov_count = maxi(0, molotov_capacity)
	molotov_count_changed.emit(_molotov_count)


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
	_has_pending_molotov_throw = false
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
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _damage_cooldown_left > 0.0:
		_damage_cooldown_left = maxf(0.0, _damage_cooldown_left - delta)

	# Reached repair target — apply repair and stop.
	if _pending_repair != null:
		if not is_instance_valid(_pending_repair):
			_pending_repair = null
		elif global_position.distance_to(_pending_repair.global_position) <= REPAIR_REACH:
			if not _pending_repair.is_destroyed():
				if GameState.try_spend_supplies(GameState.repair_supplies_cost):
					_pending_repair.repair(REPAIR_AMOUNT)
			_pending_repair = null
			_abort_move_to_target()
			return
	if _has_pending_molotov_throw:
		if _molotov_count <= 0:
			_has_pending_molotov_throw = false
		elif global_position.distance_to(_pending_molotov_target) <= molotov_throw_max_radius:
			_execute_pending_molotov_throw()
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
	_has_pending_molotov_throw = false
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
	_has_pending_molotov_throw = false
	_set_mode(Mode.MOVE_REPAIR)
	_move_to(get_global_mouse_position())


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
			_begin_throw_molotov(mouse_pos)


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
	_has_pending_trap = false
	_has_pending_molotov_throw = false
	_stuck_time_seconds = 0.0
	_footstep_in_walk_cadence = false
	target = world_pos
	_show_destination_marker_at(target)


## Walk to world_pos; drop a trap when arriving.
func _begin_place_trap(electric: bool, world_pos: Vector2) -> void:
	_move_to(world_pos)
	_pending_trap_electric = electric
	_has_pending_trap = true


func _begin_throw_molotov(world_pos: Vector2) -> void:
	if _molotov_count <= 0:
		return
	_pending_repair = null
	_has_pending_trap = false
	_pending_molotov_target = world_pos
	_has_pending_molotov_throw = true
	_update_sprite_facing(global_position.direction_to(world_pos))
	if global_position.distance_to(world_pos) <= molotov_throw_max_radius:
		_execute_pending_molotov_throw()
		return
	_stuck_time_seconds = 0.0
	_footstep_in_walk_cadence = false
	target = world_pos
	_show_destination_marker_at(target)


func _execute_pending_molotov_throw() -> void:
	if not _has_pending_molotov_throw:
		return
	if _molotov_count <= 0:
		_has_pending_molotov_throw = false
		return
	var throw_target: Vector2 = _pending_molotov_target
	_has_pending_molotov_throw = false
	_abort_move_to_target()
	_throw_molotov(throw_target)


func _spawn_trap(electric: bool, world_pos: Vector2) -> void:
	var supplies_cost: int = GameState.electric_trap_supplies_cost if electric else GameState.trap_supplies_cost
	if not GameState.try_spend_supplies(supplies_cost):
		action_warning_requested.emit("Not enough supplies for trap")
		return
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
	if _molotov_count <= 0:
		return
	var molotov: Node2D = MOLOTOV_SCENE.instantiate() as Node2D
	get_parent().add_child(molotov)
	molotov.global_position = global_position
	if molotov.has_method("launch_to"):
		molotov.call("launch_to", _world_pos)
	_molotov_count = maxi(0, _molotov_count - 1)
	molotov_count_changed.emit(_molotov_count)


func get_molotov_count() -> int:
	return _molotov_count


func get_current_hp() -> int:
	return _hp


func add_molotovs(amount: int) -> bool:
	if amount <= 0:
		return false
	var previous_count: int = _molotov_count
	_molotov_count = clampi(_molotov_count + amount, 0, molotov_capacity)
	if _molotov_count == previous_count:
		return false
	molotov_count_changed.emit(_molotov_count)
	return true


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


func _play_hit_vocalization() -> void:
	if _hit_vocal_streams.is_empty():
		for path: String in _HIT_VOCAL_PATHS:
			var loaded_stream: AudioStream = load(path) as AudioStream
			if loaded_stream != null:
				_hit_vocal_streams.append(loaded_stream)
	if _hit_vocal_streams.is_empty():
		return
	var stream: AudioStream = _hit_vocal_streams[randi_range(0, _hit_vocal_streams.size() - 1)]
	AudioManager.play_sfx_2d(stream, global_position)


func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return
	if _damage_cooldown_left > 0.0:
		return
	_damage_cooldown_left = damage_cooldown_seconds
	_hp = maxi(0, _hp - amount)
	_update_head_health_bar()
	_play_hit_vocalization()
	if _hp <= 0:
		_is_dead = true
		velocity = Vector2.ZERO
		_play_animation(DEAD_ANIMATION)
		GameState.notify_player_died()


func _update_head_health_bar() -> void:
	var clamped_max_hp: int = maxi(1, max_hp)
	var clamped_current_hp: int = clampi(_hp, 0, clamped_max_hp)
	_head_health_bar.max_value = clamped_max_hp
	_head_health_bar.value = clamped_current_hp
	_head_health_bar.visible = clamped_current_hp < clamped_max_hp
	var hp_ratio: float = float(clamped_current_hp) / float(clamped_max_hp)
	if hp_ratio <= HP_RED_THRESHOLD:
		_apply_head_health_bar_fill_color(HP_COLOR_RED)
	elif hp_ratio <= HP_YELLOW_THRESHOLD:
		_apply_head_health_bar_fill_color(HP_COLOR_YELLOW)
	else:
		_apply_head_health_bar_fill_color(HP_COLOR_GREEN)


func _apply_head_health_bar_fill_color(color: Color) -> void:
	var fill_stylebox: StyleBoxFlat = _head_health_bar.get_theme_stylebox("fill")
	if fill_stylebox != null:
		var fill_copy: StyleBoxFlat = fill_stylebox.duplicate() as StyleBoxFlat
		fill_copy.bg_color = color
		_head_health_bar.add_theme_stylebox_override("fill", fill_copy)
