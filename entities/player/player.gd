extends CharacterBody2D
class_name Player

const WALK_ANIMATION: StringName = &"walk"
const IDLE_ANIMATION: StringName = &"idle"
const CLICK_ACTION: StringName = &"click"
const FLIP_THRESHOLD: float = 0.01

const TARGET_MARKER_SCENE: PackedScene = preload("res://entities/fx/target_marker.tscn")

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

@export var speed: float = 400.0
@export var stop_distance: float = 10.0
## Stop trying to reach the click if we barely move for this long (e.g. blocked by a rock).
@export var stuck_timeout_seconds: float = 2.0
## Max squared distance moved in one physics tick to count as "no progress" (world units²).
@export var stuck_movement_epsilon_sq: float = 0.0625
## Time between footstep sounds while walking (only when actually moving).
@export var footstep_interval_seconds: float = 0.38
@export var footstep_volume_db: float = 8.0

var target: Vector2

var _destination_marker: Node2D = null
var _stuck_time_seconds: float = 0.0
var _footstep_phase_seconds: float = 0.0
## False until the first real movement after idle/stuck/new click; then interval cadence.
var _footstep_in_walk_cadence: bool = false

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("player")
	target = global_position


func reset_target() -> void:
	target = global_position
	_stuck_time_seconds = 0.0
	_footstep_phase_seconds = 0.0
	_footstep_in_walk_cadence = false
	_hide_destination_marker()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(CLICK_ACTION):
		_stuck_time_seconds = 0.0
		_footstep_in_walk_cadence = false
		target = get_global_mouse_position()
		_show_destination_marker_at(target)


func _physics_process(delta: float) -> void:
	if global_position.distance_to(target) <= stop_distance:
		velocity = Vector2.ZERO
		_stuck_time_seconds = 0.0
		_footstep_phase_seconds = 0.0
		_footstep_in_walk_cadence = false
		_hide_destination_marker()
		_play_animation(IDLE_ANIMATION)
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


func _play_animation(animation_name: StringName) -> void:
	if _animated_sprite.animation == animation_name:
		return
	_animated_sprite.play(animation_name)


func _update_sprite_facing(direction: Vector2) -> void:
	if abs(direction.x) <= FLIP_THRESHOLD:
		return
	_animated_sprite.flip_h = direction.x > 0.0


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


func _play_footstep() -> void:
	var stream: AudioStream = _FOOTSTEP_STREAMS[randi_range(0, _FOOTSTEP_STREAMS.size() - 1)]
	AudioManager.play_sfx_2d(stream, global_position, footstep_volume_db)
