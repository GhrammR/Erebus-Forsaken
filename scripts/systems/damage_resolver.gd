class_name DamageResolver extends RefCounted
## AD-04 — THE single damage-math entry point. Every hit (basic attack,
## skill, DoT, environmental) calls resolve(). No script computes final
## damage inline.

const HIT_FLOOR: float = 0.30           ## min 30% chance to hit
const HIT_CEIL:  float = 0.95           ## max 95% chance to hit
const DEFENSE_HIT_WEIGHT: int = 2       ## defense's contribution to hit denominator
const MIN_DAMAGE: int = 1               ## any successful hit does >= 1

## Returns final damage after hit-roll and mitigation.
## 0 indicates a miss.
static func resolve(attack: Attack, defender: Stats) -> int:
	if attack == null or defender == null:
		return 0
	var attacker_stats := _stats_of(attack.source)
	var ar: int = attacker_stats.attack_rating if attacker_stats != null else 0
	var denom: int = maxi(1, ar + defender.defense * DEFENSE_HIT_WEIGHT)
	var hit_chance: float = clampf(float(ar) / float(denom), HIT_FLOOR, HIT_CEIL)
	if randf() > hit_chance:
		return 0
	var base: int = attack.base_damage
	if attacker_stats != null:
		base += attacker_stats.physical_damage_bonus()
	return maxi(MIN_DAMAGE, base - defender.mitigation())

static func _stats_of(node: Node) -> Stats:
	if node == null:
		return null
	if "current_stats" in node:
		return node.current_stats as Stats
	return null
