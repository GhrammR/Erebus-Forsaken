extends Node
## Stage 4 verifier — Inventory + Stats apply_equipment_totals +
## SaveSystem round-trip (using a separate test save path).

const TEST_SAVE_PATH := "user://test_save_stage4.json"

func _ready() -> void:
	var fail := 0
	print("--- Stage 4 verify ---")

	# Build a Player-ish bag of state in code. We use Stats directly +
	# an Inventory not under a real Player.
	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	if cd == null:
		print("[FAIL] missing Myrmidon ClassData"); get_tree().quit(1); return
	var stats := Stats.from_class_data(cd, 1)
	var inv := Inventory.new()
	add_child(inv)
	inv.stats = stats
	inv.class_id = cd.id

	# Database content
	var n_items := Database.items.size()
	var ok_db: bool = n_items >= 11
	print("[%s] Database loaded %d items (expect >= 11)" % [
		"OK  " if ok_db else "FAIL", n_items])
	if not ok_db: fail += 1

	# Add a few items
	inv.add_item(&"myrmidon_spear_starter")
	inv.add_item(&"bronze_plate")
	inv.add_item(&"silken_robe")          # wrong class — should not be equippable
	inv.add_item(&"iron_ring")
	inv.add_item(&"silver_amulet")
	var ok_size: bool = inv.backpack_size() == 5
	print("[%s] backpack size after 5 adds = %d (expect 5)" % [
		"OK  " if ok_size else "FAIL", inv.backpack_size()])
	if not ok_size: fail += 1

	# Class restriction
	var ok_class_block: bool = not inv.can_equip(Database.get_item(&"silken_robe") as ItemData) \
		and inv.can_equip(Database.get_item(&"bronze_plate") as ItemData)
	print("[%s] Myrmidon rejects silken_robe, accepts bronze_plate" % (
		"OK  " if ok_class_block else "FAIL"))
	if not ok_class_block: fail += 1

	# Equip and verify stat application.
	# AR formula = dex*5 + weapon_ar + level*5. The amulet adds +1 DEX
	# so AR gets +30 from the spear AND +5 from the +1 DEX bonus.
	var ar0 := stats.attack_rating
	var str0 := stats.strength
	inv.equip(&"myrmidon_spear_starter")    # +30 weapon_ar, +2 STR
	inv.equip(&"bronze_plate")              # +12 armor_def, +3 STR
	inv.equip(&"iron_ring")                 # +2 VIT
	inv.equip(&"silver_amulet")             # +1 to all attrs, +5 resist
	var expected_ar: int = ar0 + 30 + 5     # weapon AR + DEX-bonus AR
	var ok_apply: bool = stats.attack_rating == expected_ar \
		and stats.armor_defense == 12 \
		and stats.strength == str0 + 2 + 3 + 1 \
		and stats.vitality == (cd.base_vitality + 2 + 1) \
		and stats.resistance == 5
	print("[%s] equip applied: AR %d->%d (expect %d), STR %d->%d, VIT->%d, RES=%d" % [
		"OK  " if ok_apply else "FAIL",
		ar0, stats.attack_rating, expected_ar, str0, stats.strength,
		stats.vitality, stats.resistance])
	if not ok_apply: fail += 1

	# Unequip and verify revert
	inv.unequip(EquipmentSlot.Slot.WEAPON)
	inv.unequip(EquipmentSlot.Slot.CHEST)
	inv.unequip(EquipmentSlot.Slot.RING)
	inv.unequip(EquipmentSlot.Slot.AMULET)
	var ok_revert: bool = stats.attack_rating == ar0 \
		and stats.armor_defense == 0 \
		and stats.strength == cd.base_strength \
		and stats.resistance == 0
	print("[%s] unequip reverts to baseline (AR=%d, STR=%d, RES=%d)" % [
		"OK  " if ok_revert else "FAIL",
		stats.attack_rating, stats.strength, stats.resistance])
	if not ok_revert: fail += 1

	# Backpack capacity guard
	for i in Inventory.BACKPACK_CAPACITY + 5:
		inv.add_item(&"linen_wrap")
	var ok_cap: bool = inv.backpack_size() == Inventory.BACKPACK_CAPACITY
	print("[%s] backpack caps at %d (got %d)" % [
		"OK  " if ok_cap else "FAIL",
		Inventory.BACKPACK_CAPACITY, inv.backpack_size()])
	if not ok_cap: fail += 1

	# Save/load round-trip
	fail = _run_save_load_test(fail)
	print("--- Stage 4 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _run_save_load_test(fail_in: int) -> int:
	var fail := fail_in
	# Construct a fake Player node with the required fields/methods.
	var fake_player := preload("res://test/_save_test_player.gd").new()
	add_child(fake_player)
	fake_player.setup(&"myrmidon")
	GameState.player = fake_player

	fake_player.current_stats.set_level(3)
	fake_player.current_stats.alloc_strength = 5
	fake_player.get_inventory().add_item(&"bronze_plate")
	fake_player.get_inventory().add_item(&"iron_ring")
	fake_player.get_inventory().equip(&"bronze_plate")
	fake_player.get_inventory().equip(&"iron_ring")
	fake_player.get_wallet().add_gold(137)
	fake_player.global_position = Vector2(123.0, -456.0)

	# Snapshot before save
	var before_lvl := fake_player.current_stats.level
	var before_str := fake_player.current_stats.strength
	var before_pos := fake_player.global_position
	var before_bp := fake_player.get_inventory().backpack.duplicate()
	var before_eq := fake_player.get_inventory().equipped.duplicate()
	var before_gold := fake_player.get_wallet().gold

	# Save via the autoload (uses real SAVE_PATH; fine for this test)
	var ok_save := SaveSystem.save_game()
	print("[%s] SaveSystem.save_game returned true" % ("OK  " if ok_save else "FAIL"))
	if not ok_save: fail += 1

	# Mutate state
	fake_player.current_stats.set_level(1)
	fake_player.current_stats.alloc_strength = 0
	fake_player.get_inventory().backpack.clear()
	fake_player.get_inventory().equipped.clear()
	fake_player.get_inventory()._recompute_totals()
	fake_player.get_wallet().set_gold(0)
	fake_player.global_position = Vector2.ZERO

	# Load
	var ok_load := SaveSystem.load_game()
	print("[%s] SaveSystem.load_game returned true" % ("OK  " if ok_load else "FAIL"))
	if not ok_load: fail += 1

	var ok_roundtrip: bool = fake_player.current_stats.level == before_lvl \
		and fake_player.current_stats.strength == before_str \
		and fake_player.global_position == before_pos \
		and fake_player.get_inventory().equipped.size() == before_eq.size() \
		and fake_player.get_wallet().gold == before_gold
	print("[%s] round-trip preserves level=%d str=%d pos=(%d,%d) equipped=%d gold=%d" % [
		"OK  " if ok_roundtrip else "FAIL",
		fake_player.current_stats.level, fake_player.current_stats.strength,
		int(fake_player.global_position.x), int(fake_player.global_position.y),
		fake_player.get_inventory().equipped.size(),
		fake_player.get_wallet().gold])
	if not ok_roundtrip: fail += 1

	# Per-class loadout isolation: Myrmidon equipment must not appear
	# on Pythia, and switching back to Myrmidon restores it exactly.
	fake_player.assign_class(Database.get_class_data(&"myrmidon"))
	fake_player.get_inventory().add_item(&"bronze_plate")
	fake_player.get_inventory().equip(&"bronze_plate")
	var myr_eq_before := fake_player.get_inventory().equipped.duplicate()
	var myr_bp_before := fake_player.get_inventory().backpack.duplicate()
	fake_player.assign_class(Database.get_class_data(&"pythia"))
	var pyt_empty_eq: bool = fake_player.get_inventory().equipped.is_empty()
	var pyt_empty_bp: bool = fake_player.get_inventory().backpack.is_empty()
	fake_player.assign_class(Database.get_class_data(&"myrmidon"))
	var myr_eq_after := fake_player.get_inventory().equipped.duplicate()
	var myr_bp_after := fake_player.get_inventory().backpack.duplicate()
	var ok_loadout: bool = pyt_empty_eq and pyt_empty_bp \
		and myr_eq_before == myr_eq_after \
		and myr_bp_before == myr_bp_after
	print("[%s] per-class loadout isolated: pythia empty=%s, myr restored=%s" % [
		"OK  " if ok_loadout else "FAIL",
		pyt_empty_eq and pyt_empty_bp,
		myr_eq_before == myr_eq_after and myr_bp_before == myr_bp_after])
	if not ok_loadout: fail += 1

	# Migration shim — v1 jumps through every step up to SAVE_VERSION.
	var v1: Dictionary = {"version": 1, "class_id": "myrmidon", "level": 1}
	var migrated := SaveSystem.migrate(v1)
	var inv_block: Dictionary = migrated.get("inventory", {})
	var ok_mig: bool = int(migrated.get("version", 0)) == SaveSystem.SAVE_VERSION \
		and inv_block.has("loadouts") \
		and inv_block.has("active_class") \
		and String(inv_block["active_class"]) == "myrmidon" \
		and (inv_block["loadouts"] as Dictionary).has("myrmidon") \
		and migrated.has("gold")
	print("[%s] migrate(v1->v%d) bumps version + per-class loadouts + gold seeded" % [
		"OK  " if ok_mig else "FAIL", SaveSystem.SAVE_VERSION])
	if not ok_mig: fail += 1

	# Cleanup test save so we don't leave litter for real runs
	SaveSystem.delete_save()
	return fail
