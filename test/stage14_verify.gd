extends Node
## Stage 14 verifier — Sundered Ferry waypoint system.

func _ready() -> void:
	var fail := 0
	print("--- Stage 14 verify ---")

	fail = _verify_save_schema_v17(fail)
	fail = _verify_game_state_field(fail)
	fail = _verify_waypoint_class_and_scene(fail)
	fail = _verify_waypoint_extends_portal(fail)
	fail = _verify_zone_procgen_waypoint_pos(fail)
	fail = _verify_waypoint_pos_determinism(fail)
	fail = _verify_waypoint_pos_divergence(fail)
	fail = _verify_waypoint_menu_scene(fail)
	fail = _verify_waypoint_menu_does_not_pause(fail)
	fail = _verify_reach_places_waypoint(fail)
	fail = _verify_camp_arrival_marker(fail)
	fail = _verify_audio_bank_entries(fail)
	fail = _verify_game_wires_menu(fail)
	fail = _verify_no_cross_save_leakage(fail)
	fail = _verify_town_brazier(fail)
	fail = _verify_waypoint_does_not_block_los(fail)

	print("--- Stage 14 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- save schema --------------------------------------------------------

func _verify_save_schema_v17(fail: int) -> int:
	fail = _expect(SaveSystem.SAVE_VERSION >= 17,
			"SAVE_VERSION >= 17", fail)
	var legacy: Dictionary = { "version": 16, "zone_caches": {} }
	var migrated := SaveSystem.migrate(legacy)
	fail = _expect(int(migrated.get("version", 0)) >= 17,
			"v16 migrates to >= 17", fail)
	fail = _expect(migrated.has("discovered_waypoints"),
			"v17 migration installs discovered_waypoints key", fail)
	var arr: Array = migrated.get("discovered_waypoints", null) as Array
	fail = _expect(arr != null and arr.is_empty(),
			"legacy discovered_waypoints defaults to empty array", fail)
	return fail

func _verify_game_state_field(fail: int) -> int:
	fail = _expect("discovered_waypoints" in GameState,
			"GameState.discovered_waypoints field exists", fail)
	# reset_run clears it.
	GameState.discovered_waypoints = ["blighted_reach"]
	GameState.reset_run()
	fail = _expect((GameState.discovered_waypoints as Array).is_empty(),
			"GameState.reset_run clears discovered_waypoints", fail)
	return fail

# ---- Waypoint node ------------------------------------------------------

func _verify_waypoint_class_and_scene(fail: int) -> int:
	var packed: PackedScene = load("res://scenes/world/waypoint.tscn") as PackedScene
	fail = _expect(packed != null, "waypoint.tscn loads", fail)
	if packed == null:
		return fail
	var inst := packed.instantiate()
	fail = _expect(inst is Waypoint, "instance is a Waypoint", fail)
	fail = _expect(inst.display_name == "The Sundered Ferry",
			"Waypoint.display_name == 'The Sundered Ferry'", fail)
	fail = _expect(inst.has_node("Body/Flame"),
			"Waypoint has Body/Flame node", fail)
	fail = _expect(inst.has_node("Body/Glow"),
			"Waypoint has Body/Glow node", fail)
	inst.free()
	return fail

func _verify_waypoint_extends_portal(fail: int) -> int:
	# Source-level check — class_name Waypoint extends Portal is the
	# contract that gives us click-to-interact + selection ring +
	# proximity prompt for free.
	var src := FileAccess.get_file_as_string("res://scripts/world/waypoint.gd")
	fail = _expect(src.contains("class_name Waypoint extends Portal"),
			"waypoint.gd extends Portal", fail)
	fail = _expect(src.contains("menu_requested"),
			"Waypoint declares menu_requested signal", fail)
	fail = _expect(src.contains("discovered_waypoints.append"),
			"Waypoint marks zone discovered on first interact", fail)
	return fail

# ---- ZoneProcgen waypoint slot -------------------------------------------

func _verify_zone_procgen_waypoint_pos(fail: int) -> int:
	WorldSeed.master_seed = 11
	var bounds := Rect2(Vector2(-400, -400), Vector2(800, 800))
	var result := ZoneProcgen.generate_for(&"wp_test", bounds, [], 8, 4, 0.7)
	fail = _expect(result.has("waypoint_pos"),
			"ZoneProcgen result has waypoint_pos key", fail)
	var pos: Vector2 = result["waypoint_pos"]
	fail = _expect(bounds.has_point(pos) or pos == bounds.get_center(),
			"waypoint_pos within bounds (or fallback to center)", fail)
	return fail

func _verify_waypoint_pos_determinism(fail: int) -> int:
	WorldSeed.master_seed = 42424
	var bounds := Rect2(Vector2(-500, -500), Vector2(1000, 1000))
	var a := ZoneProcgen.generate_for(&"wp_det", bounds, [], 10, 5, 0.6)
	var b := ZoneProcgen.generate_for(&"wp_det", bounds, [], 10, 5, 0.6)
	var pa: Vector2 = a["waypoint_pos"]
	var pb: Vector2 = b["waypoint_pos"]
	fail = _expect(pa.is_equal_approx(pb),
			"same seed → identical waypoint_pos", fail)
	return fail

func _verify_waypoint_pos_divergence(fail: int) -> int:
	WorldSeed.master_seed = 42424
	var bounds := Rect2(Vector2(-500, -500), Vector2(1000, 1000))
	var a := ZoneProcgen.generate_for(&"wp_div", bounds, [], 10, 5, 0.6)
	WorldSeed.master_seed = 99999
	var b := ZoneProcgen.generate_for(&"wp_div", bounds, [], 10, 5, 0.6)
	var pa: Vector2 = a["waypoint_pos"]
	var pb: Vector2 = b["waypoint_pos"]
	fail = _expect(not pa.is_equal_approx(pb),
			"different master seeds → different waypoint_pos", fail)
	return fail

# ---- WaypointMenu --------------------------------------------------------

func _verify_waypoint_menu_scene(fail: int) -> int:
	var packed: PackedScene = load("res://scenes/ui/waypoint_menu.tscn") as PackedScene
	fail = _expect(packed != null, "waypoint_menu.tscn loads", fail)
	if packed == null:
		return fail
	var inst := packed.instantiate()
	fail = _expect(inst is CanvasLayer,
			"WaypointMenu root is CanvasLayer", fail)
	fail = _expect(inst.has_method("show_menu"),
			"WaypointMenu.show_menu exists", fail)
	fail = _expect(inst.has_method("hide_menu"),
			"WaypointMenu.hide_menu exists", fail)
	fail = _expect(inst.has_signal("travel_requested"),
			"WaypointMenu emits travel_requested", fail)
	inst.free()
	return fail

func _verify_waypoint_menu_does_not_pause(fail: int) -> int:
	# Stage 14.2 — user-locked design call: the menu does NOT pause
	# time. Player must use it tactically (in a safe spot, or rush it
	# while enemies are still active). Damage closes the menu.
	# Source-level guard so a future refactor can't quietly revert
	# to the pausing pattern.
	var src := FileAccess.get_file_as_string("res://scripts/ui/waypoint_menu.gd")
	fail = _expect(not src.contains("Engine.time_scale = 0.0"),
			"WaypointMenu does NOT pause on show", fail)
	fail = _expect(src.contains("_hook_damage_interrupt"),
			"WaypointMenu subscribes to player damage on show", fail)
	fail = _expect(src.contains("_on_player_damaged"),
			"WaypointMenu has a damage interrupt handler", fail)
	fail = _expect(src.contains("hide_menu()") and src.contains("damaged.connect"),
			"WaypointMenu wires damaged → hide_menu", fail)
	return fail

# ---- zone integration ----------------------------------------------------

func _verify_reach_places_waypoint(fail: int) -> int:
	# BlightedReach script must call _place_waypoint with the procgen
	# result. We can't easily run the full zone _ready in isolation,
	# so the assert is source-level + a structural call check.
	var src := FileAccess.get_file_as_string(
			"res://scripts/zones/blighted_reach.gd")
	fail = _expect(src.contains("_place_waypoint"),
			"blighted_reach.gd defines _place_waypoint", fail)
	fail = _expect(src.contains("result.get(\"waypoint_pos\""),
			"blighted_reach.gd consumes waypoint_pos from procgen", fail)
	fail = _expect(src.contains("FromWaypoint"),
			"blighted_reach.gd adds FromWaypoint arrival marker", fail)
	return fail

func _verify_camp_arrival_marker(fail: int) -> int:
	var text := FileAccess.get_file_as_string(
			"res://scenes/zones/threshold_camp.tscn")
	fail = _expect(text.contains("FromWaypoint"),
			"threshold_camp.tscn has FromWaypoint marker", fail)
	return fail

func _verify_town_brazier(fail: int) -> int:
	# Stage 14.1 — town hub brazier. starts_lit=true so it skips the
	# discovery flow (player can use it immediately). FromWaypoint
	# marker sits adjacent so arrivals land at the brazier, not at
	# camp center.
	var packed: PackedScene = load(
			"res://scenes/zones/threshold_camp.tscn") as PackedScene
	fail = _expect(packed != null, "threshold_camp.tscn loads", fail)
	if packed == null:
		return fail
	var inst := packed.instantiate()
	var wp := inst.get_node_or_null(^"Waypoint") as Waypoint
	fail = _expect(wp != null,
			"threshold_camp has a Waypoint node", fail)
	if wp != null:
		fail = _expect(bool(wp.starts_lit) == true,
				"town brazier starts_lit = true (no discovery needed)", fail)
		var marker := inst.get_node_or_null(^"FromWaypoint") as Marker2D
		if marker != null and wp != null:
			var d := (marker.position - wp.position).length()
			fail = _expect(d < 60.0,
					"FromWaypoint marker sits adjacent to town brazier (<60px)", fail)
	# Waypoint script source-level asserts.
	var src := FileAccess.get_file_as_string("res://scripts/world/waypoint.gd")
	fail = _expect(src.contains("starts_lit"),
			"Waypoint declares starts_lit export", fail)
	fail = _expect(src.contains("not starts_lit"),
			"interact() skips discovery flow when starts_lit", fail)
	inst.free()
	return fail

func _verify_waypoint_does_not_block_los(fail: int) -> int:
	# Stage 14.3 — wilderness enemy LOS uses wall layer (1) as the
	# block-mask. If the brazier sits on that layer, every enemy
	# behind it stays idle until the player moves out of its LOS
	# shadow. Waypoint must NOT carry layer-1 membership.
	var packed: PackedScene = load("res://scenes/world/waypoint.tscn") as PackedScene
	if packed == null:
		return fail + 1
	var inst := packed.instantiate() as StaticBody2D
	fail = _expect(inst != null, "Waypoint root is StaticBody2D", fail)
	if inst != null:
		fail = _expect(int(inst.collision_layer) == 0,
				"Waypoint collision_layer == 0 (does not block LOS)", fail)
		inst.free()
	return fail

# ---- audio + game wiring -------------------------------------------------

func _verify_audio_bank_entries(fail: int) -> int:
	var ok_discover: bool = AudioBank.SFX_BANK.has(&"waypoint_discover") \
			if "SFX_BANK" in AudioBank \
			else _read_audio_bank_for(&"waypoint_discover")
	fail = _expect(ok_discover,
			"AudioBank has waypoint_discover entry", fail)
	var ok_travel: bool = AudioBank.SFX_BANK.has(&"waypoint_travel") \
			if "SFX_BANK" in AudioBank \
			else _read_audio_bank_for(&"waypoint_travel")
	fail = _expect(ok_travel,
			"AudioBank has waypoint_travel entry", fail)
	return fail

func _read_audio_bank_for(key: StringName) -> bool:
	# AudioBank's _SFX_BANK is a const Dictionary in the script body
	# (no public accessor). Fall back to a source-level check.
	var src := FileAccess.get_file_as_string("res://scripts/autoload/audio_bank.gd")
	return src.contains("&\"%s\"" % String(key))

func _verify_game_wires_menu(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://scenes/game.gd")
	fail = _expect(src.contains("_waypoint_menu"),
			"game.gd holds a _waypoint_menu reference", fail)
	fail = _expect(src.contains("menu_requested.connect"),
			"game.gd connects Waypoint.menu_requested", fail)
	fail = _expect(src.contains("FromWaypoint"),
			"game.gd routes waypoint travel via FromWaypoint marker", fail)
	var tscn := FileAccess.get_file_as_string("res://scenes/game.tscn")
	fail = _expect(tscn.contains("WaypointMenu"),
			"game.tscn instances WaypointMenu", fail)
	return fail

func _verify_no_cross_save_leakage(fail: int) -> int:
	# GameState.reset_run must clear discovered_waypoints (asserted
	# above) so a new game starting after a load doesn't inherit the
	# prior run's discoveries. Plus the save round-trip carries the
	# array verbatim so two save slots stay independent.
	GameState.discovered_waypoints = []
	GameState.discovered_waypoints.append("blighted_reach")
	# Fake save snapshot through migrate to make sure the key round-
	# trips with a non-empty value.
	var snap: Dictionary = {
		"version": SaveSystem.SAVE_VERSION,
		"discovered_waypoints": GameState.discovered_waypoints.duplicate(),
	}
	var migrated := SaveSystem.migrate(snap)  # idempotent at current ver
	fail = _expect(
			(migrated.get("discovered_waypoints", []) as Array).size() == 1,
			"discovered_waypoints round-trips through migrate without loss",
			fail)
	GameState.discovered_waypoints = []
	return fail
