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
	&"myrmidon":       &"SpearArm",
	&"pythia":         &"StaffArm",
	&"shade_hunter":   &"BowArm",
	&"ossuary_priest": &"WandArm",
}

## Default offhand node (already painted on the class sprite). For
## Myrmidon, the Buckler doubles as the offhand visual. Other classes
## have no built-in offhand visual; an overlay is built instead.
const BUILTIN_OFFHAND: Dictionary = {
	&"myrmidon": ^"Body/Buckler",
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
func build_overlay(slot: int, class_id: StringName, item: ItemData) -> Polygon2D:
	if item == null:
		return null
	match slot:
		EquipmentSlot.Slot.HEAD:    return _build_head(class_id, item)
		EquipmentSlot.Slot.CHEST:   return _build_chest(class_id, item)
		EquipmentSlot.Slot.LEGS:    return _build_legs(class_id, item)
		EquipmentSlot.Slot.OFFHAND: return _build_offhand(class_id, item)
	return null

# ---- HEAD overlays --------------------------------------------------------

func _build_head(class_id: StringName, item: ItemData) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = "EquipHead"
	p.color = tier_color(tier_for(item))
	# All four classes have a head circle centered near (0, -44 .. -48).
	# Helmet sits as a low cap atop the head ring.
	match class_id:
		&"myrmidon":
			# Bronze legionary cap over y=-44
			p.polygon = PackedVector2Array([
				Vector2(-8, -44), Vector2(8, -44),
				Vector2(7, -50),  Vector2(-7, -50),
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
			# Inset cuirass over y=-14..-32
			p.polygon = PackedVector2Array([
				Vector2(-9, -14), Vector2(9, -14),
				Vector2(7, -32),  Vector2(-7, -32),
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

func _build_legs(class_id: StringName, item: ItemData) -> Polygon2D:
	var p := Polygon2D.new()
	p.name = "EquipLegs"
	p.color = tier_color(tier_for(item))
	match class_id:
		&"myrmidon":
			# Greaves over y=-2..-12
			p.polygon = PackedVector2Array([
				Vector2(-6, -2), Vector2(6, -2),
				Vector2(5, -12), Vector2(-5, -12),
			])
		&"pythia":
			# Robe trim hem y=-2..-10
			p.polygon = PackedVector2Array([
				Vector2(-10, -2), Vector2(10, -2),
				Vector2(9, -10),  Vector2(-9, -10),
			])
		&"shade_hunter":
			# Wraps over the dark legs y=-2..-12
			p.polygon = PackedVector2Array([
				Vector2(-5, -2), Vector2(5, -2),
				Vector2(4, -12), Vector2(-4, -12),
			])
		&"ossuary_priest":
			# Bone hem on the dark robe y=-2..-10
			p.polygon = PackedVector2Array([
				Vector2(-11, -2), Vector2(11, -2),
				Vector2(9, -10),  Vector2(-9, -10),
			])
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
