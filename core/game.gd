extends Node2D
class_name Game

const LEVELS_PATH: String = "res://levels/"
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")

const TINT_FADE_SECONDS: float = 1.5
const DAY_TINT: Color = Color(0, 0, 0, 0)
const NIGHT_TINT: Color = Color(0.05, 0.05, 0.15, 0.55)

var _current_level: Node = null
var _player: Player = null
var _tint_tween: Tween = null

@onready var _tint: ColorRect = $TintOverlay/Rect


func _ready() -> void:
	AudioManager.start_game_music()
	load_level("level_01")

	GameState.phase_changed.connect(_on_phase_changed)
	GameState.run_won.connect(_on_run_won)
	GameState.run_lost.connect(_on_run_lost)

	_tint.color = DAY_TINT
	GameState.start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phase_skip"):
		GameState.debug_advance()


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


func _on_phase_changed(phase: int, day_index: int) -> void:
	var night: bool = phase == GameState.Phase.NIGHT
	_fade_tint(NIGHT_TINT if night else DAY_TINT)
	if night:
		_spawn_wave_for_night(day_index)


## Stub: replaced by the real MutantSpawner in step 5 of IMPROVEMENTS.md.
## Auto-clears after a short delay so the 4-night loop runs end-to-end
## before any enemy code exists.
func _spawn_wave_for_night(day_index: int) -> void:
	var seconds: float = 3.0 + float(day_index)
	var timer: SceneTreeTimer = get_tree().create_timer(seconds)
	timer.timeout.connect(GameState.notify_wave_cleared)


func _fade_tint(target: Color) -> void:
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint, "color", target, TINT_FADE_SECONDS)


func _on_run_won() -> void:
	# TODO step 13: show UI/win_screen.tscn
	print("[Game] Run won — dawn breaks.")


func _on_run_lost() -> void:
	# TODO step 13: show UI/game_over.tscn
	print("[Game] Run lost.")
