extends Node2D
## Faint grid for movement reference. Workbench-only helper.

const STEP: int = 64
const HALF_EXTENT: int = 2000
const LINE_COLOR: Color = Color(1, 1, 1, 0.05)
const AXIS_COLOR: Color = Color(1, 1, 1, 0.20)

func _draw() -> void:
	for x in range(-HALF_EXTENT, HALF_EXTENT + 1, STEP):
		var c := AXIS_COLOR if x == 0 else LINE_COLOR
		draw_line(Vector2(x, -HALF_EXTENT), Vector2(x, HALF_EXTENT), c, 1.0)
	for y in range(-HALF_EXTENT, HALF_EXTENT + 1, STEP):
		var c := AXIS_COLOR if y == 0 else LINE_COLOR
		draw_line(Vector2(-HALF_EXTENT, y), Vector2(HALF_EXTENT, y), c, 1.0)
