extends Node2D

const RADIUS: float = 2.0

func _ready() -> void:
	z_index = 100
	visible = false


func _draw() -> void:
	draw_arc(Vector2.ZERO, RADIUS + 1.0, 0.0, TAU, 16, Color(1, 1, 1, 0.7), 1.0, true)
