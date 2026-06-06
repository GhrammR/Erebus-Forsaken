class_name SpriteSidecar extends Object
## Stage 17.5 — per-part AI bitmap swap helper.
##
## Each Polygon2D part in a sprite tree may opt in to a sidecar
## bitmap at `res://data/sprites/<sprite_id>/<part>.png`. When the
## file exists, the polygon is hidden and a sibling Sprite2D is
## inserted at the same parent with the same name + "_Bitmap".
##
## Procedural baseline always ships; sidecar is optional polish.
## Mirrors the Stage 16 item-icon sidecar pattern (res://data/icons).
##
## Bind via `SpriteSidecar.apply(sprite_root, sprite_id)` from each
## sprite scene's `_ready`. Cheap: walks the tree once, only loads
## textures for parts that have a sidecar PNG.

const SUFFIX: StringName = &"_Bitmap"

static func sidecar_path(sprite_id: StringName, part_name: StringName) -> String:
	return "res://data/sprites/%s/%s.png" % [String(sprite_id), String(part_name)]

static func apply(sprite_root: Node, sprite_id: StringName) -> int:
	var swapped := 0
	for poly in _polygons_in(sprite_root):
		var path := sidecar_path(sprite_id, poly.name)
		if not ResourceLoader.exists(path):
			continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null:
			continue
		var bitmap := Sprite2D.new()
		bitmap.name = StringName(String(poly.name) + String(SUFFIX))
		bitmap.texture = tex
		bitmap.position = poly.position
		bitmap.rotation = poly.rotation
		bitmap.scale = poly.scale
		bitmap.z_index = poly.z_index
		bitmap.z_as_relative = poly.z_as_relative
		poly.get_parent().add_child(bitmap)
		# Keep the Polygon2D in the tree so AnimationPlayer tracks
		# bound to its transform keep driving the bitmap's parent
		# space — just hide it. The bitmap inherits transforms via
		# the shared parent node (e.g. `Body`), not directly.
		poly.visible = false
		swapped += 1
	return swapped

static func _polygons_in(root: Node) -> Array[Polygon2D]:
	var out: Array[Polygon2D] = []
	_walk(root, out)
	return out

static func _walk(n: Node, out: Array[Polygon2D]) -> void:
	if n is Polygon2D:
		out.append(n as Polygon2D)
	for c in n.get_children():
		_walk(c, out)
