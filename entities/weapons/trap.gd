extends Area2D
class_name Trap

## Bear trap:     max_charges = 1  — snaps shut on first enemy, stays closed on the map.
## Electric trap: max_charges = 5  — zaps up to 5 enemies, then goes dark on the map.
@export var max_charges: int = 1
@export_flags_2d_physics var enemy_collision_mask: int = 4

const BEAR_SPLATTER_SFX_PATH: String = "res://audio/splatter.mp3"
const BEAR_TRAP_SFX_PATH: String = "res://audio/trap.mp3"
const ELECTRIC_KILL_SFX_PATH: String = "res://audio/electricitydeath.mp3"

var _charges: int = 0
var _is_electric: bool = false
var _bear_splatter_sfx: AudioStream = null
var _bear_trap_sfx: AudioStream = null
var _electric_kill_sfx: AudioStream = null

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_charges = max_charges
	_is_electric = max_charges > 1
	collision_mask = enemy_collision_mask
	monitoring = true
	body_entered.connect(_on_body_entered)
	_sprite.play(&"default")


func _on_body_entered(body: Node2D) -> void:
	if not monitoring:
		return
	if not body.is_in_group("enemies"):
		return
	if body.has_method("die_from_trap"):
		body.call("die_from_trap", _is_electric)
	else:
		body.queue_free()
	if _is_electric:
		_play_electric_kill_sfx()
	_charges -= 1
	if _charges <= 0:
		_deactivate()


func _deactivate() -> void:
	monitoring = false
	monitorable = false
	# Bear trap has "activated" (snap-shut animation, loop=false) — play and freeze on last frame.
	# Electric trap has "off" (dark idle) — switch to it.
	if _is_electric:
		if _sprite.sprite_frames.has_animation(&"electrified"):
			_sprite.play(&"electrified")
		elif _sprite.sprite_frames.has_animation(&"off"):
			_sprite.play(&"off")
	else:
		_play_bear_activation_sfx()
		if _sprite.sprite_frames.has_animation(&"killed"):
			_sprite.play(&"killed")
		elif _sprite.sprite_frames.has_animation(&"activated"):
			_sprite.play(&"activated")


func _play_bear_activation_sfx() -> void:
	if _is_electric:
		return
	if _bear_splatter_sfx == null:
		_bear_splatter_sfx = load(BEAR_SPLATTER_SFX_PATH) as AudioStream
	if _bear_trap_sfx == null:
		_bear_trap_sfx = load(BEAR_TRAP_SFX_PATH) as AudioStream
	AudioManager.play_sfx_2d(_bear_splatter_sfx, global_position)
	AudioManager.play_sfx_2d(_bear_trap_sfx, global_position)


func _play_electric_kill_sfx() -> void:
	if not _is_electric:
		return
	if _electric_kill_sfx == null:
		_electric_kill_sfx = load(ELECTRIC_KILL_SFX_PATH) as AudioStream
	AudioManager.play_sfx_2d(_electric_kill_sfx, global_position)
