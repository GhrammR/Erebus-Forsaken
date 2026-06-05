extends Node
## Stage 12 verifier — walkable town↔wilderness transit.
## Confirms the WalkGate scaffold + scene wiring without running a
## full playtest: scenes load, walk-gates and arrival markers are
## present where expected, the trigger does NOT fire on its own
## arming grace, and the structural contract (split perimeter wall +
## paired markers) holds.

const CAMP_PATH := "res://scenes/zones/threshold_camp.tscn"
const REACH_PATH := "res://scenes/zones/blighted_reach.tscn"

func _ready() -> void:
	var fail := 0
	print("--- Stage 12 verify ---")

	fail = _verify_walkgate_class(fail)
	fail = _verify_walkgate_scene(fail)
	fail = _verify_camp_gate(fail)
	fail = _verify_reach_gate(fail)
	fail = _verify_arrival_markers_outside_triggers(fail)
	fail = _verify_no_old_portals(fail)
	fail = _verify_arming_guard(fail)
	fail = _verify_beyond_dressing(fail)

	print("--- Stage 12 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- class + scene ------------------------------------------------------

func _verify_walkgate_class(fail: int) -> int:
	var s: Script = load("res://scripts/world/walk_gate.gd") as Script
	fail = _expect(s != null, "walk_gate.gd loads", fail)
	# Class name registered as WalkGate.
	fail = _expect(ClassDB.class_exists("Area2D"),
			"Area2D base class available (sanity)", fail)
	return fail

func _verify_walkgate_scene(fail: int) -> int:
	var packed: PackedScene = load("res://scenes/world/walk_gate.tscn") as PackedScene
	fail = _expect(packed != null, "walk_gate.tscn loads", fail)
	if packed == null:
		return fail
	var inst := packed.instantiate()
	fail = _expect(inst is WalkGate, "instance is a WalkGate", fail)
	fail = _expect(inst.has_node("CollisionShape2D"),
			"WalkGate has CollisionShape2D", fail)
	fail = _expect(inst.has_node("RoadArt"),
			"WalkGate has RoadArt", fail)
	# Mask must include the player CharacterBody2D layer (layer 2 = bit 1
	# from player.tscn: collision_layer = 2).
	fail = _expect(int((inst as Area2D).collision_mask) == 2,
			"WalkGate collision_mask == 2 (detects player)", fail)
	inst.free()
	return fail

# ---- camp + reach structural ----------------------------------------------

func _verify_camp_gate(fail: int) -> int:
	var camp := _instance(CAMP_PATH)
	if camp == null:
		return fail + 1
	fail = _expect(camp.has_node("TownSouthGate"),
			"camp has TownSouthGate", fail)
	fail = _expect(camp.has_node("FromBlightedReach"),
			"camp keeps FromBlightedReach arrival marker", fail)
	# Wall split: S_west + S_east present, single S removed.
	var walls := camp.get_node_or_null("PerimeterWalls")
	fail = _expect(walls != null and walls.has_node("S_west"),
			"camp south wall split: S_west", fail)
	fail = _expect(walls != null and walls.has_node("S_east"),
			"camp south wall split: S_east", fail)
	fail = _expect(walls != null and not walls.has_node("S"),
			"camp legacy single 'S' wall removed", fail)
	if camp.has_node("TownSouthGate"):
		var gate := camp.get_node("TownSouthGate") as WalkGate
		fail = _expect(gate.target_zone == &"blighted_reach",
				"TownSouthGate.target_zone == blighted_reach", fail)
		fail = _expect(gate.arrival_marker == &"FromTownGate",
				"TownSouthGate.arrival_marker == FromTownGate", fail)
	camp.free()
	return fail

func _verify_reach_gate(fail: int) -> int:
	var reach := _instance(REACH_PATH)
	if reach == null:
		return fail + 1
	fail = _expect(reach.has_node("WildernessNorthGate"),
			"reach has WildernessNorthGate", fail)
	fail = _expect(reach.has_node("FromTownGate"),
			"reach has FromTownGate arrival marker (Stage 12 new)", fail)
	fail = _expect(reach.has_node("CryptPortal"),
			"reach retains CryptPortal (still discrete interactable)", fail)
	fail = _expect(not reach.has_node("ReturnPortal"),
			"reach legacy ReturnPortal removed", fail)
	var walls := reach.get_node_or_null("PerimeterWalls")
	fail = _expect(walls != null and walls.has_node("N_west"),
			"reach north wall split: N_west", fail)
	fail = _expect(walls != null and walls.has_node("N_east"),
			"reach north wall split: N_east", fail)
	fail = _expect(walls != null and not walls.has_node("N"),
			"reach legacy single 'N' wall removed", fail)
	if reach.has_node("WildernessNorthGate"):
		var gate := reach.get_node("WildernessNorthGate") as WalkGate
		fail = _expect(gate.target_zone == &"threshold_camp",
				"WildernessNorthGate.target_zone == threshold_camp", fail)
		fail = _expect(gate.arrival_marker == &"FromBlightedReach",
				"WildernessNorthGate.arrival_marker == FromBlightedReach", fail)
	reach.free()
	return fail

# ---- safety contracts ---------------------------------------------------

func _verify_arrival_markers_outside_triggers(fail: int) -> int:
	# Re-entry guard #3: arrival marker must sit beyond the destination
	# zone's reverse-direction trigger so player doesn't spawn inside
	# the trigger and immediately re-trigger.
	var camp := _instance(CAMP_PATH)
	if camp != null:
		var gate := camp.get_node_or_null("TownSouthGate") as Area2D
		var marker := camp.get_node_or_null("FromBlightedReach") as Marker2D
		if gate != null and marker != null:
			# Trigger spans y in [gate.y - 20, gate.y + 20] (40px tall).
			# Marker should be outside that band.
			var inside := absf(marker.position.y - gate.position.y) <= 20.0
			fail = _expect(not inside,
					"camp FromBlightedReach is outside TownSouthGate trigger", fail)
		camp.free()
	var reach := _instance(REACH_PATH)
	if reach != null:
		var gate := reach.get_node_or_null("WildernessNorthGate") as Area2D
		var marker := reach.get_node_or_null("FromTownGate") as Marker2D
		if gate != null and marker != null:
			var inside := absf(marker.position.y - gate.position.y) <= 20.0
			fail = _expect(not inside,
					"reach FromTownGate is outside WildernessNorthGate trigger", fail)
		reach.free()
	return fail

func _verify_no_old_portals(fail: int) -> int:
	# The two camp↔wilderness portals must be gone; the crypt portal
	# remains (explicit-doorway semantics for the dungeon entrance).
	var camp_text := FileAccess.get_file_as_string(CAMP_PATH)
	fail = _expect(not camp_text.contains("WildernessPortal"),
			"camp.tscn no longer references WildernessPortal", fail)
	var reach_text := FileAccess.get_file_as_string(REACH_PATH)
	fail = _expect(not reach_text.contains("ReturnPortal"),
			"reach.tscn no longer references ReturnPortal", fail)
	fail = _expect(reach_text.contains("CryptPortal"),
			"reach.tscn keeps CryptPortal", fail)
	return fail

func _verify_arming_guard(fail: int) -> int:
	# WalkGate must not fire body_entered until ARMING_DELAY elapses.
	# We can't easily run a tree+physics tick in isolation, but we
	# can confirm the script logic: _armed starts false, _consumed
	# starts false, and the source ties body_entered to the guard.
	var src := FileAccess.get_file_as_string("res://scripts/world/walk_gate.gd")
	fail = _expect(src.contains("_armed: bool = false"),
			"WalkGate._armed defaults false (arming grace active)", fail)
	fail = _expect(src.contains("_consumed: bool = false"),
			"WalkGate._consumed defaults false (one-shot)", fail)
	fail = _expect(src.contains("if _consumed or not _armed"),
			"WalkGate.body_entered checks both guards", fail)
	fail = _expect(src.contains("ARMING_DELAY"),
			"WalkGate uses an ARMING_DELAY constant", fail)
	return fail

# ---- Stage 12.1 — beyond-the-gate dressing ------------------------------

func _verify_beyond_dressing(fail: int) -> int:
	# Camp: BeyondWilderness preview must sit south of the south wall
	# (y >= 400 + 20 = 420). At least one tree silhouette + a fog band.
	var camp := _instance(CAMP_PATH)
	if camp != null:
		var beyond := camp.get_node_or_null("BeyondWilderness") as Node2D
		fail = _expect(beyond != null,
				"camp has BeyondWilderness dressing node", fail)
		if beyond != null:
			fail = _expect(beyond.get_child_count() >= 5,
					"BeyondWilderness has at least 5 dressing children", fail)
			fail = _expect(beyond.has_node("Fog"),
					"BeyondWilderness has Fog band", fail)
			fail = _expect(beyond.has_node("Tree1"),
					"BeyondWilderness has at least one tree silhouette", fail)
			# Sanity: positioned children (instanced scenes — not the
			# Polygon2Ds which carry their coords in the polygon array
			# and stay at position 0) sit south of the wall plane.
			var any_north := false
			for c in beyond.get_children():
				if c is Node2D and (c as Node2D).position != Vector2.ZERO \
						and (c as Node2D).position.y < 400:
					any_north = true
					break
			fail = _expect(not any_north,
					"BeyondWilderness scenes sit south of wall (y >= 400)", fail)
		camp.free()
	# Reach: BeyondCamp preview must sit north of the north wall
	# (y <= -600 - 20 = -620). At least one tent silhouette + fog + glow.
	var reach := _instance(REACH_PATH)
	if reach != null:
		var beyond := reach.get_node_or_null("BeyondCamp") as Node2D
		fail = _expect(beyond != null,
				"reach has BeyondCamp dressing node", fail)
		if beyond != null:
			fail = _expect(beyond.get_child_count() >= 5,
					"BeyondCamp has at least 5 dressing children", fail)
			fail = _expect(beyond.has_node("Fog"),
					"BeyondCamp has Fog band", fail)
			fail = _expect(beyond.has_node("FirePit"),
					"BeyondCamp has firepit glow", fail)
			fail = _expect(beyond.has_node("Tent1"),
					"BeyondCamp has at least one tent silhouette", fail)
			var any_south := false
			for c in beyond.get_children():
				if c is Node2D and (c as Node2D).position != Vector2.ZERO \
						and (c as Node2D).position.y > -600:
					any_south = true
					break
			fail = _expect(not any_south,
					"BeyondCamp scenes sit north of wall (y <= -600)", fail)
		reach.free()
	return fail

# ---- helpers ------------------------------------------------------------

func _instance(path: String) -> Node:
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		printerr("  could not load %s" % path)
		return null
	var node := packed.instantiate()
	# Don't add to the tree — the verifier just inspects nodes.
	return node
