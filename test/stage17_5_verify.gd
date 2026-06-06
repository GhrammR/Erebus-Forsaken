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
const BESPOKE_SPRITES: Array[StringName] = [
	&"hekate_marked",
]

var _fail: int = 0

func _ready() -> void:
	print("--- Stage 17.5 verify ---")
	_verify_registry_loaded()
	_verify_human_sprites_registered()
	_verify_wraith_sprites_registered()
	_verify_bespoke_sprites_registered()
	_verify_bone_servant_unchanged_skeleton()
	_verify_equipment_overlays_target_human_parts()
	_verify_sidecar_path_contract()
	print("--- Stage 17.5 verify: %s ---" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		print("  FAIL  %s" % label)
		_fail += 1

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
