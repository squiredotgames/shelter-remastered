extends CharacterBody2D
class_name Player

const WALK_ANIMATION: StringName = &"walk"
const IDLE_ANIMATION: StringName = &"idle"
const CLICK_ACTION: StringName = &"click"
const FLIP_THRESHOLD: float = 0.01

const TARGET_MARKER_SCENE: PackedScene = preload("res://entities/fx/target_marker.tscn")

@export var speed: float = 400.0
@export var stop_distance: float = 10.0
## Stop trying to reach the click if we barely move for this long (e.g. blocked by a rock).
@export var stuck_timeout_seconds: float = 2.0
## Max squared distance moved in one physics tick to count as "no progress" (world units²).
@export var stuck_movement_epsilon_sq: float = 0.0625

var target: Vector2

var _destination_marker: Node2D = null
var _stuck_time_seconds: float = 0.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	target = global_position


func reset_target() -> void:
	target = global_position
	_stuck_time_seconds = 0.0
	_hide_destination_marker()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(CLICK_ACTION):
		_stuck_time_seconds = 0.0
		target = get_global_mouse_position()
		_show_destination_marker_at(target)


func _physics_process(delta: float) -> void:
	if global_position.distance_to(target) <= stop_distance:
		velocity = Vector2.ZERO
		_stuck_time_seconds = 0.0
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
		if _stuck_time_seconds >= stuck_timeout_seconds:
			_abort_move_to_target()
			return
	else:
		_stuck_time_seconds = 0.0

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
	_hide_destination_marker()
	_play_animation(IDLE_ANIMATION)
