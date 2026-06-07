extends StaticBody2D
class_name Wall

enum Orientation {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
	CORNER_TL,
	CORNER_TR,
	CORNER_BL,
	CORNER_BR,
}

## 0 = intact … 5 = destroyed. Matches folder order under res://sprites/Walls/.
const _TIER_FOLDER: Array[String] = [
	"No Damage/",
	"Damaged/Tier I/",
	"Damaged/Tier II/",
	"Damaged/Tier III/",
	"Damaged/Tier IV/",
	"Destroyed/",
]
const _TIER_PREFIX: Array[String] = [
	"wall nd ",
	"wall d ",
	"wall d2 ",
	"wall d3 ",
	"wall d4 ",
	"wall d5 ",
]
const _TIER_THRESH: Array[float] = [0.8, 0.6, 0.4, 0.2, 0.0]

const _SPRITES := "res://sprites/Walls/"
const _BREAK_SFX_PATH: String = "res://audio/walls/break.wav"
const _BREAK_SFX_VOLUME_DB: float = 1.5
const _HIT_SFX_VOLUME_DB: float = -2.0
## Draw rubble below actors but above ground tiles (which sit at z -2).
const _DESTROYED_Z_INDEX: int = -1
const _DEFAULT_Z_INDEX: int = 0

signal health_changed(current_health: int, max_health: int)
signal wall_destroyed

## Set per wall_* scene (top / left / corner …).
@export var orientation := Orientation.TOP
@export var max_health: int = 100

## Max enemies that can claim attack slots on this wall at once.
## Walls are 48px along their tangent; capacity 2 places attackers at ±12.
const ATTACKER_CAPACITY: int = 2
## Distance (px) between adjacent attacker slots along the wall's tangent.
const ATTACKER_SLOT_SPREAD: float = 24.0
## Push attacker slot targets to the outside wall face (center -> face = 8 px for 16 px thick walls).
const ATTACKER_APPROACH_OFFSET: float = 8.0

var _health: int
var _tier: int = 0
var _attackers: Array[Node] = []
var _break_sfx_stream: AudioStream = null
var _hit_sfx_stream: AudioStream = null

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("walls")
	_health = max_health
	_refresh_texture()
	_update_draw_order()


func take_damage(amount: int) -> void:
	if _is_corner() or _health <= 0:
		return
	if _hit_sfx_stream == null:
		_hit_sfx_stream = load(_BREAK_SFX_PATH) as AudioStream
	AudioManager.play_sfx_2d(_hit_sfx_stream, global_position, _HIT_SFX_VOLUME_DB)
	_set_health(_health - amount)


func repair(amount: int) -> void:
	if _is_corner() or _health <= 0:
		return
	_set_health(_health + amount)


func fully_repair() -> void:
	if _is_corner():
		return
	_health = max_health
	_tier = 0
	_collision.set_deferred("disabled", false)
	health_changed.emit(_health, max_health)
	_refresh_texture()
	_update_draw_order()


func is_destroyed() -> bool:
	return _health <= 0


## True if an attacker slot is available (not corner, not destroyed, under capacity).
func can_be_claimed() -> bool:
	if _is_corner() or is_destroyed():
		return false
	_prune_stale_attackers()
	return _attackers.size() < ATTACKER_CAPACITY


## Reserve an attacker slot. Idempotent if `enemy` already holds one.
## Returns false if the wall is full / unclaimable.
func claim(enemy: Node) -> bool:
	if not can_be_claimed():
		return _attackers.has(enemy)
	if not _attackers.has(enemy):
		_attackers.append(enemy)
	return true


func release(enemy: Node) -> void:
	_attackers.erase(enemy)


## World position the given attacker should walk to. Slots are spread along the
## wall's tangent based on the attacker's index in `_attackers` so multiple
## enemies on the same wall fan out instead of stacking. Falls back to the
## wall's center if `enemy` hasn't claimed.
func slot_position_for(enemy: Node) -> Vector2:
	_prune_stale_attackers()
	var idx: int = _attackers.find(enemy)
	if idx == -1:
		return global_position + _outward_axis() * ATTACKER_APPROACH_OFFSET
	var count: int = _attackers.size()
	var offset_steps: float = float(idx) - float(count - 1) * 0.5
	return (
		global_position
		+ _tangent_axis() * (offset_steps * ATTACKER_SLOT_SPREAD)
		+ _outward_axis() * ATTACKER_APPROACH_OFFSET
	)


