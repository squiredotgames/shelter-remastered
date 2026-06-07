extends Area2D

@export var supplies_count: int = 3

const _PICKUP_STREAM_PATHS: Array[String] = [
	"res://audio/player/leather_inventory.wav",
	"res://audio/player/cloth-inventory.wav",
]
const BONUS_MOLOTOV_SFX_PATH: String = "res://audio/player/metal-clash.wav"
const BONUS_MOLOTOV_CHANCE_DENOMINATOR: int = 10
const BONUS_POPUP_TEXT: String = "+1 Molotov"
const BONUS_POPUP_LIFETIME_SECONDS: float = 0.6
const BONUS_POPUP_RISE_DISTANCE: float = 20.0

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
	if randi_range(1, BONUS_MOLOTOV_CHANCE_DENOMINATOR) == 1:
		if player.add_molotovs(1):
			var bonus_stream: AudioStream = load(BONUS_MOLOTOV_SFX_PATH) as AudioStream
			AudioManager.play_sfx_2d(bonus_stream, global_position)
			_show_bonus_molotov_popup()
	queue_free()


func _show_bonus_molotov_popup() -> void:
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return
	var popup: Label = Label.new()
	popup.text = BONUS_POPUP_TEXT
	popup.global_position = global_position + Vector2(0.0, -12.0)
	popup.modulate = Color(1.0, 0.85, 0.2, 1.0)
	parent_node.add_child(popup)
	var tween: Tween = popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		popup,
		"global_position",
		popup.global_position + Vector2(0.0, -BONUS_POPUP_RISE_DISTANCE),
		BONUS_POPUP_LIFETIME_SECONDS,
	)
	tween.tween_property(popup, "modulate:a", 0.0, BONUS_POPUP_LIFETIME_SECONDS)
	tween.finished.connect(func() -> void:
		if is_instance_valid(popup):
			popup.queue_free()
	)

