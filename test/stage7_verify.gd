extends Node
## Stage 7 verifier — wilderness zone + spawn director + corpse-run
## death penalty + save schema v10. Pure autoload + resource checks;
## avoids instantiating the full zone subtree so the headless run
## stays deterministic.

func _ready() -> void:
	var fail := 0
	print("--- Stage 7 verify ---")

	fail = _verify_enemy_registry(fail)
	fail = _verify_bog_caller_strategy_source(fail)
	fail = _verify_wilderness_drop_table(fail)
	fail = _verify_corpse_system_basic(fail)
	fail = _verify_corpse_eviction_to_spill(fail)
	fail = _verify_corpse_snapshot_roundtrip(fail)
	fail = _verify_save_v6_to_v10_migration(fail)
	fail = _verify_save_corpses_roundtrip(fail)
	fail = _verify_portal_target_zones(fail)

	print("--- Stage 7 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

# ---- EnemyRegistry --------------------------------------------------------

func _verify_enemy_registry(fail: int) -> int:
	var ok_sw: bool = EnemyRegistry.scene_for(&"shade_wretch") != null
	print("[%s] EnemyRegistry resolves shade_wretch" % ("OK  " if ok_sw else "FAIL"))
	if not ok_sw: fail += 1

	var ok_bc: bool = EnemyRegistry.scene_for(&"bog_caller") != null
	print("[%s] EnemyRegistry resolves bog_caller" % ("OK  " if ok_bc else "FAIL"))
	if not ok_bc: fail += 1

	var ok_miss: bool = EnemyRegistry.scene_for(&"nonexistent_mob") == null
	print("[%s] EnemyRegistry returns null for unknown id" % ("OK  " if ok_miss else "FAIL"))
	if not ok_miss: fail += 1
	return fail

func _verify_bog_caller_strategy_source(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://scripts/enemies/bog_caller.gd")
	var checks := {
		"exports ideal_range": src.contains("@export var ideal_range"),
		"exports danger_range": src.contains("@export var danger_range"),
		"exports panic_range": src.contains("@export var panic_range"),
		"has post-dodge cast delay": src.contains("post_dodge_cast_delay"),
		"reads player attack commitment": src.contains("_target_is_attacking"),
		"dodges from committed melee": src.contains("dist < danger_range and _target_is_attacking"),
		"re-enters offense after bait": src.contains("_cast_at(player)"),
		"uses explicit dodge vector": src.contains("_start_dodge"),
	}
	for label in checks:
		var ok: bool = bool(checks[label])
		print("[%s] Bog Caller strategy: %s" % [("OK  " if ok else "FAIL"), label])
		if not ok:
			fail += 1
	return fail

# ---- Wilderness DropTable -------------------------------------------------

func _verify_wilderness_drop_table(fail: int) -> int:
	var dt: DropTable = load("res://data/enemies/wilderness_basic_drops.tres") as DropTable
	var ok_load: bool = dt != null
	print("[%s] wilderness_basic_drops.tres loads" % ("OK  " if ok_load else "FAIL"))
	if not ok_load:
		return fail + 1

	# Sample roll-coverage: 500 rolls should hit at least 3 distinct ids
	# AND produce at least one no_drop result (no_drop_weight > 0).
	var seen: Dictionary = {}
	var no_drops := 0
	for i in 500:
		var id: StringName = dt.roll()
		if id == &"":
			no_drops += 1
		else:
			seen[id] = true
	var ok_variety: bool = seen.size() >= 3
	print("[%s] drop table variety: %d distinct ids over 500 rolls" \
			% [("OK  " if ok_variety else "FAIL"), seen.size()])
	if not ok_variety: fail += 1

	var ok_no_drop: bool = no_drops > 0
	print("[%s] drop table produces no_drop entries (got %d)" \
			% [("OK  " if ok_no_drop else "FAIL"), no_drops])
	if not ok_no_drop: fail += 1
	return fail

# ---- CorpseSystem basics --------------------------------------------------

func _verify_corpse_system_basic(fail: int) -> int:
	CorpseSystem.clear_all()
	var ok_empty: bool = (not CorpseSystem.has_any()) and CorpseSystem.corpses.is_empty()
	print("[%s] CorpseSystem starts empty" % ("OK  " if ok_empty else "FAIL"))
	if not ok_empty: fail += 1

	var entry: Dictionary = CorpseSystem.add_corpse(
			&"blighted_reach", Vector2(120, -40),
			55, &"iron_ring", 5)
	var ok_add: bool = entry.get("id", -1) == 1 \
			and CorpseSystem.corpses.size() == 1 \
			and int(entry.get("gold", 0)) == 55
	print("[%s] add_corpse returns id=1 with stored gold" % ("OK  " if ok_add else "FAIL"))
	if not ok_add: fail += 1

	var in_zone := CorpseSystem.corpses_in_zone(&"blighted_reach")
	var ok_filter: bool = in_zone.size() == 1
	print("[%s] corpses_in_zone filters by zone_id" % ("OK  " if ok_filter else "FAIL"))
	if not ok_filter: fail += 1

	var ok_other_zone: bool = CorpseSystem.corpses_in_zone(&"threshold_camp").is_empty()
	print("[%s] corpses_in_zone misses non-matching zone" \
			% ("OK  " if ok_other_zone else "FAIL"))
	if not ok_other_zone: fail += 1

	CorpseSystem.remove_corpse(1)
	var ok_remove: bool = not CorpseSystem.has_any()
	print("[%s] remove_corpse by id clears entry" % ("OK  " if ok_remove else "FAIL"))
	if not ok_remove: fail += 1
	return fail

# ---- Eviction + spill -----------------------------------------------------

func _verify_corpse_eviction_to_spill(fail: int) -> int:
	CorpseSystem.clear_all()
	# Stack 4 corpses → oldest should evict to spills.
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(0, 0), 10, &"linen_wrap", 4)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(20, 0), 20, &"worn_helm", 2)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(40, 0), 30, &"simple_greaves", 3)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(60, 0), 40, &"iron_ring", 5)

	var ok_cap: bool = CorpseSystem.corpses.size() == CorpseSystem.MAX_CORPSES
	print("[%s] corpses capped at MAX_CORPSES after 4th add" \
			% ("OK  " if ok_cap else "FAIL"))
	if not ok_cap: fail += 1

	var ok_spill_queued: bool = CorpseSystem.spills.size() == 1
	print("[%s] evicted corpse #1 queued as spill" \
			% ("OK  " if ok_spill_queued else "FAIL"))
	if not ok_spill_queued: fail += 1

	var spill: Dictionary = CorpseSystem.spills[0] as Dictionary
	var ok_spill_payload: bool = int(spill.get("gold", -1)) == 10 \
			and String(spill.get("item_id", "")) == "linen_wrap" \
			and String(spill.get("zone_id", "")) == "blighted_reach"
	print("[%s] spill carries gold + item + zone of evicted corpse" \
			% ("OK  " if ok_spill_payload else "FAIL"))
	if not ok_spill_payload: fail += 1

	var drained := CorpseSystem.consume_spills_in_zone(&"blighted_reach")
	var ok_drain: bool = drained.size() == 1 and CorpseSystem.spills.is_empty()
	print("[%s] consume_spills_in_zone drains entries" \
			% ("OK  " if ok_drain else "FAIL"))
	if not ok_drain: fail += 1

	# A consume against a zone with no matching spills must not crash.
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(80, 0), 50, &"silver_amulet", 6)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(100, 0), 5, &"round_buckler", 1)
	var noop := CorpseSystem.consume_spills_in_zone(&"threshold_camp")
	var ok_noop: bool = noop.is_empty()
	print("[%s] consume_spills_in_zone safely returns empty for unmatched zone" \
			% ("OK  " if ok_noop else "FAIL"))
	if not ok_noop: fail += 1
	return fail

