extends Node2D

## Walk / click destination — solid dot sized for 480×270 scaled up (integer stretch).

func _ready() -> void:
	z_index = 100
	visible = false


func _draw() -> void:
	var c := Vector2.ZERO
	# Radii in game units — ~6px diameter at base res reads clearly after viewport scale.
	draw_circle(c, 2.8, Color(0.06, 0.08, 0.14, 0.92))
	draw_circle(c, 2.0, Color(0.28, 0.52, 0.72, 0.55))
	draw_circle(c, 1.15, Color(1.0, 1.0, 1.0, 1.0))
