class_name Volley extends Skill
## Shade-Hunter's primary skill — a small fan of three arrows in
## facing_dir. Each arrow is an independent Projectile that despawns
## on first hit; total per-cast damage = base_damage * FAN_COUNT.

const _PROJECTILE_SCENE := preload("res://scenes/vfx/projectile.tscn")

const PROJECTILE_SPEED: float = 600.0
const FAN_COUNT: int = 3
const FAN_SPREAD_RAD: float = 0.26     ## ~15° between outer and centre arrow
const SPAWN_OFFSET: float = 22.0
const ARROW_COLOR: Color = Color(0.85, 0.95, 0.9, 1.0)

func _configure() -> void:
	display_name = "Volley"
	mp_cost = 14
	cooldown = 1.5
	base_damage = 8       ## per arrow; 3 arrows = 24 total
	range_px = 500.0

func _execute(caster: Node, facing_dir: Vector2) -> void:
	if not caster is Node2D:
		return
	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.RIGHT
	dir = dir.normalized()
	var caster_pos: Vector2 = (caster as Node2D).global_position
	var parent := caster.get_parent()

	# Fan geometry: arrow i goes from -FAN_SPREAD_RAD to +FAN_SPREAD_RAD
	# in equal steps around the centre. With FAN_COUNT=3 this puts one
	# arrow on the centre and one to either side.
	var step := 0.0
	if FAN_COUNT > 1:
		step = (2.0 * FAN_SPREAD_RAD) / float(FAN_COUNT - 1)

	for i in FAN_COUNT:
		var angle := -FAN_SPREAD_RAD + step * float(i)
		var arrow_dir := dir.rotated(angle)
		var proj := _PROJECTILE_SCENE.instantiate() as Projectile
		proj.configure(arrow_dir, base_damage, caster, PROJECTILE_SPEED, range_px, ARROW_COLOR)
		parent.add_child(proj)
		(proj as Node2D).global_position = caster_pos + arrow_dir * SPAWN_OFFSET

	if caster.has_method("play_sprite_anim"):
		caster.call("play_sprite_anim", &"attack")
