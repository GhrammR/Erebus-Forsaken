class_name BlightedReach extends Zone
## The Blighted Reach — first wilderness zone outside the threshold
## camp. Stage 7: hand-placed trees + anchors. Stage 13: layout is
## now procedurally rolled from WorldSeed.sub_seed("blighted_reach"),
## so a new game with a different master seed reshuffles tree
## variants + positions, anchor positions, and the enemy archetype
## palette pick. Same seed always rolls the same layout — the
## structural elements (walls, gates, crypt portal, ground polygon,
## beyond-camp dressing) stay hand-placed.

## Rect2 of the zone's prop / anchor playable area. Excludes the
## perimeter (walls live at ±960 / ±600) and the gate corridor.
const PROP_BOUNDS := Rect2(Vector2(-880, -480), Vector2(1760, 960))

## Rects where no prop/anchor may land — gate footprints, dressing
## footprints, crypt-portal swirl. Author-locked.
const EXCLUSIONS: Array = [
	# WildernessNorthGate corridor (-100..100 x, -620..-460 y).
	Rect2(Vector2(-120, -620), Vector2(240, 160)),
	# CryptPortal footprint (centered on (0, 500)).
	Rect2(Vector2(-100, 420), Vector2(200, 160)),
	# BeyondCamp dressing extending into bounds south of the wall —
	# already outside PROP_BOUNDS so listed for documentation.
]

const PROP_COUNT: int = 18
const ANCHOR_COUNT: int = 10
const TREE_WEIGHT: float = 0.65

func _ready() -> void:
	zone_id = &"blighted_reach"
	# Run procgen BEFORE super._ready so we populate SpawnAnchors and
	# Trees containers before any deferred system queries them. The
	# SpawnDirector also defers its anchor scan to next idle, which
	# gives us a second chance — but populating eagerly here keeps the
	# initial frame's enemy mix correct.
	_run_procgen()
	super._ready()

func _run_procgen() -> void:
	var result := ZoneProcgen.generate_for(
			zone_id, PROP_BOUNDS, EXCLUSIONS,
			PROP_COUNT, ANCHOR_COUNT, TREE_WEIGHT)
	_populate_anchors(result.get("anchors", []))
	_populate_props(result.get("props", []))
	_apply_palette_pick(result.get("palette", {}))
	_place_waypoint(result.get("waypoint_pos", Vector2.ZERO))

func _populate_anchors(anchors: Array) -> void:
	var holder := get_node_or_null(^"SpawnAnchors") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "SpawnAnchors"
		add_child(holder)
	# Clear any hand-placed leftovers (legacy A0..A8).
	for c in holder.get_children():
		c.queue_free()
	for i in anchors.size():
		var m := Marker2D.new()
		m.name = "A%d" % i
		m.position = anchors[i]
		holder.add_child(m)

func _populate_props(props: Array) -> void:
	var holder := get_node_or_null(^"Trees") as Node2D
	if holder == null:
		holder = Node2D.new()
		holder.name = "Trees"
		# Trees parent renders above ground (-10) but below characters.
		holder.z_index = -5
		add_child(holder)
	# Clear hand-placed leftovers (legacy T0..T11).
	for c in holder.get_children():
		c.queue_free()
	for i in props.size():
		var entry: Dictionary = props[i]
		var path: String
		if String(entry["kind"]) == "tree":
			path = ZoneProcgen.tree_scene_path(int(entry["variant"]))
		else:
			path = ZoneProcgen.rock_scene_path(int(entry["variant"]))
		if path == "":
			continue
		var packed: PackedScene = load(path) as PackedScene
		if packed == null:
			continue
		var inst := packed.instantiate() as Node2D
		if inst == null:
			continue
		inst.name = "P%d" % i
		inst.position = entry["pos"]
		inst.scale = Vector2(entry["scale"], entry["scale"])
		inst.rotation = entry["rotation"]
		holder.add_child(inst)

func _apply_palette_pick(palette: Dictionary) -> void:
	var director := get_node_or_null(^"SpawnDirector") as SpawnDirector
	if director == null:
		return
	director.palette_per_archetype = palette.duplicate()

const _WAYPOINT_SCENE := preload("res://scenes/world/waypoint.tscn")

func _place_waypoint(pos: Vector2) -> void:
	# Idempotent: if the zone's _ready ever fires twice (it shouldn't,
	# but cache restore + transit ordering can be subtle), don't
	# double-spawn the waypoint.
	if has_node("Waypoint"):
		return
	var wp := _WAYPOINT_SCENE.instantiate()
	wp.name = "Waypoint"
	wp.position = pos
	add_child(wp)
	# Arrival marker for incoming waypoint travel — sits a few px
	# south of the waypoint so the player drops next to the brazier,
	# not inside its footprint.
	if not has_node("FromWaypoint"):
		var m := Marker2D.new()
		m.name = "FromWaypoint"
		m.position = pos + Vector2(0, 40)
		add_child(m)
