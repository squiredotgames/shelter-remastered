extends Node2D
class_name Game

const LEVELS_PATH: String = "res://levels/"
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

var _current_level: Node = null
var _player: Player = null

func _ready() -> void:
	load_level("level_01")


func load_level(level_name: String) -> void:
	_remove_player_from_level()

	if _current_level:
		_current_level.queue_free()
		_current_level = null

	var level_path: String = LEVELS_PATH + level_name + ".tscn"
	var level_scene: PackedScene = load(level_path) as PackedScene
	if not level_scene:
		push_error("Failed to load level: " + level_path)
		return

	_current_level = level_scene.instantiate()
	add_child(_current_level)
	move_child(_current_level, 0)

	_add_player_to_level()


func _add_player_to_level() -> void:
	var entities: Node2D = _current_level.get_node_or_null("Entities") as Node2D
	if not entities:
		push_error("Level is missing an Entities node")
		return

	if not _player:
		_player = PLAYER_SCENE.instantiate() as Player

	entities.add_child(_player)

	var spawn: Marker2D = _current_level.get_node_or_null("SpawnPoint") as Marker2D
	if spawn:
		_player.global_position = spawn.global_position
	_player.reset_target()


func _remove_player_from_level() -> void:
	if _player and _player.get_parent():
		_player.get_parent().remove_child(_player)
