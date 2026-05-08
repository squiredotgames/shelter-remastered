extends Node2D
class_name MutantSpawner
## Spawns enemies at intervals from the level's `EnemySpawnPoints` markers.
## Add an instance to the level on NIGHT, free it on DAY.
##
## v1: stub wave config (count + interval). Will be replaced by `wave_data.gd`
## per IMPROVEMENTS.md step 5 once the resource is added.

const ENEMY_SCENE: PackedScene = preload("res://entities/enemies/enemy.tscn")

## How many mutants to spawn this wave (cycles through spawn markers in order).
@export var spawn_count: int = 5
@export var spawn_interval_seconds: float = 2.5
## Path (relative to the level root) to the node holding spawn `Marker2D`s.
@export var spawn_points_path: NodePath = ^"EnemySpawnPoints"
## Path (relative to the level root) where spawned enemies should be parented.
@export var enemies_container_path: NodePath = ^"Entities"

var _spawn_points: Array[Marker2D] = []
var _enemies_container: Node = null
var _spawned_count: int = 0
var _timer: Timer


func _ready() -> void:
	_resolve_paths()
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.wait_time = spawn_interval_seconds
	_timer.timeout.connect(_on_spawn_tick)
	add_child(_timer)
	_timer.start()
	_spawn_one()


func _resolve_paths() -> void:
	var level_root: Node = get_parent()
	if level_root == null:
		push_error("MutantSpawner has no parent; expected to be added under the level root")
		return

	var points_node: Node = level_root.get_node_or_null(spawn_points_path)
	if points_node:
		for child: Node in points_node.get_children():
			var marker: Marker2D = child as Marker2D
			if marker:
				_spawn_points.append(marker)
	if _spawn_points.is_empty():
		push_error("MutantSpawner: no spawn markers found at " + str(spawn_points_path))

	_enemies_container = level_root.get_node_or_null(enemies_container_path)
	if _enemies_container == null:
		push_error("MutantSpawner: enemies container not found at " + str(enemies_container_path))


func _on_spawn_tick() -> void:
	if _spawned_count >= spawn_count:
		_timer.stop()
		return
	_spawn_one()


func _spawn_one() -> void:
	if _spawn_points.is_empty() or _enemies_container == null:
		return
	var marker: Marker2D = _spawn_points[_spawned_count % _spawn_points.size()]
	var enemy: Node2D = ENEMY_SCENE.instantiate() as Node2D
	# Place before entering the tree to avoid a one-frame render at origin.
	enemy.global_position = marker.global_position
	_enemies_container.add_child(enemy)
	_spawned_count += 1
