extends Node
## Stage 15.1 verifier — bundled hotfix bundle:
## 1. zone_id updated on transit
## 2. weapon damage end-to-end
## 3. consumables never roll a prefix
## 4. save migration v17->v18 repairs stale-zone-id positions

func _ready() -> void:
	var fail := 0
	print("--- Stage 15.1 verify ---")

	fail = _verify_zone_id_set_on_transit_source(fail)
	fail = _verify_save_version_bumped(fail)
	fail = _verify_v17_to_v18_in_bounds_untouched(fail)
	fail = _verify_v17_to_v18_out_of_bounds_repaired(fail)
	fail = _verify_v17_to_v18_unknown_zone_untouched(fail)
	fail = _verify_v17_to_v18_matches_reported_save(fail)
	fail = _verify_v17_to_v18_clears_misattributed_enemies(fail)
	fail = _verify_v17_to_v18_in_bounds_keeps_enemies(fail)
	fail = _verify_item_data_has_weapon_damage(fail)
	fail = _verify_starter_weapons_have_damage(fail)
	fail = _verify_stats_weapon_damage_field(fail)
	fail = _verify_inventory_rolls_weapon_damage(fail)
	fail = _verify_damage_resolver_adds_weapon_damage(fail)
	fail = _verify_consumables_skip_prefix(fail)
	fail = _verify_equipment_still_rolls_prefix(fail)

	print("--- Stage 15.1 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- 1. zone_id on transit ----------------------------------------------

func _verify_zone_id_set_on_transit_source(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://scenes/game.gd")
	fail = _expect(src.contains("GameState.current_zone_id = zone_id"),
			"_do_transit writes GameState.current_zone_id", fail)
	return fail

# ---- 4. save migration --------------------------------------------------

func _verify_save_version_bumped(fail: int) -> int:
	fail = _expect(SaveSystem.SAVE_VERSION >= 18, "SAVE_VERSION >= 18", fail)
	return fail

func _verify_v17_to_v18_in_bounds_untouched(fail: int) -> int:
	# Player inside threshold_camp at the southern SpawnPoint area.
	var legacy := {
		"version": 17,
		"zone_id": "threshold_camp",
		"position": { "x": 0.0, "y": 140.0 },
	}
	var migrated := SaveSystem.migrate(legacy)
	var p: Dictionary = migrated.get("position", {})
	fail = _expect(int(migrated.get("version", 0)) >= 18,
			"in-bounds v17 migrates to >=18", fail)
	fail = _expect(float(p.get("y", 0.0)) == 140.0,
			"in-bounds position left untouched", fail)
	return fail

func _verify_v17_to_v18_out_of_bounds_repaired(fail: int) -> int:
	# The bug: zone=threshold_camp but position in wilderness coords.
	var legacy := {
		"version": 17,
		"zone_id": "threshold_camp",
		"position": { "x": 1.05, "y": -584.24 },
	}
	var migrated := SaveSystem.migrate(legacy)
	var p: Dictionary = migrated.get("position", {})
	fail = _expect(float(p.get("y", 0.0)) == 140.0,
			"out-of-bounds y=-584 snapped to threshold_camp spawn y=140", fail)
	fail = _expect(float(p.get("x", 0.0)) == 0.0,
			"out-of-bounds x snapped to spawn x=0", fail)
	return fail

func _verify_v17_to_v18_unknown_zone_untouched(fail: int) -> int:
	# A zone the migrator doesn't know about (forsaken_crypt etc).
	# Position must be left alone — we don't snap blindly.
	var legacy := {
		"version": 17,
		"zone_id": "forsaken_crypt",
		"position": { "x": 999.0, "y": 999.0 },
	}
	var migrated := SaveSystem.migrate(legacy)
	var p: Dictionary = migrated.get("position", {})
	fail = _expect(float(p.get("y", 0.0)) == 999.0,
			"unknown-zone position left untouched", fail)
	return fail

func _verify_v17_to_v18_matches_reported_save(fail: int) -> int:
	# Exact repro of the user's reported save file.
	var legacy := {
		"version": 17,
		"zone_id": "threshold_camp",
		"position": { "x": 1.05193686485291, "y": -584.238037109375 },
	}
	var migrated := SaveSystem.migrate(legacy)
	var p: Dictionary = migrated.get("position", {})
	# Threshold camp spawn = (0, 140); post-migration position must equal that.
	var ok := float(p.get("x", 1.0)) == 0.0 and float(p.get("y", 1.0)) == 140.0
	fail = _expect(ok, "reported-save case repaired to SpawnPoint", fail)
	return fail

# ---- 2. weapon damage ---------------------------------------------------

func _verify_v17_to_v18_clears_misattributed_enemies(fail: int) -> int:
	# When stale-zone repair fires, top-level enemies + loot must be
	# dropped — they were captured in the wrong zone's coordinate frame.
	var legacy := {
		"version": 17,
		"zone_id": "threshold_camp",
		"position": { "x": 1.05, "y": -584.24 },
		"enemies": [
			{ "archetype": "shade_wretch", "hp": 40, "pos": { "x": -560.0, "y": -360.0 } },
			{ "archetype": "shade_wretch", "hp": 90, "pos": { "x": 560.0, "y": -360.0 } },
		],
		"loot": [{ "id": "junk", "pos": { "x": 0.0, "y": 0.0 } }],
	}
	var migrated := SaveSystem.migrate(legacy)
	fail = _expect((migrated.get("enemies", null) as Array).is_empty(),
			"stale-zone repair clears misattributed enemies", fail)
	fail = _expect((migrated.get("loot", null) as Array).is_empty(),
			"stale-zone repair clears misattributed loot", fail)
	return fail

func _verify_v17_to_v18_in_bounds_keeps_enemies(fail: int) -> int:
	# An in-bounds save must NOT have its enemies dropped — only the
	# stale-zone case clears them.
	var legacy := {
		"version": 17,
		"zone_id": "threshold_camp",
		"position": { "x": 0.0, "y": 140.0 },
		"enemies": [{ "archetype": "x", "hp": 1, "pos": { "x": 0.0, "y": 0.0 } }],
		"loot": [{ "id": "y" }],
	}
	var migrated := SaveSystem.migrate(legacy)
	fail = _expect((migrated.get("enemies", []) as Array).size() == 1,
			"in-bounds save keeps its enemies", fail)
	fail = _expect((migrated.get("loot", []) as Array).size() == 1,
			"in-bounds save keeps its loot", fail)
	return fail

func _verify_item_data_has_weapon_damage(fail: int) -> int:
	var item := ItemData.new()
	fail = _expect("base_weapon_damage" in item,
			"ItemData declares base_weapon_damage field", fail)
	return fail

func _verify_starter_weapons_have_damage(fail: int) -> int:
	var ids := [
		&"myrmidon_spear_starter", &"pythia_staff_starter",
		&"shade_bow_starter", &"ossuary_wand_starter",
	]
	for id in ids:
		var item: ItemData = Database.items.get(id, null) as ItemData
		if item == null:
			fail = _expect(false, "starter weapon %s loads" % id, fail)
			continue
		fail = _expect(item.base_weapon_damage > 0,
				"%s carries base_weapon_damage > 0" % id, fail)
	return fail

func _verify_stats_weapon_damage_field(fail: int) -> int:
	var s := Stats.new()
	fail = _expect("weapon_damage" in s,
			"Stats declares weapon_damage field", fail)
	# apply_equipment_totals reads the key.
	s.class_id = &""
	s.apply_equipment_totals({ &"weapon_damage": 12 })
	fail = _expect(s.weapon_damage == 12,
			"Stats.apply_equipment_totals reads weapon_damage key", fail)
	return fail

func _verify_inventory_rolls_weapon_damage(fail: int) -> int:
	# Source-level check — Inventory._recompute_totals adds the key.
	var src := FileAccess.get_file_as_string("res://scripts/systems/inventory.gd")
	fail = _expect(src.contains("&\"weapon_damage\""),
			"Inventory._recompute_totals adds &\"weapon_damage\" key", fail)
	return fail

func _verify_damage_resolver_adds_weapon_damage(fail: int) -> int:
	# Source-level check — resolver folds weapon_damage into base.
	var src := FileAccess.get_file_as_string("res://scripts/systems/damage_resolver.gd")
	fail = _expect(src.contains("attacker_stats.weapon_damage"),
			"DamageResolver adds attacker_stats.weapon_damage to base", fail)
	return fail

# ---- 3. consumable prefix ----------------------------------------------

func _verify_consumables_skip_prefix(fail: int) -> int:
	# mana_potion is a known consumable in data/items/consumables/.
	# Force the prefix-roll index so the only thing keeping the
	# prefix off is the consumable guard.
	ItemInstanceRegistry.force_next_index(0)
	var rolled := ItemInstanceRegistry.maybe_roll_prefix(&"mana_potion")
	fail = _expect(rolled == &"mana_potion",
			"Consumable (mana_potion) never receives a prefix", fail)
	fail = _expect(not ItemInstanceRegistry.is_instance(rolled),
			"No synthetic instance registered for consumable", fail)
	# Make sure the force-index is cleared (guard returned before consuming it).
	# Re-roll with a non-consumable: prefix should land on it.
	ItemInstanceRegistry.force_next_index(0)
	var rolled2 := ItemInstanceRegistry.maybe_roll_prefix(&"myrmidon_spear_starter")
	fail = _expect(rolled2 != &"myrmidon_spear_starter",
			"Equipment still rolls prefix when force_next_index set", fail)
	return fail

func _verify_equipment_still_rolls_prefix(fail: int) -> int:
	# Already covered above; assert the synthetic id resolves via Database.
	ItemInstanceRegistry.force_next_index(0)
	var rolled := ItemInstanceRegistry.maybe_roll_prefix(&"shade_bow_starter")
	var ok := ItemInstanceRegistry.is_instance(rolled)
	fail = _expect(ok, "Equipment prefix registers a synthetic instance", fail)
	return fail
