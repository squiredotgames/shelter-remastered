extends Node
## Autoload: AudioManager. Game music and pooled one-shot SFX (global and 2D).

const GAME_MUSIC_PATH: String = "res://audio/horrible.mp3"
const SFX_POOL_SIZE: int = 8
const SFX2D_POOL_SIZE: int = 8

var _music: AudioStreamPlayer
var _game_music_stream: AudioStream
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx2d_pool: Array[AudioStreamPlayer2D] = []


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.name = "GameMusic"
	add_child(_music)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		add_child(p)
		_sfx_pool.append(p)

	for j in SFX2D_POOL_SIZE:
		var p2 := AudioStreamPlayer2D.new()
		p2.name = "SFX2D_%d" % j
		add_child(p2)
		_sfx2d_pool.append(p2)


func start_game_music() -> void:
	if _music.playing:
		return
	if _game_music_stream == null:
		_game_music_stream = load(GAME_MUSIC_PATH) as AudioStream
		if _game_music_stream == null:
			push_error("AudioManager: could not load " + GAME_MUSIC_PATH)
			return
		_game_music_stream.loop = true
	_music.stream = _game_music_stream
	_music.play()


func stop_game_music() -> void:
	_music.stop()


func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if stream == null:
		return
	var player := _take_idle_sfx_player()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()


func play_sfx_2d(
	stream: AudioStream,
	global_position: Vector2,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	max_distance: float = 2000.0,
) -> void:
	if stream == null:
		return
	var player := _take_idle_sfx2d_player()
	player.global_position = global_position
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.max_distance = max_distance
	player.play()


func _take_idle_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_pool:
		if not p.playing:
			return p
	return _sfx_pool[0]


func _take_idle_sfx2d_player() -> AudioStreamPlayer2D:
	for p in _sfx2d_pool:
		if not p.playing:
			return p
	return _sfx2d_pool[0]
