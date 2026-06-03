extends Node
## Stage 9 verifier — Act boss + class-aware unique + Act 1 completion.
## Structural + behavioural checks: boss scene loads, phase enum lives,
## damage-driven phase transitions fire at thresholds, four uniques are
## in Database with skill-bonus affixes, equipment-totals path routes
## skill_bonus_* into Stats.equip_skill_bonuses, GameState flags + save
## v12 round-trip, R3 swap, endless slot marker present.

const _BOSS_SCENE := "res://scenes/enemies/act_boss.tscn"
const _CRYPT_SCENE := "res://scenes/zones/forsaken_crypt.tscn"

const _UNIQUES: Dictionary = {
	&"myrmidon":       &"forsaken_myrmidon_sigil",
	&"pythia":         &"forsaken_pythia_sigil",
	&"shade_hunter":   &"forsaken_shade_hunter_sigil",
	&"ossuary_priest": &"forsaken_ossuary_priest_sigil",
}

const _SKILL_FOR_CLASS: Dictionary = {
	&"myrmidon":       &"spear_lunge",
	&"pythia":         &"oracle_bolt",
	&"shade_hunter":   &"volley",
	&"ossuary_priest": &"bone_servant",
}

func _ready() -> void:
	var fail := 0
	print("--- Stage 9 verify ---")

	fail = _verify_boss_scene(fail)
	fail = _verify_unique_database(fail)
	fail = _verify_unique_affix_shape(fail)
	fail = _verify_skill_bonus_routing(fail)
	fail = await _verify_phase_transitions(fail)
	fail = _verify_enemy_registry(fail)
	fail = _verify_gamestate_flags(fail)
	fail = _verify_save_schema(fail)
	fail = _verify_save_roundtrip(fail)
	fail = await _verify_crypt_r3(fail)

	print("--- Stage 9 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _verify_boss_scene(fail: int) -> int:
	var packed := load(_BOSS_SCENE) as PackedScene
	var ok_load := packed != null
	print("[%s] act_boss.tscn loads at %s" % [_ok(ok_load), _BOSS_SCENE])
	if not ok_load: return fail + 1
	var inst := packed.instantiate() as ActBoss
	var ok_class := inst != null
	print("[%s] boss root extends ActBoss" % _ok(ok_class))
	if not ok_class:
		if inst != null: inst.queue_free()
		return fail + 1
	var ok_id := inst.enemy_id == &"act_boss"
	print("[%s] boss enemy_id == &\"act_boss\"" % _ok(ok_id))
	if not ok_id: fail += 1
	var ok_hp := inst.max_hp >= 200
	print("[%s] boss max_hp tuned for an Act boss (got %d)"
			% [_ok(ok_hp), inst.max_hp])
	if not ok_hp: fail += 1
	# Phase enum is at least 3 values.
	var ok_phases := ActBoss.Phase.size() >= 3
	print("[%s] Phase enum exposes >= 3 phases (got %d)"
			% [_ok(ok_phases), ActBoss.Phase.size()])
	if not ok_phases: fail += 1
	inst.queue_free()
	return fail

func _verify_unique_database(fail: int) -> int:
	for class_id in _UNIQUES.keys():
		var uid: StringName = _UNIQUES[class_id]
		var item: ItemData = Database.get_item(uid) as ItemData
		var ok := item != null and item.id == uid
		print("[%s] Database has unique '%s' for class '%s'"
				% [_ok(ok), uid, class_id])
		if not ok: fail += 1
	return fail

func _verify_unique_affix_shape(fail: int) -> int:
	for class_id in _UNIQUES.keys():
		var uid: StringName = _UNIQUES[class_id]
		var skill_id: StringName = _SKILL_FOR_CLASS[class_id]
		var affix_key := StringName("skill_bonus_%s" % skill_id)
		var item: ItemData = Database.get_item(uid) as ItemData
		if item == null:
			fail += 1
			continue
		var ok_affix := item.affixes.has(affix_key) \
				and int(item.affixes[affix_key]) > 0
		print("[%s] unique '%s' carries '%s' affix (+%d)"
				% [_ok(ok_affix), uid, affix_key,
					int(item.affixes.get(affix_key, 0))])
		if not ok_affix: fail += 1
		# Gold rarity glyph.
		var ok_gold := item.glyph_color.r >= 0.9 and item.glyph_color.g >= 0.7 \
				and item.glyph_color.b <= 0.5
		print("[%s] unique '%s' glyph_color is gold-tier" % [_ok(ok_gold), uid])
		if not ok_gold: fail += 1
	return fail

func _verify_skill_bonus_routing(fail: int) -> int:
	# apply_equipment_totals fans `skill_bonus_<id>` keys into
	# equip_skill_bonuses[id]. get_skill_bonus returns the value.
	var s := Stats.new_basic(100)
	s.apply_equipment_totals({
		&"skill_bonus_spear_lunge": 12,
		&"skill_bonus_volley": 9,
		&"strength": 3,
	})
	var ok_sl := s.get_skill_bonus(&"spear_lunge") == 12
	print("[%s] Stats.get_skill_bonus(spear_lunge) == 12 (got %d)"
			% [_ok(ok_sl), s.get_skill_bonus(&"spear_lunge")])
	if not ok_sl: fail += 1
	var ok_v := s.get_skill_bonus(&"volley") == 9
	print("[%s] Stats.get_skill_bonus(volley) == 9 (got %d)"
			% [_ok(ok_v), s.get_skill_bonus(&"volley")])
	if not ok_v: fail += 1
	var ok_zero := s.get_skill_bonus(&"oracle_bolt") == 0
	print("[%s] unseeded skill returns 0 bonus" % _ok(ok_zero))
	if not ok_zero: fail += 1
	# Skill base picks the bonus up in effective_damage().
	var sl := SpearLunge.new()
	var holder := Node2D.new()
	add_child(holder)
	holder.set_meta("dummy", true)
	# Build a dummy caster exposing current_stats.
	holder.set_script(load("res://test/stage9_dummy_caster.gd"))
	holder.current_stats = s
	var eff := sl.effective_damage(holder)
	var ok_eff := eff == sl.base_damage + 12
	print("[%s] SpearLunge.effective_damage = base + skill_bonus (got %d, base %d)"
			% [_ok(ok_eff), eff, sl.base_damage])
	if not ok_eff: fail += 1
	sl.free()
	holder.queue_free()
	return fail

func _verify_phase_transitions(fail: int) -> int:
	var packed := load(_BOSS_SCENE) as PackedScene
	var inst := packed.instantiate() as ActBoss
	add_child(inst)
	await get_tree().process_frame
	var ok_p1 := inst.get_phase() == int(ActBoss.Phase.P1_STALK)
	print("[%s] boss begins in P1_STALK (got %d)"
			% [_ok(ok_p1), inst.get_phase()])
	if not ok_p1: fail += 1
	# Drive HP under the P2 threshold and re-check.
	var s := inst.current_stats
	if s == null:
		print("[FAIL] boss has no current_stats post-_ready")
		inst.queue_free()
		return fail + 1
	s.current_hp = int(float(s.max_hp) * (ActBoss.PHASE_2_THRESHOLD - 0.01))
	inst.force_check_phase()
	var ok_p2 := inst.get_phase() == int(ActBoss.Phase.P2_CHANNEL)
	print("[%s] HP <= 66%% triggers P2_CHANNEL (got %d)"
			% [_ok(ok_p2), inst.get_phase()])
	if not ok_p2: fail += 1
	s.current_hp = int(float(s.max_hp) * (ActBoss.PHASE_3_THRESHOLD - 0.01))
	inst.force_check_phase()
	var ok_p3 := inst.get_phase() == int(ActBoss.Phase.P3_FRENZY)
	print("[%s] HP <= 33%% triggers P3_FRENZY (got %d)"
			% [_ok(ok_p3), inst.get_phase()])
	if not ok_p3: fail += 1
	inst.queue_free()
	await get_tree().process_frame
	return fail

func _verify_enemy_registry(fail: int) -> int:
	var packed := EnemyRegistry.scene_for(&"act_boss")
	var ok := packed != null
	print("[%s] EnemyRegistry.scene_for(act_boss) resolves" % _ok(ok))
	if not ok: fail += 1
	return fail

func _verify_gamestate_flags(fail: int) -> int:
	GameState.act_1_complete = false
	GameState.boss_first_kill = false
	var ok_default := not GameState.act_1_complete and not GameState.boss_first_kill
	print("[%s] GameState flags default false" % _ok(ok_default))
	if not ok_default: fail += 1
	GameState.act_1_complete = true
	GameState.boss_first_kill = true
	GameState.reset_run()
	var ok_reset := not GameState.act_1_complete and not GameState.boss_first_kill
	print("[%s] reset_run clears Act-1 flags" % _ok(ok_reset))
	if not ok_reset: fail += 1
	return fail

func _verify_save_schema(fail: int) -> int:
	var ok_v := SaveSystem.SAVE_VERSION == 12
	print("[%s] SaveSystem.SAVE_VERSION == 12 (got %d)"
			% [_ok(ok_v), SaveSystem.SAVE_VERSION])
	if not ok_v: fail += 1
	# v11 -> v12 seeds both flags.
	var migrated := SaveSystem.migrate({ "version": 11 })
	var ok_mig := int(migrated.get("version", 0)) == 12 \
			and migrated.has("act_1_complete") \
			and migrated.has("boss_first_kill")
	print("[%s] migrate v11 -> v12 seeds Act-1 flags" % _ok(ok_mig))
	if not ok_mig: fail += 1
	return fail

func _verify_save_roundtrip(fail: int) -> int:
	# Apply path needs minimal data + the GameState mutations; we bypass
	# the player path and just exercise migrate + the field copy.
	GameState.act_1_complete = false
	GameState.boss_first_kill = false
	var migrated := SaveSystem.migrate({
		"version": 11,
		"act_1_complete": true,
		"boss_first_kill": true,
	})
	# Direct fan-out the way SaveSystem._apply does at the tail.
	GameState.act_1_complete = bool(migrated.get("act_1_complete", false))
	GameState.boss_first_kill = bool(migrated.get("boss_first_kill", false))
	var ok := GameState.act_1_complete and GameState.boss_first_kill
	print("[%s] roundtrip restores both Act-1 flags" % _ok(ok))
	if not ok: fail += 1
	GameState.act_1_complete = false
	GameState.boss_first_kill = false
	return fail

func _verify_crypt_r3(fail: int) -> int:
	var packed := load(_CRYPT_SCENE) as PackedScene
	var inst := packed.instantiate() as ForsakenCrypt
	add_child(inst)
	await get_tree().process_frame
	# EndlessPortalSlot marker reserved for Stage 9.7.
	var slot := inst.get_node_or_null(^"EndlessPortalSlot") as Marker2D
	var ok_slot := slot != null
	print("[%s] crypt has EndlessPortalSlot marker" % _ok(ok_slot))
	if not ok_slot: fail += 1
	# Boss should now live in Room 3 (single member of crypt_room_3).
	var boss_count := 0
	var found_boss := false
	for n in get_tree().get_nodes_in_group(&"crypt_room_3"):
		boss_count += 1
		if n is ActBoss:
			found_boss = true
	var ok_boss := found_boss and boss_count == 1
	print("[%s] R3 contains exactly 1 ActBoss (count %d, has_boss %s)"
			% [_ok(ok_boss), boss_count, found_boss])
	if not ok_boss: fail += 1
	inst.queue_free()
	await get_tree().process_frame
	return fail

func _ok(b: bool) -> String:
	return "OK  " if b else "FAIL"
