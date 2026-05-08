extends Node2D
## Level 01 controller. Owns the navigation mesh: bakes it from world-layer
## static colliders on load, and re-bakes whenever a wall is destroyed so
## newly-opened breaches become walkable for enemy NavigationAgents.

@onready var _nav_region: NavigationRegion2D = $NavigationRegion2D


func _ready() -> void:
	_connect_walls()
	_rebake_nav()


func _connect_walls() -> void:
	for node: Node in get_tree().get_nodes_in_group("walls"):
		var wall: Wall = node as Wall
		if wall == null:
			continue
		wall.wall_destroyed.connect(_on_any_wall_destroyed)


func _on_any_wall_destroyed() -> void:
	_rebake_nav()


func _rebake_nav() -> void:
	if _nav_region == null:
		return
	_nav_region.bake_navigation_polygon(true)
