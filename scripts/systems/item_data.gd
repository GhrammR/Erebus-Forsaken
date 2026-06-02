class_name ItemData extends Resource
## AD-06 — items are referenced by `id` (StringName) in saves and code.
## Stage 4 has no random rolls; affixes are fixed Dictionaries on the
## item resource. Random affix rolls land in Act 2.

@export var id: StringName
@export var display_name: String
@export var slot: EquipmentSlot.Slot = EquipmentSlot.Slot.WEAPON
@export var class_mask: int = EquipmentSlot.ClassMask.ALL
@export var level_req: int = 1

@export_group("Base slot contribution")
@export var base_armor_defense: int = 0
@export var base_weapon_ar: int = 0
@export var base_resist: int = 0

@export_group("Affixes (Stage 4 fixed)")
## StringName -> int. Supported keys (apply_equipment_totals reads these):
##   &"strength" &"dexterity" &"vitality" &"pneuma"
##   &"defense" &"attack_rating" &"resistance"
@export var affixes: Dictionary = {}

@export_group("Display (Stage 4 procedural)")
@export var glyph_color: Color = Color(0.85, 0.78, 0.55)
@export var glyph_shape: ItemGlyph.Shape = ItemGlyph.Shape.SQUARE

@export_group("Economy (Stage 6)")
## Base shop price in gold. Vendors buy at half this value, sell at
## this value (a flat 2x spread for now; market dynamics come later).
## A value of 0 means non-sellable and not stocked by vendors.
@export var base_price: int = 0
