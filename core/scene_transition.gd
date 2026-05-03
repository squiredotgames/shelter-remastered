extends CanvasLayer

const FADE_DURATION: float = 1

@onready var _overlay: ColorRect = $Overlay


func _ready() -> void:
	_overlay.color.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func change_scene_to_packed(scene: PackedScene) -> void:
	await fade_out()
	var error: int = get_tree().change_scene_to_packed(scene)
	if error != OK:
		push_error("Failed to change scene: %d" % error)
	await fade_in()


func change_scene_to_file(path: String) -> void:
	await fade_out()
	var error: int = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Failed to change scene: " + path)
	await fade_in()


func fade_out() -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, FADE_DURATION)
	await tween.finished


func fade_in() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, FADE_DURATION)
	await tween.finished
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
