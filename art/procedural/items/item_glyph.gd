class_name ItemGlyph extends Node2D
## Tiny procedural per-slot glyph. Stage 4 placeholder; bitmap icons
## replace it later per the asset-pipeline rule.

enum Shape { SQUARE, TRIANGLE, DIAMOND, CIRCLE }

const RADIUS: float = 8.0

@export var color: Color = Color(0.85, 0.78, 0.55)
@export var shape: Shape = Shape.SQUARE

func _draw() -> void:
	var poly: PackedVector2Array = []
	match shape:
		Shape.SQUARE:
			poly = PackedVector2Array([
				Vector2(-RADIUS, -RADIUS), Vector2(RADIUS, -RADIUS),
				Vector2(RADIUS, RADIUS),   Vector2(-RADIUS, RADIUS),
			])
		Shape.TRIANGLE:
			poly = PackedVector2Array([
				Vector2(0, -RADIUS), Vector2(RADIUS, RADIUS), Vector2(-RADIUS, RADIUS),
			])
		Shape.DIAMOND:
			poly = PackedVector2Array([
				Vector2(0, -RADIUS), Vector2(RADIUS, 0),
				Vector2(0, RADIUS), Vector2(-RADIUS, 0),
			])
		Shape.CIRCLE:
			var n := 16
			for i in n:
				var t := TAU * i / n
				poly.append(Vector2(RADIUS * cos(t), RADIUS * sin(t)))
	draw_colored_polygon(poly, color)
	# Outline for legibility on dark backgrounds
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_polyline(outline, Color(0, 0, 0, 0.6), 1.0)

func set_shape(s: Shape) -> void:
	shape = s
	queue_redraw()

func set_color_glyph(c: Color) -> void:
	color = c
	queue_redraw()
