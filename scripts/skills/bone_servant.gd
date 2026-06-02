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

func _configure() -> void:
	display_name = "Bone Servant"
	mp_cost = 20
	cooldown = 5.0
	base_damage = 0      ## skill itself does no direct damage
	range_px = 200.0     ## spawn radius around caster

func _execute(caster: Node, facing_dir: Vector2) -> void:
	if not caster is Node2D:
		return
	# Single-instance enforcement: free any existing minion first.
	for existing in caster.get_tree().get_nodes_in_group(MINION_GROUP):
		if is_instance_valid(existing):
			existing.queue_free()

	var dir := facing_dir if facing_dir != Vector2.ZERO else Vector2.RIGHT
	dir = dir.normalized()
	var minion := _MINION_SCENE.instantiate() as BoneServantMinion
	if minion == null:
		push_error("BoneServant: minion scene failed to instantiate")
		return
	minion.owner_caster = caster
	caster.get_parent().add_child(minion)
	(minion as Node2D).global_position = (caster as Node2D).global_position + dir * SPAWN_OFFSET

	if caster.has_method("play_sprite_anim"):
		caster.call("play_sprite_anim", &"cast")
