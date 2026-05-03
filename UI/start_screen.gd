extends Control
class_name StartScreen

const GAME_SCENE: PackedScene = preload("res://core/game.tscn")
const SCENE_TRANSITION_PATH: NodePath = ^"/root/SceneTransition"


func _on_play_button_pressed() -> void:
	var transition: Node = get_node(SCENE_TRANSITION_PATH)
	await transition.call("change_scene_to_packed", GAME_SCENE)
