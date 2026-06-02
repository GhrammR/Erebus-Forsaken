class_name SpearLunge extends Skill
## Myrmidon's skill. Stage 5 Phase 2 implements the actual lunge —
## Phase 1 only configures the tunables so class-balance can validate
## bands.

func _configure() -> void:
	display_name = "Spear Lunge"
	mp_cost = 8
	cooldown = 1.2
	base_damage = 22
	range_px = 80.0

func _execute(_caster: Node, _facing_dir: Vector2) -> void:
	# Phase 1 placeholder — Phase 2 implements directional swing.
	print("[skill] Spear Lunge (phase 1 stub)")
