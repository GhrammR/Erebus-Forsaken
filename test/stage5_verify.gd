extends Node
## Stage 5 verifier — grows phase by phase.
## Phase 1: skill construction + class-balance bands.
## Phase 2: SpearLunge spawns a properly-configured HitboxComponent.
## Phase 3-5 will add projectile + volley + minion + save-exclusion checks.

func _ready() -> void:
	var fail := 0
	print("--- Stage 5 verify ---")

	# Phase 1: subclasses instantiate and configure
	var skills := {
		&"spear_lunge":  SpearLunge.new(),
		&"oracle_bolt":  OracleBolt.new(),
		&"volley":       Volley.new(),
		&"bone_servant": BoneServant.new(),
	}
	for id in skills:
		var s: Skill = skills[id]
		var ok_mp: bool = s.mp_cost >= 5 and s.mp_cost <= 25
		var ok_cd: bool = s.cooldown >= 0.5 and s.cooldown <= 6.0
		var ok_name: bool = s.display_name != "" and s.display_name != "Unnamed Skill"
		print("[%s] %-14s mp=%d cd=%.1fs dmg=%d  name=%s" % [
			"OK  " if (ok_mp and ok_cd and ok_name) else "FAIL",
			id, s.mp_cost, s.cooldown, s.base_damage, s.display_name])
		if not (ok_mp and ok_cd and ok_name): fail += 1
		s.free()

	# Phase 2: SpearLunge directional swing setup
	# Build a fake caster (Node2D with current_stats), call _execute,
	# confirm a HitboxComponent appears in the parent with the right
	# base_damage and rotation.
	var parent := Node2D.new()
	add_child(parent)
	var caster_script := GDScript.new()
	caster_script.source_code = "extends Node2D\nvar current_stats: Stats\nfunc play_sprite_anim(_n): pass"
	caster_script.reload()
	var caster := Node2D.new()
	caster.set_script(caster_script)
	parent.add_child(caster)
	caster.global_position = Vector2(100, 50)
	# Give caster Myrmidon stats so Stats.spend_mp succeeds.
	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	caster.current_stats = Stats.from_class_data(cd, 1)

	var lunge := SpearLunge.new()
	add_child(lunge)
	var dir := Vector2(0, 1)   # downward
	var ok_act := lunge.try_activate(caster, dir)
	# The hitbox is spawned as a sibling of caster (under `parent`).
	# Find it.
	var hb_node: HitboxComponent = null
	for c in parent.get_children():
		if c is HitboxComponent:
			hb_node = c as HitboxComponent
			break
	var ok_spawn: bool = hb_node != null
	var ok_dmg: bool = ok_spawn and hb_node.base_damage == lunge.base_damage
	var ok_pos: bool = ok_spawn and hb_node.global_position.distance_to(
		caster.global_position + dir * SpearLunge.HITBOX_FORWARD_OFFSET) < 0.5
	var ok_rot: bool = ok_spawn and abs(hb_node.rotation - dir.angle()) < 0.001
	var ok_owner: bool = ok_spawn and hb_node.owner_body == caster
	print("[%s] SpearLunge activated=%s spawned=%s dmg=%s pos=%s rot=%s owner=%s" % [
		"OK  " if (ok_act and ok_spawn and ok_dmg and ok_pos and ok_rot and ok_owner) else "FAIL",
		str(ok_act), str(ok_spawn), str(ok_dmg), str(ok_pos), str(ok_rot), str(ok_owner)])
	if not (ok_act and ok_spawn and ok_dmg and ok_pos and ok_rot and ok_owner):
		fail += 1

	# Cooldown enforced — second activation fails
	var ok_cd_block := not lunge.try_activate(caster, dir)
	print("[%s] cooldown blocks immediate re-cast" % ("OK  " if ok_cd_block else "FAIL"))
	if not ok_cd_block: fail += 1

	# MP cost was deducted
	var mp_before := cd.base_mp + int(cd.base_pneuma * cd.pne_per_mp)
	var ok_mp_spent: bool = caster.current_stats.current_mp == mp_before - lunge.mp_cost
	print("[%s] MP spent: %d -> %d (expected -%d)" % [
		"OK  " if ok_mp_spent else "FAIL",
		mp_before, caster.current_stats.current_mp, lunge.mp_cost])
	if not ok_mp_spent: fail += 1

	print("--- Stage 5 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)
