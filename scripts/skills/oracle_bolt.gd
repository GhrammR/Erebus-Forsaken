class_name OracleBolt extends Skill
## Pythia's skill. Stage 5 Phase 3 introduces the Projectile component
## and implements the bolt. Phase 1 only configures tunables.

const PROJECTILE_SPEED: float = 500.0

func _configure() -> void:
	display_name = "Oracle Bolt"
	mp_cost = 12
	cooldown = 0.9
	base_damage = 18
	range_px = 600.0

func _execute(_caster: Node, _facing_dir: Vector2) -> void:
	print("[skill] Oracle Bolt (phase 1 stub)")
