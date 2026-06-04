class_name DamageResult extends Resource
## Stage 9.5 — DamageResolver.resolve return type. Pre-9.5 it returned
## a bare int; crit math needs both the magnitude and the crit flag,
## and a Resource is the lowest-friction shape that future fields
## (damage_type breakdown, penetration applied, was_blocked when
## Act 2 lands BlockChance) can extend without re-touching every call
## site.
##
## AD-04 still holds: DamageResolver is the only producer.

@export var damage: int = 0
@export var is_crit: bool = false

static func make(value: int, crit: bool = false) -> DamageResult:
	var r := DamageResult.new()
	r.damage = value
	r.is_crit = crit
	return r

static func miss() -> DamageResult:
	return make(0, false)
