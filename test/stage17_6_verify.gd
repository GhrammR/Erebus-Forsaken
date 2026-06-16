extends Node
## Stage 17.6 verifier — species roster + anim_set contract spine.
##
## Locks the data layer from rules/sprite-animation.md: five species
## (HUMAN/DEMON/BEAST/UNDEAD/CONSTRUCT) derived from the white baseline,
## the six canonical animation names (AD-11), and the named anim_set
## profiles each species/sub-variant builds against. Procedural rig
## geometry for the new species is authored + screenshot-verified in
## follow-up increments; this verifier guards the contract they fill.

const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")

# A registered HUMAN-baseline scene used to cross-check that the
# canonical anim names the contract declares are the ones a real sprite
# actually builds.
const BASELINE_SCENE := "res://art/procedural/classes/myrmidon_sprite.tscn"

var _fail: int = 0

func _ready() -> void:
	print("--- Stage 17.6 verify ---")
	_verify_species_roster()
	_verify_legacy_families_demoted()
	_verify_construct_species()
	_verify_canonical_anim_names()
	await _verify_canonical_anims_build_on_baseline()
	_verify_anim_set_profiles()
	_verify_species_default_anim_sets()
	_verify_anim_set_resolution()
	_verify_sub_variant_naming()
	_verify_no_sprite_uses_legacy_family()
	await _verify_wraith_rig_scenes()
	_verify_wraith_drift_pruning()
	await _verify_wraith_hovers_off_ground()
	await _verify_skeleton_rig()
	await _verify_revenant_rig()
	await _verify_human_skins()
	print("--- Stage 17.6 verify: %s ---" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		print("  FAIL  %s" % label)
		_fail += 1

func _verify_species_roster() -> void:
	var species := AnatomyFamilies.species_list()
	_expect(species.size() == 5, "exactly five live species declared")
	for fam in [
		AnatomyFamilies.Family.HUMAN, AnatomyFamilies.Family.UNDEAD,
		AnatomyFamilies.Family.BEAST, AnatomyFamilies.Family.DEMON,
		AnatomyFamilies.Family.CONSTRUCT,
	]:
		_expect(AnatomyFamilies.is_species(fam),
				"%s is a live species" % AnatomyFamilies.family_name(fam))

func _verify_legacy_families_demoted() -> void:
	for fam in [AnatomyFamilies.Family.HUMANOID, AnatomyFamilies.Family.FLYING]:
		var name := AnatomyFamilies.family_name(fam)
		_expect(AnatomyFamilies.is_legacy_family(fam),
				"%s flagged as legacy" % name)
		_expect(not AnatomyFamilies.is_species(fam),
				"%s is NOT a live species" % name)

func _verify_construct_species() -> void:
	_expect(AnatomyFamilies.PARTS.has(AnatomyFamilies.Family.CONSTRUCT),
			"CONSTRUCT part set declared")
	var construct: Array = AnatomyFamilies.PARTS.get(AnatomyFamilies.Family.CONSTRUCT, [])
	# CONSTRUCT must keep the HUMAN joint names so HUMAN-anim tracks bind.
	var human_joints: Array = [
		&"Head", &"Neck", &"Torso", &"Hips",
		&"UpperArmL", &"ForearmL", &"HandL",
		&"UpperArmR", &"ForearmR", &"HandR",
		&"ThighL", &"ShinL", &"FootL",
		&"ThighR", &"ShinR", &"FootR",
	]
	var all_present := true
	for j in human_joints:
		if not (j in construct):
			all_present = false
	_expect(all_present, "CONSTRUCT keeps HUMAN joint names (anim tracks bind)")
	_expect(&"Faceplate" in construct and &"CoreGlow" in construct,
			"CONSTRUCT adds Faceplate + CoreGlow parts")

func _verify_canonical_anim_names() -> void:
	var expected: Array = [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]
	_expect(AnatomyFamilies.CANONICAL_ANIMS == expected,
			"CANONICAL_ANIMS == idle/walk/attack/cast/hit/die (AD-11)")
	# Guard against a hurt/death drift re-entering the contract.
	_expect(not (&"hurt" in AnatomyFamilies.CANONICAL_ANIMS)
			and not (&"death" in AnatomyFamilies.CANONICAL_ANIMS),
			"no hurt/death in canonical anim names")

func _verify_canonical_anims_build_on_baseline() -> void:
	var packed := load(BASELINE_SCENE) as PackedScene
	_expect(packed != null, "baseline HUMAN scene loads")
	if packed == null:
		return
	var sprite := packed.instantiate() as Node2D
	add_child(sprite)
	await get_tree().process_frame
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(anim != null, "baseline exposes AnimationPlayer")
	if anim != null:
		for n in AnatomyFamilies.CANONICAL_ANIMS:
			_expect(anim.has_animation(n),
					"baseline builds canonical anim '%s'" % n)
	sprite.queue_free()

func _verify_anim_set_profiles() -> void:
	for set_id in [&"human_default", &"wraith_float", &"quadruped", &"construct_rigid"]:
		_expect(AnatomyFamilies.has_anim_set(set_id),
				"anim_set '%s' declared" % set_id)
		var prof: Dictionary = AnatomyFamilies.ANIM_SETS.get(set_id, {})
		var stance: StringName = prof.get("stance", &"")
		# Each profile's stance must resolve to a real SpriteMotionStances
		# entry (get_stance returns DEFAULT on a miss — assert the id round
		# -trips so a typo can't silently fall back).
		var resolved: Dictionary = SpriteMotionStances.get_stance(stance)
		_expect(resolved.get("id", &"") == stance,
				"anim_set '%s' stance '%s' is a real stance" % [set_id, stance])
	_expect(AnatomyFamilies.ANIM_SETS[&"wraith_float"].get("legs", true) == false,
			"wraith_float has no leg motion")
	_expect(AnatomyFamilies.ANIM_SETS[&"construct_rigid"].get("rigid", false) == true,
			"construct_rigid is rigid")

func _verify_species_default_anim_sets() -> void:
	for fam in AnatomyFamilies.species_list():
		var set_id: StringName = AnatomyFamilies.SPECIES_DEFAULT_ANIM_SET.get(fam, &"")
		_expect(set_id != &"",
				"%s has a default anim_set" % AnatomyFamilies.family_name(fam))
		_expect(AnatomyFamilies.has_anim_set(set_id),
				"%s default anim_set '%s' is declared" % [AnatomyFamilies.family_name(fam), set_id])

func _verify_anim_set_resolution() -> void:
	_expect(AnatomyFamilies.anim_set_for(&"myrmidon") == &"human_default",
			"myrmidon resolves to human_default")
	_expect(AnatomyFamilies.anim_set_for(&"shade_wretch") == &"wraith_float",
			"shade_wretch resolves to wraith_float (entry override)")
	_expect(AnatomyFamilies.anim_set_for(&"bog_caller") == &"wraith_float",
			"bog_caller resolves to wraith_float (entry override)")
	_expect(AnatomyFamilies.anim_set_for(&"bone_servant") == &"human_default",
			"bone_servant (skeleton) resolves to human_default")

func _verify_sub_variant_naming() -> void:
	_expect(AnatomyFamilies.sub_variant_name(&"bone_servant") == "skeleton",
			"bone_servant sub-variant = skeleton")
	_expect(AnatomyFamilies.sub_variant_name(&"shade_wretch") == "wraith",
			"shade_wretch sub-variant = wraith")
	_expect(AnatomyFamilies.UndeadSubtype.REVENANT
			== AnatomyFamilies.UndeadSubtype.REVENANT,
			"REVENANT undead sub-variant enum exists")
	# Bespoke + unregistered have no sub-variant.
	_expect(AnatomyFamilies.sub_variant_name(&"act_boss") == "",
			"bespoke act_boss has no sub-variant")
	_expect(AnatomyFamilies.sub_variant_name(&"nonexistent") == "",
			"unregistered sprite has no sub-variant")

# The UNDEAD wraith rig (Stage 17.6): proven floating, legless geometry
# restored to the live shade_wretch + bog_caller scenes, driven by
# SpriteRuntime2D (enemy_sprite_palette). Asserts the rig is a real
# wraith — no legs, has the cloak/face part set, builds all six
# canonical anims and resolves to wraith_float.
const WRAITH_SCENES: Array = [
	{ "id": &"shade_wretch", "path": "res://art/procedural/enemies/shade_wretch_sprite.tscn", "robe": &"Cloak" },
	{ "id": &"bog_caller",   "path": "res://art/procedural/enemies/bog_caller_sprite.tscn",   "robe": &"Cloak" },
]

func _verify_wraith_rig_scenes() -> void:
	for rec_v in WRAITH_SCENES:
		var rec: Dictionary = rec_v
		var id: StringName = rec["id"]
		var packed := load(String(rec["path"])) as PackedScene
		_expect(packed != null, "%s wraith scene loads" % id)
		if packed == null:
			continue
		var sprite := packed.instantiate() as Node2D
		sprite.sprite_id = id
		sprite.stance_bucket = &"enemies"
		add_child(sprite)
		await get_tree().process_frame
		var body := sprite.get_node_or_null(^"Body")
		_expect(body != null, "%s has Body" % id)
		# Wraith floats — NO leg chain.
		_expect(sprite.get_node_or_null(^"Body/LegLHip") == null
				and sprite.get_node_or_null(^"Body/LegRHip") == null,
				"%s has no legs (floats)" % id)
		# Wraith part set present.
		_expect(sprite.get_node_or_null(^"Body/Hood") != null, "%s has Hood" % id)
		_expect(sprite.get_node_or_null(^"Body/FaceVoid") != null, "%s has FaceVoid" % id)
		_expect(body != null and body.get_node_or_null(NodePath(String(rec["robe"]))) != null,
				"%s has %s drape layer" % [id, rec["robe"]])
		# Rebuilt on the shared HUMAN rig (Stage 17.8d): articulated arms
		# that hang down like a character's, ending in claws.
		_expect(sprite.get_node_or_null(^"Body/ArmLShoulder/ElbowPivot/Forearm") != null
				and sprite.get_node_or_null(^"Body/ArmRShoulder/ElbowPivot/Forearm") != null,
				"%s has both articulated arms" % id)
		# All six canonical anims build on the wraith.
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		_expect(anim != null, "%s exposes AnimationPlayer" % id)
		if anim != null:
			for n in AnatomyFamilies.CANONICAL_ANIMS:
				_expect(anim.has_animation(n), "%s builds canonical anim '%s'" % [id, n])
			# Idle must not animate a (non-existent) leg track.
			var idle := anim.get_animation(&"idle")
			var leg_track := false
			if idle != null:
				for t in idle.get_track_count():
					if String(idle.track_get_path(t)).contains("Leg"):
						leg_track = true
			_expect(not leg_track, "%s idle has no leg tracks" % id)
		_expect(AnatomyFamilies.anim_set_for(id) == &"wraith_float",
				"%s resolves to wraith_float" % id)
		sprite.queue_free()

# Drift-only stance pruning: a wraith's locomotion menu is a single
# float/drift, never a footed gait; death is dissolve-only; the
# non-caster Shade Wretch is offered no cast pose.
func _verify_wraith_drift_pruning() -> void:
	var sw_walk := SpriteMotionStances.ids_for_context(&"enemies", &"shade_wretch", &"walk")
	_expect(sw_walk.size() == 1 and (&"enemy_drift_hover" in sw_walk),
			"shade_wretch walk is drift-only (enemy_drift_hover)")
	_expect(not (&"enemy_walk_lurch" in sw_walk) and not (&"enemy_walk_stalk" in sw_walk),
			"shade_wretch has no footed-gait walk stances")
	# The wraith must never be offered a stance whose id says "walk".
	_expect(not _any_id_contains(sw_walk, "walk"),
			"shade_wretch locomotion stance id is not a 'walk'")
	var sw_die := SpriteMotionStances.ids_for_context(&"enemies", &"shade_wretch", &"die")
	_expect(sw_die == [&"enemy_die_dissolve"], "shade_wretch death is dissolve-only")
	var sw_cast := SpriteMotionStances.ids_for_context(&"enemies", &"shade_wretch", &"cast")
	_expect(sw_cast.is_empty(), "shade_wretch (non-caster) offered no cast stance")
	# bog_caller drifts too but DOES cast.
	var bc_walk := SpriteMotionStances.ids_for_context(&"enemies", &"bog_caller", &"walk")
	_expect(bc_walk.size() == 1 and (&"enemy_drift_hover" in bc_walk),
			"bog_caller walk is drift-only")
	var bc_cast := SpriteMotionStances.ids_for_context(&"enemies", &"bog_caller", &"cast")
	_expect(not bc_cast.is_empty(), "bog_caller (caster) keeps cast stances")

# A wraith floats: its Body rests above the ground (negative y) while
# the Shadow stays on the ground plane, opening a visible gap.
# UNDEAD skeleton sub-variant (Phase 1a): Bone Servant rebuilt on the
# shared HUMAN rig (Myrmidon anatomy — articulated arms + legs) and
# re-skinned as bone (ribcage, sternum, loincloth, eye-glow). Builds the
# six canonical anims via SpriteRuntime2D.
func _verify_skeleton_rig() -> void:
	var packed := load("res://art/procedural/enemies/bone_servant_sprite.tscn") as PackedScene
	_expect(packed != null, "bone_servant scene loads")
	if packed == null:
		return
	_expect(_scene_script_path("res://art/procedural/enemies/bone_servant_sprite.tscn").ends_with("bone_servant_sprite.gd"),
			"bone_servant uses its own skeleton script (not baseline)")
	var sprite := packed.instantiate() as Node2D
	add_child(sprite)
	await get_tree().process_frame
	# Shares the HUMAN rig anatomy: head, torso, both articulated arms,
	# both articulated legs with knee pivots.
	for part in [^"Body/Head", ^"Body/Torso", ^"Body/ArmLShoulder/ElbowPivot",
			^"Body/ArmRShoulder/ElbowPivot", ^"Body/LegLHip/KneePivot",
			^"Body/LegRHip/KneePivot"]:
		_expect(sprite.get_node_or_null(part) != null,
				"bone_servant has HUMAN-rig part %s" % part)
	# Bone re-skin overlays.
	for part in [^"Body/Rib1", ^"Body/Sternum", ^"Body/Loincloth", ^"Body/EyeGlowL"]:
		_expect(sprite.get_node_or_null(part) != null,
				"bone_servant has skeletal overlay %s" % part)
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(anim != null, "bone_servant exposes AnimationPlayer")
	if anim != null:
		for n in AnatomyFamilies.CANONICAL_ANIMS:
			_expect(anim.has_animation(n), "bone_servant builds canonical anim '%s'" % n)
	_expect(AnatomyFamilies.sub_variant_name(&"bone_servant") == "skeleton",
			"bone_servant sub-variant = skeleton")
	sprite.queue_free()

# UNDEAD revenant sub-variant (Phase 1b): HUMAN rig + decayed flesh
# (torn tunic, exposed rib slivers, sunken eyes, hip rag).
func _verify_revenant_rig() -> void:
	var packed := load("res://art/procedural/enemies/revenant_sprite.tscn") as PackedScene
	_expect(packed != null, "revenant scene loads")
	if packed == null:
		return
	var sprite := packed.instantiate() as Node2D
	add_child(sprite)
	await get_tree().process_frame
	# Full HUMAN rig (fleshed — articulated arms + legs).
	for part in [^"Body/Head", ^"Body/Torso", ^"Body/ArmLShoulder/ElbowPivot",
			^"Body/LegLHip/KneePivot", ^"Body/LegRHip/KneePivot"]:
		_expect(sprite.get_node_or_null(part) != null,
				"revenant has HUMAN-rig part %s" % part)
	# Decay overlays.
	for part in [^"Body/Tunic", ^"Body/Rip", ^"Body/HipRag", ^"Body/EyeGlowL"]:
		_expect(sprite.get_node_or_null(part) != null,
				"revenant has decay overlay %s" % part)
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	_expect(anim != null, "revenant exposes AnimationPlayer")
	if anim != null:
		for n in AnatomyFamilies.CANONICAL_ANIMS:
			_expect(anim.has_animation(n), "revenant builds canonical anim '%s'" % n)
	_expect(AnatomyFamilies.sub_variant_name(&"revenant") == "revenant",
			"revenant sub-variant = revenant")
	# No part hides behind the editor background (z > -100).
	var min_z := 9999
	for poly in sprite.find_children("*", "Polygon2D", true, false):
		min_z = mini(min_z, (poly as Polygon2D).z_index)
	_expect(min_z > -100, "revenant parts above editor BG z (min=%d)" % min_z)
	sprite.queue_free()

# HUMAN skins (Phase 2): the data-driven SkinLibrary paints the shared
# baseline rig with a class palette + accoutrement layers. Myrmidon is
# the first authored skin; the rest fill in as pure data.
const SkinLibrary = preload("res://scripts/systems/skin_library.gd")

const _HUMAN_SKINS: Array = [
	{ "id": &"myrmidon", "path": "res://art/procedural/classes/myrmidon_sprite.tscn" },
	{ "id": &"pythia", "path": "res://art/procedural/classes/pythia_sprite.tscn" },
	{ "id": &"shade_hunter", "path": "res://art/procedural/classes/shade_hunter_sprite.tscn" },
	{ "id": &"ossuary_priest", "path": "res://art/procedural/classes/ossuary_priest_sprite.tscn" },
	{ "id": &"kallias", "path": "res://art/procedural/npcs/kallias_sprite.tscn" },
	{ "id": &"eurynome", "path": "res://art/procedural/npcs/eurynome_sprite.tscn" },
]

func _verify_human_skins() -> void:
	# Myrmidon spot-check: BASE CLOTHING ONLY (2b-A) — a tunic + belt, and
	# NO baked armor/headgear (those are equipment now).
	var mp := load("res://art/procedural/classes/myrmidon_sprite.tscn") as PackedScene
	if mp != null:
		var ms := mp.instantiate() as Node2D
		add_child(ms)
		await get_tree().process_frame
		for part in [^"Body/Tunic", ^"Body/Belt"]:
			_expect(ms.get_node_or_null(part) != null,
					"myrmidon base-clothing part %s" % part)
		for armor in [^"Body/Cuirass", ^"Body/Helm", ^"Body/Plume"]:
			_expect(ms.get_node_or_null(armor) == null,
					"myrmidon has NO baked armor (%s is equipment)" % armor)
		ms.queue_free()
	# Every HUMAN skin: registered, palette took effect (torso not white),
	# at least one accoutrement layer added, six canonical anims build.
	for rec_v in _HUMAN_SKINS:
		var rec: Dictionary = rec_v
		var id: StringName = rec["id"]
		_expect(SkinLibrary.has(id), "SkinLibrary has a %s skin" % id)
		var packed := load(String(rec["path"])) as PackedScene
		_expect(packed != null, "%s scene loads" % id)
		if packed == null:
			continue
		var sprite := packed.instantiate() as Node2D
		add_child(sprite)
		await get_tree().process_frame
		var body := sprite.get_node_or_null(^"Body") as Node2D
		var torso := sprite.get_node_or_null(^"Body/Torso") as Polygon2D
		_expect(torso != null and torso.color != Color.WHITE,
				"%s torso painted by skin (not white baseline)" % id)
		# Accoutrement count: the skin adds Polygon2D layers beyond the
		# bare rig — at least one named part from the skin data exists.
		var added := 0
		for part_v in SkinLibrary.SKINS.get(id, {}).get("parts", []):
			if sprite.get_node_or_null(NodePath(
					String(part_v.get("parent", "Body")) + "/" + String(part_v["node"]))) != null:
				added += 1
		_expect(added > 0, "%s skin layered %d accoutrement parts" % [id, added])
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		_expect(anim != null, "%s exposes AnimationPlayer" % id)
		if anim != null:
			for n in AnatomyFamilies.CANONICAL_ANIMS:
				_expect(anim.has_animation(n), "%s builds canonical anim '%s'" % [id, n])
		sprite.queue_free()

func _scene_script_path(scene_path: String) -> String:
	var src := FileAccess.get_file_as_string(scene_path)
	for line in src.split("\n"):
		if line.begins_with("[ext_resource") and line.contains("Script") and line.contains("path="):
			var a := line.split('path="')
			if a.size() > 1:
				return (a[1] as String).split('"')[0]
	return ""

func _any_id_contains(ids: Array, token: String) -> bool:
	for id in ids:
		if String(id).contains(token):
			return true
	return false

func _verify_wraith_hovers_off_ground() -> void:
	var packed := load("res://art/procedural/enemies/shade_wretch_sprite.tscn") as PackedScene
	_expect(packed != null, "shade_wretch scene loads for hover check")
	if packed == null:
		return
	var sprite := packed.instantiate() as Node2D
	sprite.sprite_id = &"shade_wretch"
	sprite.stance_bucket = &"enemies"
	add_child(sprite)
	await get_tree().process_frame
	var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	var body := sprite.get_node_or_null(^"Body") as Node2D
	_expect(anim != null and body != null, "shade_wretch has Body + AnimationPlayer")
	if anim != null and body != null:
		anim.play(&"idle")
		anim.seek(0.0, true)
		await get_tree().process_frame
		_expect(body.position.y < -1.0,
				"shade_wretch Body floats above ground (y=%.1f < 0)" % body.position.y)
		var shadow := sprite.get_node_or_null(^"Shadow") as Node2D
		_expect(shadow != null and shadow.position.y >= body.position.y,
				"shadow stays at/below the floating body (gap)")
	sprite.queue_free()

func _verify_no_sprite_uses_legacy_family() -> void:
	var any_legacy := false
	for id in AnatomyFamilies.ENTRIES.keys():
		var fam := AnatomyFamilies.family_of(id)
		if AnatomyFamilies.is_legacy_family(fam):
			any_legacy = true
			print("    legacy-family registration: %s" % id)
	_expect(not any_legacy, "no registered sprite uses a legacy family")
