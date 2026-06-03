class_name BogCaller extends WildernessEnemy
## Ranged caster. Tries to keep the player between attack_range and
## keep_distance: walks in if too far, kites if too close, otherwise
## stops and lobs a slow orb at the player. Two of these together
## are a real threat — solo they are easy to weave between projectiles.
##
## Projectile path: configure() the enemy_projectile scene, add it to
## the zone (the BogCaller's parent), aim at the player. Damage routes
## through the projectile's HitboxComponent into the player's Hurtbox
## via DamageResolver (AD-04 preserved).

const _PROJECTILE_SCENE := preload("res://scenes/vfx/enemy_projectile.tscn")

@export var projectile_damage: int = 10
@export var projectile_speed: float = 280.0
@export var projectile_range: float = 480.0
@export var projectile_color: Color = Color(0.55, 0.85, 0.55, 1)

func _ready() -> void:
	super._ready()
	if elite_damage_mult != 1.0:
		projectile_damage = int(round(float(projectile_damage) * elite_damage_mult))

func _perform_attack(dir: Vector2) -> void:
	# Defer the actual spawn to next idle so a Bog-Caller standing in
	# a tight cluster never schedules an Area2D add during a physics
	# flush from a sibling's attack. See failure-modes #17.
	_spawn_orb.call_deferred(dir)

func _spawn_orb(dir: Vector2) -> void:
	var parent := get_parent()
	if parent == null or not is_instance_valid(parent):
		return
	var orb: Projectile = _PROJECTILE_SCENE.instantiate() as Projectile
	if orb == null:
		return
	# Spawn just in front of the caster's chest so the orb doesn't
	# clip back into the caller's own hurtbox.
	var spawn_pos := global_position + Vector2(0, -18) + dir * 18.0
	orb.configure(dir, projectile_damage, self,
			projectile_speed, projectile_range, projectile_color)
	parent.add_child(orb)
	orb.global_position = spawn_pos