func _tangent_axis() -> Vector2:
	match orientation:
		Orientation.TOP, Orientation.BOTTOM:
			return Vector2(1.0, 0.0)
		_:
			return Vector2(0.0, 1.0)


func _outward_axis() -> Vector2:
	match orientation:
		Orientation.TOP:
			return Vector2(0.0, -1.0)
		Orientation.BOTTOM:
			return Vector2(0.0, 1.0)
		Orientation.LEFT:
			return Vector2(-1.0, 0.0)
		Orientation.RIGHT:
			return Vector2(1.0, 0.0)
		_:
			return Vector2.ZERO


func _prune_stale_attackers() -> void:
	var i: int = _attackers.size() - 1
	while i >= 0:
		if not is_instance_valid(_attackers[i]):
			_attackers.remove_at(i)
		i -= 1


## Alpha applied to the wall sprite while it is set passable (door open look).
const PASSABLE_SPRITE_ALPHA: float = 0.35

## Toggle whether the wall is currently walk-through.
## Used by door-style subclasses; no-op once the wall is destroyed
## (a destroyed wall is permanently passable regardless of phase).
func set_passable(passable: bool) -> void:
	if is_destroyed():
		return
	_collision.set_deferred("disabled", passable)
	if _sprite:
		_sprite.modulate.a = PASSABLE_SPRITE_ALPHA if passable else 1.0


func _is_corner() -> bool:
	return orientation >= Orientation.CORNER_TL


func _set_health(value: int) -> void:
	_health = clampi(value, 0, max_health)
	health_changed.emit(_health, max_health)

	var t: int = _tier_from_health()
	if t == _tier:
		return
	_tier = t
	_refresh_texture()
	_update_draw_order()
	if _tier == 5:
		_collision.set_deferred("disabled", true)
		if _break_sfx_stream == null:
			_break_sfx_stream = load(_BREAK_SFX_PATH) as AudioStream
		AudioManager.play_sfx_2d(_break_sfx_stream, global_position, _BREAK_SFX_VOLUME_DB)
		wall_destroyed.emit()


func _tier_from_health() -> int:
	if _health <= 0:
		return 5
	var ratio: float = float(_health) / float(max_health)
	for i: int in _TIER_THRESH.size():
		if ratio > _TIER_THRESH[i]:
			return i
	return 5


func _refresh_texture() -> void:
	if _sprite == null:
		return
	var path: String = _texture_path()
	if path.is_empty():
		return
	var tex: Texture2D = load(path) as Texture2D
	if tex:
		_sprite.texture = tex
	elif not path.is_empty():
		push_error("Wall: missing texture %s" % path)


func _texture_path() -> String:
	if _is_corner():
		match orientation:
			Orientation.CORNER_TL:
				return _SPRITES + "corner01.png"
			Orientation.CORNER_TR:
				return _SPRITES + "corner02.png"
			Orientation.CORNER_BL:
				return _SPRITES + "corner03.png"
			_:
				return _SPRITES + "corner04.png"

	match orientation:
		Orientation.TOP:
			return _SPRITES + _TIER_FOLDER[_tier] + _TIER_PREFIX[_tier] + "top.png"
		Orientation.BOTTOM:
			return _SPRITES + _TIER_FOLDER[_tier] + _TIER_PREFIX[_tier] + "bot.png"
		Orientation.LEFT:
			return _SPRITES + _TIER_FOLDER[_tier] + _TIER_PREFIX[_tier] + "left.png"
		_:
			return _SPRITES + _TIER_FOLDER[_tier] + _TIER_PREFIX[_tier] + "right.png"


func _update_draw_order() -> void:
	# Rubble is floor debris: pin it below actors (z -1) so player/ghouls always
	# walk over a breach. Ground tiles sit lower still (z -2) so rubble stays
	# above the grass. Intact walls keep z 0 and Y-sort with the actors.
	z_index = _DESTROYED_Z_INDEX if is_destroyed() else _DEFAULT_Z_INDEX
