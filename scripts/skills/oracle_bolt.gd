class_name OracleBolt extends Skill
## Pythia's primary skill — a single arcane bolt in `facing_dir`.
## Spawns a Projectile that despawns on first hit or after `range_px`.
## Damage routes through Projectile.Hitbox -> HurtboxComponent ->
## HealthComponent.take_damage -> DamageResolver per AD-04.

const _PROJECTILE_SCENE := preload("res://scenes/vfx/projectile.tscn")

const PROJECTILE_SPEED: float = 500.0
const SPAWN_OFFSET: float = 24.0
const BOLT_COLOR: Color = Color(0.78, 0.55, 1.0, 1.0)  ## violet

func _configure() -> void:
	display_name = "Oracle Bolt"
	skill_id = &"oracle_bolt"
	mp_cost = 12
	cooldown = 0.9
	base_damage = 18
	range_px = 600.0

func _execute(caster: Node, facing_dir: Vector2) -> void:
	if not caster is Node2D:
		return
	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.RIGHT
	dir = dir.normalized()

	var proj := _PROJECTILE_SCENE.instantiate() as Projectile
	proj.configure(dir, effective_damage(caster), caster, PROJECTILE_SPEED, range_px, BOLT_COLOR)
	caster.get_parent().add_child(proj)
	(proj as Node2D).global_position = (caster as Node2D).global_position + dir * SPAWN_OFFSET

	if caster.has_method("play_sprite_anim"):
		caster.call("play_sprite_anim", &"cast")
