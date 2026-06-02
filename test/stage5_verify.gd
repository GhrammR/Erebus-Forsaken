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

	# Clean up the Spear Lunge hitbox so it doesn't confuse later phase
	# checks that count Projectiles in `parent`.
	if hb_node != null:
		hb_node.queue_free()
	await get_tree().process_frame

	# Phase 3: OracleBolt spawns a Projectile with the right config.
	var cd_p: ClassData = Database.get_class_data(&"pythia") as ClassData
	caster.current_stats = Stats.from_class_data(cd_p, 1)
	var bolt := OracleBolt.new()
	add_child(bolt)
	var ok_bolt := bolt.try_activate(caster, Vector2(1, 0))
	await get_tree().process_frame
	var bolt_proj: Projectile = null
	for c in parent.get_children():
		if c is Projectile:
			bolt_proj = c as Projectile
			break
	var ok_proj_spawned: bool = bolt_proj != null
	var ok_proj_speed: bool = ok_proj_spawned and abs(bolt_proj.speed - OracleBolt.PROJECTILE_SPEED) < 0.5
	var ok_proj_dist: bool = ok_proj_spawned and abs(bolt_proj.max_distance - bolt.range_px) < 0.5
	print("[%s] OracleBolt activated=%s spawned=%s speed=%s dist=%s" % [
		"OK  " if (ok_bolt and ok_proj_spawned and ok_proj_speed and ok_proj_dist) else "FAIL",
		str(ok_bolt), str(ok_proj_spawned), str(ok_proj_speed), str(ok_proj_dist)])
	if not (ok_bolt and ok_proj_spawned and ok_proj_speed and ok_proj_dist): fail += 1
	if bolt_proj != null: bolt_proj.queue_free()
	await get_tree().process_frame

	# Phase 4: Volley spawns FAN_COUNT projectiles with angular spread.
	caster.current_stats = Stats.from_class_data(
		Database.get_class_data(&"shade_hunter") as ClassData, 1)
	var volley := Volley.new()
	add_child(volley)
	var ok_volley := volley.try_activate(caster, Vector2(1, 0))
	await get_tree().process_frame
	var arrow_count := 0
	var arrow_dirs: Array[Vector2] = []
	for c in parent.get_children():
		if c is Projectile:
			arrow_count += 1
			arrow_dirs.append((c as Projectile).direction)
	var ok_fan_count: bool = arrow_count == Volley.FAN_COUNT
	var ok_fan_unit: bool = true
	for d in arrow_dirs:
		if abs(d.length() - 1.0) > 0.01: ok_fan_unit = false
	var ok_fan_spread: bool = false
	if arrow_count >= 2:
		var angles: Array[float] = []
		for d in arrow_dirs:
			angles.append(d.angle())
		angles.sort()
		var spread: float = angles[angles.size() - 1] - angles[0]
		ok_fan_spread = abs(spread - 2.0 * Volley.FAN_SPREAD_RAD) < 0.01
	print("[%s] Volley activated=%s arrows=%d unit_dirs=%s spread=%s" % [
		"OK  " if (ok_volley and ok_fan_count and ok_fan_unit and ok_fan_spread) else "FAIL",
		str(ok_volley), arrow_count, str(ok_fan_unit), str(ok_fan_spread)])
	if not (ok_volley and ok_fan_count and ok_fan_unit and ok_fan_spread): fail += 1

	print("--- Stage 5 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)
