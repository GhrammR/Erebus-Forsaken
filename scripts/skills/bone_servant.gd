class_name BoneServant extends Skill
## Ossuary Priest's primary skill — summons one persistent minion.
##
## Scope-lock: ONE minion at a time in Act 1. Enforced via the
## `bone_servant_minions` group — every cast frees existing members
## before spawning a fresh one. No skill trees, no scaling minion count.
##
## Save exclusion: minions are not snapshotted by SaveSystem. The next
## cast after a load will replace any stale minion via the group sweep,
## but the post-load state has no live minion until the player re-casts.

const _MINION_SCENE := preload("res://scenes/enemies/bone_servant_minion.tscn")

const SPAWN_OFFSET: float = 60.0
const MINION_GROUP: StringName = &"bone_servant_minions"

## Tracks whether the minion was alive at the moment of a zone transit.
## Set on successful summon, cleared on real death (HC.died). On the
## next EventBus.zone_changed we resummon next to the player so the
## minion follows through portals.
var _minion_alive: bool = false
var _zone_signal_wired: bool = false
var _caster_ref: WeakRef = null

func _configure() -> void:
	display_name = "Bone Servant"
	skill_id = &"bone_servant"
	mp_cost = 20
	cooldown = 5.0
	base_damage = 0      ## skill itself does no direct damage
	range_px = 200.0     ## spawn radius around caster

func _ready() -> void:
	# Connect once; lives as long as the skill node does.
	if not _zone_signal_wired:
		EventBus.zone_changed.connect(_on_zone_changed)
		_zone_signal_wired = true

func _execute(caster: Node, facing_dir: Vector2) -> void:
	_caster_ref = weakref(caster)
	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.RIGHT
	_spawn_minion(caster, dir.normalized())

func _spawn_minion(caster: Node, dir: Vector2) -> void:
	if not caster is Node2D:
		return
	# Single-instance enforcement: free any existing minion first.
	for existing in caster.get_tree().get_nodes_in_group(MINION_GROUP):
		if is_instance_valid(existing):
			existing.queue_free()

	var minion := _MINION_SCENE.instantiate() as BoneServantMinion
	if minion == null:
		push_error("BoneServant: minion scene failed to instantiate")
		return
	minion.owner_caster = caster
	# Stage 9 — unique-item bonus rides into the minion's per-swing
	# damage rather than the skill itself (the cast deals 0).
	minion.bonus_damage = effective_damage(caster)
	caster.get_parent().add_child(minion)
	(minion as Node2D).global_position = (caster as Node2D).global_position + dir * SPAWN_OFFSET
	# Pipe the minion's damage events into the shared DamageNumberLayer
	# so hits dealt and taken are visible.
	for g in caster.get_tree().get_nodes_in_group(&"game_host"):
		if g.has_method("wire_combatant_vfx"):
			g.wire_combatant_vfx(minion)

	_minion_alive = true
	# A real death clears the resummon flag; a zone-transit free does
	# not, so the next zone_changed will re-spawn.
	minion.tree_exiting.connect(_on_minion_tree_exiting)
	if minion.has_node(^"HealthComponent"):
		(minion.get_node(^"HealthComponent") as HealthComponent) \
				.died.connect(_on_minion_died)

	if caster.has_method("play_sprite_anim"):
		caster.call("play_sprite_anim", &"cast")

func _on_minion_died(_killer: Node) -> void:
	_minion_alive = false

func _on_minion_tree_exiting() -> void:
	# Tree-exit alone doesn't tell us why; we rely on _on_minion_died
	# having already cleared the flag on real deaths. If the flag is
	# still set when this fires, the cause was zone teardown.
	pass

func _on_zone_changed(_zone_id: StringName) -> void:
	if not _minion_alive:
		return
	var caster: Node = _caster_ref.get_ref() if _caster_ref != null else null
	if caster == null or not is_instance_valid(caster):
		return
	# Wait one frame so the new zone is settled (Game.transit emits
	# this after add_child). Spawn next to the player facing wherever
	# they're facing.
	_resummon_next_frame.call_deferred(caster)

func _resummon_next_frame(caster: Node) -> void:
	if not is_instance_valid(caster) or caster.get_parent() == null:
		return
	var face: Vector2 = Vector2.RIGHT
	if "facing_dir" in caster:
		var f: Vector2 = caster.facing_dir
		if f != Vector2.ZERO:
			face = f.normalized()
	_spawn_minion(caster, face)
