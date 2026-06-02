class_name Volley extends Skill
## Shade-Hunter's skill — three arrows in a fan. Stage 5 Phase 4
## implements; Phase 1 configures tunables.

const PROJECTILE_SPEED: float = 600.0
const FAN_COUNT: int = 3
const FAN_SPREAD_RAD: float = 0.26  ## ~15° between arrows

func _configure() -> void:
	display_name = "Volley"
	mp_cost = 14
	cooldown = 1.5
	base_damage = 8   ## per arrow; total = 8 × 3 = 24
	range_px = 500.0

func _execute(_caster: Node, _facing_dir: Vector2) -> void:
	print("[skill] Volley (phase 1 stub)")
