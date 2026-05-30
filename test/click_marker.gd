extends Node2D
## Visual marker for the current click-to-move target.

const RADIUS: float = 6.0
const COLOR: Color = Color(0.95, 0.75, 0.30, 0.80)

func _draw() -> void:
	# Hollow ring + cross-hair
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, COLOR, 1.5)
	draw_line(Vector2(-RADIUS - 2, 0), Vector2(RADIUS + 2, 0), COLOR, 1.0)
	draw_line(Vector2(0, -RADIUS - 2), Vector2(0, RADIUS + 2), COLOR, 1.0)
