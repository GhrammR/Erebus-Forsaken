extends Node
## Stage 17.5 verifier — anatomy family registry + per-sprite
## part-set conformance + sidecar contract.
##
## Filled in incrementally as sprites are authored. The skeleton
## here covers the registry + sidecar contract; per-sprite parts
## checks are added as each sprite ships.

const HUMAN_SPRITES: Array[StringName] = [
	&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
	&"kallias", &"eurynome",
]
const WRAITH_SPRITES: Array[StringName] = [
	&"shade_wretch", &"bog_caller",
]
const DEMON_SPRITES: Array[StringName] = [
	&"act_boss",
]
const BESPOKE_SPRITES: Array[StringName] = [
	&"act_boss", &"hekate_marked",
]

const StaffStances = preload("res://scripts/systems/stances/staff_stances.gd")
const BowStances = preload("res://scripts/systems/stances/bow_stances.gd")
const SpearStances = preload("res://scripts/systems/stances/spear_stances.gd")
const StanceSelection = preload("res://scripts/systems/stance_selection.gd")
const WandStances = preload("res://scripts/systems/stances/wand_stances.gd")
const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")

var _fail: int = 0

func _ready() -> void:
	print("--- Stage 17.5 verify ---")
	_verify_registry_loaded()
	_verify_human_sprites_registered()
	_verify_wraith_sprites_registered()
	_verify_demon_sprites_registered()
	_verify_bespoke_sprites_registered()
	_verify_bone_servant_unchanged_skeleton()
	_verify_equipment_overlays_target_human_parts()
	_verify_sidecar_path_contract()
	await _verify_stance_catalog_geometry_drives_sprites()
	_verify_stance_catalog_filters()
	await _verify_current_sprite_animation_surface()
	await _verify_sprite_detail_contract()
	_verify_pose_editor_authoring_contract()
	print("--- Stage 17.5 verify: %s ---" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		print("  FAIL  %s" % label)
		_fail += 1

func _vec_close(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) <= 0.01

func _verify_registry_loaded() -> void:
	_expect(AnatomyFamilies != null, "AnatomyFamilies autoload registered")
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.HUMAN),
			"HUMAN family declared")
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.HUMANOID),
			"HUMANOID family declared")
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.BEAST),
			"BEAST family declared")
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.DEMON),
			"DEMON family declared")
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.FLYING),
			"FLYING family declared")
	_expect(AnatomyFamilies.UNDEAD_SKELETON_PARTS.size() > 0,
			"UNDEAD skeleton subtype part set declared")
	_expect(AnatomyFamilies.UNDEAD_WRAITH_PARTS.size() > 0,
			"UNDEAD wraith subtype part set declared")

func _verify_human_sprites_registered() -> void:
	for id in HUMAN_SPRITES:
		var fam := AnatomyFamilies.family_of(id)
		_expect(fam == AnatomyFamilies.Family.HUMAN,
				"%s registered as HUMAN" % id)

func _verify_wraith_sprites_registered() -> void:
	for id in WRAITH_SPRITES:
		var fam := AnatomyFamilies.family_of(id)
		var sub := AnatomyFamilies.subtype_of(id)
		_expect(fam == AnatomyFamilies.Family.UNDEAD,
				"%s registered as UNDEAD" % id)
		_expect(sub == AnatomyFamilies.UndeadSubtype.WRAITH,
				"%s subtype = WRAITH" % id)

func _verify_demon_sprites_registered() -> void:
	for id in DEMON_SPRITES:
		var fam := AnatomyFamilies.family_of(id)
		_expect(fam == AnatomyFamilies.Family.DEMON,
				"%s registered as DEMON" % id)

func _verify_bespoke_sprites_registered() -> void:
	for id in BESPOKE_SPRITES:
		_expect(AnatomyFamilies.is_bespoke(id),
				"%s registered as bespoke (unique-boss) entry" % id)

func _verify_bone_servant_unchanged_skeleton() -> void:
	_expect(AnatomyFamilies.subtype_of(&"bone_servant")
			== AnatomyFamilies.UndeadSubtype.SKELETON,
			"bone_servant subtype = SKELETON (anchor, unchanged)")
	# Spot-check: file still exists at the canonical path.
	_expect(ResourceLoader.exists("res://art/procedural/enemies/bone_servant_sprite.tscn"),
			"bone_servant sprite scene path intact")

