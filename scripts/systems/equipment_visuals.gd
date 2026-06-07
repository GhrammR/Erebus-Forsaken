extends Node
## Stage 15 — paper-doll overlay registry. Builds procedural Polygon2D
## overlays for HEAD / CHEST / LEGS / OFFHAND per class. WEAPON is
## handled by toggling the class sprite's built-in weapon arm
## (SpearArm/StaffArm/BowArm/WandArm) — see weapon_arm_for(class_id).
##
## Hybrid art contract: this autoload is the procedural baseline. When
## Stage 11's AI bitmap pipeline produces a per-slot Sprite2D scene, the
## EquipmentPaperdoll component will prefer it if BitmapMode.enabled and
## a sidecar is present. Falls back to these procedural overlays
## otherwise. No AI dependency at runtime.

const TIER_DULL: Color   = Color(0.55, 0.55, 0.58)
const TIER_NORMAL: Color = Color(0.85, 0.82, 0.70)
const TIER_BRIGHT: Color = Color(1.00, 0.90, 0.50)

## Class -> weapon arm node name (lives directly under the sprite root).
## EquipmentPaperdoll toggles .visible based on whether the WEAPON slot
## is occupied. Empty slot = bare hands = arm hidden.
const WEAPON_ARMS: Dictionary = {
	# Stage 17.5 — SpearArm lives under the right hand. Shaft polygon
	# is HORIZONTAL with grip at the back (spear-local origin = hand),
	# so the strike rotates the arm forward and the spear translates
	# with the hand instead of arcing around it.
	&"myrmidon":       &"Body/ArmRShoulder/ElbowPivot/SpearArm",
	# Stage 17.6 — StaffArm lives under the RIGHT hand at the lower
	# grip (per reference-photo two-handed quarterstaff stance); the
	# LEFT arm grips the upper shaft via IK pinning.
	&"pythia":         &"Body/ArmRShoulder/ElbowPivot/StaffArm",
	&"shade_hunter":   &"BowArm",
	&"ossuary_priest": &"WandArm",
}

## Default offhand node (already painted on the class sprite). For
## Myrmidon, the Buckler doubles as the offhand visual. Other classes
## have no built-in offhand visual; an overlay is built instead.
const BUILTIN_OFFHAND: Dictionary = {
	# Stage 17.5 — Buckler moved under the left elbow pivot so it
	# rides the arm during shield-raise.
	&"myrmidon": ^"Body/ArmLShoulder/ElbowPivot/Buckler",
}

func weapon_arm_for(class_id: StringName) -> StringName:
	return WEAPON_ARMS.get(class_id, &"")

func builtin_offhand_path_for(class_id: StringName) -> NodePath:
	return BUILTIN_OFFHAND.get(class_id, NodePath(""))

## Magnitude of an equipped item used to band the overlay color. Low
## defensive items wash out toward grey; high-value items shine. Driven
## entirely off base contributions — affix-only items still band normally.
func tier_for(item: ItemData) -> int:
	if item == null:
		return 0
	var magnitude: int = item.base_armor_defense + item.base_weapon_ar + item.base_resist
	if magnitude >= 8:
		return 2
	if magnitude >= 3:
		return 1
	return 0

func tier_color(tier: int) -> Color:
	match tier:
		2: return TIER_BRIGHT
		1: return TIER_NORMAL
	return TIER_DULL

## Returns a Polygon2D overlay for the given (slot, class) pair, tinted
## by item tier. Returns null when the slot has no visual for this
## class (e.g. RING, AMULET — Act 1 has no jewelry visuals).
##
## Legacy single-node API — returns the FIRST part of
## `build_overlay_parts`. Kept so the Stage 15 verifier and other
## callers that only need one polygon still work.
func build_overlay(slot: int, class_id: StringName, item: ItemData) -> Polygon2D:
	var parts := build_overlay_parts(slot, class_id, item)
	if parts.is_empty():
		return null
	return parts[0]["poly"] as Polygon2D

