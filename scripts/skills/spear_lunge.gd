class_name SpearLunge extends Skill
## Myrmidon's primary skill — directional melee swing in `facing_dir`.
## Spawns a transient hitbox (rectangle 80x35) in front of the caster,
## rotated along facing_dir, arms it for the swing window, then
## queue_frees. Damage routes through HealthComponent.take_damage ->
## DamageResolver per AD-04 — the spawned hitbox carries `base_damage`
## but the math itself stays in DamageResolver.

const _HITBOX_SCENE := preload("res://scenes/vfx/skill_hitbox.tscn")

const SWING_LEAD: float = 0.05    ## seconds before the hitbox arms
const SWING_WINDOW: float = 0.18  ## seconds the hitbox stays armed
const HITBOX_FORWARD_OFFSET: float = 40.0 ## center of hitbox vs caster

func _configure() -> void:
	display_name = "Spear Lunge"
	mp_cost = 8
	cooldown = 1.2
	base_damage = 22
	range_px = 80.0

func _execute(caster: Node, facing_dir: Vector2) -> void:
	if not caster is Node2D:
		return
	# If facing_dir is zero (no recent movement intent), default to right.
	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.RIGHT
	dir = dir.normalized()

	# Spawn hitbox in front of caster, rotated to align with facing.
	var hb_node := _HITBOX_SCENE.instantiate()
	var hb := hb_node as HitboxComponent
	hb.owner_body = caster
	hb.base_damage = base_damage
	# Add to caster's parent (the active zone) so it's not affected by
	# the caster's child transforms (SpriteAnchor flips, etc.).
	caster.get_parent().add_child(hb)
	var caster_pos: Vector2 = (caster as Node2D).global_position
	hb.global_position = caster_pos + dir * HITBOX_FORWARD_OFFSET
	hb.rotation = dir.angle()

	# Play the swing anim if the sprite supports it.
	if caster.has_method("play_sprite_anim"):
		caster.call("play_sprite_anim", &"attack")

	# Schedule arm / disarm / free.
	caster.get_tree().create_timer(SWING_LEAD).timeout.connect(hb.arm)
	caster.get_tree().create_timer(SWING_LEAD + SWING_WINDOW).timeout.connect(hb.disarm)
	caster.get_tree().create_timer(SWING_LEAD + SWING_WINDOW + 0.05) \
		.timeout.connect(hb.queue_free)