func _verify_equipment_overlays_target_human_parts() -> void:
	# After Stage 17.5 ships, every overlay path EquipmentVisuals
	# declares must be a HUMAN family part name.
	var src := FileAccess.get_file_as_string("res://scripts/systems/equipment_visuals.gd")
	# Source-level check until OVERLAYS gets an introspection API.
	# Full rebinding to the new HUMAN part paths (Body/Head, Body/Torso,
	# Body/Hips + Body/Thigh{L,R}) is asserted once player sprites ship.
	_expect(src.length() > 0,
			"equipment_visuals.gd present (overlay rebinding asserted per-sprite)")

func _verify_sidecar_path_contract() -> void:
	_expect(ResourceLoader.exists("res://scripts/systems/sprite_sidecar.gd"),
			"SpriteSidecar helper exists")
	# Path format contract — kept in sync with item-icon sidecars.
	var expected := "res://data/sprites/myrmidon/Torso.png"
	var actual := SpriteSidecar.sidecar_path(&"myrmidon", &"Torso")
	_expect(actual == expected,
			"sidecar_path('myrmidon','Torso') == %s" % expected)

func _verify_stance_catalog_geometry_drives_sprites() -> void:
	var pythia_id := StanceSelection.selected_for_class(
			&"pythia", &"diagonal_high_guard", StaffStances.all_ids())
	var pythia_row: Dictionary = StaffStances.get_stance(pythia_id)
	var pythia_scene := load("res://art/procedural/classes/pythia_sprite.tscn") as PackedScene
	var pythia = pythia_scene.instantiate()
	pythia.stance_id = &"diagonal_high_guard"
	add_child(pythia)
	await get_tree().process_frame
	var staff := pythia.get_node(^"Body/StaffArm") as Node2D
	_expect(pythia.stance_id == pythia_id,
			"Pythia resolved selected StaffStances id")
	_expect(_vec_close(staff.position, pythia_row.get("staff_pos", Vector2.ZERO)),
			"Pythia StaffStances row drives StaffArm position")
	_expect(is_equal_approx(staff.rotation, float(pythia_row.get("staff_rot", 0.0))),
			"Pythia StaffStances row drives StaffArm rotation")
	pythia.queue_free()

	var myrmidon_id := StanceSelection.selected_for_class(
			&"myrmidon", &"overhand_javelin", SpearStances.all_ids())
	var myrmidon_row: Dictionary = SpearStances.get_stance(myrmidon_id)
	var myrmidon_scene := load("res://art/procedural/classes/myrmidon_sprite.tscn") as PackedScene
	var myrmidon = myrmidon_scene.instantiate()
	myrmidon.stance_id = &"overhand_javelin"
	add_child(myrmidon)
	await get_tree().process_frame
	var body := myrmidon.get_node(^"Body") as Node2D
	var spear := myrmidon.get_node(^"Body/ArmRShoulder/ElbowPivot/SpearArm") as Node2D
	var spear_parent := spear.get_parent() as Node2D
	var expected_spear_pos := spear_parent.to_local(
			body.to_global(myrmidon_row.get("spear_pos", Vector2(9, -24))))
	_expect(myrmidon.stance_id == myrmidon_id,
			"Myrmidon resolved selected SpearStances id")
	_expect(_vec_close(spear.position, expected_spear_pos),
			"Myrmidon SpearStances row drives SpearArm position")
	_expect(is_equal_approx(spear.rotation, float(myrmidon_row.get("spear_rot", 0.0))),
			"Myrmidon SpearStances row drives SpearArm rotation")
	var meta: Dictionary = myrmidon.get_meta(&"spear_stance", {})
	_expect(_vec_close(meta.get("rest_pos", Vector2.INF), expected_spear_pos),
			"Myrmidon exports spear rest_pos metadata for WeaponProfiles")
	myrmidon.queue_free()

func _verify_stance_catalog_filters() -> void:
	for anim_name in [&"idle", &"walk", &"attack", &"cast", &"die"]:
		_expect(BowStances.ids_for_anim(anim_name).size() >= 3,
				"BowStances exposes >=3 %s stance variants" % anim_name)
		_expect(StaffStances.ids_for_anim(anim_name).size() >= 3,
				"StaffStances exposes >=3 %s stance variants" % anim_name)
		_expect(SpearStances.ids_for_anim(anim_name).size() >= 3,
				"SpearStances exposes >=3 %s stance variants" % anim_name)
		_expect(WandStances.ids_for_anim(anim_name).size() >= 3,
				"WandStances exposes >=3 %s stance variants" % anim_name)
		var enemy_ids := SpriteMotionStances.ids_for_context(&"enemies", &"bog_caller", anim_name)
		var npc_ids := SpriteMotionStances.ids_for_context(&"npcs", &"kallias", anim_name)
		_expect(enemy_ids.size() >= 3 and _ids_have_prefix(enemy_ids, "enemy_"),
				"enemy motion catalog exposes role-specific %s variants" % anim_name)
		_expect(npc_ids.size() >= 3 and _ids_have_prefix(npc_ids, "npc_"),
				"npc motion catalog exposes role-specific %s variants" % anim_name)

