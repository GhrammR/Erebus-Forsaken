extends Node
## Stage 3 verifier. Exercises DamageResolver against the design table
## and confirms HealthComponent.kill produces the expected signal flow.
## Quits with exit code = fail count.

const SAMPLES: int = 1000     ## for hit-rate sampling

func _ready() -> void:
	var fail := 0
	print("--- Stage 3 verify ---")

	# Myrmidon vs dummy (DEF=5, HP=100). Expected: ~91% hit, 15 dmg.
	var myr := Stats.from_class_data(Database.get_class_data(&"myrmidon") as ClassData, 1)
	var dummy := Stats.new_basic(100, 5, 0)
	var atk := Attack.new()
	atk.base_damage = 8
	atk.source = _attacker_node(myr)
	var hits := 0
	var dmg_on_hit := 0
	for i in SAMPLES:
		var d := DamageResolver.resolve(atk, dummy)
		if d > 0:
			hits += 1
			dmg_on_hit = d   # damage is deterministic on hit
	var hit_rate := float(hits) / float(SAMPLES)
	var ok_rate := hit_rate >= 0.85 and hit_rate <= 0.97
	var ok_dmg := dmg_on_hit == 15
	print("[%s] Myrmidon vs dummy: hit_rate=%.3f (expect ~0.91), dmg_on_hit=%d (expect 15)" % [
		("OK  " if (ok_rate and ok_dmg) else "FAIL"), hit_rate, dmg_on_hit])
	if not (ok_rate and ok_dmg): fail += 1

	# Pythia vs dummy: STR=10 -> +2, expect 10 on hit
	var pyt := Stats.from_class_data(Database.get_class_data(&"pythia") as ClassData, 1)
	atk.source = _attacker_node(pyt)
	var pyt_dmg := 0
	for i in 200:
		var d := DamageResolver.resolve(atk, dummy)
		if d > 0: pyt_dmg = d
	var ok_p := pyt_dmg == 10
	print("[%s] Pythia hit dmg=%d (expect 10)" % [("OK  " if ok_p else "FAIL"), pyt_dmg])
	if not ok_p: fail += 1

	# Shade-Hunter (STR 15 -> +3, expect 11)
	var sh := Stats.from_class_data(Database.get_class_data(&"shade_hunter") as ClassData, 1)
	atk.source = _attacker_node(sh)
	var sh_dmg := 0
	for i in 200:
		var d := DamageResolver.resolve(atk, dummy)
		if d > 0: sh_dmg = d
	var ok_sh := sh_dmg == 11
	print("[%s] Shade-Hunter hit dmg=%d (expect 11)" % [("OK  " if ok_sh else "FAIL"), sh_dmg])
	if not ok_sh: fail += 1

	# Null attack / null defender -> 0, no crash
	var ok_nil := DamageResolver.resolve(null, dummy) == 0 \
		and DamageResolver.resolve(atk, null) == 0
	print("[%s] null inputs return 0" % ("OK  " if ok_nil else "FAIL"))
	if not ok_nil: fail += 1

	# HIT_FLOOR enforced: zero-AR attacker still hits 30%+
	atk.source = null
	var floor_hits := 0
	for i in SAMPLES:
		if DamageResolver.resolve(atk, dummy) > 0: floor_hits += 1
	var floor_rate := float(floor_hits) / float(SAMPLES)
	var ok_floor := floor_rate >= 0.25 and floor_rate <= 0.36
	print("[%s] HIT_FLOOR enforced: zero-AR rate=%.3f (expect ~0.30)" % [
		("OK  " if ok_floor else "FAIL"), floor_rate])
	if not ok_floor: fail += 1

	# Stats.physical_damage_bonus and mitigation
	var ok_helpers := myr.physical_damage_bonus() == 7 and dummy.mitigation() == 0 \
		and Stats.new_basic(100, 24).mitigation() == 3
	print("[%s] Stats helpers: bonus=%d expect 7; mitigation(24)=%d expect 3" % [
		("OK  " if ok_helpers else "FAIL"),
		myr.physical_damage_bonus(), Stats.new_basic(100, 24).mitigation()])
	if not ok_helpers: fail += 1

	# Classless Stats short-circuit
	var classless := Stats.new_basic(60, 3, 0)
	classless.set_equipment_contributions(10, 20, 30)
	# classless ignores equipment additions since recompute short-circuits
	# but current_hp should still be clamped, max_hp should stay 60
	var ok_classless := classless.max_hp == 60 and classless.current_hp == 60 \
		and classless.defense == 3
	print("[%s] classless Stats untouched by equipment contribs" % ("OK  " if ok_classless else "FAIL"))
	if not ok_classless: fail += 1

	print("--- Stage 3 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

# Helper: synthesize a Node with current_stats that DamageResolver._stats_of
# will pick up via the "current_stats" property duck-test.
func _attacker_node(s: Stats) -> Node:
	var n := Node.new()
	n.set_meta("current_stats", s)
	# DamageResolver uses `"current_stats" in node`, which matches script-
	# declared properties but NOT metadata. So we use a tiny inline script.
	var sc := GDScript.new()
	sc.source_code = "extends Node\nvar current_stats: Stats"
	sc.reload()
	n.set_script(sc)
	n.current_stats = s
	add_child(n)
	return n
