class_name EnemySpritePalette extends "res://scripts/systems/sprite_runtime_2d.gd"
## Stage 13 — sits as the script on a procedural enemy sprite root
## (Node2D-built sprites with named Polygon2D children). Re-tints
## those children at _ready per a small variant table baked into the
## scene.
##
## The wilderness zone rolls a per-archetype palette variant from its
## sub-seed; SpawnDirector forwards the int to each spawned enemy;
## the enemy script writes it onto the sprite via set_palette_variant
## before/after the sprite is added to the tree.
##
## Variant 0 is always "default" — apply() short-circuits so the legacy
## hand-tinted look stays correct for any caller that doesn't ask for
## a variant. Variant >= 1 walks the palette_table.

## Variant chosen at spawn. Caller sets this BEFORE _ready ideally; if
## set later, call apply(variant) to re-tint.
@export var palette_variant: int = 0

## Per-variant tint table. Keys are variant ints; values are dicts of
## `child_node_path -> Color`. Baked per-archetype in the sprite scene.
@export var palette_table: Dictionary = {}

func _ready() -> void:
	apply(palette_variant)
	setup_sprite_runtime()

func set_palette_variant(v: int) -> void:
	palette_variant = v
	if is_inside_tree():
		apply(v)

func apply(v: int) -> void:
	palette_variant = v
	if v == 0 or palette_table.is_empty():
		return
	var entry: Dictionary = palette_table.get(v, {})
	if entry.is_empty():
		return
	for path_key in entry.keys():
		var node := get_node_or_null(NodePath(path_key))
		if node is Polygon2D:
			(node as Polygon2D).color = entry[path_key]
