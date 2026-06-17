extends Node
## Stage 17.7 verifier — CharacterDef registry.
##
## Asserts the registry is the single source of truth: every character
## resolves to a buildable sprite, its aggregated CharacterDef is
## consistent with AnatomyFamilies + SkinLibrary, equipment slots are
## HUMAN-player-only, and ClassData resolves its sprite through the
## registry by character_id.

const CharacterRegistry = preload("res://scripts/systems/character_registry.gd")
const CANON: Array = [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]
const EXPECTED: Array = [
	&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
	&"kallias", &"eurynome",
	&"bone_servant", &"revenant", &"shade_wretch", &"bog_caller", &"act_boss",
	&"fiend",
]
const CLASS_TRES: Array = [
	{ "id": &"myrmidon", "path": "res://data/classes/myrmidon.tres" },
	{ "id": &"pythia", "path": "res://data/classes/pythia.tres" },
	{ "id": &"shade_hunter", "path": "res://data/classes/shade_hunter.tres" },
	{ "id": &"ossuary_priest", "path": "res://data/classes/ossuary_priest.tres" },
]

var _fail: int = 0

func _ready() -> void:
	print("--- Stage 17.7 verify ---")
	_verify_roster()
	await _verify_resolution_and_defs()
	_verify_classdata_wiring()
	print("--- Stage 17.7 verify: %s ---" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		print("  FAIL  %s" % label)
		_fail += 1

func _verify_roster() -> void:
	for id in EXPECTED:
		_expect(CharacterRegistry.has(id), "registry has %s" % id)
	_expect(CharacterRegistry.ids().size() == EXPECTED.size(),
			"registry roster size == %d" % EXPECTED.size())

func _verify_resolution_and_defs() -> void:
	for id in EXPECTED:
		# Scene resolves + builds the canonical anim set.
		var packed := CharacterRegistry.scene_for(id)
		_expect(packed != null, "%s scene_for resolves" % id)
		if packed == null:
			continue
		var sprite := CharacterRegistry.instantiate(id) as Node2D
		_expect(sprite != null, "%s instantiates" % id)
		if sprite == null:
			continue
		add_child(sprite)
		await get_tree().process_frame
		var anim := sprite.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
		_expect(anim != null, "%s has AnimationPlayer" % id)
		if anim != null:
			for n in CANON:
				_expect(anim.has_animation(n), "%s builds anim '%s'" % [id, n])
		sprite.queue_free()
		# Aggregated CharacterDef is consistent with the source registries.
		var d := CharacterRegistry.def(id)
		_expect(not d.is_empty(), "%s def resolves" % id)
		_expect(AnatomyFamilies.has_anim_set(d.get("anim_set", &"")),
				"%s anim_set '%s' is declared" % [id, d.get("anim_set", &"")])
		_expect(d.get("sub_variant", "") == AnatomyFamilies.sub_variant_name(id),
				"%s sub_variant matches AnatomyFamilies" % id)
		# Equipment slots: HUMAN player classes ONLY (bucket==classes).
		var slots_expected: bool = d.get("bucket", &"") == &"classes"
		_expect(bool(d.get("equipment_slots", false)) == slots_expected,
				"%s equipment_slots == (player class)" % id)
		# has_skin iff HUMAN species (the data-driven SkinLibrary cast).
		var is_human: bool = AnatomyFamilies.family_of(id) == AnatomyFamilies.Family.HUMAN
		_expect(bool(d.get("has_skin", false)) == is_human,
				"%s has_skin == (HUMAN species)" % id)

func _verify_classdata_wiring() -> void:
	for rec_v in CLASS_TRES:
		var rec: Dictionary = rec_v
		var cd := load(String(rec["path"])) as Resource
		_expect(cd != null, "%s ClassData loads" % rec["id"])
		if cd == null:
			continue
		_expect(cd.character_id == rec["id"],
				"%s ClassData.character_id == %s" % [rec["id"], rec["id"]])
		# Registry resolves to the same scene the class points at.
		var reg_scene := CharacterRegistry.scene_for(cd.character_id)
		_expect(reg_scene != null and cd.sprite_scene != null
				and reg_scene.resource_path == cd.sprite_scene.resource_path,
				"%s registry scene == ClassData.sprite_scene" % rec["id"])
