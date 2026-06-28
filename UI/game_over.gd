extends CanvasLayer
class_name GameOverScreen
## Overlay shown when the run is lost (the player died). Reads the final run
## stats from GameState, displays them, and returns to the main menu.

const START_SCREEN_PATH: String = "res://UI/start_screen.tscn"
const SCENE_TRANSITION_PATH: NodePath = ^"/root/SceneTransition"

@onready var _days_label: Label = $Center/Panel/Margin/VBoxContainer/Stats/DaysLabel
@onready var _time_label: Label = $Center/Panel/Margin/VBoxContainer/Stats/TimeLabel
@onready var _mutants_label: Label = $Center/Panel/Margin/VBoxContainer/Stats/MutantsLabel
@onready var _supplies_label: Label = $Center/Panel/Margin/VBoxContainer/Stats/SuppliesLabel
@onready var _main_menu_button: Button = $Center/Panel/Margin/VBoxContainer/MainMenuButton


func _ready() -> void:
	_populate_stats()
	_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	_main_menu_button.grab_focus()


func _populate_stats() -> void:
	_days_label.text = "Reached Day %d / %d" % [GameState.day_index, GameState.TOTAL_NIGHTS]
	_time_label.text = "Survived %s" % _format_mm_ss(GameState.get_survival_time_seconds())
	_mutants_label.text = "Mutants killed: %d" % GameState.mutants_killed
	_supplies_label.text = "Supplies collected: %d" % GameState.total_supplies_collected


func _format_mm_ss(seconds: float) -> String:
	var total: int = maxi(0, int(floor(seconds)))
	var m: int = int(total / 60.0)
	var s: int = total % 60
	return "%d:%02d" % [m, s]


func _on_main_menu_button_pressed() -> void:
	var transition: Node = get_node(SCENE_TRANSITION_PATH)
	await transition.call("change_scene_to_file", START_SCREEN_PATH)
