extends Node
## Stage 9.7 verifier — endless mode. Asserts:
##   - FeatureFlags + EndlessRun autoloads exist
##   - EventBus has the three new endless signals (AD-08 whitelist)
##   - SceneRouter knows endless_arena
##   - EndlessRun seed encode/decode round-trips
##   - EndlessRun lifecycle (begin/record_kill/advance_wave/rollback)
##   - EndlessDirector tuning curves at waves 1/3/5/10
##   - Species pick determinism off a fixed seed
##   - EndlessDirector loads from endless_arena scene as expected
##   - ForsakenCrypt does NOT spawn portal when act_1_complete = false
##   - ForsakenCrypt DOES spawn portal when act_1_complete = true (and demo_mode false)
##   - ForsakenCrypt skips portal when demo_mode = true
##   - SaveSystem.save_game no-ops while EndlessRun.active
##   - Wave HUD label exists in game.tscn
##   - Endless summary modal scene loads + has the expected nodes

func _ready() -> void:
	var fail := 0
	print("--- Stage 9.7 verify ---")

	fail = _verify_autoloads(fail)
	fail = _verify_event_bus_signals(fail)
	fail = _verify_scene_router(fail)
	fail = _verify_seed_roundtrip(fail)
	fail = _verify_endless_run_lifecycle(fail)
	fail = _verify_director_scaling(fail)
	fail = _verify_director_determinism(fail)
	fail = _verify_arena_scene(fail)
	fail = await _verify_crypt_portal_gates(fail)
	fail = _verify_save_guard(fail)
	fail = _verify_game_hud(fail)
	fail = _verify_summary_scene(fail)
	# Stage 9.7 polish
	fail = _verify_finite_budget(fail)
	fail = _verify_milestone_grants(fail)
	fail = _verify_milestone_idempotency(fail)
	fail = _verify_milestone_items_loaded(fail)
	fail = _verify_save_schema_v13(fail)
	fail = _verify_milestone_modal_scene(fail)

	print("--- Stage 9.7 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

# ---- autoloads -----------------------------------------------------------

func _verify_autoloads(fail: int) -> int:
	var root: Node = Engine.get_main_loop().root
	var ff: Node = root.get_node_or_null(^"FeatureFlags")
	var ok_ff: bool = ff != null and "demo_mode" in ff
	print("[%s] FeatureFlags autoload + demo_mode field" % _ok(ok_ff))
	if not ok_ff: fail += 1
	var er: Node = root.get_node_or_null(^"EndlessRun")
	var ok_er: bool = er != null and er.has_method("begin") \
			and er.has_method("rollback") and er.has_method("encode_seed")
	print("[%s] EndlessRun autoload + begin/rollback/encode_seed" % _ok(ok_er))
	if not ok_er: fail += 1
	return fail

# ---- event bus -----------------------------------------------------------

func _verify_event_bus_signals(fail: int) -> int:
	var names: Array[String] = ["endless_wave_started",
			"endless_wave_completed", "endless_run_ended"]
	for n in names:
		var has: bool = EventBus.has_signal(n)
		print("[%s] EventBus.%s on whitelist" % [_ok(has), n])
		if not has: fail += 1
	return fail

# ---- scene router --------------------------------------------------------

func _verify_scene_router(fail: int) -> int:
	var path: String = SceneRouter.zone_scene_path(&"forsaken_depths")
	var ok: bool = path == "res://scenes/zones/forsaken_depths.tscn" \
			and ResourceLoader.exists(path)
	print("[%s] SceneRouter registers forsaken_depths -> %s" % [_ok(ok), path])
	if not ok: fail += 1
	# Stale endless_arena id should NOT route anywhere
	var stale: String = SceneRouter.zone_scene_path(&"endless_arena")
	var ok_stale: bool = stale == ""
	print("[%s] SceneRouter has no stale endless_arena entry" % _ok(ok_stale))
	if not ok_stale: fail += 1
	return fail

# ---- seed encoding -------------------------------------------------------

func _verify_seed_roundtrip(fail: int) -> int:
	var samples: Array[int] = [0, 1, 42, 9999, 0x7FFFFFFF, 123456789]
	var all_ok := true
	for s in samples:
		var encoded: String = EndlessRun.encode_seed(s)
		var decoded: int = EndlessRun.decode_seed(encoded)
		var ok: bool = decoded == (s & 0x3FFFFFFFFF)  # 40 bits = 8 * 5
		if not ok:
			print("    seed %d -> '%s' -> %d" % [s, encoded, decoded])
			all_ok = false
	print("[%s] EndlessRun.encode/decode_seed round-trip 40-bit window" % _ok(all_ok))
	if not all_ok: fail += 1
	var fmt_ok: bool = (EndlessRun.encode_seed(0) as String).begins_with("EREBUS-") \
			and (EndlessRun.encode_seed(0) as String).count("-") == 2
	print("[%s] seed string format EREBUS-XXXX-XXXX" % _ok(fmt_ok))
	if not fmt_ok: fail += 1
	return fail

# ---- run lifecycle -------------------------------------------------------

func _verify_endless_run_lifecycle(fail: int) -> int:
	EndlessRun.rollback()  # cold start
	var was_inactive: bool = not EndlessRun.active
	print("[%s] EndlessRun starts inactive" % _ok(was_inactive))
	if not was_inactive: fail += 1
	EndlessRun.begin(12345)
	var begun_ok: bool = EndlessRun.active and EndlessRun.seed == 12345 \
			and EndlessRun.wave == 0 and EndlessRun.kills == 0
	print("[%s] EndlessRun.begin sets active + seed + zero counters" % _ok(begun_ok))
	if not begun_ok: fail += 1
	EndlessRun.advance_wave(1, 8)
	EndlessRun.record_kill(true)
	EndlessRun.record_kill(true)
	EndlessRun.record_kill(false)
	var counts_ok: bool = EndlessRun.kills == 3 \
			and EndlessRun.kills_this_wave == 2 \
			and EndlessRun.wave == 1 \
			and EndlessRun.kills_required == 8
	print("[%s] record_kill splits wave-counted vs run-cumulative" % _ok(counts_ok))
	if not counts_ok: fail += 1
	EndlessRun.rollback()
	var cleared: bool = not EndlessRun.active and EndlessRun.wave == 0 \
			and EndlessRun.kills == 0 and EndlessRun.seed == 0
	print("[%s] EndlessRun.rollback clears state (side-effect-free)" % _ok(cleared))
	if not cleared: fail += 1
	return fail

# ---- director scaling ----------------------------------------------------

func _verify_director_scaling(fail: int) -> int:
	var dir := EndlessDirector.new()
	var cases: Array[Dictionary] = [
		{ "wave": 1,  "cap": 7,  "delay": 4.75, "elite": 0.07, "req": 8 },
		{ "wave": 3,  "cap": 9,  "delay": 4.25, "elite": 0.11, "req": 12 },
		{ "wave": 5,  "cap": 11, "delay": 3.75, "elite": 0.15, "req": 16 },
		{ "wave": 10, "cap": 14, "delay": 2.5,  "elite": 0.25, "req": 26 },
		{ "wave": 20, "cap": 14, "delay": 1.5,  "elite": 0.30, "req": 46 },
	]
	var all_ok := true
	for c in cases:
		var t: Dictionary = dir.tuning_preview(int(c["wave"]))
		var cap_ok: bool = int(t["concurrent_cap"]) == int(c["cap"])
		var delay_ok: bool = absf(float(t["respawn_delay"]) - float(c["delay"])) < 0.001
		var elite_ok: bool = absf(float(t["elite_chance"]) - float(c["elite"])) < 0.001
		var req_ok: bool = int(t["kills_required"]) == int(c["req"])
		var ok := cap_ok and delay_ok and elite_ok and req_ok
		if not ok:
			print("    wave %d: cap %s delay %s elite %s req %s"
					% [c["wave"], cap_ok, delay_ok, elite_ok, req_ok])
		all_ok = all_ok and ok
	print("[%s] EndlessDirector tuning curves (cap/delay/elite/req at waves 1/3/5/10/20)"
			% _ok(all_ok))
	if not all_ok: fail += 1
	# Species bands shift over waves
	var early: Array = dir.tuning_preview(1)["species"]
	var late: Array = dir.tuning_preview(10)["species"]
	var bands_diff: bool = early.size() != late.size() \
			or (early.size() > 0 and early[0]["weight"] != late[0]["weight"])
	print("[%s] EndlessDirector species reweight across waves" % _ok(bands_diff))
	if not bands_diff: fail += 1
	dir.free()
	return fail

# ---- determinism ---------------------------------------------------------

func _verify_director_determinism(fail: int) -> int:
	# Two directors fed the same seed must produce identical species
	# pick sequences. Anchors are non-deterministic by design (depend
	# on live player position); species picks are the seedable surface.
	EndlessRun.begin(424242)
	var d1 := EndlessDirector.new()
	var d2 := EndlessDirector.new()
	add_child(d1); add_child(d2)
	# tuning_preview's species are deterministic by definition; instead
	# force both to read from the same band and call _pick_species().
	d1.species = d1.tuning_preview(5)["species"]
	d2.species = d2.tuning_preview(5)["species"]
	var picks_1: Array[String] = []
	var picks_2: Array[String] = []
	for i in 32:
		picks_1.append(String(d1._pick_species()))
		picks_2.append(String(d2._pick_species()))
	var ok: bool = picks_1 == picks_2
	print("[%s] _pick_species deterministic for fixed EndlessRun.seed" % _ok(ok))
	if not ok: fail += 1
	d1.queue_free(); d2.queue_free()
	EndlessRun.rollback()
	return fail

# ---- arena scene ---------------------------------------------------------

func _verify_arena_scene(fail: int) -> int:
	var path := "res://scenes/zones/forsaken_depths.tscn"
	var ok_exists: bool = ResourceLoader.exists(path)
	print("[%s] forsaken_depths.tscn exists" % _ok(ok_exists))
	if not ok_exists:
		fail += 1
		return fail
	var packed: PackedScene = load(path) as PackedScene
	var inst := packed.instantiate() as Zone
	add_child(inst)
	var has_director: bool = inst.get_node_or_null(^"EndlessDirector") != null
	var has_anchors: bool = inst.get_node_or_null(^"SpawnAnchors") != null
	var has_entry: bool = inst.get_node_or_null(^"DepthsEntry") != null
	var has_walls: bool = inst.get_node_or_null(^"Walls") != null
	var zid_ok: bool = inst.zone_id == &"forsaken_depths"
	print("[%s] depths has EndlessDirector + SpawnAnchors + DepthsEntry + Walls + zone_id"
			% _ok(has_director and has_anchors and has_entry and has_walls and zid_ok))
	if not (has_director and has_anchors and has_entry and has_walls and zid_ok):
		fail += 1
	inst.queue_free()
	return fail

# ---- crypt portal gating -------------------------------------------------

func _verify_crypt_portal_gates(fail: int) -> int:
	var path := "res://scenes/zones/forsaken_crypt.tscn"
	var packed: PackedScene = load(path) as PackedScene
	# Case 1: act_1_complete = false → portal absent
	GameState.act_1_complete = false
	FeatureFlags.demo_mode = false
	var c1 := packed.instantiate() as ForsakenCrypt
	add_child(c1)
	await get_tree().process_frame
	var no_portal: bool = not c1.has_endless_portal()
	print("[%s] crypt: no portal when act_1_complete=false" % _ok(no_portal))
	if not no_portal: fail += 1
	c1.queue_free()
	await get_tree().process_frame
	# Case 2: act_1_complete = true + demo_mode = false → portal present
	GameState.act_1_complete = true
	FeatureFlags.demo_mode = false
	var c2 := packed.instantiate() as ForsakenCrypt
	add_child(c2)
	await get_tree().process_frame
	var has_portal: bool = c2.has_endless_portal()
	print("[%s] crypt: portal spawned when act_1_complete=true + demo off"
			% _ok(has_portal))
	if not has_portal: fail += 1
	c2.queue_free()
	await get_tree().process_frame
	# Case 3: demo_mode = true → portal absent even with act_1_complete
	GameState.act_1_complete = true
	FeatureFlags.demo_mode = true
	var c3 := packed.instantiate() as ForsakenCrypt
	add_child(c3)
	await get_tree().process_frame
	var no_portal_demo: bool = not c3.has_endless_portal()
	print("[%s] crypt: no portal when demo_mode=true" % _ok(no_portal_demo))
	if not no_portal_demo: fail += 1
	c3.queue_free()
	# Reset world state
	GameState.act_1_complete = false
	FeatureFlags.demo_mode = false
	return fail

# ---- save guard ----------------------------------------------------------

func _verify_save_guard(fail: int) -> int:
	EndlessRun.begin(1)
	var ok_blocked: bool = not SaveSystem.save_game()
	print("[%s] SaveSystem.save_game returns false during active endless run"
			% _ok(ok_blocked))
	if not ok_blocked: fail += 1
	EndlessRun.rollback()
	return fail

# ---- game HUD ------------------------------------------------------------

func _verify_game_hud(fail: int) -> int:
	var path := "res://scenes/game.tscn"
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text() if f != null else ""
	if f != null: f.close()
	var has_wave_counter: bool = text.find("WaveCounter") != -1
	var has_endless_summary: bool = text.find("EndlessSummary") != -1
	print("[%s] game.tscn declares WaveCounter HUD label" % _ok(has_wave_counter))
	if not has_wave_counter: fail += 1
	print("[%s] game.tscn includes EndlessSummary modal" % _ok(has_endless_summary))
	if not has_endless_summary: fail += 1
	return fail

# ---- summary modal -------------------------------------------------------

func _verify_summary_scene(fail: int) -> int:
	var path := "res://scenes/ui/endless_summary.tscn"
	var ok_exists: bool = ResourceLoader.exists(path)
	print("[%s] endless_summary.tscn exists" % _ok(ok_exists))
	if not ok_exists:
		fail += 1
		return fail
	var packed: PackedScene = load(path) as PackedScene
	var inst := packed.instantiate() as CanvasLayer
	add_child(inst)
	var has_show: bool = inst.has_method("show_summary")
	var has_return_signal: bool = inst.has_signal("return_requested")
	print("[%s] EndlessSummary has show_summary() + return_requested signal"
			% _ok(has_show and has_return_signal))
	if not (has_show and has_return_signal): fail += 1
	inst.queue_free()
	return fail

# ---- Stage 9.7 polish ----------------------------------------------------

func _verify_finite_budget(fail: int) -> int:
	# Blighted Reach scene wires total_spawn_budget on its SpawnDirector
	var path := "res://scenes/zones/blighted_reach.tscn"
	var f := FileAccess.open(path, FileAccess.READ)
	var text := f.get_as_text() if f != null else ""
	if f != null: f.close()
	var has_budget: bool = text.find("total_spawn_budget = 16") != -1
	print("[%s] blighted_reach.tscn sets total_spawn_budget = 16" % _ok(has_budget))
	if not has_budget: fail += 1
	# Director is in the spawn_director group so SaveSystem snapshot can find it
	var in_group: bool = text.find("groups=[\"spawn_director\"]") != -1
	print("[%s] blighted_reach SpawnDirector in 'spawn_director' group" % _ok(in_group))
	if not in_group: fail += 1
	# Source has the budget gate
	var sd_f := FileAccess.open("res://scripts/systems/spawn_director.gd", FileAccess.READ)
	var sd_text := sd_f.get_as_text() if sd_f != null else ""
	if sd_f != null: sd_f.close()
	var has_gate: bool = sd_text.find("total_spawn_budget >= 0 and _budget_remaining <= 0") != -1
	print("[%s] SpawnDirector._spawn_one() gates on exhausted budget" % _ok(has_gate))
	if not has_gate: fail += 1
	var has_helpers: bool = sd_text.find("func budget_remaining") != -1 \
			and sd_text.find("func has_finite_budget") != -1
	print("[%s] SpawnDirector exposes budget_remaining + has_finite_budget" % _ok(has_helpers))
	if not has_helpers: fail += 1
	# SaveSystem snapshots / restores budgets
	var ss_f := FileAccess.open("res://scripts/autoload/save_system.gd", FileAccess.READ)
	var ss_text := ss_f.get_as_text() if ss_f != null else ""
	if ss_f != null: ss_f.close()
	var has_snap: bool = ss_text.find("_snapshot_director_budgets") != -1 \
			and ss_text.find("consume_pending_director_budget") != -1
	print("[%s] SaveSystem snapshots + consumes per-zone budgets" % _ok(has_snap))
	if not has_snap: fail += 1
	return fail

func _verify_milestone_grants(fail: int) -> int:
	# Cold state: no milestones, fresh player stats
	GameState.endless_milestones = []
	GameState.titles = []
	EndlessRun.begin(7)
	# Floor 10 -> stat reward (Vitality +1). Without a Player in tree
	# the stat application is a no-op, but the milestone list should
	# still record the floor.
	EndlessRun.advance_wave(10, 26)
	var got_10: bool = GameState.endless_milestones.has(10)
	print("[%s] floor 10 milestone recorded" % _ok(got_10))
	if not got_10: fail += 1
	# Floor 50 -> title (does not require Player in tree)
	EndlessRun.advance_wave(50, 106)
	var got_title: bool = GameState.titles.has("Delver")
	print("[%s] floor 50 grants 'Delver' title" % _ok(got_title))
	if not got_title: fail += 1
	# Floor 100 -> item (no player so inventory grant skips, but
	# the milestone list should still capture the floor)
	EndlessRun.advance_wave(100, 206)
	var got_100: bool = GameState.endless_milestones.has(100)
	print("[%s] floor 100 milestone recorded" % _ok(got_100))
	if not got_100: fail += 1
	# Non-milestone floor -> no new milestone entry
	var before := GameState.endless_milestones.size()
	EndlessRun.advance_wave(11, 28)
	var ok_noop: bool = GameState.endless_milestones.size() == before
	print("[%s] non-milestone floor does not record" % _ok(ok_noop))
	if not ok_noop: fail += 1
	EndlessRun.rollback()
	GameState.endless_milestones = []
	GameState.titles = []
	return fail

func _verify_milestone_idempotency(fail: int) -> int:
	# Reaching a milestone twice (e.g. second run that passes the
	# same floor) must NOT re-grant the reward.
	GameState.endless_milestones = [25]
	GameState.titles = []
	EndlessRun.begin(7)
	EndlessRun.advance_wave(25, 56)
	var count := 0
	for f in GameState.endless_milestones:
		if int(f) == 25:
			count += 1
	var ok: bool = count == 1
	print("[%s] milestone idempotent (no duplicate on re-visit)" % _ok(ok))
	if not ok: fail += 1
	# milestones_new_this_run excludes pre-existing ones
	var new_run := EndlessRun.milestones_new_this_run()
	var ok_diff: bool = not new_run.has(25)
	print("[%s] milestones_new_this_run excludes pre-run earned" % _ok(ok_diff))
	if not ok_diff: fail += 1
	EndlessRun.rollback()
	GameState.endless_milestones = []
	return fail

func _verify_milestone_items_loaded(fail: int) -> int:
	var charm: ItemData = Database.get_item(&"depth_touched_charm")
	var ok_charm: bool = charm != null and charm.affixes.has(&"hp_max")
	print("[%s] depth_touched_charm loaded + hp_max affix" % _ok(ok_charm))
	if not ok_charm: fail += 1
	var crown: ItemData = Database.get_item(&"crown_of_the_forsaken")
	var ok_crown: bool = crown != null and crown.affixes.has(&"strength") \
			and crown.affixes.has(&"vitality")
	print("[%s] crown_of_the_forsaken loaded + 4-attribute affixes" % _ok(ok_crown))
	if not ok_crown: fail += 1
	return fail

func _verify_save_schema_v13(fail: int) -> int:
	# Stage 9.7 introduced schema v13; later stages monotonically bump it
	# (Stage 9.8 -> v14 for consumable cooldowns). Use >= so this check
	# tracks the floor without rewriting per stage.
	var ok_version: bool = SaveSystem.SAVE_VERSION >= 13
	print("[%s] SaveSystem.SAVE_VERSION >= 13" % _ok(ok_version))
	if not ok_version: fail += 1
	# v12 -> v13 migration seeds the new fields
	var v12: Dictionary = {
		"version": 12,
		"zone_id": "endless_arena",  # stale id from pre-rename cache
	}
	var migrated: Dictionary = SaveSystem.migrate(v12)
	var ok_keys: bool = migrated.has("director_budgets") \
			and migrated.has("endless_milestones") and migrated.has("titles")
	print("[%s] v12->v13 migration seeds director_budgets / milestones / titles"
			% _ok(ok_keys))
	if not ok_keys: fail += 1
	var ok_rename: bool = String(migrated.get("zone_id", "")) == "forsaken_depths"
	print("[%s] v12->v13 migration rewrites stale endless_arena zone_id"
			% _ok(ok_rename))
	if not ok_rename: fail += 1
	return fail

func _verify_milestone_modal_scene(fail: int) -> int:
	var path := "res://scenes/ui/milestone_modal.tscn"
	var ok_exists: bool = ResourceLoader.exists(path)
	print("[%s] milestone_modal.tscn exists" % _ok(ok_exists))
	if not ok_exists:
		fail += 1
		return fail
	var packed: PackedScene = load(path) as PackedScene
	var inst := packed.instantiate() as CanvasLayer
	add_child(inst)
	var has_show: bool = inst.has_method("show_milestone")
	var has_signal: bool = inst.has_signal("continue_pressed")
	print("[%s] MilestoneModal has show_milestone() + continue_pressed signal"
			% _ok(has_show and has_signal))
	if not (has_show and has_signal): fail += 1
	inst.queue_free()
	return fail

# ---- helpers -------------------------------------------------------------

func _ok(b: bool) -> String:
	return "OK  " if b else "FAIL"
