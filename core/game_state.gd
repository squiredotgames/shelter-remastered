extends Node
## Autoload: GameState. Owns the day/night phase clock and run progression.
##
## Other systems (HUD, spawner, door, win/lose screens) react via signals;
## nothing reaches into this node directly.

enum Phase { DAY, NIGHT }

signal phase_changed(phase: int, day_index: int)
signal day_tick(time_left_seconds: float)
signal run_won
signal run_lost

const TOTAL_NIGHTS: int = 4
const DAY_DURATION_SECONDS: float = 45.0

var phase: int = Phase.DAY
var day_index: int = 1

var _day_time_left: float = 0.0
var _wave_active: bool = false
var _run_active: bool = false


func start_run() -> void:
	day_index = 1
	_run_active = true
	set_process(true)
	_enter_day()


func _process(delta: float) -> void:
	if not _run_active or phase != Phase.DAY:
		return
	_day_time_left = maxf(0.0, _day_time_left - delta)
	day_tick.emit(_day_time_left)
	if _day_time_left <= 0.0:
		_enter_night()


## Called by the spawner when the night's wave hits zero mutants alive.
func notify_wave_cleared() -> void:
	if not _run_active or phase != Phase.NIGHT or not _wave_active:
		return
	_wave_active = false
	if day_index >= TOTAL_NIGHTS:
		_run_active = false
		run_won.emit()
		return
	day_index += 1
	_enter_day()


## Called by the player when HP reaches 0.
func notify_player_died() -> void:
	if not _run_active:
		return
	_run_active = false
	set_process(false)
	run_lost.emit()


## Debug helper bound to the `phase_skip` input action.
## In DAY: forces dawn-to-dusk by zeroing the timer.
## In NIGHT: pretends the wave was cleared.
func debug_advance() -> void:
	if not _run_active:
		return
	if phase == Phase.DAY:
		_day_time_left = 0.0
	else:
		notify_wave_cleared()


func get_day_time_left() -> float:
	return _day_time_left


func _enter_day() -> void:
	phase = Phase.DAY
	_day_time_left = DAY_DURATION_SECONDS
	phase_changed.emit(phase, day_index)


func _enter_night() -> void:
	phase = Phase.NIGHT
	_wave_active = true
	phase_changed.emit(phase, day_index)
