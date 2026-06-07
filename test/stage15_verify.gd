extends Node
## Stage 15 verifier — Equipment paper-doll rendering.

func _ready() -> void:
	var fail := 0
	print("--- Stage 15 verify ---")

	fail = _verify_autoload_registered(fail)
	fail = _verify_visuals_weapon_arm_table(fail)
	fail = _verify_visuals_tier_bands(fail)
	fail = _verify_visuals_overlay_build(fail)
	fail = _verify_visuals_rejects_jewelry(fail)
	fail = _verify_paperdoll_class_exists(fail)
	fail = _verify_player_holds_paperdoll(fail)
	fail = await _verify_bare_hands_hides_weapon(fail)
	fail = await _verify_equip_weapon_shows_arm(fail)
	fail = await _verify_equip_head_adds_overlay(fail)
	fail = await _verify_unequip_clears_overlay(fail)
	fail = await _verify_class_swap_rebinds(fail)
	fail = await _verify_anim_tracks_survive_visibility_toggle(fail)
	fail = _verify_failure_modes_entries(fail)

	print("--- Stage 15 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- autoload + registry ------------------------------------------------

func _verify_autoload_registered(fail: int) -> int:
	# Source-level — project.godot lists EquipmentVisuals.
	var src := FileAccess.get_file_as_string("res://project.godot")
	fail = _expect(src.contains("EquipmentVisuals=\"*res://scripts/systems/equipment_visuals.gd\""),
			"project.godot registers EquipmentVisuals autoload", fail)
	# Runtime — autoload is reachable.
	fail = _expect(Engine.has_singleton("EquipmentVisuals") or get_node_or_null("/root/EquipmentVisuals") != null,
			"EquipmentVisuals reachable at /root/", fail)
	return fail

func _verify_visuals_weapon_arm_table(fail: int) -> int:
	fail = _expect(EquipmentVisuals.weapon_arm_for(&"myrmidon") == &"Body/ArmRShoulder/ElbowPivot/SpearArm",
			"Myrmidon weapon arm path = Body/ArmRShoulder/ElbowPivot/SpearArm", fail)
	fail = _expect(EquipmentVisuals.weapon_arm_for(&"pythia") == &"Body/ArmLShoulder/ElbowPivot/StaffArm",
			"Pythia weapon arm path = Body/ArmLShoulder/ElbowPivot/StaffArm", fail)
	fail = _expect(EquipmentVisuals.weapon_arm_for(&"shade_hunter") == &"BowArm",
			"ShadeHunter weapon arm = BowArm", fail)
	fail = _expect(EquipmentVisuals.weapon_arm_for(&"ossuary_priest") == &"WandArm",
			"OssuaryPriest weapon arm = WandArm", fail)
	fail = _expect(EquipmentVisuals.weapon_arm_for(&"unknown_class") == &"",
			"Unknown class returns empty StringName", fail)
	return fail

func _verify_visuals_tier_bands(fail: int) -> int:
	var dull := ItemData.new()
	dull.kind = ItemData.Kind.EQUIPMENT
	dull.base_armor_defense = 1
	var normal := ItemData.new()
	normal.kind = ItemData.Kind.EQUIPMENT
	normal.base_armor_defense = 4
	var bright := ItemData.new()
	bright.kind = ItemData.Kind.EQUIPMENT
	bright.base_armor_defense = 10
	fail = _expect(EquipmentVisuals.tier_for(dull) == 0, "tier_for dull = 0", fail)
	fail = _expect(EquipmentVisuals.tier_for(normal) == 1, "tier_for normal = 1", fail)
	fail = _expect(EquipmentVisuals.tier_for(bright) == 2, "tier_for bright = 2", fail)
	fail = _expect(EquipmentVisuals.tier_for(null) == 0, "tier_for null = 0", fail)
	# Colors are distinct so the eye can read the band.
	var c0 := EquipmentVisuals.tier_color(0)
	var c1 := EquipmentVisuals.tier_color(1)
	var c2 := EquipmentVisuals.tier_color(2)
	fail = _expect(c0 != c1 and c1 != c2, "tier colors all distinct", fail)
	return fail

func _verify_visuals_overlay_build(fail: int) -> int:
	var helm := ItemData.new()
	helm.kind = ItemData.Kind.EQUIPMENT
	helm.slot = EquipmentSlot.Slot.HEAD
	helm.base_armor_defense = 3
	for cid in [&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest"]:
		var p := EquipmentVisuals.build_overlay(EquipmentSlot.Slot.HEAD, cid, helm)
		fail = _expect(p != null and p is Polygon2D and p.polygon.size() >= 3,
				"HEAD overlay built for %s" % cid, fail)
		if p != null:
			p.free()
	return fail

func _verify_visuals_rejects_jewelry(fail: int) -> int:
	var ring := ItemData.new()
	ring.kind = ItemData.Kind.EQUIPMENT
	ring.slot = EquipmentSlot.Slot.RING
	var amulet := ItemData.new()
	amulet.kind = ItemData.Kind.EQUIPMENT
	amulet.slot = EquipmentSlot.Slot.AMULET
	fail = _expect(EquipmentVisuals.build_overlay(EquipmentSlot.Slot.RING, &"myrmidon", ring) == null,
			"RING has no Act 1 visual", fail)
	fail = _expect(EquipmentVisuals.build_overlay(EquipmentSlot.Slot.AMULET, &"myrmidon", amulet) == null,
			"AMULET has no Act 1 visual", fail)
	return fail

# ---- paperdoll class + player wiring ------------------------------------

func _verify_paperdoll_class_exists(fail: int) -> int:
	# Source-level check — class_name + bind() entry point.
	var src := FileAccess.get_file_as_string("res://scripts/systems/equipment_paperdoll.gd")
	fail = _expect(src.contains("class_name EquipmentPaperdoll"),
			"EquipmentPaperdoll declares class_name", fail)
	fail = _expect(src.contains("func bind(sprite_root: Node, inv: Inventory, class_id: StringName)"),
			"EquipmentPaperdoll.bind(sprite_root, inv, class_id) defined", fail)
	return fail

func _verify_player_holds_paperdoll(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://scripts/player/player.gd")
	fail = _expect(src.contains("_paperdoll: EquipmentPaperdoll"),
			"Player declares _paperdoll: EquipmentPaperdoll", fail)
	fail = _expect(src.contains("_paperdoll.call_deferred(&\"bind\""),
			"Player.assign_class binds paperdoll via call_deferred", fail)
	return fail

# ---- runtime behavior on a real player instance -------------------------

func _build_test_player() -> Player:
	# Smallest possible class data + sprite scene reuse.
	var cd := ClassData.new()
	cd.id = &"myrmidon"
	cd.display_name = "Myrmidon"
	cd.primary_attribute = &"strength"
	cd.base_strength = 10
	cd.base_vitality = 10
	cd.base_hp = 80
	cd.vit_per_hp = 4.0
	cd.base_mp = 20
	cd.pne_per_mp = 1.0
	cd.sprite_scene = load("res://art/procedural/classes/myrmidon_sprite.tscn") as PackedScene
	var packed := load("res://scenes/player/player.tscn") as PackedScene
	var p: Player = packed.instantiate() as Player
	add_child(p)
	p.assign_class(cd)
	return p

func _await_two_frames() -> void:
	# bind() is call_deferred — sprite _ready() also runs deferred. Wait
	# a couple frames before introspecting overlays.
	await get_tree().process_frame
	await get_tree().process_frame

func _verify_bare_hands_hides_weapon(fail: int) -> int:
	var p := _build_test_player()
	await _await_two_frames()
	var pd: Node = p.get_node_or_null(^"EquipmentPaperdoll")
	if pd == null:
		p.queue_free()
		return _expect(false, "Player has EquipmentPaperdoll child", fail)
	var arm: Node2D = pd.get_weapon_arm() as Node2D
	fail = _expect(arm != null, "Myrmidon SpearArm found", fail)
	fail = _expect(arm != null and not arm.visible,
			"WEAPON slot empty -> SpearArm hidden (bare hands)", fail)
	p.queue_free()
	return fail

func _make_item(slot: int, armor: int = 3, ar: int = 0) -> ItemData:
	var item := ItemData.new()
	item.id = StringName("test_item_%d" % slot)
	item.kind = ItemData.Kind.EQUIPMENT
	item.slot = slot
	item.class_mask = EquipmentSlot.ClassMask.ALL
	item.level_req = 1
	item.base_armor_defense = armor
	item.base_weapon_ar = ar
	return item

func _verify_equip_weapon_shows_arm(fail: int) -> int:
	var p := _build_test_player()
	await _await_two_frames()
	var pd: Node = p.get_node_or_null(^"EquipmentPaperdoll")
	# Inject test weapon into the database via fake item registration.
	var weapon := _make_item(EquipmentSlot.Slot.WEAPON, 0, 5)
	Database.items[weapon.id] = weapon
	var inv := p.get_inventory()
	inv.add_item(weapon.id)
	var equipped: bool = inv.equip(weapon.id)
	await _await_two_frames()
	var arm: Node2D = pd.get_weapon_arm() as Node2D
	fail = _expect(equipped, "Inventory.equip accepted test weapon", fail)
	fail = _expect(arm != null and arm.visible,
			"Equipping WEAPON shows SpearArm", fail)
	# Clean up: pop the test item out of the global database.
	Database.items.erase(weapon.id)
	p.queue_free()
	return fail

func _verify_equip_head_adds_overlay(fail: int) -> int:
	var p := _build_test_player()
	await _await_two_frames()
	var pd: Node = p.get_node_or_null(^"EquipmentPaperdoll")
	var helm := _make_item(EquipmentSlot.Slot.HEAD, 4)
	Database.items[helm.id] = helm
	var inv := p.get_inventory()
	inv.add_item(helm.id)
	inv.equip(helm.id)
	await _await_two_frames()
	var overlay: Polygon2D = pd.get_overlay_for(EquipmentSlot.Slot.HEAD) as Polygon2D
	fail = _expect(overlay != null and is_instance_valid(overlay),
			"Equipping HEAD adds overlay node", fail)
	fail = _expect(overlay != null and overlay.get_parent() != null
			and String(overlay.get_parent().name) == "Body",
			"HEAD overlay is parented under sprite Body", fail)
	Database.items.erase(helm.id)
	p.queue_free()
	return fail

func _verify_unequip_clears_overlay(fail: int) -> int:
	var p := _build_test_player()
	await _await_two_frames()
	var pd: Node = p.get_node_or_null(^"EquipmentPaperdoll")
	var chest := _make_item(EquipmentSlot.Slot.CHEST, 5)
	Database.items[chest.id] = chest
	var inv := p.get_inventory()
	inv.add_item(chest.id)
	inv.equip(chest.id)
	await _await_two_frames()
	var before: Polygon2D = pd.get_overlay_for(EquipmentSlot.Slot.CHEST) as Polygon2D
	fail = _expect(before != null, "CHEST overlay present after equip", fail)
	inv.unequip(EquipmentSlot.Slot.CHEST)
	await _await_two_frames()
	var after: Polygon2D = pd.get_overlay_for(EquipmentSlot.Slot.CHEST) as Polygon2D
	fail = _expect(after == null, "Unequip CHEST clears overlay", fail)
	# And the previously held node must be freed.
	fail = _expect(not is_instance_valid(before),
			"Previous overlay node is freed", fail)
	Database.items.erase(chest.id)
	p.queue_free()
	return fail

func _verify_class_swap_rebinds(fail: int) -> int:
	var p := _build_test_player()
	await _await_two_frames()
	var pd: Node = p.get_node_or_null(^"EquipmentPaperdoll")
	# Swap to Pythia. Sprite scene swap should still leave the
	# paperdoll bound to the new arm name.
	var cd2 := ClassData.new()
	cd2.id = &"pythia"
	cd2.display_name = "Pythia"
	cd2.primary_attribute = &"pneuma"
	cd2.base_pneuma = 10
	cd2.base_vitality = 6
	cd2.base_hp = 60
	cd2.vit_per_hp = 3.0
	cd2.base_mp = 60
	cd2.pne_per_mp = 2.0
	cd2.sprite_scene = load("res://art/procedural/classes/pythia_sprite.tscn") as PackedScene
	p.assign_class(cd2)
	await _await_two_frames()
	var arm: Node2D = pd.get_weapon_arm() as Node2D
	fail = _expect(arm != null and String(arm.name) == "StaffArm",
			"Class swap rebinds to StaffArm", fail)
	fail = _expect(arm != null and not arm.visible,
			"Pythia bare hands -> StaffArm hidden", fail)
	p.queue_free()
	return fail

func _verify_anim_tracks_survive_visibility_toggle(fail: int) -> int:
	# Regression guard for failure-mode entry: hiding the weapon arm
	# must not break the AnimationPlayer track that animates it.
	# Concretely: arm.visible = false; play("attack"); arm.rotation
	# must still change frame-to-frame.
	var packed := load("res://art/procedural/classes/myrmidon_sprite.tscn") as PackedScene
	var sprite := packed.instantiate() as Node2D
	add_child(sprite)
	await get_tree().process_frame
	var arm := sprite.get_node(^"Body/ArmRShoulder/ElbowPivot/SpearArm") as Node2D
	arm.visible = false
	var anim := sprite.get_node(^"AnimationPlayer") as AnimationPlayer
	var r_before := arm.rotation
	anim.play(&"attack")
	anim.advance(0.15)  # mid-swing
	var r_mid := arm.rotation
	fail = _expect(not is_equal_approx(r_before, r_mid),
			"AnimationPlayer still drives hidden weapon arm rotation", fail)
	sprite.queue_free()
	return fail

func _verify_failure_modes_entries(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://.agent_governance/rules/failure-modes.md")
	fail = _expect(src.contains("Stage 15") or src.contains("paper-doll") or src.contains("paperdoll"),
			"failure-modes.md notes Stage 15 paper-doll traps", fail)
	return fail
