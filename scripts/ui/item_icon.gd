class_name ItemIcon extends Control
## Stage 16 — Control-based per-item icon for the inventory grid.
## Procedural baseline: draws ItemGlyph's shape inside a tier-colored
## ring. AI bitmap polish (Stage 11) plugs in via a sidecar PNG at
## res://data/icons/<item_id>.png when present.

const CELL_SIZE: Vector2 = Vector2(40, 40)
const SHAPE_RADIUS: float = 12.0
const RING_WIDTH: float = 2.0
const EMPTY_BG: Color = Color(0.10, 0.10, 0.12, 0.85)
const EMPTY_BORDER: Color = Color(0.25, 0.25, 0.28, 1.0)
const DISABLED_TINT: Color = Color(1, 1, 1, 0.35)

var item_id: StringName = &""
var _item: ItemData = null
var _tier: int = 0
var _bitmap: Texture2D = null
var _is_disabled: bool = false

signal pressed(item_id: StringName)
signal hovered(item_id: StringName, screen_rect: Rect2)
signal unhovered()

func _ready() -> void:
	custom_minimum_size = CELL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func set_item(id: StringName, item: ItemData, tier: int = 0) -> void:
	item_id = id
	_item = item
	_tier = tier
	_bitmap = _try_load_sidecar(id)
	queue_redraw()

func set_empty() -> void:
	item_id = &""
	_item = null
	_tier = 0
	_bitmap = null
	queue_redraw()

func set_disabled(d: bool) -> void:
	if _is_disabled == d:
		return
	_is_disabled = d
	queue_redraw()

func is_empty() -> bool:
	return _item == null

func get_item() -> ItemData:
	return _item

func _try_load_sidecar(id: StringName) -> Texture2D:
	if id == &"":
		return null
	var path := "res://data/icons/%s.png" % String(id)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, EMPTY_BG, true)
	if _item == null:
		draw_rect(rect, EMPTY_BORDER, false, 1.0)
		return
	var ring := _ring_color(_tier)
	# Outer ring colored by tier.
	draw_rect(rect, ring, false, RING_WIDTH)
	var center := size * 0.5
	if _bitmap != null:
		var pad := Vector2(RING_WIDTH + 2, RING_WIDTH + 2)
		var inner := Rect2(pad, size - pad * 2.0)
		draw_texture_rect(_bitmap, inner, false, _disabled_modulate(Color.WHITE))
	else:
		_draw_glyph(center, _disabled_modulate(_item.glyph_color), _item.glyph_shape)

func _draw_glyph(center: Vector2, color: Color, shape: int) -> void:
	var poly: PackedVector2Array = []
	match shape:
		ItemGlyph.Shape.SQUARE:
			poly = PackedVector2Array([
				center + Vector2(-SHAPE_RADIUS, -SHAPE_RADIUS),
				center + Vector2(SHAPE_RADIUS, -SHAPE_RADIUS),
				center + Vector2(SHAPE_RADIUS, SHAPE_RADIUS),
				center + Vector2(-SHAPE_RADIUS, SHAPE_RADIUS),
			])
		ItemGlyph.Shape.TRIANGLE:
			poly = PackedVector2Array([
				center + Vector2(0, -SHAPE_RADIUS),
				center + Vector2(SHAPE_RADIUS, SHAPE_RADIUS),
				center + Vector2(-SHAPE_RADIUS, SHAPE_RADIUS),
			])
		ItemGlyph.Shape.DIAMOND:
			poly = PackedVector2Array([
				center + Vector2(0, -SHAPE_RADIUS),
				center + Vector2(SHAPE_RADIUS, 0),
				center + Vector2(0, SHAPE_RADIUS),
				center + Vector2(-SHAPE_RADIUS, 0),
			])
		ItemGlyph.Shape.CIRCLE:
			var n := 18
			for i in n:
				var t := TAU * i / n
				poly.append(center + Vector2(SHAPE_RADIUS * cos(t), SHAPE_RADIUS * sin(t)))
	draw_colored_polygon(poly, color)
	var outline := poly.duplicate()
	if poly.size() > 0:
		outline.append(poly[0])
		draw_polyline(outline, _disabled_modulate(Color(0, 0, 0, 0.7)), 1.0)

func _disabled_modulate(c: Color) -> Color:
	if not _is_disabled:
		return c
	return Color(c.r, c.g, c.b, c.a * DISABLED_TINT.a)

func _ring_color(tier: int) -> Color:
	# Mirror EquipmentVisuals tier bands so the inventory matches the
	# paper-doll's overlay tone.
	match tier:
		0: return EquipmentVisuals.TIER_DULL
		1: return EquipmentVisuals.TIER_NORMAL
		2: return EquipmentVisuals.TIER_BRIGHT
	return Color(0.85, 0.82, 0.70)

func _on_mouse_entered() -> void:
	if _item == null:
		return
	var r := Rect2(global_position, size)
	hovered.emit(item_id, r)

func _on_mouse_exited() -> void:
	unhovered.emit()

func _on_gui_input(event: InputEvent) -> void:
	if _item == null:
		return
	var mb := event as InputEventMouseButton
	if mb == null:
		return
	if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(item_id)
		accept_event()