## Multi-part overlay API. Returns Array of dictionaries:
##   [ { "mount": NodePath, "poly": Polygon2D }, ... ]
## Each part should be parented under sprite_root.get_node(mount). This
## lets a single equipment slot drive multiple anatomy-following
## polygons (e.g. greaves split across both KneePivots so each shin
## band articulates with its leg instead of floating in body space).
##
## Mount paths are relative to the sprite root. Empty mount = "Body".
func build_overlay_parts(slot: int, class_id: StringName, item: ItemData) -> Array:
	if item == null:
		return []
	match slot:
		EquipmentSlot.Slot.HEAD:
			var head := _build_head(class_id, item)
			if head == null: return []
			return [{ "mount": NodePath("Body"), "poly": head }]
		EquipmentSlot.Slot.CHEST:
			var chest := _build_chest(class_id, item)
			if chest == null: return []
			return [{ "mount": NodePath("Body"), "poly": chest }]
		EquipmentSlot.Slot.LEGS:
			return _build_legs_parts(class_id, item)
		EquipmentSlot.Slot.OFFHAND:
			var oh := _build_offhand(class_id, item)
			if oh == null: return []
			return [{ "mount": NodePath("Body"), "poly": oh }]
	return []

# ---- HEAD overlays --------------------------------------------------------

func _build_head(class_id: StringName, item: ItemData) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = "EquipHead"
	p.color = tier_color(tier_for(item))
	# All four classes have a head circle centered near (0, -44 .. -48).
	# Helmet sits as a low cap atop the head ring.
	match class_id:
		&"myrmidon":
			# Stage 17.5 — face-mask Corinthian helmet over the new
			# anatomy (head ~y=-60..-48). Covers the upper face down
			# to the cheekbones; T-slit for eye visibility. Tier
			# color tints the bronze.
			p.polygon = PackedVector2Array([
				Vector2(-7, -60),               # crown left
				Vector2(-3, -62), Vector2(3, -62), Vector2(7, -60),  # crown
				Vector2(7, -54),                # right temple
				Vector2(3.5, -54), Vector2(3.5, -50),  # right eye-slit step
				Vector2(7, -50), Vector2(7, -47),  # cheek guard right
				Vector2(2, -47),                # nose bridge bottom-right
				Vector2(1, -52), Vector2(-1, -52),  # nose ridge
				Vector2(-2, -47),               # nose bridge bottom-left
				Vector2(-7, -47), Vector2(-7, -50),
				Vector2(-3.5, -50), Vector2(-3.5, -54),  # left eye-slit step
				Vector2(-7, -54),
			])
		&"pythia":
			# Diadem band over y=-48
			p.polygon = PackedVector2Array([
				Vector2(-6, -50), Vector2(6, -50),
				Vector2(5, -54),  Vector2(-5, -54),
			])
		&"shade_hunter":
			# Hood reinforcement strip
			p.polygon = PackedVector2Array([
				Vector2(-6, -50), Vector2(6, -50),
				Vector2(4, -56),  Vector2(0, -58), Vector2(-4, -56),
			])
		&"ossuary_priest":
			# Bone circlet
			p.polygon = PackedVector2Array([
				Vector2(-6, -50), Vector2(6, -50),
				Vector2(5, -54),  Vector2(-5, -54),
			])
	return p

# ---- CHEST overlays -------------------------------------------------------

func _build_chest(class_id: StringName, item: ItemData) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = "EquipChest"
	p.color = tier_color(tier_for(item))
	# A trapezoid that hugs each class's torso polygon.
	match class_id:
		&"myrmidon":
			# Stage 17.5 — overlay sits on top of the base bronze
			# cuirass (y=-44..-28 in the new anatomy). Slightly
			# inset so the tier color reads as a chest decoration
			# (pectoral plate / better-quality cuirass) over the
			# muscled bronze.
			p.polygon = PackedVector2Array([
				Vector2(-8, -42), Vector2(8, -42),
				Vector2(7, -30),  Vector2(-7, -30),
			])
		&"pythia":
			# Mantle over the violet torso y=-30..-40
			p.polygon = PackedVector2Array([
				Vector2(-8, -30), Vector2(8, -30),
				Vector2(6, -40),  Vector2(-6, -40),
			])
		&"shade_hunter":
			# Tunic accent over y=-16..-36
			p.polygon = PackedVector2Array([
				Vector2(-7, -16), Vector2(7, -16),
				Vector2(5, -36),  Vector2(-5, -36),
			])
		&"ossuary_priest":
			# Bone breastplate over y=-30..-40
			p.polygon = PackedVector2Array([
				Vector2(-7, -30), Vector2(7, -30),
				Vector2(5, -40),  Vector2(-5, -40),
			])
	return p