# ---- Snapshot / restore ---------------------------------------------------

func _verify_corpse_snapshot_roundtrip(fail: int) -> int:
	CorpseSystem.clear_all()
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(15, -30), 99, &"iron_ring", 5)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(45, -10), 0, &"", -1)
	CorpseSystem.add_corpse(&"threshold_camp", Vector2(0, 0), 25, &"linen_wrap", 4)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(75, 12), 60, &"silver_amulet", 6)
	# 4 corpses → cap evicts the 1st (the iron_ring one).
	var snap: Dictionary = CorpseSystem.snapshot()
	var ok_shape: bool = snap.has("corpses") and snap.has("next_id") and snap.has("spills")
	print("[%s] snapshot includes corpses + next_id + spills" \
			% ("OK  " if ok_shape else "FAIL"))
	if not ok_shape: fail += 1

	CorpseSystem.clear_all()
	CorpseSystem.restore(snap)
	var ok_corpses: bool = CorpseSystem.corpses.size() == 3
	print("[%s] restore loads %d corpses" \
			% [("OK  " if ok_corpses else "FAIL"), CorpseSystem.corpses.size()])
	if not ok_corpses: fail += 1

	var ok_spills: bool = CorpseSystem.spills.size() == 1 \
			and int(CorpseSystem.spills[0].get("gold", -1)) == 99
	print("[%s] restore loads spill with the evicted gold (99)" \
			% ("OK  " if ok_spills else "FAIL"))
	if not ok_spills: fail += 1
	return fail

