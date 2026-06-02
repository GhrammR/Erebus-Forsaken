class_name BoneServant extends Skill
## Ossuary Priest's skill — summons one minion. Stage 5 Phase 5 wires
## the persistent minion entity, basic AI, single-instance enforcement,
## and save exclusion (minions don't persist across saves per scope-lock
## and gap-log).

const MINION_HP: int = 60
const MINION_ATTACK_INTERVAL: float = 0.8
const MINION_ATTACK_DAMAGE: int = 8

func _configure() -> void:
	display_name = "Bone Servant"
	mp_cost = 20
	cooldown = 5.0
	base_damage = 0   ## the skill itself does no direct damage
	range_px = 200.0  ## spawn radius around caster

func _execute(_caster: Node, _facing_dir: Vector2) -> void:
	print("[skill] Bone Servant (phase 1 stub)")
