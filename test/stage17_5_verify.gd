extends Node
## Stage 17.5 verifier - anatomy family registry + baseline reset
## conformance + sidecar contract.
##
## Current policy: all active player, NPC, and enemy sprite scene
## paths instantiate the same white Myrmidon-derived anatomy rig.
## Bespoke implementations are archived for reference.

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

# Stage 17.6 re-authored these as the UNDEAD wraith sub-variant rig
# (enemy_sprite_palette / SpriteRuntime2D, no legs, floating). They are
# intentionally NO LONGER the baseline white biped, so they are excluded
# from the baseline-conformance loops below. Their wraith contract is
# asserted in test/stage17_6_verify.gd instead. Registry membership
# (UNDEAD / WRAITH) is still checked here.
# Re-authored beyond the white baseline (wraith/skeleton rigs + Phase 2
# HUMAN skins). Excluded from the white-baseline conformance loops; each
# has its own contract in stage17_6_verify.
const REAUTHORED_17_6: Array[StringName] = [
	&"shade_wretch", &"bog_caller", &"bone_servant",
	&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
	&"kallias", &"eurynome",
]

const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")

const BASELINE_SCRIPT := "res://art/procedural/baseline_white_sprite.gd"
const ARCHIVE_ROOT := "res://art/procedural/archive/baseline_reset_2026_06_11"
const SPRITE_SCENES: Array = [
	{ "id": &"myrmidon", "path": "res://art/procedural/classes/myrmidon_sprite.tscn", "bucket": &"classes" },
	{ "id": &"pythia", "path": "res://art/procedural/classes/pythia_sprite.tscn", "bucket": &"classes" },
	{ "id": &"shade_hunter", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn", "bucket": &"classes" },
	{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn", "bucket": &"classes" },
	{ "id": &"training_dummy", "path": "res://art/procedural/enemies/dummy_sprite.tscn", "bucket": &"enemies" },
	{ "id": &"bone_servant", "path": "res://art/procedural/enemies/bone_servant_sprite.tscn", "bucket": &"enemies" },
	{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn", "bucket": &"enemies" },
	{ "id": &"bog_caller", "path": "res://art/procedural/enemies/bog_caller_sprite.tscn", "bucket": &"enemies" },
	{ "id": &"act_boss", "path": "res://art/procedural/enemies/act_boss_sprite.tscn", "bucket": &"enemies" },
	{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn", "bucket": &"npcs" },
	{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn", "bucket": &"npcs" },
]

const BASELINE_NODE_PATHS: PackedStringArray = [
	"Shadow",
	"Body",
	"Body/LegLHip",
	"Body/LegLHip/Thigh",
	"Body/LegLHip/KneePivot",
	"Body/LegLHip/KneePivot/Shin",
	"Body/LegLHip/KneePivot/Foot",
	"Body/LegRHip",
	"Body/LegRHip/Thigh",
	"Body/LegRHip/KneePivot",
	"Body/LegRHip/KneePivot/Shin",
	"Body/LegRHip/KneePivot/Foot",
	"Body/Hips",
	"Body/Torso",
	"Body/ArmLShoulder",
	"Body/ArmLShoulder/UpperArm",
	"Body/ArmLShoulder/ElbowPivot",
	"Body/ArmLShoulder/ElbowPivot/Forearm",
	"Body/ArmLShoulder/ElbowPivot/Hand",
	"Body/ArmRShoulder",
	"Body/ArmRShoulder/UpperArm",
	"Body/ArmRShoulder/ElbowPivot",
	"Body/ArmRShoulder/ElbowPivot/Forearm",
	"Body/ArmRShoulder/ElbowPivot/Hand",
	"Body/Neck",
	"Body/Head",
	"AnimationPlayer",
]

const FORBIDDEN_ACTIVE_NODE_TOKENS: PackedStringArray = [
	"Face", "Eye", "Brow", "Nose", "Mouth", "Hair", "Beard",
	"Hood", "Robe", "Cowl", "Helm", "Cloth", "Skirt",
]

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
	_verify_archived_sprite_sources()
	_verify_stance_catalog_filters()
	await _verify_current_sprite_animation_surface()
	await _verify_baseline_sprite_contract()
	await _verify_pose_editor_authoring_contract()
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
				"%s registered as bespoke entry" % id)

func _verify_bone_servant_unchanged_skeleton() -> void:
	_expect(AnatomyFamilies.subtype_of(&"bone_servant")
			== AnatomyFamilies.UndeadSubtype.SKELETON,
			"bone_servant subtype = SKELETON registry anchor")
	_expect(ResourceLoader.exists("res://art/procedural/enemies/bone_servant_sprite.tscn"),
			"bone_servant sprite scene path intact")

func _verify_equipment_overlays_target_human_parts() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/systems/equipment_visuals.gd")
	_expect(src.length() > 0,
			"equipment_visuals.gd present")

func _verify_sidecar_path_contract() -> void:
	_expect(ResourceLoader.exists("res://scripts/systems/sprite_sidecar.gd"),
			"SpriteSidecar helper exists")
	var expected := "res://data/sprites/myrmidon/Torso.png"
	var actual := SpriteSidecar.sidecar_path(&"myrmidon", &"Torso")
	_expect(actual == expected,
			"sidecar_path('myrmidon','Torso') == %s" % expected)

func _verify_archived_sprite_sources() -> void:
	_expect(ResourceLoader.exists(BASELINE_SCRIPT),
			"baseline white sprite script exists")
	_expect(FileAccess.file_exists(ARCHIVE_ROOT + "/README.md"),
			"baseline-reset archive README exists")
	for rec_v in SPRITE_SCENES:
		var rec: Dictionary = rec_v
		var active_path := String(rec["path"])
		var archived_path := ARCHIVE_ROOT + "/" + active_path.trim_prefix("res://")
		_expect(ResourceLoader.exists(archived_path),
				"%s original scene archived" % rec["id"])
	for script_path in [
		"art/procedural/classes/myrmidon_sprite.gd",
		"art/procedural/classes/pythia_sprite.gd",
		"art/procedural/classes/shade_hunter_sprite.gd",
		"art/procedural/classes/ossuary_priest_sprite.gd",
		"art/procedural/enemies/dummy_sprite.gd",
		"art/procedural/enemies/bone_servant_sprite.gd",
	]:
		_expect(ResourceLoader.exists(ARCHIVE_ROOT + "/" + script_path),
				"%s original script archived" % script_path.get_file())

func _verify_stance_catalog_filters() -> void:
	for anim_name in [&"idle", &"walk", &"attack", &"cast", &"die"]:
		# Use a non-drift enemy here — drift sprites (wraiths) are
		# intentionally pruned to fewer, float-only stances and are
		# asserted separately in stage17_6_verify.
		var enemy_ids := SpriteMotionStances.ids_for_context(&"enemies", &"bone_servant", anim_name)
		var npc_ids := SpriteMotionStances.ids_for_context(&"npcs", &"kallias", anim_name)
		var player_ids := SpriteMotionStances.ids_for_context(&"classes", &"pythia", anim_name)
		# Stage 17.8e — pruned to ONE proper stance per (role, anim); the
		# editor no longer offers the broken extras. Still role-namespaced.
		_expect(enemy_ids.size() == 1 and _ids_have_prefix(enemy_ids, "enemy_"),
				"enemy motion catalog exposes the canonical %s stance" % anim_name)
		_expect(npc_ids.size() == 1 and _ids_have_prefix(npc_ids, "npc_"),
				"npc motion catalog exposes the canonical %s stance" % anim_name)
		_expect(player_ids.size() == 1 and _ids_have_prefix(player_ids, "player_"),
				"player motion catalog exposes the canonical %s stance" % anim_name)

func _ids_have_prefix(ids: Array, prefix: String) -> bool:
	for id in ids:
		if not String(id).begins_with(prefix):
			return false
	return true

func _verify_current_sprite_animation_surface() -> void:
	for rec_v in SPRITE_SCENES:
		var rec: Dictionary = rec_v
		var packed := load(String(rec["path"])) as PackedScene
		_expect(packed != null, "%s sprite scene loads" % rec["id"])
		if packed == null:
			continue
		var sprite := packed.instantiate() as Node2D
		if &"sprite_id" in sprite:
			sprite.sprite_id = rec["id"]
		if &"stance_bucket" in sprite:
			sprite.stance_bucket = rec["bucket"]
		add_child(sprite)
		await get_tree().process_frame
		if not (rec["id"] in REAUTHORED_17_6):
			_expect(_scene_uses_baseline_script(String(rec["path"])),
					"%s active scene uses baseline script" % rec["id"])
			_expect(sprite.get_script() != null
					and String(sprite.get_script().resource_path) == BASELINE_SCRIPT,
					"%s instantiated script is baseline" % rec["id"])
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		_expect(anim != null, "%s exposes AnimationPlayer" % rec["id"])
		if anim != null:
			for anim_name in [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]:
				_expect(anim.has_animation(anim_name),
						"%s has %s animation" % [rec["id"], anim_name])
		sprite.queue_free()

func _verify_baseline_sprite_contract() -> void:
	for rec_v in SPRITE_SCENES:
		var rec: Dictionary = rec_v
		if rec["id"] in REAUTHORED_17_6:
			continue  # wraith rig — geometry asserted in stage17_6_verify
		var packed := load(String(rec["path"])) as PackedScene
		if packed == null:
			_expect(false, "%s baseline scene loads" % rec["id"])
			continue
		var sprite := packed.instantiate() as Node2D
		add_child(sprite)
		await get_tree().process_frame
		var body := sprite.get_node_or_null(^"Body")
		_expect(body != null, "%s has Body node" % rec["id"])
		_expect(sprite.get_node_or_null(^"Shadow") != null, "%s has Shadow" % rec["id"])
		for path in BASELINE_NODE_PATHS:
			_expect(sprite.get_node_or_null(NodePath(path)) != null,
					"%s baseline path exists: %s" % [rec["id"], path])
		for token in FORBIDDEN_ACTIVE_NODE_TOKENS:
			_expect(not _has_node_name_token(sprite, token),
					"%s has no %s layer" % [rec["id"], token])
		var counts := { "arms": 0, "hands": 0, "elbows": 0, "fingers": 0, "legs": 0, "knees": 0, "feet": 0, "shadows": 0 }
		_count_pose_parts(sprite, counts)
		_expect(int(counts["arms"]) == 2, "%s has exactly two arm roots" % rec["id"])
		_expect(int(counts["hands"]) == 2, "%s has exactly two hands" % rec["id"])
		_expect(int(counts["elbows"]) == 2, "%s has exactly two elbow pivots" % rec["id"])
		_expect(int(counts["legs"]) == 2, "%s has exactly two leg hip controls" % rec["id"])
		_expect(int(counts["knees"]) == 2, "%s has exactly two knee pivots" % rec["id"])
		_expect(int(counts["feet"]) == 2, "%s has exactly two feet" % rec["id"])
		var leg_l := body.get_node_or_null(^"LegLHip") as Node2D
		var leg_r := body.get_node_or_null(^"LegRHip") as Node2D
		_expect(leg_l != null and _vec_close(leg_l.position, HumanRig.LEG_L_HIP),
				"%s left leg uses HumanRig hip position" % rec["id"])
		_expect(leg_r != null and _vec_close(leg_r.position, HumanRig.LEG_R_HIP),
				"%s right leg uses HumanRig hip position" % rec["id"])
		_expect(_visible_polygons_are_white(body),
				"%s visible anatomy polygons are pure white" % rec["id"])
		sprite.queue_free()

func _count_pose_parts(node: Node, counts: Dictionary) -> void:
	for child in node.get_children():
		var n := String(child.name)
		if child is Node2D:
			if n == "Shadow":
				counts["shadows"] = int(counts["shadows"]) + 1
			if n == "ArmLShoulder" or n == "ArmRShoulder":
				counts["arms"] = int(counts["arms"]) + 1
			if n == "Hand":
				counts["hands"] = int(counts["hands"]) + 1
			if n.ends_with("ElbowPivot"):
				counts["elbows"] = int(counts["elbows"]) + 1
			if n == "LegLHip" or n == "LegRHip":
				counts["legs"] = int(counts["legs"]) + 1
			if n.ends_with("KneePivot"):
				counts["knees"] = int(counts["knees"]) + 1
			if n == "Foot":
				counts["feet"] = int(counts["feet"]) + 1
			if n.contains("Finger"):
				counts["fingers"] = int(counts["fingers"]) + 1
		_count_pose_parts(child, counts)

func _scene_uses_baseline_script(scene_path: String) -> bool:
	var src := FileAccess.get_file_as_string(scene_path)
	return src.contains('path="%s"' % BASELINE_SCRIPT)

func _has_node_name_token(node: Node, token: String) -> bool:
	if String(node.name).contains(token):
		return true
	for child in node.get_children():
		if _has_node_name_token(child, token):
			return true
	return false

func _visible_polygons_are_white(node: Node) -> bool:
	if node is Polygon2D:
		var item := node as Polygon2D
		# is_visible_in_tree, not .visible — weapon arms are painted up
		# front but hidden; their children's own .visible is still true.
		if item.is_visible_in_tree() and item.color != Color.WHITE:
			return false
	for child in node.get_children():
		if not _visible_polygons_are_white(child):
			return false
	return true

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
	_expect(src.contains("GRADE: UNSCORED") and src.contains("_score_card"),
			"pose_tuner exposes a prominent scorecard rating")
	_expect(src.contains("KEY_Z") and src.contains("_undo_pose"),
			"pose_tuner supports Ctrl+Z undo")
	_expect(src.contains("CUSTOM_STANCES_FILE")
			and src.contains("_on_save_stance_pressed")
			and src.contains("_on_delete_stance_pressed"),
			"pose_tuner can save/edit/delete custom stances")
	_expect(src.contains("_custom_import_warning")
			and src.contains("replicate grip/attack transforms")
			and src.contains("_copy_recommended_stance"),
			"pose_tuner warns and imports cross-sprite custom stances softly")
	_expect(src.contains("Idle Unarmed") and src.contains("\"show_staff\": false")
			and src.contains("\"show_bow\": false")
			and src.contains("\"show_spear\": false")
			and src.contains("\"show_wand\": false"),
			"pose_tuner exposes unarmed player animation variants")
	_expect(not src.contains("npc_kallias_die_old_man_fall")
			and not src.contains("enemy_bog_caller_walk_swamp_drift")
			and not src.contains("player_pythia_idle_oracle_staff"),
			"pose_tuner variant labels are short editor labels")
	_expect(src.contains("\"scales\": {}") and src.contains("_add_scale_sliders"),
			"pose_tuner saves scale/shape edits for sprite layers")
	_expect(src.contains("_shape_hit_distance") and src.contains("Line2D") and src.contains("Polygon2D"),
			"pose_tuner hit-tests visible weapon geometry for click-drag")
	# Regression guard: editor chrome must sit behind ALL sprite content.
	# An opaque background at z=0 once hid the bone_servant's z=-1 injected
	# legs in the editor while they rendered in-game. The BG/floor must use
	# a deeply-negative z so the tuner shows what ships.
	_expect(src.contains("const BG_Z: int = -100"),
			"pose_tuner BG_Z is deeply negative (-100)")
	_expect(src.contains("bg.z_index = BG_Z"),
			"pose_tuner background uses BG_Z (behind all sprite parts)")
	# And no live sprite part may sit at/below the chrome z, or it would
	# vanish behind the editor background.
	await _verify_sprite_parts_above_editor_bg()

func _verify_sprite_parts_above_editor_bg() -> void:
	const BG_Z := -100
	for rec_v in SPRITE_SCENES:
		var rec: Dictionary = rec_v
		var packed := load(String(rec["path"])) as PackedScene
		if packed == null:
			continue
		var sprite := packed.instantiate() as Node2D
		if &"sprite_id" in sprite:
			sprite.sprite_id = rec["id"]
		if &"stance_bucket" in sprite:
			sprite.stance_bucket = rec["bucket"]
		add_child(sprite)
		await get_tree().process_frame
		var min_z := 9999
		for poly in sprite.find_children("*", "Polygon2D", true, false):
			min_z = mini(min_z, (poly as Polygon2D).z_index)
		_expect(min_z > BG_Z,
				"%s has no part at/below editor BG z (min part z=%d > %d)" % [rec["id"], min_z, BG_Z])
		sprite.queue_free()
