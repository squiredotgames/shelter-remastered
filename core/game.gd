extends Node2D
class_name Game

const LEVELS_PATH: String = "res://levels/"
const PLAYER_SCENE: PackedScene = preload("res://entities/player/player.tscn")
const MUTANT_SPAWNER_SCENE: PackedScene = preload("res://entities/enemies/mutant_spawner.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://UI/game_over.tscn")

## Delay before the game over screen appears, so the death animation can play.
const GAME_OVER_DELAY_SECONDS: float = 1.5

const TINT_FADE_SECONDS: float = 1.5
const DAY_TINT: Color = Color(0, 0, 0, 0)
const NIGHT_TINT: Color = Color(0.05, 0.05, 0.15, 0.55)
const NIGHT_FIRST_SPAWN_DELAY_SECONDS: float = 5.0
const NIGHT_HOWL_SFX_PATH: String = "res://audio/zombie/zombie howl.wav"
const NIGHT_HOWL_VOLUME_DB: float = -1.0

var _current_level: Node = null
var _player: Player = null
var _tint_tween: Tween = null
var _mutant_spawner: Node = null
var _night_howl_stream: AudioStream = null
var _night_spawn_delay_timer: Timer = null
var _game_over_screen: CanvasLayer = null

@onready var _tint: ColorRect = $TintOverlay/Rect
@onready var _hud: Control = $HUDCanvas/HudRoot


func _ready() -> void:
	AudioManager.start_game_music()
	load_level("level_01")
	_night_spawn_delay_timer = Timer.new()
	_night_spawn_delay_timer.one_shot = true
	_night_spawn_delay_timer.wait_time = NIGHT_FIRST_SPAWN_DELAY_SECONDS
	_night_spawn_delay_timer.timeout.connect(_on_night_spawn_delay_timeout)
	add_child(_night_spawn_delay_timer)

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
		_player.mode_changed.connect(func(mode: Player.Mode) -> void:
			if is_instance_valid(_hud):
				_hud.call("set_active_mode", mode)
		)
		_player.molotov_count_changed.connect(func(count: int) -> void:
			if is_instance_valid(_hud):
				_hud.call("set_molotov_count", count)
		)
		_player.action_warning_requested.connect(func(message: String) -> void:
			if is_instance_valid(_hud):
				_hud.call("show_warning", message)
		)

	entities.add_child(_player)

	var spawn: Marker2D = _current_level.get_node_or_null("SpawnPoint") as Marker2D
	if spawn:
		_player.global_position = spawn.global_position
	_player.reset_target()
	if is_instance_valid(_hud):
		_hud.call("set_molotov_count", _player.get_molotov_count())


func _remove_player_from_level() -> void:
	if _player and _player.get_parent():
		_player.get_parent().remove_child(_player)


func _on_phase_changed(phase: int, _day_index: int) -> void:
	var night: bool = phase == GameState.Phase.NIGHT
	_fade_tint(NIGHT_TINT if night else DAY_TINT)
	if night:
		_play_night_howl()
		_start_mutant_spawner_after_delay()
	else:
		if _night_spawn_delay_timer != null:
			_night_spawn_delay_timer.stop()
		_stop_mutant_spawner()


func _start_mutant_spawner() -> void:
	if _current_level == null:
		return
	_stop_mutant_spawner()
	_mutant_spawner = MUTANT_SPAWNER_SCENE.instantiate()
	_current_level.add_child(_mutant_spawner)


func _stop_mutant_spawner() -> void:
	if _mutant_spawner and is_instance_valid(_mutant_spawner):
		_mutant_spawner.queue_free()
	_mutant_spawner = null


func _fade_tint(target: Color) -> void:
	if _tint_tween and _tint_tween.is_valid():
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint, "color", target, TINT_FADE_SECONDS)


func _on_run_won() -> void:
	# TODO step 13: show UI/win_screen.tscn
	print("[Game] Run won — dawn breaks.")


func _on_run_lost() -> void:
	_stop_mutant_spawner()
	if _night_spawn_delay_timer != null:
		_night_spawn_delay_timer.stop()
	await get_tree().create_timer(GAME_OVER_DELAY_SECONDS).timeout
	if _game_over_screen != null:
		return
	AudioManager.stop_game_music()
	_game_over_screen = GAME_OVER_SCENE.instantiate() as CanvasLayer
	add_child(_game_over_screen)


func _play_night_howl() -> void:
	if _night_howl_stream == null:
		_night_howl_stream = load(NIGHT_HOWL_SFX_PATH) as AudioStream
	AudioManager.play_sfx(_night_howl_stream, NIGHT_HOWL_VOLUME_DB)


func _start_mutant_spawner_after_delay() -> void:
	_stop_mutant_spawner()
	if _night_spawn_delay_timer == null:
		return
	_night_spawn_delay_timer.start(NIGHT_FIRST_SPAWN_DELAY_SECONDS)


func _on_night_spawn_delay_timeout() -> void:
	if GameState.phase != GameState.Phase.NIGHT:
		return
	_start_mutant_spawner()