# ---- Save schema v6 -> v10 migration --------------------------------------

func _verify_save_v6_to_v10_migration(fail: int) -> int:
	# Synthetic v6 save: zone_id present, but no enemies/loot/corpse.
	var v6: Dictionary = {
		"version": 6,
		"zone_id": "threshold_camp",
		"gold": 0,
		"quests": {},
	}
	var migrated := SaveSystem.migrate(v6)
	var ok_version: bool = int(migrated.get("version", -1)) == SaveSystem.SAVE_VERSION
	print("[%s] migrate(v6 -> current) bumps to v%d" \
			% [("OK  " if ok_version else "FAIL"), SaveSystem.SAVE_VERSION])
	if not ok_version: fail += 1

	var ok_enemies: bool = migrated.has("enemies") and (migrated["enemies"] as Array).is_empty()
	print("[%s] v6 -> current seeds empty enemies list" \
			% ("OK  " if ok_enemies else "FAIL"))
	if not ok_enemies: fail += 1

	var ok_loot: bool = migrated.has("loot") and (migrated["loot"] as Array).is_empty()
	print("[%s] v6 -> current seeds empty loot list" \
			% ("OK  " if ok_loot else "FAIL"))
	if not ok_loot: fail += 1

	var corpse_data: Dictionary = migrated.get("corpse", {})
	var ok_corpse_shape: bool = corpse_data.has("corpses") \
			and corpse_data.has("next_id") \
			and corpse_data.has("spills")
	print("[%s] v6 -> current seeds corpse {corpses, next_id, spills}" \
			% ("OK  " if ok_corpse_shape else "FAIL"))
	if not ok_corpse_shape: fail += 1

	# v9 legacy with a populated single corpse should wrap into corpses[0].
	var v9: Dictionary = {
		"version": 9,
		"zone_id": "blighted_reach",
		"corpse": {
			"zone_id": "blighted_reach",
			"pos": {"x": 12.0, "y": -8.0},
			"gold": 77,
			"item_id": "iron_ring",
			"slot": 5,
		},
	}
	var migrated9 := SaveSystem.migrate(v9)
	var legacy_wrapped: Dictionary = migrated9.get("corpse", {})
	var wrapped_list: Array = legacy_wrapped.get("corpses", [])
	var ok_wrap: bool = wrapped_list.size() == 1 \
			and int(wrapped_list[0].get("gold", -1)) == 77 \
			and int(wrapped_list[0].get("id", -1)) == 1
	print("[%s] v9 single-corpse migrates into corpses[0] with id=1" \
			% ("OK  " if ok_wrap else "FAIL"))
	if not ok_wrap: fail += 1
	return fail

