class_name ItemData extends Resource
## AD-06 — items are referenced by `id` (StringName) in saves and code.
## Stage 4 has no random rolls; affixes are fixed Dictionaries on the
## item resource. Random affix rolls land in Act 2.

## Stage 9.8 — `kind` discriminates equipment from consumables. Slot/affix/
## armor fields are ignored when kind == CONSUMABLE; consumable-only fields
## live in the "Consumable (Stage 9.8)" group.
enum Kind { EQUIPMENT = 0, CONSUMABLE = 1 }

## Stage 9.8 — describes what a consumable does when used. EQUIPMENT items
## ignore this. See ConsumableUse for the runtime dispatcher.
enum UseKind {
	NONE = 0,
	HEARTH_EMBER = 1,    ## 2s channel -> Threshold Camp OR EndlessRun.end_run(false)
	HEAL_OVER_TIME = 2,  ## flat HP restored linearly over `use_duration` seconds
	MANA_OVER_TIME = 3,  ## flat MP restored linearly over `use_duration` seconds
	INSTANT_BOTH_PCT = 4,  ## % of max HP + % of max MP, instant (Ichor)
}

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.EQUIPMENT
@export var slot: EquipmentSlot.Slot = EquipmentSlot.Slot.WEAPON
@export var class_mask: int = EquipmentSlot.ClassMask.ALL
@export var level_req: int = 1

@export_group("Consumable (Stage 9.8)")
## Shared-cooldown key. Same key = same cooldown timer.
##   &"potion_health"  &"potion_mana"  &"potion_ichor"  &"hearth_ember"
@export var cooldown_id: StringName = &""
## Cooldown duration in seconds.
@export var cooldown_seconds: float = 0.0
## How this consumable resolves. See UseKind comments.
@export var use_kind: UseKind = UseKind.NONE
## Channel time before the effect lands (0 = instant). Hearth Ember = 2.0.
@export var use_channel_seconds: float = 0.0
## For HEAL_OVER_TIME / MANA_OVER_TIME: total seconds the regen ticks for.
@export var use_duration: float = 0.0
## For HEAL_OVER_TIME / MANA_OVER_TIME: flat HP or MP restored total.
@export var use_flat_amount: int = 0
## For INSTANT_BOTH_PCT: percent of max HP restored (0.0 - 1.0).
@export var use_hp_pct: float = 0.0
## For INSTANT_BOTH_PCT: percent of max MP restored (0.0 - 1.0).
@export var use_mp_pct: float = 0.0

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
