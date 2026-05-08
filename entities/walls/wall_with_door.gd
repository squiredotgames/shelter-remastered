extends Wall
class_name WallWithDoor
## A wall that doubles as the shelter's door. Passable during the day,
## sealed at night. Still takes mutant damage like a normal wall while sealed.

## Mirrors GameState.Phase.DAY (the autoload's enum value for daytime).
## Hard-coded to avoid a typed reference to the autoload script.
const PHASE_DAY: int = 0


func _ready() -> void:
	super._ready()
	GameState.phase_changed.connect(_on_phase_changed)
	_apply_phase(GameState.phase)


func _on_phase_changed(phase: int, _day_index: int) -> void:
	_apply_phase(phase)


func _apply_phase(phase: int) -> void:
	set_passable(phase == PHASE_DAY)