# ---- LEGS overlays --------------------------------------------------------

# Returns leg parts that mount under each KneePivot so they
# articulate with the actual shin polygons during walk. Previously
# this was a single body-local shin band that floated in place while
# the shins swung beneath it (the "non-moving blocky shape over
# moving legs" bug). Each part is keyed in knee-local space (knee
# pivot at (0,0), shin extending down to (0, ANKLE_DROP=10)).
func _build_legs_parts(class_id: StringName, item: ItemData) -> Array:
	var color := tier_color(tier_for(item))
	match class_id:
		&"myrmidon":
			# Per-leg bronze greave wrapping the shin (knee → ankle).
			# In knee-local space, the shin runs y=0..10. Greave
			# covers the lower 3/4 of the shin with a strap notch.
			var poly := PackedVector2Array([
				Vector2(-3.4, 1.5),
				Vector2(3.4, 1.5),
				Vector2(3.6, 4.0),
				Vector2(3.2, 9.5),
				Vector2(-3.2, 9.5),
				Vector2(-3.6, 4.0),
			])
			return [
				{ "mount": NodePath("Body/LegLHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsL", poly, color) },
				{ "mount": NodePath("Body/LegRHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsR", poly, color) },
			]
		&"pythia":
			# Robe hem — both panels follow each leg.
			var poly2 := PackedVector2Array([
				Vector2(-4, 0), Vector2(4, 0),
				Vector2(4.5, 9.5), Vector2(-4.5, 9.5),
			])
			return [
				{ "mount": NodePath("Body/LegLHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsL", poly2, color) },
				{ "mount": NodePath("Body/LegRHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsR", poly2, color) },
			]
		&"shade_hunter":
			var poly3 := PackedVector2Array([
				Vector2(-3, 2), Vector2(3, 2),
				Vector2(3, 9.5), Vector2(-3, 9.5),
			])
			return [
				{ "mount": NodePath("Body/LegLHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsL", poly3, color) },
				{ "mount": NodePath("Body/LegRHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsR", poly3, color) },
			]
		&"ossuary_priest":
			var poly4 := PackedVector2Array([
				Vector2(-4, 0), Vector2(4, 0),
				Vector2(4.5, 9.5), Vector2(-4.5, 9.5),
			])
			return [
				{ "mount": NodePath("Body/LegLHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsL", poly4, color) },
				{ "mount": NodePath("Body/LegRHip/KneePivot"),
				  "poly": _make_leg_part(&"EquipLegsR", poly4, color) },
			]
	return []

static func _make_leg_part(part_name: StringName, pts: PackedVector2Array,
		color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = String(part_name)
	p.polygon = pts
	p.color = color
	return p

# ---- OFFHAND overlays -----------------------------------------------------
# Myrmidon already has a Buckler painted on the body — we just retint
# that node rather than building an overlay (see builtin_offhand_path_for).
# For other classes we instantiate a small focus/orb on the opposite hip.

func _build_offhand(class_id: StringName, item: ItemData) -> Polygon2D:
	if class_id == &"myrmidon":
		# Buckler is built-in; no overlay needed.
		return null
	var p := Polygon2D.new()
	p.name = "EquipOffhand"
	p.color = tier_color(tier_for(item))
	# Small disc on the LEFT hip (negative x).
	var cx := -12.0
	var cy := -22.0
	var r := 5.0
	var pts: PackedVector2Array = []
	for i in 8:
		var t := TAU * i / 8.0
		pts.append(Vector2(cx + r * cos(t), cy + r * sin(t)))
	p.polygon = pts
	return p
