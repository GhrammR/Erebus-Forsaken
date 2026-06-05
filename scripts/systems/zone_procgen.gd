class_name ZoneProcgen extends Object
## Stage 13 — deterministic per-zone procgen, driven by WorldSeed.
## Stateless: every public method takes the inputs it needs and returns
## fresh data. Same WorldSeed + same zone_id + same inputs → identical
## output, every machine, every load.
##
## Scope: prop scatter (trees + rocks with mixed variants), spawn anchor
## positions, per-archetype palette pick. The caller is responsible for
## turning the result into scene nodes — this layer never touches the
## tree.
##
## What this is NOT yet doing (deferred to later stages):
##   - Path winding / road shape (Stage 20)
##   - Multi-zone chaining with min/max distance from town (Stage 20)
##   - Per-tile terrain block placement (Stage 20)
##   - Bitmap variant pick — procedural-only until Stage 11 pipeline
##     lands real assets

## Salts so independent RNG streams don't bleed into each other. Same
## (master_seed, zone_id) gets different rolls for props vs anchors vs
## palette, so "the wilderness reshuffles its trees" never accidentally
## moves the enemy anchors too.
const SALT_PROPS: int = 1
const SALT_ANCHORS: int = 2
const SALT_PALETTE: int = 3
const SALT_WAYPOINT: int = 4

## Tree variant scene paths. Variant index is the array index. Add
## entries here when a new tree scene lands; the procgen pick respects
## the full list.
const TREE_SCENES: Array[String] = [
	"res://art/procedural/world/dead_tree.tscn",
	"res://art/procedural/world/withered_pine.tscn",
	"res://art/procedural/world/broken_stump.tscn",
]

const ROCK_SCENES: Array[String] = [
	"res://art/procedural/world/rock_round.tscn",
	"res://art/procedural/world/rock_angular.tscn",
	"res://art/procedural/world/rock_flat.tscn",
]

## Per-archetype palette variant count. Index 0 is always "default";
## additional entries are baked into each sprite scene's palette_table.
## Pick is uniform across [0, count - 1].
const PALETTE_COUNT: Dictionary = {
	&"shade_wretch": 2,
	&"bog_caller": 2,
}

## Generate the full procgen result for a zone.
##
## bounds        — Rect2 inside which props + anchors may sit. Caller's
##                 responsibility to ensure this lies within the zone's
##                 walkable area.
## exclusions    — Array[Rect2] of rectangles inside `bounds` where no
##                 prop or anchor should land (gate footprints, npc
##                 spots, road tiles, etc.).
## prop_count    — int, how many props to scatter (trees + rocks mixed).
## anchor_count  — int, how many enemy spawn anchors to place.
## tree_weight   — float in [0,1]; props pick tree at this rate, rock
##                 at (1 - tree_weight).
##
## Returns:
##   {
##     "props":        Array[Dictionary { kind, variant, pos, scale, rotation }],
##     "anchors":      Array[Vector2],
##     "palette":      Dictionary[StringName -> int],
##     "waypoint_pos": Vector2  (Stage 14 — Sundered Ferry placement)
##   }
static func generate_for(zone_id: StringName, bounds: Rect2,
		exclusions: Array, prop_count: int, anchor_count: int,
		tree_weight: float = 0.7) -> Dictionary:
	var props_rng := WorldSeed.make_rng(zone_id, SALT_PROPS)
	var anchors_rng := WorldSeed.make_rng(zone_id, SALT_ANCHORS)
	var palette_rng := WorldSeed.make_rng(zone_id, SALT_PALETTE)
	var waypoint_rng := WorldSeed.make_rng(zone_id, SALT_WAYPOINT)

	var props: Array = []
	for i in prop_count:
		var pos := _roll_position(props_rng, bounds, exclusions, props, 28.0, 48)
		if pos == Vector2.INF:
			continue
		var is_tree: bool = props_rng.randf() < tree_weight
		var kind := "tree" if is_tree else "rock"
		var variant_count := TREE_SCENES.size() if is_tree else ROCK_SCENES.size()
		var entry: Dictionary = {
			"kind": kind,
			"variant": props_rng.randi_range(0, variant_count - 1),
			"pos": pos,
			"scale": props_rng.randf_range(0.85, 1.15),
			"rotation": props_rng.randf_range(-0.05, 0.05),
		}
		props.append(entry)

	var anchors: Array = []
	# Anchors get a larger separation than props so spawn rings don't
	# collapse onto each other.
	for i in anchor_count:
		var pos := _roll_position(anchors_rng, bounds, exclusions, anchors, 180.0, 64)
		if pos == Vector2.INF:
			continue
		anchors.append(pos)

	var palette: Dictionary = {}
	for archetype in PALETTE_COUNT.keys():
		var count: int = PALETTE_COUNT[archetype]
		palette[archetype] = palette_rng.randi_range(0, count - 1)

	# Stage 14 — Sundered Ferry waypoint placement. Reject-sample with
	# a larger exclusion radius against anchors so the brazier doesn't
	# spawn inside an enemy spawn ring. Anchors are reused as the
	# "existing" list; the waypoint is rolled into the same bounds +
	# exclusions but with its own RNG stream.
	var waypoint_pos := _roll_position(
			waypoint_rng, bounds, exclusions, anchors, 220.0, 96)
	if waypoint_pos == Vector2.INF:
		# Couldn't place after 96 attempts — fall back to bounds center
		# so the zone still gets a waypoint. Caller can detect a
		# fallback by comparing to bounds.get_center(), but Blighted
		# Reach's bounds are generous enough that this branch should
		# only trigger if the caller passes pathological inputs.
		waypoint_pos = bounds.get_center()

	return {
		"props": props,
		"anchors": anchors,
		"palette": palette,
		"waypoint_pos": waypoint_pos,
	}

## Stable resource-path lookup. variant 0..N-1 maps to the constant
## arrays above. Returns "" for invalid input so callers can fall back
## to a sane default.
static func tree_scene_path(variant: int) -> String:
	if variant < 0 or variant >= TREE_SCENES.size():
		return ""
	return TREE_SCENES[variant]

static func rock_scene_path(variant: int) -> String:
	if variant < 0 or variant >= ROCK_SCENES.size():
		return ""
	return ROCK_SCENES[variant]

# ---- internals ----------------------------------------------------------

## Reject-sample a position within bounds, outside every exclusion, and
## at least `min_dist` from anything in `existing`. existing entries
## may be Vector2 (anchor list) or Dictionary with "pos" key (prop list).
static func _roll_position(rng: RandomNumberGenerator, bounds: Rect2,
		exclusions: Array, existing: Array, min_dist: float,
		max_attempts: int) -> Vector2:
	for attempt in max_attempts:
		var p := Vector2(
				rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
				rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y))
		var bad := false
		for ex_v in exclusions:
			var ex := ex_v as Rect2
			if ex.has_point(p):
				bad = true
				break
		if bad:
			continue
		for e in existing:
			var ep: Vector2
			if e is Vector2:
				ep = e
			elif e is Dictionary and e.has("pos"):
				ep = e["pos"]
			else:
				continue
			if p.distance_to(ep) < min_dist:
				bad = true
				break
		if not bad:
			return p
	# Caller treats Vector2.INF as "couldn't place" and skips this slot.
	return Vector2.INF
