extends Node2D
## Y-sort within a Y-sort enabled ancestor uses each item's effective Y in that
## ancestor's space. Godot's [code]y_sort_origin[/code] does NOT exist on plain
## [Node2D], so we instead move this node so its [b]global[/b] Y sits just above
## the player's, then counter-offset the child sprite so the artwork stays put.
##
## Place the decoration sprite as a child named "Sprite2D" of this Node2D.
## Works regardless of how deep this node and the player are nested, as long as
## they share a Y-sort enabled ancestor (each Node2D in the chain must also have
## [member CanvasItem.y_sort_enabled] = true).

@export var sprite_path: NodePath = ^"Sprite2D"

var _sprite: Node2D
var _base_global_position: Vector2


func _ready() -> void:
	_sprite = get_node(sprite_path) as Node2D
	_base_global_position = global_position


func _process(_delta: float) -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _sprite == null:
		global_position = _base_global_position
		_sprite.global_position = _base_global_position
		return

	# Sort just above the player → drawn earlier → ends up behind the player.
	global_position = Vector2(_base_global_position.x, player.global_position.y - 1.0)
	# Pin the visual back to the original world position.
	_sprite.global_position = _base_global_position
