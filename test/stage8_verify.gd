extends Node
## Stage 8 verifier — dungeon scaffold + elite suffix + affix tier.
## All checks are structural/code-inspection: the dungeon scene loads,
## the registries return the expected shapes, the save schema bumps
## and round-trips. Visual playtest of gate dissolves and elite tints
## is the user's job in the next pass.

const _PREFIX_TABLE_PATH := "res://data/affixes/prefix_table.tres"
const _CRYPT_SCENE := "res://scenes/zones/forsaken_crypt.tscn"
const _BLIGHTED_REACH := "res://scenes/zones/blighted_reach.tscn"

const _EXPECTED_PREFIX_STATS: Array[StringName] = [
	&"strength", &"dexterity", &"vitality", &"pneuma",
	&"hp_max", &"armor_defense",
]
const _EXPECTED_ELITE_IDS: Array[StringName] = [
	&"elite_fast", &"elite_tough", &"elite_spawner",
]

func _ready() -> void:
	var fail := 0
	print("--- Stage 8 verify ---")

	fail = _verify_prefix_table(fail)
	fail = _verify_elite_modifiers(fail)
	fail = _verify_instance_registry(fail)
	fail = _verify_database_dispatch(fail)
	fail = _verify_inventory_cap(fail)
	fail = await _verify_crypt_scene(fail)
	fail = await _verify_blighted_entrance(fail)
	fail = _verify_scene_router(fail)
	fail = _verify_save_schema(fail)
	fail = _verify_save_roundtrip(fail)
	fail = _verify_audio_bank(fail)

	print("--- Stage 8 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _verify_prefix_table(fail: int) -> int:
	var table := load(_PREFIX_TABLE_PATH) as PrefixTable
	var ok_load := table != null
	print("[%s] PrefixTable loads at %s" % [_ok(ok_load), _PREFIX_TABLE_PATH])
	if not ok_load:
		return fail + 1
	var ok_size := table.size() == 6
	print("[%s] PrefixTable has 6 entries (got %d)" % [_ok(ok_size), table.size()])
	if not ok_size: fail += 1
	var stats_present: Dictionary = {}
	for entry_v in table.entries:
		var entry: Dictionary = entry_v
		stats_present[StringName(entry.get("stat", &""))] = true
		var word := String(entry.get("word", ""))
		var value := int(entry.get("value", 0))
		var ok_entry := word != "" and value > 0
		print("[%s]   prefix '%s' +%d %s" % [_ok(ok_entry),
				word, value, entry.get("stat", "")])
		if not ok_entry: fail += 1
	for k in _EXPECTED_PREFIX_STATS:
		var ok_stat := stats_present.has(k)
		print("[%s]   prefix table covers stat '%s'" % [_ok(ok_stat), k])
		if not ok_stat: fail += 1
	return fail

func _verify_elite_modifiers(fail: int) -> int:
	for id in _EXPECTED_ELITE_IDS:
		var em := EnemyRegistry.elite_modifier_for(id)
		var ok := em != null and em.id == id
		print("[%s] EliteModifier '%s' loads via EnemyRegistry"
				% [_ok(ok), id])
		if not ok: fail += 1
	# Spawner spawns something on death.
	var spawner := EnemyRegistry.elite_modifier_for(&"elite_spawner")
	var ok_spawner := spawner != null and spawner.spawns_on_death != &"" \
			and spawner.spawn_count > 0
	print("[%s] elite_spawner.spawns_on_death wired (%s x%d)"
			% [_ok(ok_spawner),
				str(spawner.spawns_on_death) if spawner != null else "?",
				spawner.spawn_count if spawner != null else 0])
	if not ok_spawner: fail += 1
	# Application path: spin up a bare Enemy and confirm pre-stats mutation.
	var test_enemy := Enemy.new()
	test_enemy.max_hp = 100
	test_enemy.defense_value = 4
	var tough := EnemyRegistry.elite_modifier_for(&"elite_tough")
	test_enemy.elite_modifier = tough
	test_enemy._apply_elite_pre_stats()
	var ok_apply := test_enemy.max_hp > 100 \
			and test_enemy.elite_damage_mult == tough.damage_mult
	print("[%s] EliteModifier mults applied via _apply_elite_pre_stats (hp=%d dmg_mult=%.2f)"
			% [_ok(ok_apply), test_enemy.max_hp, test_enemy.elite_damage_mult])
	if not ok_apply: fail += 1
	test_enemy.free()
	return fail

func _verify_instance_registry(fail: int) -> int:
	ItemInstanceRegistry.clear_instances()
	var ok_empty := ItemInstanceRegistry.instance_count() == 0
	print("[%s] ItemInstanceRegistry starts empty after clear"
			% _ok(ok_empty))
	if not ok_empty: fail += 1
	# Force a roll on a known base item.
	var base_id := _pick_base_item_id()
	if base_id == &"":
		print("[FAIL] could not find a base item to test roll against")
		return fail + 1
	ItemInstanceRegistry.force_next_index(0) # Mighty (+strength)
	var rolled := ItemInstanceRegistry.maybe_roll_prefix(base_id)
	var ok_rolled := rolled != base_id and ItemInstanceRegistry.is_instance(rolled)
	print("[%s] forced roll produces distinct instance id (%s -> %s)"
			% [_ok(ok_rolled), base_id, rolled])
	if not ok_rolled: fail += 1
	# Statistical check: 200 unforced rolls land in [25, 75] hits at 25% chance.
	# Wide band accommodates RNG variance without becoming a flaky test.
	ItemInstanceRegistry.clear_instances()
	var hits := 0
	for i in 200:
		var r := ItemInstanceRegistry.maybe_roll_prefix(base_id)
		if r != base_id:
			hits += 1
	var ok_stats := hits >= 25 and hits <= 75
	print("[%s] 200 rolls at 25%% land in [25,75] (got %d)"
			% [_ok(ok_stats), hits])
	if not ok_stats: fail += 1
	ItemInstanceRegistry.clear_instances()
	return fail

func _verify_database_dispatch(fail: int) -> int:
	ItemInstanceRegistry.clear_instances()
	var base_id := _pick_base_item_id()
	ItemInstanceRegistry.force_next_index(0) # Mighty +3 strength
	var instance_id := ItemInstanceRegistry.maybe_roll_prefix(base_id)
	var synth: ItemData = Database.get_item(instance_id) as ItemData
	var ok_synth := synth != null and synth.id == instance_id
	print("[%s] Database.get_item routes instance id to synthesized clone"
			% _ok(ok_synth))
	if not ok_synth: fail += 1
	if synth == null:
		return fail
	var ok_str := int(synth.affixes.get(&"strength", 0)) >= 3
	print("[%s] synth item carries +3 strength affix (got %d)"
			% [_ok(ok_str), int(synth.affixes.get(&"strength", 0))])
	if not ok_str: fail += 1
	var ok_name := synth.display_name.begins_with("Mighty ")
	print("[%s] synth item display_name starts with 'Mighty ' (got '%s')"
			% [_ok(ok_name), synth.display_name])
	if not ok_name: fail += 1
	var ok_color := synth.glyph_color == ItemInstanceRegistry.RARE_TINT
	print("[%s] synth item glyph_color is rare-tier blue"
			% _ok(ok_color))
	if not ok_color: fail += 1
	ItemInstanceRegistry.clear_instances()
	return fail

func _verify_inventory_cap(fail: int) -> int:
	var ok_cap := Inventory.BACKPACK_CAPACITY == 36
	print("[%s] Inventory.BACKPACK_CAPACITY == 36 (got %d)"
			% [_ok(ok_cap), Inventory.BACKPACK_CAPACITY])
	if not ok_cap: fail += 1
	return fail

func _verify_crypt_scene(fail: int) -> int:
	var packed := load(_CRYPT_SCENE) as PackedScene
	var ok_load := packed != null
	print("[%s] forsaken_crypt.tscn loads" % _ok(ok_load))
	if not ok_load: return fail + 1
	var inst := packed.instantiate() as ForsakenCrypt
	var ok_class := inst != null
	print("[%s] crypt root extends ForsakenCrypt" % _ok(ok_class))
	if not ok_class:
		if inst != null: inst.queue_free()
		return fail + 1
	add_child(inst)
	# Required structural children.
	var needs: Array[String] = [
		"Room1Anchors", "Room2Anchors", "Room3Anchors",
		"Gate1", "Gate2", "ReturnPortal", "SpawnPoint",
		"FromBlightedReach", "Enemies",
	]
	for name in needs:
		var ok := inst.has_node(name)
		print("[%s]   crypt has node '%s'" % [_ok(ok), name])
		if not ok: fail += 1
	# Anchor count: 3 + 5 + 2 by design.
	var counts: Array = [
		["Room1Anchors", 3], ["Room2Anchors", 5], ["Room3Anchors", 2],
	]
	for entry in counts:
		var n := inst.get_node_or_null(NodePath(entry[0])) as Node
		var got := 0 if n == null else n.get_child_count()
		var ok := got == int(entry[1])
		print("[%s]   '%s' has %d anchors (got %d)"
				% [_ok(ok), entry[0], int(entry[1]), got])
		if not ok: fail += 1
	# Gates start locked.
	var g1 := inst.get_node_or_null(^"Gate1") as Gate
	var g2 := inst.get_node_or_null(^"Gate2") as Gate
	var ok_locked := g1 != null and not g1.is_unlocked() \
			and g2 != null and not g2.is_unlocked()
	print("[%s] both gates start locked" % _ok(ok_locked))
	if not ok_locked: fail += 1
	# Return portal targets blighted_reach.
	var rp := inst.get_node_or_null(^"ReturnPortal") as Portal
	var ok_target := rp != null and rp.target_zone == &"blighted_reach"
	print("[%s] ReturnPortal targets blighted_reach" % _ok(ok_target))
	if not ok_target: fail += 1
	inst.queue_free()
	await get_tree().process_frame
	return fail

func _verify_blighted_entrance(fail: int) -> int:
	var packed := load(_BLIGHTED_REACH) as PackedScene
	var inst := packed.instantiate() as Node
	add_child(inst)
	var cp := inst.get_node_or_null(^"CryptPortal") as Portal
	var ok_present := cp != null
	print("[%s] BlightedReach has CryptPortal" % _ok(ok_present))
	if not ok_present:
		inst.queue_free()
		return fail + 1
	var ok_target := cp.target_zone == &"forsaken_crypt"
	print("[%s] CryptPortal targets forsaken_crypt"
			% _ok(ok_target))
	if not ok_target: fail += 1
	var marker := inst.get_node_or_null(^"FromForsakenCrypt") as Marker2D
	var ok_marker := marker != null
	print("[%s] BlightedReach has FromForsakenCrypt arrival marker"
			% _ok(ok_marker))
	if not ok_marker: fail += 1
	inst.queue_free()
	await get_tree().process_frame
	return fail

func _verify_scene_router(fail: int) -> int:
	var path := SceneRouter.zone_scene_path(&"forsaken_crypt")
	var ok := path == _CRYPT_SCENE
	print("[%s] SceneRouter.ZONE_PATHS['forsaken_crypt'] -> %s"
			% [_ok(ok), path])
	if not ok: fail += 1
	return fail

func _verify_save_schema(fail: int) -> int:
	var ok_v := SaveSystem.SAVE_VERSION == 11
	print("[%s] SaveSystem.SAVE_VERSION == 11 (got %d)"
			% [_ok(ok_v), SaveSystem.SAVE_VERSION])
	if not ok_v: fail += 1
	# Migration from v10 seeds the registry block.
	var old: Dictionary = { "version": 10 }
	var migrated := SaveSystem.migrate(old)
	var ok_mig := int(migrated.get("version", 0)) == 11 \
			and migrated.has("item_instances")
	print("[%s] migrate v10 -> v11 seeds item_instances block"
			% _ok(ok_mig))
	if not ok_mig: fail += 1
	return fail

func _verify_save_roundtrip(fail: int) -> int:
	ItemInstanceRegistry.clear_instances()
	var base_id := _pick_base_item_id()
	ItemInstanceRegistry.force_next_index(0)
	var instance_id := ItemInstanceRegistry.maybe_roll_prefix(base_id)
	var ok_minted := ItemInstanceRegistry.is_instance(instance_id)
	print("[%s] roundtrip: minted instance present"
			% _ok(ok_minted))
	if not ok_minted: fail += 1
	var snap := ItemInstanceRegistry.snapshot()
	ItemInstanceRegistry.clear_instances()
	var ok_cleared := not ItemInstanceRegistry.is_instance(instance_id)
	print("[%s] roundtrip: registry cleared mid-test"
			% _ok(ok_cleared))
	if not ok_cleared: fail += 1
	ItemInstanceRegistry.restore(snap)
	var ok_restored := ItemInstanceRegistry.is_instance(instance_id)
	print("[%s] roundtrip: registry restores instance from snapshot"
			% _ok(ok_restored))
	if not ok_restored: fail += 1
	var synth: ItemData = Database.get_item(instance_id) as ItemData
	var ok_synth_after := synth != null \
			and int(synth.affixes.get(&"strength", 0)) >= 3
	print("[%s] roundtrip: synth survives restore (+strength preserved)"
			% _ok(ok_synth_after))
	if not ok_synth_after: fail += 1
	ItemInstanceRegistry.clear_instances()
	return fail

func _verify_audio_bank(fail: int) -> int:
	var keys: Array = AudioBank.ambient_bank_keys()
	var ok := keys.has(&"forsaken_crypt")
	print("[%s] AudioBank registers forsaken_crypt ambient"
			% _ok(ok))
	if not ok: fail += 1
	return fail

# ---- helpers --------------------------------------------------------------

func _ok(b: bool) -> String:
	return "OK  " if b else "FAIL"

func _pick_base_item_id() -> StringName:
	# Any registered base item works for the roll-side tests. Take the
	# first sorted id for determinism in the verifier output.
	var ids: Array = Database.items.keys()
	ids.sort()
	for v in ids:
		if v is StringName and not ItemInstanceRegistry.is_instance(v):
			return v
	return &""
