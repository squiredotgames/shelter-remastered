extends Node2D

@export var flight_duration_seconds: float = 0.6
@export var impact_distance: float = 8.0
@export var arc_height: float = 36.0
@export var spin_speed_degrees: float = 500.0

var _target: Vector2 = Vector2.ZERO
var _is_flying: bool = false
var _start_position: Vector2 = Vector2.ZERO
var _travel_duration: float = 0.0
var _elapsed_time: float = 0.0


func launch_to(target_position: Vector2) -> void:
	_start_position = global_position
	_target = target_position
	_travel_duration = maxf(0.001, flight_duration_seconds)
	_elapsed_time = 0.0
	_is_flying = true


func _process(delta: float) -> void:
	if not _is_flying:
		return
	rotation += deg_to_rad(spin_speed_degrees) * delta
	_elapsed_time += delta
	var progress: float = clampf(_elapsed_time / _travel_duration, 0.0, 1.0)
	var base_position: Vector2 = _start_position.lerp(_target, progress)
	# Parabolic arc peaking at the midpoint (progress = 0.5).
	var arc_offset_y: float = -4.0 * arc_height * progress * (1.0 - progress)
	global_position = base_position + Vector2(0.0, arc_offset_y)
	if progress >= 1.0 or global_position.distance_to(_target) <= impact_distance:
		global_position = _target
		_impact()


func _impact() -> void:
	_is_flying = false
	# Placeholder for future fire/explosion logic.
	queue_free()