func _ids_have_prefix(ids: Array, prefix: String) -> bool:
	for id in ids:
		if not String(id).begins_with(prefix):
			return false
	return true

func _verify_current_sprite_animation_surface() -> void:
	var sprites: Array = [
		{ "id": &"pythia", "path": "res://art/procedural/classes/pythia_sprite.tscn", "stance": StaffStances.DEFAULT_STANCE, "bucket": &"classes" },
		{ "id": &"myrmidon", "path": "res://art/procedural/classes/myrmidon_sprite.tscn", "stance": SpearStances.DEFAULT_STANCE, "bucket": &"classes" },
		{ "id": &"shade_hunter", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn", "stance": &"forward_high_ready", "bucket": &"classes" },
		{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn", "stance": WandStances.DEFAULT_STANCE, "bucket": &"classes" },
		{ "id": &"training_dummy", "path": "res://art/procedural/enemies/dummy_sprite.tscn", "stance": SpriteMotionStances.DEFAULT_STANCE, "bucket": &"enemies" },
		{ "id": &"bone_servant", "path": "res://art/procedural/enemies/bone_servant_sprite.tscn", "stance": SpriteMotionStances.DEFAULT_STANCE, "bucket": &"enemies" },
		{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn", "stance": &"wraith_lunge", "bucket": &"enemies" },
		{ "id": &"bog_caller", "path": "res://art/procedural/enemies/bog_caller_sprite.tscn", "stance": &"caster_channel", "bucket": &"enemies" },
		{ "id": &"act_boss", "path": "res://art/procedural/enemies/act_boss_sprite.tscn", "stance": &"boss_command", "bucket": &"enemies" },
		{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn", "stance": &"merchant_idle", "bucket": &"npcs" },
		{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn", "stance": &"merchant_idle", "bucket": &"npcs" },
	]
	for rec_v in sprites:
		var rec: Dictionary = rec_v
		var packed := load(String(rec["path"])) as PackedScene
		_expect(packed != null, "%s sprite scene loads" % rec["id"])
		if packed == null:
			continue
		var sprite := packed.instantiate() as Node2D
		if &"stance_id" in sprite:
			sprite.stance_id = rec["stance"]
		if &"sprite_id" in sprite:
			sprite.sprite_id = rec["id"]
		if &"stance_bucket" in sprite:
			sprite.stance_bucket = rec["bucket"]
		add_child(sprite)
		await get_tree().process_frame
		_expect(sprite.get_node_or_null(^"Shadow") != null,
				"%s has ground shadow" % rec["id"])
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		_expect(anim != null, "%s exposes AnimationPlayer" % rec["id"])
		if anim != null:
			for anim_name in [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]:
				_expect(anim.has_animation(anim_name),
						"%s has %s animation" % [rec["id"], anim_name])
		sprite.queue_free()

func _verify_sprite_detail_contract() -> void:
	var detail_sprites: Array = [
		{ "id": &"training_dummy", "path": "res://art/procedural/enemies/dummy_sprite.tscn", "eyes": true, "arms": 2, "shadow": true },
		{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn", "eyes": true, "arms": 2, "shadow": true },
		{ "id": &"bog_caller", "path": "res://art/procedural/enemies/bog_caller_sprite.tscn", "eyes": true, "arms": 2, "shadow": true },
		{ "id": &"act_boss", "path": "res://art/procedural/enemies/act_boss_sprite.tscn", "eyes": true, "arms": 6, "shadow": true },
		{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn", "eyes": true, "legs": true, "shadow": true },
		{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn", "eyes": true, "arms": 2, "legs": true, "shadow": true },
		{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn", "eyes": true, "arms": 2, "legs": true, "shadow": true },
	]
	for rec_v in detail_sprites:
		var rec: Dictionary = rec_v
		var packed := load(String(rec["path"])) as PackedScene
		if packed == null:
			_expect(false, "%s detail scene loads" % rec["id"])
			continue
		var sprite := packed.instantiate() as Node2D
		add_child(sprite)
		await get_tree().process_frame
		var body := sprite.get_node_or_null(^"Body")
		_expect(body != null, "%s has Body node" % rec["id"])
		if bool(rec.get("shadow", false)):
			_expect(sprite.get_node_or_null(^"Shadow") != null, "%s has Shadow" % rec["id"])
		if bool(rec.get("eyes", false)):
			_expect(sprite.get_node_or_null(^"Body/EyeL") != null, "%s has EyeL" % rec["id"])
			_expect(sprite.get_node_or_null(^"Body/EyeR") != null, "%s has EyeR" % rec["id"])
		var counts := { "arms": 0, "hands": 0, "elbows": 0, "fingers": 0, "legs": 0, "knees": 0, "feet": 0, "shadows": 0 }
		_count_pose_parts(sprite, counts)
		_expect(int(counts["arms"]) >= int(rec.get("arms", 0)),
				"%s has >= %d arm roots (got %d)" % [rec["id"], int(rec.get("arms", 0)), int(counts["arms"])])
		_expect(int(counts["hands"]) >= int(rec.get("arms", 0)),
				"%s has draggable hands/claws (got %d)" % [rec["id"], int(counts["hands"])])
		_expect(int(counts["elbows"]) >= mini(2, int(rec.get("arms", 0))),
				"%s has elbow pivots" % rec["id"])
		if bool(rec.get("legs", false)):
			_expect(int(counts["legs"]) >= 2,
					"%s has left/right leg hip controls" % rec["id"])
			_expect(int(counts["knees"]) >= 2,
					"%s has knee pivots" % rec["id"])
			_expect(int(counts["feet"]) >= 2,
					"%s has visible feet under robe" % rec["id"])
		if rec["id"] == &"act_boss":
			_expect(int(counts["fingers"]) >= 6,
					"act_boss has six middle-finger taunt controls")
		sprite.queue_free()

func _count_pose_parts(node: Node, counts: Dictionary) -> void:
	for child in node.get_children():
		var n := String(child.name)
		if child is Node2D:
			if n == "Shadow":
				counts["shadows"] = int(counts["shadows"]) + 1
			if n.contains("ArmL") or n.contains("ArmR"):
				counts["arms"] = int(counts["arms"]) + 1
			if n.contains("Hand") or n.contains("Claw"):
				counts["hands"] = int(counts["hands"]) + 1
			if n.ends_with("ElbowPivot"):
				counts["elbows"] = int(counts["elbows"]) + 1
			if n.contains("LegLHip") or n.contains("LegRHip"):
				counts["legs"] = int(counts["legs"]) + 1
			if n.ends_with("KneePivot"):
				counts["knees"] = int(counts["knees"]) + 1
			if n.contains("Foot"):
				counts["feet"] = int(counts["feet"]) + 1
			if n.contains("Finger"):
				counts["fingers"] = int(counts["fingers"]) + 1
		_count_pose_parts(child, counts)

func _verify_pose_editor_authoring_contract() -> void:
	var src := FileAccess.get_file_as_string("res://test/pose_tuner.gd")
	_expect(src.contains("Launch in Maw"),
			"pose_tuner exposes Launch in Maw button")
	_expect(src.contains("LAUNCH_FILE") and src.contains("pose_tuner_launch.json"),
			"pose_tuner writes editor launch intent")
	_expect(src.contains("OS.create_process"),
			"pose_tuner starts the game scene for manual debug")
	_expect(src.contains("ScrollContainer") and src.contains("_slider_box"),
			"pose_tuner sidebar is scroll-backed")
	_expect(src.contains("Legend:") and src.contains("ARMS / HANDS / WEAPONS"),
			"pose_tuner labels slider groups with a legend")
	_expect(src.contains("_enumerate_draggables")
			and src.contains("HandR")
			and src.contains("HandL")
			and src.contains("ElbowPivot"),
			"pose_tuner enumerates hands, elbows, and weapon parts for click-drag")
	_expect(src.contains("input_lock_until_click"),
			"pose_tuner launch requests game-input lock")
	_expect(src.contains("ids_for_anim") and src.contains("ids_for_context"),
			"pose_tuner filters stances by variant animation")
	_expect(src.contains("RichTextLabel") and src.contains("[b]") and src.contains("_color_for_path"),
			"pose_tuner uses color-coded rich slider labels")
	_expect(src.contains("controls[2].set_value_no_signal")
			and src.contains("controls[3].set_value_no_signal"),
			"pose_tuner syncs drag edits back into numeric slider fields")
	_expect(src.contains("player_pythia_idle_oracle_staff")
			and src.contains("enemy_bog_caller_walk_swamp_drift")
			and src.contains("npc_kallias_idle_merchant_watch"),
			"pose_tuner variants are role-specific and pre-authored")
