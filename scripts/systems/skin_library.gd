class_name SkinLibrary extends Object
## Data-driven HUMAN-rig skins (Stage 17.6 Phase 2). A skin is the
## visible identity layered on the SHARED baseline HUMAN rig: a palette
## (which colours paint the rig's flesh parts) plus accoutrement layers
## (named Polygon2D overlays — clothing, armour-look, helms). This is
## the `skin` half of the Stage 17.7 CharacterDef, built early so each
## class/NPC is pure data, not a bespoke scene. See
## rules/sprite-animation.md §4.
##
## Schema, per sprite_id:
##   {
##     "palette": { "skin": Color, "skin_shadow": Color },
##     "parts": [
##       { "node": StringName, "parent": String (NodePath from sprite root,
##         default "Body"), "poly": PackedVector2Array, "color": Color,
##         "z": int },
##       ...
##     ],
##   }
## Coords are HUMAN-rig body-local (HumanRig constants; feet y=0, up = -y).

const _BRONZE: Color      = Color(0.60, 0.42, 0.20)
const _BRONZE_LIT: Color  = Color(0.70, 0.50, 0.26)
const _PLUME_RED: Color   = Color(0.70, 0.16, 0.12)
const _LEATHER: Color     = Color(0.30, 0.20, 0.12)
const _HOPLITE_SKIN: Color   = Color(0.78, 0.62, 0.50)
const _HOPLITE_SHADOW: Color = Color(0.54, 0.40, 0.30)

