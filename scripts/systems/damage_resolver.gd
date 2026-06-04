class_name DamageResolver extends RefCounted
## AD-04 — THE single damage-math entry point. Every hit (basic attack,
## skill, DoT, environmental) calls resolve(). No script computes final
## damage inline.

const HIT_FLOOR: float = 0.30           ## min 30% chance to hit
const HIT_CEIL:  float = 0.95           ## max 95% chance to hit
const DEFENSE_HIT_WEIGHT: int = 2       ## defense's contribution to hit denominator
const MIN_DAMAGE: int = 1               ## any successful hit does >= 1

## Stage 9.5 — base crit chance/multiplier. Universal across attackers
## for Act 1 (no per-class crit ramp until skill trees land). Per-class
## crit scaling is parking_lot.md material.
const CRIT_CHANCE: float = 0.05
const CRIT_MULT: float = 2.0

## Returns a DamageResult { damage: int, is_crit: bool }.
## damage == 0 indicates a miss; is_crit is always false on a miss.
## See scripts/systems/damage_result.gd for the rationale on a
## Resource return.
static func resolve(attack: Attack, defender: Stats) -> DamageResult:
	if attack == null or defender == null:
		return DamageResult.miss()
	var attacker_stats := _stats_of(attack.source)
	var ar: int = attacker_stats.attack_rating if attacker_stats != null else 0
	var denom: int = maxi(1, ar + defender.defense * DEFENSE_HIT_WEIGHT)
	var hit_chance: float = clampf(float(ar) / float(denom), HIT_FLOOR, HIT_CEIL)
	if randf() > hit_chance:
		return DamageResult.miss()
	var base: int = attack.base_damage
	if attacker_stats != null:
		base += attacker_stats.physical_damage_bonus()
	var raw := maxi(MIN_DAMAGE, base - defender.mitigation())
	var crit := randf() < CRIT_CHANCE
	var final_damage: int = int(round(float(raw) * CRIT_MULT)) if crit else raw
	return DamageResult.make(final_damage, crit)

static func _stats_of(node: Node) -> Stats:
	if node == null:
		return null
	if "current_stats" in node:
		return node.current_stats as Stats
	return null
