extends Control
## HUD under Game: day index, day countdown, night elapsed time, and action hotbar.

const COLOR_ACTIVE: Color = Color(1.0, 0.85, 0.2)    # yellow highlight
const COLOR_INACTIVE: Color = Color(0.55, 0.55, 0.55) # dim grey

@onready var _day_counter: Label = $MarginContainer/VBoxContainer/StatsRow/DayCounterLabel
@onready var _phase_time: Label = $MarginContainer/VBoxContainer/StatsRow/PhaseTimeLabel

@onready var _slot_labels: Array[Label] = [
	$HotbarRow/Slot1/Label,
	$HotbarRow/Slot2/Label,
	$HotbarRow/Slot3/Label,
	$HotbarRow/Slot4/Label,
]


func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.day_tick.connect(_on_day_tick)
	GameState.night_tick.connect(_on_night_tick)
	call_deferred("_sync_initial")
	set_active_mode(Player.Mode.MOVE_REPAIR)


func _sync_initial() -> void:
	_on_phase_changed(GameState.phase, GameState.day_index)
	if GameState.phase == GameState.Phase.DAY:
		_on_day_tick(GameState.get_day_time_left())
	else:
		_on_night_tick(GameState.get_night_elapsed())


## Called by Game when the player switches hotbar slot.
func set_active_mode(mode: Player.Mode) -> void:
	for i: int in _slot_labels.size():
		_slot_labels[i].add_theme_color_override(
			"font_color",
			COLOR_ACTIVE if i == mode else COLOR_INACTIVE
		)


func _on_phase_changed(phase: int, day_idx: int) -> void:
	_day_counter.text = "Day %d / %d" % [day_idx, GameState.TOTAL_NIGHTS]
	if phase == GameState.Phase.DAY:
		_phase_time.text = _format_mm_ss(GameState.get_day_time_left())
	else:
		_phase_time.text = "Night %s" % _format_mm_ss(GameState.get_night_elapsed())


func _on_day_tick(time_left_seconds: float) -> void:
	if GameState.phase != GameState.Phase.DAY:
		return
	_phase_time.text = _format_mm_ss(time_left_seconds)


func _on_night_tick(elapsed_seconds: float) -> void:
	if GameState.phase != GameState.Phase.NIGHT:
		return
	_phase_time.text = "Night %s" % _format_mm_ss(elapsed_seconds)


func _format_mm_ss(seconds: float) -> String:
	var total: int = maxi(0, int(floor(seconds)))
	var m: int = int(total / 60.0)
	var s: int = total % 60
	return "%d:%02d" % [m, s]