# static var (not const): the poly arrays are runtime-built, so this
# can't be a constant expression.
static var SKINS: Dictionary = {
	# Myrmidon — bronze-age hoplite: leather/bronze cuirass, crested
	# helm with red plume, greaves on the shins, a shield strap.
	# Myrmidon — BASE CLOTHING ONLY (2b-A): a plain leather exomis tunic +
	# belt. Bronze helm/plume/cuirass/greaves + shield are EQUIPMENT now.
	&"myrmidon": {
		"palette": { "skin": _HOPLITE_SKIN, "skin_shadow": _HOPLITE_SHADOW },
		"parts": [
			{ "node": &"Tunic", "parent": "Body", "z": 2, "color": Color(0.60, 0.42, 0.28),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(10, -28), Vector2(9, -16),
					Vector2(4, -18), Vector2(0, -16), Vector2(-4, -18), Vector2(-9, -16),
					Vector2(-10, -28)]) },
			{ "node": &"Belt", "parent": "Body", "z": 3, "color": _LEATHER,
				"poly": PackedVector2Array([
					Vector2(-9, -30), Vector2(9, -30), Vector2(9, -27), Vector2(-9, -27)]) },
		],
	},
	# Pythia — oracle: stained linen robe (pale violet), gold circlet +
	# trim, gold sash. Robe drapes over the legs.
	# Pythia — BASE CLOTHING ONLY (2b-A): stained-linen oracle robe with
	# gold trim/sash. The gold circlet + laurel (headgear) moved OUT to
	# the equipment layer — base skins carry no armour/headgear so any
	# equipped helm/circlet layers cleanly on top.
	&"pythia": {
		"palette": { "skin": Color(0.80, 0.66, 0.55), "skin_shadow": Color(0.56, 0.42, 0.32) },
		"parts": [
			{ "node": &"Robe", "parent": "Body", "z": 2, "color": Color(0.66, 0.60, 0.70),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(10, -28), Vector2(11, -11),
					Vector2(6, -13), Vector2(2, -10), Vector2(-2, -13), Vector2(-6, -10),
					Vector2(-11, -11), Vector2(-10, -28)]) },
			{ "node": &"RobeTrim", "parent": "Body", "z": 3, "color": Color(0.80, 0.66, 0.26),
				"poly": PackedVector2Array([
					Vector2(-3, -44), Vector2(3, -44), Vector2(4, -11), Vector2(-4, -11)]) },
			{ "node": &"Sash", "parent": "Body", "z": 3, "color": Color(0.80, 0.66, 0.26),
				"poly": PackedVector2Array([
					Vector2(-9, -31), Vector2(9, -31), Vector2(9, -28), Vector2(-9, -28)]) },
		],
	},
	# Shade-Hunter — BASE CLOTHING ONLY (2b-A): short hunter's tunic +
	# soft boots. Hood, cloak, vambraces, quiver are EQUIPMENT now.
	&"shade_hunter": {
		"palette": { "skin": Color(0.74, 0.60, 0.50), "skin_shadow": Color(0.50, 0.38, 0.30) },
		"parts": [
			{ "node": &"Tunic", "parent": "Body", "z": 2, "color": Color(0.32, 0.36, 0.32),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(10, -28), Vector2(9, -16),
					Vector2(4, -18), Vector2(0, -16), Vector2(-4, -18), Vector2(-9, -16),
					Vector2(-10, -28)]) },
			{ "node": &"Belt", "parent": "Body", "z": 3, "color": Color(0.24, 0.20, 0.16),
				"poly": PackedVector2Array([
					Vector2(-9, -30), Vector2(9, -30), Vector2(9, -27), Vector2(-9, -27)]) },
			{ "node": &"BootL", "parent": "Body/LegLHip/KneePivot", "z": 2,
				"color": Color(0.22, 0.20, 0.18), "poly": PackedVector2Array([
					Vector2(-3.3, 5), Vector2(3.3, 5), Vector2(3.1, 11), Vector2(-3.1, 11)]) },
			{ "node": &"BootR", "parent": "Body/LegRHip/KneePivot", "z": 2,
				"color": Color(0.22, 0.20, 0.18), "poly": PackedVector2Array([
					Vector2(-3.3, 5), Vector2(3.3, 5), Vector2(3.1, 11), Vector2(-3.1, 11)]) },
		],
	},
	# Ossuary Priest — ash-grey vestments hemmed with bone fragments,
	# hooded cap, a sickly-green sigil at the chest.
	&"ossuary_priest": {
		"palette": { "skin": Color(0.72, 0.70, 0.62), "skin_shadow": Color(0.50, 0.48, 0.42) },
		"parts": [
			{ "node": &"Robe", "parent": "Body", "z": 2, "color": Color(0.52, 0.52, 0.48),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(10, -28), Vector2(11, -11),
					Vector2(6, -13), Vector2(2, -10), Vector2(-2, -13), Vector2(-6, -10),
					Vector2(-11, -11), Vector2(-10, -28)]) },
			{ "node": &"BoneHem", "parent": "Body", "z": 3, "color": Color(0.88, 0.86, 0.74),
				"poly": PackedVector2Array([
					Vector2(-11, -11), Vector2(-8, -7), Vector2(-5, -11), Vector2(-2, -7),
					Vector2(1, -11), Vector2(4, -7), Vector2(7, -11), Vector2(10, -7),
					Vector2(11, -11)]) },
			{ "node": &"Sigil", "parent": "Body", "z": 4, "color": Color(0.45, 0.80, 0.42),
				"poly": PackedVector2Array([
					Vector2(0, -39), Vector2(2.2, -36), Vector2(0, -33), Vector2(-2.2, -36)]) },
			# Hood is EQUIPMENT now (2b-A) — base = ash vestment robe only.
		],
	},
	# Kallias (vendor NPC) — patched merchant cloak over a tunic, belt of
	# pouches.
	&"kallias": {
		"palette": { "skin": Color(0.74, 0.58, 0.46), "skin_shadow": Color(0.52, 0.38, 0.28) },
		"parts": [
			# Mantle (outerwear) is EQUIPMENT now (2b-A) — base = tunic.
			{ "node": &"Tunic", "parent": "Body", "z": 2, "color": Color(0.44, 0.32, 0.20),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(10, -28), Vector2(9, -17),
					Vector2(0, -19), Vector2(-9, -17), Vector2(-10, -28)]) },
			{ "node": &"Patch", "parent": "Body", "z": 3, "color": Color(0.54, 0.40, 0.24),
				"poly": PackedVector2Array([
					Vector2(2.5, -39), Vector2(6.5, -39), Vector2(6.5, -34), Vector2(2.5, -34)]) },
			{ "node": &"Belt", "parent": "Body", "z": 3, "color": Color(0.24, 0.16, 0.09),
				"poly": PackedVector2Array([
					Vector2(-9, -28), Vector2(9, -28), Vector2(9, -25), Vector2(-9, -25)]) },
			{ "node": &"Pouch", "parent": "Body", "z": 3, "color": Color(0.30, 0.20, 0.11),
				"poly": PackedVector2Array([
					Vector2(4, -28), Vector2(8, -28), Vector2(8, -23), Vector2(4, -23)]) },
		],
	},
	# Eurynome (quest-giver NPC) — heavy ceremonial indigo robe with a lit
	# center panel, a veil, and a gold sigil at the throat.
	&"eurynome": {
		"palette": { "skin": Color(0.80, 0.66, 0.56), "skin_shadow": Color(0.56, 0.42, 0.34) },
		"parts": [
			{ "node": &"Robe", "parent": "Body", "z": 2, "color": Color(0.22, 0.24, 0.36),
				"poly": PackedVector2Array([
					Vector2(-9, -44), Vector2(9, -44), Vector2(11, -28), Vector2(12, -11),
					Vector2(6, -13), Vector2(0, -10), Vector2(-6, -13), Vector2(-12, -11),
					Vector2(-11, -28)]) },
			{ "node": &"RobePanel", "parent": "Body", "z": 3, "color": Color(0.32, 0.34, 0.48),
				"poly": PackedVector2Array([
					Vector2(-2.5, -44), Vector2(2.5, -44), Vector2(3.5, -11), Vector2(-3.5, -11)]) },
			{ "node": &"Sigil", "parent": "Body", "z": 4, "color": Color(0.82, 0.68, 0.28),
				"poly": PackedVector2Array([
					Vector2(0, -46), Vector2(1.6, -44), Vector2(0, -42), Vector2(-1.6, -44)]) },
			# Veil (headgear) is EQUIPMENT now (2b-A) — base = ceremonial robe.
		],
	},
}

static func has(sprite_id: StringName) -> bool:
	return SKINS.has(sprite_id)

## Paint the rig's flesh parts with the skin palette and layer on the
## accoutrement Polygon2Ds. Returns false (and does nothing) when the
## sprite has no skin entry, so callers fall back to their default paint.
static func apply(sprite_root: Node2D, sprite_id: StringName) -> bool:
	var skin: Dictionary = SKINS.get(sprite_id, {})
	if skin.is_empty():
		return false
	var body := sprite_root.get_node_or_null(^"Body") as Node2D
	if body == null:
		return false
	var pal: Dictionary = skin.get("palette", {})
	HumanRig.apply(body,
			pal.get("skin", HumanRig.SKIN_BASE),
			pal.get("skin_shadow", HumanRig.SKIN_SHADOW))
	for part_v in skin.get("parts", []):
		var part: Dictionary = part_v
		var parent := sprite_root.get_node_or_null(
				NodePath(String(part.get("parent", "Body")))) as Node2D
		if parent == null:
			continue
		var node_name := StringName(part["node"])
		var p := parent.get_node_or_null(NodePath(String(node_name))) as Polygon2D
		if p == null:
			p = Polygon2D.new()
			p.name = String(node_name)
			parent.add_child(p)
		p.polygon = part["poly"]
		p.color = part["color"]
		p.z_index = int(part.get("z", 1))
	return true