# ---- Live save round-trip (CorpseSystem state) ----------------------------

func _verify_save_corpses_roundtrip(fail: int) -> int:
	# Stage 6 already covers player + gold + quest + zone round-trip.
	# Here we focus on corpse state moving cleanly through the disk.
	CorpseSystem.clear_all()
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(11, 22), 33, &"iron_ring", 5)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(44, 55), 66, &"silver_amulet", 6)
	# A spill from a synthetic eviction (drop two more so corpse #1 evicts).
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(77, 88), 99, &"linen_wrap", 4)
	CorpseSystem.add_corpse(&"blighted_reach", Vector2(10, 10), 1, &"worn_helm", 2)
	# Now: 3 corpses, 1 spill (the iron_ring one).

	# Seed GameState.player with a barebones Player so SaveSystem can
	# capture the rest of the snapshot without crashing on a null player.
	var packed: PackedScene = load("res://scenes/player/player.tscn") as PackedScene
	var p: Player = packed.instantiate() as Player
	add_child(p)
	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	p.assign_class(cd)
	GameState.player = p

	var ok_save: bool = SaveSystem.save_game()
	print("[%s] save_game succeeds with corpses + spills" \
			% ("OK  " if ok_save else "FAIL"))
	if not ok_save: fail += 1

	CorpseSystem.clear_all()
	var ok_load: bool = SaveSystem.load_game()
	print("[%s] load_game succeeds" % ("OK  " if ok_load else "FAIL"))
	if not ok_load: fail += 1

	var ok_corpses: bool = CorpseSystem.corpses.size() == 3
	print("[%s] round-trip restores 3 active corpses" \
			% ("OK  " if ok_corpses else "FAIL"))
	if not ok_corpses: fail += 1

	var ok_spills: bool = CorpseSystem.spills.size() == 1 \
			and int(CorpseSystem.spills[0].get("gold", -1)) == 33
	print("[%s] round-trip restores 1 spill with original gold (33)" \
			% ("OK  " if ok_spills else "FAIL"))
	if not ok_spills: fail += 1

	CorpseSystem.clear_all()
	SaveSystem.delete_save()
	p.queue_free()
	return fail

# ---- Portals --------------------------------------------------------------

func _verify_portal_target_zones(fail: int) -> int:
	# Both zone scenes ship with at least one transit node (Portal or
	# WalkGate) pointing to the other. Stage 12 replaced the camp↔reach
	# Portals with WalkGates (walkable seam, no E-press) so this check
	# accepts either base class — only that a path exists between them.
	var camp: PackedScene = load("res://scenes/zones/threshold_camp.tscn") as PackedScene
	var wild: PackedScene = load("res://scenes/zones/blighted_reach.tscn") as PackedScene
	var ok_camp: bool = camp != null and _scene_has_transit_to(camp, &"blighted_reach")
	print("[%s] threshold_camp ships a transit -> blighted_reach" \
			% ("OK  " if ok_camp else "FAIL"))
	if not ok_camp: fail += 1

	var ok_wild: bool = wild != null and _scene_has_transit_to(wild, &"threshold_camp")
	print("[%s] blighted_reach ships a transit -> threshold_camp" \
			% ("OK  " if ok_wild else "FAIL"))
	if not ok_wild: fail += 1
	return fail

func _scene_has_transit_to(packed: PackedScene, target: StringName) -> bool:
	var inst := packed.instantiate()
	var hit := false
	for n in inst.find_children("*", "Portal", true, false):
		var portal := n as Portal
		if portal != null and portal.target_zone == target:
			hit = true
			break
	if not hit:
		for n in inst.find_children("*", "Area2D", true, false):
			if n is WalkGate and (n as WalkGate).target_zone == target:
				hit = true
				break
	inst.queue_free()
	return hit
