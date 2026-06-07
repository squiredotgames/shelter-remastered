extends Area2D

@export var supplies_count: int = 3

const _PICKUP_STREAM_PATHS: Array[String] = [
	"res://audio/player/leather_inventory.wav",
	"res://audio/player/cloth-inventory.wav",
]

func _ready() -> void:
	collision_mask = 1 << 1  # Detect only the player physics layer (layer 2).
	body_entered.connect(_on_body_entered)


func _on_area_exited(_area: Area2D) -> void:
	pass

func _on_area_entered(_area: Area2D) -> void:
	pass


func _on_body_entered(body: Node) -> void:
	var player := body as Player
	if player == null:
		return
	var pickup_stream_path: String = _PICKUP_STREAM_PATHS[randi_range(0, _PICKUP_STREAM_PATHS.size() - 1)]
	var pickup_stream: AudioStream = load(pickup_stream_path) as AudioStream
	AudioManager.play_sfx_2d(pickup_stream, global_position)
	GameState.add_supplies(supplies_count)
	queue_free()

