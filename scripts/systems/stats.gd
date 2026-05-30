class_name Stats extends Resource
## AD-01 — single source of truth for all stat math. No script outside
## this file performs arithmetic on the four attributes. See
## .agent_governance/rules/stat-system.md.
##
## Layered model (rules/stat-system.md application order):
##   1. base_*      from class + per-level
##   2. alloc_*     player-spent points (Stage 5+)
##   3. buff_*      temporary buffs/debuffs (Stage 5+)
##   4. equipment   armor_defense / weapon_attack_rating / gear_resistance
##                  (Stage 4 populates these via inventory)
##
## `recompute()` is the ONE place attribute -> derived math happens.
## All public mutators call it exactly once at the tail of a batch.

signal recomputed                ## Owner Node forwards to EventBus.stats_changed.
                                ## Named to avoid shadowing Resource.changed.

const RESIST_CAP: int = 75

# Identity
@export var class_id: StringName
@export var level: int = 1

# Layer 1 — base (from ClassData + per-level)
@export var base_strength: int = 0
@export var base_dexterity: int = 0
@export var base_vitality: int = 0
@export var base_pneuma: int = 0

# Layer 2 — allocated (Stage 5+)
@export var alloc_strength: int = 0
@export var alloc_dexterity: int = 0
@export var alloc_vitality: int = 0
@export var alloc_pneuma: int = 0

# Layer 3 — temporary buffs (Stage 5+)
var buff_strength: int = 0
var buff_dexterity: int = 0
var buff_vitality: int = 0
var buff_pneuma: int = 0

# Equipment contributions (Stage 4 populates)
var armor_defense: int = 0
var weapon_attack_rating: int = 0
var gear_resistance: int = 0

# Cached derived (read by other systems; never recomputed per-frame)
var max_hp: int = 0
var max_mp: int = 0
var defense: int = 0
var attack_rating: int = 0
var resistance: int = 0

# Current pools
var current_hp: int = 0
var current_mp: int = 0

# Effective attributes — sum of all layers. Read-only externally.
var strength: int:
	get: return base_strength + alloc_strength + buff_strength
var dexterity: int:
	get: return base_dexterity + alloc_dexterity + buff_dexterity
var vitality: int:
	get: return base_vitality + alloc_vitality + buff_vitality
var pneuma: int:
	get: return base_pneuma + alloc_pneuma + buff_pneuma

# ---------------------------------------------------------------- construction

static func from_class_data(cd: ClassData, lvl: int = 1) -> Stats:
	assert(cd != null, "Stats.from_class_data: ClassData is null")
	assert(lvl >= 1, "Stats.from_class_data: level must be >= 1")
	var s := Stats.new()
	s.class_id = cd.id
	s.level = lvl
	var steps := lvl - 1
	s.base_strength  = cd.base_strength  + cd.str_per_level * steps
	s.base_dexterity = cd.base_dexterity + cd.dex_per_level * steps
	s.base_vitality  = cd.base_vitality  + cd.vit_per_level * steps
	s.base_pneuma    = cd.base_pneuma    + cd.pne_per_level * steps
	s.recompute()
	s.current_hp = s.max_hp
	s.current_mp = s.max_mp
	return s

# ---------------------------------------------------------------- recompute

## THE single place attribute -> derived math happens. Public mutators
## call this exactly once at the tail of a batch update so `changed`
## emits once per logical change.
func recompute() -> void:
	var cd: ClassData = Database.get_class_data(class_id) as ClassData
	if cd == null:
		push_error("Stats.recompute: missing ClassData for id=%s" % class_id)
		return

	# Derived
	max_hp = cd.base_hp + int(vitality * cd.vit_per_hp)
	max_mp = cd.base_mp + int(pneuma   * cd.pne_per_mp)
	defense = dexterity / 4 + armor_defense
	attack_rating = dexterity * 5 + weapon_attack_rating + level * 5
	resistance = clampi(gear_resistance, 0, RESIST_CAP)

	# Clamp current pools against new maxes (e.g., after level up)
	current_hp = clampi(current_hp, 0, max_hp)
	current_mp = clampi(current_mp, 0, max_mp)

	recomputed.emit()

# ---------------------------------------------------------------- mutators

func set_level(new_level: int) -> void:
	assert(new_level >= 1)
	level = new_level
	# Per-level base gains are folded in at construction via from_class_data;
	# on level-up we re-derive bases from class.
	var cd: ClassData = Database.get_class_data(class_id) as ClassData
	if cd != null:
		var steps := level - 1
		base_strength  = cd.base_strength  + cd.str_per_level * steps
		base_dexterity = cd.base_dexterity + cd.dex_per_level * steps
		base_vitality  = cd.base_vitality  + cd.vit_per_level * steps
		base_pneuma    = cd.base_pneuma    + cd.pne_per_level * steps
	recompute()

func set_equipment_contributions(armor_def: int, weapon_ar: int, resist: int) -> void:
	armor_defense = armor_def
	weapon_attack_rating = weapon_ar
	gear_resistance = resist
	recompute()

## Stage 1: passthrough. Stage 3's DamageResolver will compute final
## damage from Attack vs defender Stats before this is called.
func take_damage(amount: int, _attack: Attack) -> int:
	if amount <= 0:
		return 0
	var before := current_hp
	current_hp = clampi(current_hp - amount, 0, max_hp)
	recomputed.emit()
	return before - current_hp

func spend_mp(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mp < amount:
		return false
	current_mp = clampi(current_mp - amount, 0, max_mp)
	recomputed.emit()
	return true

func restore_hp(amount: int) -> void:
	if amount <= 0:
		return
	current_hp = clampi(current_hp + amount, 0, max_hp)
	recomputed.emit()

func restore_mp(amount: int) -> void:
	if amount <= 0:
		return
	current_mp = clampi(current_mp + amount, 0, max_mp)
	recomputed.emit()

func is_dead() -> bool:
	return current_hp <= 0
