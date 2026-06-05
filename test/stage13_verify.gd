extends Node
## Stage 13 verifier — WorldSeed + ZoneProcgen + asset variants +
## Blighted Reach integration. No live playtest — every check runs
## headless.

func _ready() -> void:
	var fail := 0
	print("--- Stage 13 verify ---")

	fail = _verify_world_seed_autoload(fail)
	fail = _verify_sub_seed_determinism(fail)
	fail = _verify_share_string_roundtrip(fail)
	fail = _verify_save_version_and_migration(fail)
	fail = _verify_tree_variants(fail)
	fail = _verify_rock_variants(fail)
	fail = _verify_palette_swap_attached(fail)
	fail = _verify_enemy_palette_field(fail)
	fail = _verify_zone_procgen_shape(fail)
	fail = _verify_zone_procgen_determinism(fail)
	fail = _verify_zone_procgen_divergence(fail)
	fail = _verify_reach_scene_trimmed(fail)
	fail = _verify_spawn_director_defer_safe(fail)
	fail = _verify_zone_caches_persisted(fail)

	print("--- Stage 13 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- WorldSeed ----------------------------------------------------------

func _verify_world_seed_autoload(fail: int) -> int:
	var root: Node = Engine.get_main_loop().root
	var ws := root.get_node_or_null(^"WorldSeed")
	fail = _expect(ws != null, "WorldSeed autoload registered", fail)
	if ws == null:
		return fail
	for method in ["assign_random", "sub_seed", "make_rng",
			"encode_seed", "decode_seed", "snapshot", "restore"]:
		fail = _expect(ws.has_method(method),
				"WorldSeed has method %s" % method, fail)
	# Default master_seed defined.
	fail = _expect("master_seed" in ws,
			"WorldSeed.master_seed field exists", fail)
	return fail

func _verify_sub_seed_determinism(fail: int) -> int:
	WorldSeed.master_seed = 12345
	var a := WorldSeed.sub_seed(&"blighted_reach", 0)
	var b := WorldSeed.sub_seed(&"blighted_reach", 0)
	fail = _expect(a == b,
			"sub_seed deterministic for same (master, zone, salt)", fail)
	var c := WorldSeed.sub_seed(&"blighted_reach", 1)
	fail = _expect(a != c,
			"sub_seed diverges across salts", fail)
	var d := WorldSeed.sub_seed(&"forsaken_crypt", 0)
	fail = _expect(a != d,
			"sub_seed diverges across zone ids", fail)
	WorldSeed.master_seed = 67890
	var e := WorldSeed.sub_seed(&"blighted_reach", 0)
	fail = _expect(a != e,
			"sub_seed diverges when master_seed changes", fail)
	return fail

func _verify_share_string_roundtrip(fail: int) -> int:
	# Encode is one-way (drops sign + truncates to 40 bits), so the
	# roundtrip is encode → decode → encode of the same value.
	var n: int = 1234567890
	var s1: String = WorldSeed.encode_seed(n)
	var d1: int = WorldSeed.decode_seed(s1)
	var s2: String = WorldSeed.encode_seed(d1)
	fail = _expect(s1 == s2,
			"encode_seed round-trip is stable", fail)
	fail = _expect(s1.begins_with("EREBUS-"),
			"encode_seed produces EREBUS-XXXX-XXXX format", fail)
	return fail

func _verify_save_version_and_migration(fail: int) -> int:
	fail = _expect(SaveSystem.SAVE_VERSION >= 16,
			"SAVE_VERSION >= 16", fail)
	# Build a fake v14 save and migrate it through v15 + v16.
	var legacy: Dictionary = {
		"version": 14,
		"consumable_cooldowns": { "cooldowns": {} },
	}
	var migrated := SaveSystem.migrate(legacy)
	fail = _expect(int(migrated.get("version", 0)) >= 16,
			"v14 migrates to >= 16", fail)
	fail = _expect(migrated.has("world_seed"),
			"v15 migration installs world_seed key", fail)
	fail = _expect(int(migrated.get("world_seed", -1)) == 0,
			"legacy world_seed defaults to 0", fail)
	fail = _expect(migrated.has("zone_caches"),
			"v16 migration installs zone_caches key", fail)
	fail = _expect((migrated.get("zone_caches", null) as Dictionary).is_empty(),
			"legacy zone_caches defaults to empty dict", fail)
	return fail

# ---- variants -----------------------------------------------------------

func _verify_tree_variants(fail: int) -> int:
	for i in 3:
		var path := ZoneProcgen.tree_scene_path(i)
		fail = _expect(path != "",
				"ZoneProcgen.tree_scene_path(%d) returns a path" % i, fail)
		fail = _expect(ResourceLoader.exists(path),
				"tree variant %d loads from disk" % i, fail)
	fail = _expect(ZoneProcgen.tree_scene_path(-1) == "",
			"tree_scene_path rejects invalid variant", fail)
	return fail

func _verify_rock_variants(fail: int) -> int:
	for i in 3:
		var path := ZoneProcgen.rock_scene_path(i)
		fail = _expect(path != "",
				"ZoneProcgen.rock_scene_path(%d) returns a path" % i, fail)
		fail = _expect(ResourceLoader.exists(path),
				"rock variant %d loads from disk" % i, fail)
	return fail

func _verify_palette_swap_attached(fail: int) -> int:
	# Sprite scenes must reference the palette script + carry a non-
	# empty palette_table for variant 1.
	var shade_path := "res://art/procedural/enemies/shade_wretch_sprite.tscn"
	var bog_path := "res://art/procedural/enemies/bog_caller_sprite.tscn"
	for p in [shade_path, bog_path]:
		var text := FileAccess.get_file_as_string(p)
		fail = _expect(text.contains("enemy_sprite_palette.gd"),
				"%s references EnemySpritePalette" % p, fail)
		fail = _expect(text.contains("palette_table"),
				"%s bakes a palette_table" % p, fail)
	# Instantiate one and confirm variant 1 applies tints to known
	# children (run through the script's apply() path).
	var packed: PackedScene = load(shade_path) as PackedScene
	var inst := packed.instantiate()
	var default_cloak: Color = inst.get_node("Body/Cloak").color
	inst.apply(1)
	var v1_cloak: Color = inst.get_node("Body/Cloak").color
	fail = _expect(default_cloak != v1_cloak,
			"ShadeWretchSprite.apply(1) re-tints Body/Cloak", fail)
	inst.free()
	return fail

func _verify_enemy_palette_field(fail: int) -> int:
	var enemy_src := FileAccess.get_file_as_string("res://scripts/enemies/enemy.gd")
	fail = _expect(enemy_src.contains("palette_variant"),
			"Enemy script declares palette_variant", fail)
	fail = _expect(enemy_src.contains("palette_variant\" in inst"),
			"Enemy forwards palette_variant to sprite before add_child", fail)
	var sd_src := FileAccess.get_file_as_string("res://scripts/systems/spawn_director.gd")
	fail = _expect(sd_src.contains("palette_per_archetype"),
			"SpawnDirector exposes palette_per_archetype", fail)
	return fail

# ---- ZoneProcgen --------------------------------------------------------

func _verify_zone_procgen_shape(fail: int) -> int:
	WorldSeed.master_seed = 11
	var bounds := Rect2(Vector2(-400, -400), Vector2(800, 800))
	var result := ZoneProcgen.generate_for(&"test_zone", bounds, [], 8, 4, 0.7)
	fail = _expect(result.has("props"),
			"ZoneProcgen result has props key", fail)
	fail = _expect(result.has("anchors"),
			"ZoneProcgen result has anchors key", fail)
	fail = _expect(result.has("palette"),
			"ZoneProcgen result has palette key", fail)
	var palette: Dictionary = result["palette"]
	fail = _expect(palette.has(&"shade_wretch"),
			"palette covers shade_wretch", fail)
	fail = _expect(palette.has(&"bog_caller"),
			"palette covers bog_caller", fail)
	var props: Array = result["props"]
	for entry in props:
		var e := entry as Dictionary
		fail = _expect(e.has("kind") and e.has("variant") \
				and e.has("pos") and e.has("scale"),
				"prop entry has full shape", fail)
		break
	return fail

func _verify_zone_procgen_determinism(fail: int) -> int:
	WorldSeed.master_seed = 4242
	var bounds := Rect2(Vector2(-400, -400), Vector2(800, 800))
	var a := ZoneProcgen.generate_for(&"det_zone", bounds, [], 10, 5, 0.6)
	var b := ZoneProcgen.generate_for(&"det_zone", bounds, [], 10, 5, 0.6)
	fail = _expect((a["props"] as Array).size() == (b["props"] as Array).size(),
			"same seed → same prop count", fail)
	var same_positions := true
	for i in (a["props"] as Array).size():
		var pa: Vector2 = (a["props"][i] as Dictionary)["pos"]
		var pb: Vector2 = (b["props"][i] as Dictionary)["pos"]
		if not pa.is_equal_approx(pb):
			same_positions = false
			break
	fail = _expect(same_positions,
			"same seed → identical prop positions", fail)
	var same_palette: bool = (a["palette"] as Dictionary).hash() \
			== (b["palette"] as Dictionary).hash()
	fail = _expect(same_palette,
			"same seed → identical palette pick", fail)
	return fail

func _verify_zone_procgen_divergence(fail: int) -> int:
	WorldSeed.master_seed = 4242
	var bounds := Rect2(Vector2(-400, -400), Vector2(800, 800))
	var a := ZoneProcgen.generate_for(&"div_zone", bounds, [], 10, 5, 0.6)
	WorldSeed.master_seed = 9999
	var b := ZoneProcgen.generate_for(&"div_zone", bounds, [], 10, 5, 0.6)
	var any_diff := false
	var size_a: int = (a["props"] as Array).size()
	var size_b: int = (b["props"] as Array).size()
	if size_a != size_b:
		any_diff = true
	else:
		for i in size_a:
			var pa: Vector2 = (a["props"][i] as Dictionary)["pos"]
			var pb: Vector2 = (b["props"][i] as Dictionary)["pos"]
			if not pa.is_equal_approx(pb):
				any_diff = true
				break
	fail = _expect(any_diff,
			"different master seeds → at least one prop differs", fail)
	return fail

# ---- Blighted Reach integration ----------------------------------------

func _verify_reach_scene_trimmed(fail: int) -> int:
	var text := FileAccess.get_file_as_string(
			"res://scenes/zones/blighted_reach.tscn")
	# Legacy hand-placed nodes must be gone (regex-style substring).
	fail = _expect(not text.contains("\"T0\" parent=\"Trees\""),
			"reach.tscn no longer carries hand-placed T0", fail)
	fail = _expect(not text.contains("\"A0\" type=\"Marker2D\" parent=\"SpawnAnchors\""),
			"reach.tscn no longer carries hand-placed A0", fail)
	# Containers still present (procgen populates them at _ready).
	fail = _expect(text.contains("name=\"Trees\""),
			"reach.tscn keeps the Trees container", fail)
	fail = _expect(text.contains("name=\"SpawnAnchors\""),
			"reach.tscn keeps the SpawnAnchors container", fail)
	var gd_src := FileAccess.get_file_as_string(
			"res://scripts/zones/blighted_reach.gd")
	fail = _expect(gd_src.contains("ZoneProcgen.generate_for"),
			"blighted_reach.gd calls ZoneProcgen.generate_for", fail)
	fail = _expect(gd_src.contains("_apply_palette_pick"),
			"blighted_reach.gd forwards palette pick to director", fail)
	return fail

# ---- defer-safe pending-snapshot capture (regression guard) -------------

func _verify_spawn_director_defer_safe(fail: int) -> int:
	# Stage 13 regression: deferring the director's init opened a
	# race where game.gd consumed the pending enemy snapshot before
	# the director checked for it, causing initial spawn to re-fire
	# on top of restored cached enemies (wilderness "reset" on
	# return to town). Fix captures the bool synchronously in _ready.
	# This assert is source-level so future refactors can't silently
	# regress the capture.
	var src := FileAccess.get_file_as_string(
			"res://scripts/systems/spawn_director.gd")
	fail = _expect(src.contains("_has_pending_snapshot_at_ready"),
			"SpawnDirector captures pending-snapshot flag at _ready", fail)
	# The capture line must precede the call_deferred — otherwise the
	# defer happens first and the bool is read in the wrong frame.
	var capture_pos := src.find("_has_pending_snapshot_at_ready = SaveSystem.has_pending_enemy_snapshot()")
	var defer_pos := src.find("call_deferred(\"_init_after_zone_ready\")")
	fail = _expect(capture_pos > 0 and defer_pos > 0 and capture_pos < defer_pos,
			"capture runs BEFORE call_deferred in _ready", fail)
	return fail

# ---- zone_caches persistence (regression guard for save-in-town wipe) ---

func _verify_zone_caches_persisted(fail: int) -> int:
	# SaveSystem must expose the set/consume pair, SceneRouter must
	# forward to game.gd's snapshot method, and game.gd must implement
	# it. The full runtime round-trip is exercised by the playtest;
	# this is the structural guard so a future refactor can't silently
	# regress the wire.
	fail = _expect(SaveSystem.has_method("set_pending_zone_caches"),
			"SaveSystem.set_pending_zone_caches exists", fail)
	fail = _expect(SaveSystem.has_method("consume_pending_zone_caches"),
			"SaveSystem.consume_pending_zone_caches exists", fail)
	# Round-trip the field directly.
	var sample := { "blighted_reach": { "enemies": [{"id": "shade_wretch"}], "loot": [] } }
	SaveSystem.set_pending_zone_caches(sample)
	var popped := SaveSystem.consume_pending_zone_caches()
	fail = _expect(popped.has("blighted_reach"),
			"set/consume pending zone caches round-trips", fail)
	# After consume the field must be empty so a subsequent save
	# doesn't pick up stale data.
	var second := SaveSystem.consume_pending_zone_caches()
	fail = _expect(second.is_empty(),
			"consume clears _pending_zone_caches", fail)
	# SceneRouter exposes the forwarding hook.
	fail = _expect(SceneRouter.has_method("snapshot_zone_caches"),
			"SceneRouter.snapshot_zone_caches exists", fail)
	# game.gd source-level: snapshot method declared + auto-load
	# branch consumes the pending caches.
	var src := FileAccess.get_file_as_string("res://scenes/game.gd")
	fail = _expect(src.contains("snapshot_zone_cache_for_save"),
			"game.gd implements snapshot_zone_cache_for_save", fail)
	fail = _expect(src.contains("consume_pending_zone_caches"),
			"game.gd consumes pending zone caches on load", fail)
	# SaveSystem.save_game must auto-fetch via SceneRouter so every
	# callsite (manual F5, endless portal anchor save, ember-exit
	# zone override, milestone-recommit save) picks up the cache
	# without per-caller boilerplate.
	var save_src := FileAccess.get_file_as_string(
			"res://scripts/autoload/save_system.gd")
	fail = _expect(save_src.contains("SceneRouter.snapshot_zone_caches"),
			"SaveSystem.save_game auto-fetches via SceneRouter", fail)
	return fail
