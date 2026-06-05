extends Node
## Stage 9.8 verifier — consumables (Hearth Ember + potions).
## Headless invariants — does NOT play through the channel:
##   - ConsumableUse autoload exists with the public API
##   - ItemData has Kind + UseKind enums
##   - All four consumable resources load with expected fields
##   - Drop table augmented (shade_wretch/bog_caller share
##     wilderness_basic_drops)
##   - Kallias stock includes ember + health/mana potions; does NOT
##     include the unique ichor potion
##   - Inventory.can_equip rejects consumables
##   - ConsumableUse cooldown lifecycle (start/tick/expire/snapshot/restore)
##   - SAVE_VERSION == 14
##   - v13 -> v14 migration installs default consumable_cooldowns key
##   - AscentSpire scene + script removed (Stage 9.7's interim exit
##     retired in favor of the Ember)
##   - PotionBar script + PlayerInput potion-hotkey helper exist

func _ready() -> void:
	var fail := 0
	print("--- Stage 9.8 verify ---")

	fail = _verify_autoload(fail)
	fail = _verify_item_data_enums(fail)
	fail = _verify_consumable_resources(fail)
	fail = _verify_drop_table(fail)
	fail = _verify_kallias_stock(fail)
	fail = _verify_inventory_rejects(fail)
	fail = _verify_cooldown_lifecycle(fail)
	fail = _verify_cooldown_save_roundtrip(fail)
	fail = _verify_save_version(fail)
	fail = _verify_v13_to_v14_migration(fail)
	fail = _verify_ascent_spire_removed(fail)
	fail = _verify_potion_bar_script(fail)
	fail = _verify_player_input_hotkey(fail)

	print("--- Stage 9.8 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- autoload -----------------------------------------------------------

func _verify_autoload(fail: int) -> int:
	var root: Node = Engine.get_main_loop().root
	var cu: Node = root.get_node_or_null(^"ConsumableUse")
	fail = _expect(cu != null, "ConsumableUse autoload exists", fail)
	if cu == null:
		return fail
	for method in ["try_use", "is_on_cooldown", "get_cooldown_remaining",
			"get_cooldown_max", "is_channeling", "cancel_ember",
			"snapshot", "restore", "set_active_player"]:
		fail = _expect(cu.has_method(method),
				"ConsumableUse has method %s" % method, fail)
	return fail

# ---- enums --------------------------------------------------------------

func _verify_item_data_enums(fail: int) -> int:
	fail = _expect(ItemData.Kind.EQUIPMENT == 0, "ItemData.Kind.EQUIPMENT == 0", fail)
	fail = _expect(ItemData.Kind.CONSUMABLE == 1, "ItemData.Kind.CONSUMABLE == 1", fail)
	fail = _expect(ItemData.UseKind.NONE == 0, "ItemData.UseKind.NONE == 0", fail)
	fail = _expect(ItemData.UseKind.HEARTH_EMBER == 1, "ItemData.UseKind.HEARTH_EMBER == 1", fail)
	fail = _expect(ItemData.UseKind.HEAL_OVER_TIME == 2, "ItemData.UseKind.HEAL_OVER_TIME == 2", fail)
	fail = _expect(ItemData.UseKind.MANA_OVER_TIME == 3, "ItemData.UseKind.MANA_OVER_TIME == 3", fail)
	fail = _expect(ItemData.UseKind.INSTANT_BOTH_PCT == 4, "ItemData.UseKind.INSTANT_BOTH_PCT == 4", fail)
	return fail

# ---- resource sanity ----------------------------------------------------

func _verify_consumable_resources(fail: int) -> int:
	var expected: Array[Dictionary] = [
		{
			"id": &"hearth_ember",
			"use_kind": ItemData.UseKind.HEARTH_EMBER,
			"channel": 2.0,
		},
		{
			"id": &"health_potion",
			"use_kind": ItemData.UseKind.HEAL_OVER_TIME,
			"cooldown_id": &"potion_health",
			"flat_min": 1,
			"duration_min": 0.5,
		},
		{
			"id": &"mana_potion",
			"use_kind": ItemData.UseKind.MANA_OVER_TIME,
			"cooldown_id": &"potion_mana",
			"flat_min": 1,
			"duration_min": 0.5,
		},
		{
			"id": &"ichor_potion",
			"use_kind": ItemData.UseKind.INSTANT_BOTH_PCT,
			"cooldown_id": &"potion_ichor",
		},
	]
	for spec in expected:
		var id: StringName = spec["id"]
		var item: ItemData = Database.get_item(id) as ItemData
		fail = _expect(item != null, "%s loads" % id, fail)
		if item == null:
			continue
		fail = _expect(item.kind == ItemData.Kind.CONSUMABLE,
				"%s has kind=CONSUMABLE" % id, fail)
		fail = _expect(int(item.use_kind) == int(spec["use_kind"]),
				"%s has use_kind=%d" % [id, int(spec["use_kind"])], fail)
		if spec.has("channel"):
			fail = _expect(absf(item.use_channel_seconds - float(spec["channel"])) < 0.01,
					"%s channel == %.1fs" % [id, float(spec["channel"])], fail)
		if spec.has("cooldown_id"):
			fail = _expect(item.cooldown_id == StringName(spec["cooldown_id"]),
					"%s cooldown_id == %s" % [id, spec["cooldown_id"]], fail)
		if spec.has("flat_min"):
			fail = _expect(item.use_flat_amount >= int(spec["flat_min"]),
					"%s flat_amount >= %d" % [id, int(spec["flat_min"])], fail)
		if spec.has("duration_min"):
			fail = _expect(item.use_duration >= float(spec["duration_min"]),
					"%s duration >= %.1fs" % [id, float(spec["duration_min"])], fail)
	# Ichor instant percentages must be non-zero for both HP and MP.
	var ichor: ItemData = Database.get_item(&"ichor_potion") as ItemData
	if ichor != null:
		fail = _expect(ichor.use_hp_pct > 0.0, "ichor_potion use_hp_pct > 0", fail)
		fail = _expect(ichor.use_mp_pct > 0.0, "ichor_potion use_mp_pct > 0", fail)
	return fail

# ---- drop table ---------------------------------------------------------

func _verify_drop_table(fail: int) -> int:
	var dt: DropTable = load("res://data/enemies/wilderness_basic_drops.tres") as DropTable
	fail = _expect(dt != null, "wilderness_basic_drops loads", fail)
	if dt == null:
		return fail
	var have_ember := false
	var have_health := false
	var have_mana := false
	var have_ichor := false
	for e in dt.entries:
		var id: StringName = StringName(e.get("item_id", &""))
		if id == &"hearth_ember": have_ember = true
		elif id == &"health_potion": have_health = true
		elif id == &"mana_potion": have_mana = true
		elif id == &"ichor_potion": have_ichor = true
	fail = _expect(have_ember, "wilderness drop table includes hearth_ember", fail)
	fail = _expect(have_health, "wilderness drop table includes health_potion", fail)
	fail = _expect(have_mana, "wilderness drop table includes mana_potion", fail)
	fail = _expect(have_ichor, "wilderness drop table includes ichor_potion", fail)
	return fail

# ---- vendor stock -------------------------------------------------------

func _verify_kallias_stock(fail: int) -> int:
	var stock: MerchantStock = load("res://data/npc/kallias_stock.tres") as MerchantStock
	fail = _expect(stock != null, "kallias_stock loads", fail)
	if stock == null:
		return fail
	fail = _expect(stock.has(&"hearth_ember"), "Kallias stocks hearth_ember", fail)
	fail = _expect(stock.has(&"health_potion"), "Kallias stocks health_potion", fail)
	fail = _expect(stock.has(&"mana_potion"), "Kallias stocks mana_potion", fail)
	fail = _expect(not stock.has(&"ichor_potion"),
			"Kallias does NOT stock ichor_potion (unique)", fail)
	return fail

# ---- inventory equip-gate ------------------------------------------------

func _verify_inventory_rejects(fail: int) -> int:
	# Synthesize a minimal inventory + potion item and confirm can_equip
	# returns false. We don't need a real Stats / class here — the
	# rejection happens on kind alone.
	var inv := Inventory.new()
	var hp: ItemData = Database.get_item(&"health_potion") as ItemData
	fail = _expect(not inv.can_equip(hp),
			"Inventory.can_equip(health_potion) == false", fail)
	var ember: ItemData = Database.get_item(&"hearth_ember") as ItemData
	fail = _expect(not inv.can_equip(ember),
			"Inventory.can_equip(hearth_ember) == false", fail)
	# Sanity: an equipment item still passes the kind gate (level 0,
	# class_mask ALL covers everything).
	var arm: ItemData = Database.get_item(&"linen_wrap") as ItemData
	fail = _expect(inv.can_equip(arm),
			"Inventory.can_equip(linen_wrap) == true (sanity)", fail)
	inv.queue_free()
	return fail

# ---- cooldown lifecycle --------------------------------------------------

func _verify_cooldown_lifecycle(fail: int) -> int:
	# Use ConsumableUse's snapshot/restore as a back-door to inject a
	# cooldown without running a real use_path (which requires a player +
	# inventory). Confirm is_on_cooldown / remaining behave correctly.
	ConsumableUse.clear_runtime()
	fail = _expect(not ConsumableUse.is_on_cooldown(&"potion_health"),
			"cooldown is clean before injection", fail)
	ConsumableUse.restore({
		"cooldowns": {
			"potion_health": { "remaining": 5.0, "max": 8.0 },
		},
	})
	fail = _expect(ConsumableUse.is_on_cooldown(&"potion_health"),
			"potion_health cooldown active after restore", fail)
	fail = _expect(absf(ConsumableUse.get_cooldown_remaining(&"potion_health") - 5.0) < 0.001,
			"potion_health remaining == 5.0", fail)
	fail = _expect(absf(ConsumableUse.get_cooldown_max(&"potion_health") - 8.0) < 0.001,
			"potion_health max == 8.0", fail)
	ConsumableUse.clear_runtime()
	return fail

func _verify_cooldown_save_roundtrip(fail: int) -> int:
	ConsumableUse.clear_runtime()
	ConsumableUse.restore({
		"cooldowns": {
			"potion_mana": { "remaining": 3.5, "max": 8.0 },
		},
	})
	var snap := ConsumableUse.snapshot()
	fail = _expect(snap.has("cooldowns"), "snapshot has cooldowns key", fail)
	var cds: Dictionary = snap.get("cooldowns", {})
	fail = _expect(cds.has("potion_mana"), "snapshot includes potion_mana", fail)
	if cds.has("potion_mana"):
		fail = _expect(absf(float(cds["potion_mana"]["remaining"]) - 3.5) < 0.001,
				"snapshot preserves remaining", fail)
		fail = _expect(absf(float(cds["potion_mana"]["max"]) - 8.0) < 0.001,
				"snapshot preserves max", fail)
	ConsumableUse.clear_runtime()
	return fail

# ---- save version --------------------------------------------------------

func _verify_save_version(fail: int) -> int:
	fail = _expect(SaveSystem.SAVE_VERSION == 14, "SAVE_VERSION == 14", fail)
	return fail

func _verify_v13_to_v14_migration(fail: int) -> int:
	var legacy := { "version": 13 }
	var migrated := SaveSystem.migrate(legacy)
	fail = _expect(int(migrated.get("version", 0)) == 14,
			"v13 migrates to v14", fail)
	fail = _expect(migrated.has("consumable_cooldowns"),
			"v14 migration installs consumable_cooldowns key", fail)
	var key: Dictionary = migrated.get("consumable_cooldowns", {})
	fail = _expect(key.has("cooldowns"),
			"consumable_cooldowns.cooldowns subkey exists", fail)
	return fail

# ---- AscentSpire removed -------------------------------------------------

func _verify_ascent_spire_removed(fail: int) -> int:
	fail = _expect(not FileAccess.file_exists("res://scripts/world/ascent_spire.gd"),
			"ascent_spire.gd deleted", fail)
	fail = _expect(not FileAccess.file_exists("res://scenes/world/ascent_spire.tscn"),
			"ascent_spire.tscn deleted", fail)
	# The depths scene must not reference the spire any more.
	var depths_text := FileAccess.get_file_as_string("res://scenes/zones/forsaken_depths.tscn")
	fail = _expect(not depths_text.contains("ascent_spire"),
			"forsaken_depths.tscn no longer references ascent_spire", fail)
	return fail

# ---- HUD / input wiring --------------------------------------------------

func _verify_potion_bar_script(fail: int) -> int:
	var s: Script = load("res://scripts/ui/potion_bar.gd") as Script
	fail = _expect(s != null, "potion_bar.gd loads", fail)
	return fail

func _verify_player_input_hotkey(fail: int) -> int:
	# Confirm the key handler exists on the PlayerInput script source.
	var src := FileAccess.get_file_as_string("res://scripts/player/player_input.gd")
	fail = _expect(src.contains("KEY_2"),
			"PlayerInput handles KEY_2 (health potion)", fail)
	fail = _expect(src.contains("KEY_3"),
			"PlayerInput handles KEY_3 (mana potion)", fail)
	fail = _expect(src.contains("_use_first_consumable"),
			"PlayerInput defines _use_first_consumable", fail)
	return fail
