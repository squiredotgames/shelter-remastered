extends Area2D
class_name Trap

## Bear trap:     max_charges = 1  — snaps shut on first enemy, stays closed on the map.
## Electric trap: max_charges = 5  — zaps up to 5 enemies, then goes dark on the map.
@export var max_charges: int = 1

var _charges: int = 0

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_charges = max_charges
	monitoring = true
	body_entered.connect(_on_body_entered)
	_sprite.play(&"default")


func _on_body_entered(body: Node2D) -> void:
	if not monitoring:
		return
	if not body.is_in_group("enemies"):
		return
	body.queue_free()
	_charges -= 1
	if _charges <= 0:
		_deactivate()


func _deactivate() -> void:
	monitoring = false
	monitorable = false
	# Bear trap has "activated" (snap-shut animation, loop=false) — play and freeze on last frame.
	# Electric trap has "off" (dark idle) — switch to it.
	if _sprite.sprite_frames.has_animation(&"activated"):
		_sprite.play(&"activated")
	elif _sprite.sprite_frames.has_animation(&"off"):
		_sprite.play(&"off")
