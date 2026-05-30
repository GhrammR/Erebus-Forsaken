extends Node
## Stage 1 headless verifier. Confirms Stats math matches the design
## table and the class-balance invariants. Quits with exit code 0 on
## full pass, nonzero otherwise.
##
## Launch via: godot --headless --path . -- --verify

const EXPECTED := {
	&"myrmidon":       {"hp": 150, "mp": 25,  "def": 5, "ar": 105},
	&"pythia":         {"hp": 60,  "mp": 115, "def": 5, "ar": 105},
	&"shade_hunter":   {"hp": 100, "mp": 45,  "def": 7, "ar": 155},
	&"ossuary_priest": {"hp": 80,  "mp": 82,  "def": 3, "ar": 80},
}

func _ready() -> void:
	var fail := 0
	print("--- Stage 1 verify ---")

	# Per-class derived stats vs design table
	for id in EXPECTED:
		var cd := Database.get_class_data(id) as ClassData
		if cd == null:
			print("[FAIL] missing ClassData %s" % id); fail += 1; continue
		var s := Stats.from_class_data(cd, 1)
		var ex: Dictionary = EXPECTED[id]
		var ok: bool = s.max_hp == int(ex["hp"]) and s.max_mp == int(ex["mp"]) \
			and s.defense == int(ex["def"]) and s.attack_rating == int(ex["ar"])
		print("[%s] %-15s HP=%-4d MP=%-4d DEF=%-3d AR=%-4d  | expected HP=%d MP=%d DEF=%d AR=%d" % [
			"OK  " if ok else "FAIL", cd.display_name,
			s.max_hp, s.max_mp, s.defense, s.attack_rating,
			ex["hp"], ex["mp"], ex["def"], ex["ar"]])
		if not ok: fail += 1

	# class-balance invariants (HP and MP ordering at level 1)
	var m  := Stats.from_class_data(Database.get_class_data(&"myrmidon") as ClassData, 1)
	var p  := Stats.from_class_data(Database.get_class_data(&"pythia") as ClassData, 1)
	var sh := Stats.from_class_data(Database.get_class_data(&"shade_hunter") as ClassData, 1)
	var op := Stats.from_class_data(Database.get_class_data(&"ossuary_priest") as ClassData, 1)
	var hp_ok := m.max_hp > sh.max_hp and sh.max_hp >= op.max_hp and op.max_hp > p.max_hp
	var mp_ok := p.max_mp > op.max_mp and op.max_mp > sh.max_mp and sh.max_mp >= m.max_mp
	print("[%s] HP order Myr>SH>=OP>Pyt  (%d, %d, %d, %d)" % [
		"OK  " if hp_ok else "FAIL", m.max_hp, sh.max_hp, op.max_hp, p.max_hp])
	print("[%s] MP order Pyt>OP>SH>=Myr  (%d, %d, %d, %d)" % [
		"OK  " if mp_ok else "FAIL", p.max_mp, op.max_mp, sh.max_mp, m.max_mp])
	if not hp_ok: fail += 1
	if not mp_ok: fail += 1

	# Damage clamping
	var t := Stats.from_class_data(Database.get_class_data(&"myrmidon") as ClassData, 1)
	var atk := Attack.new()
	atk.base_damage = 30
	var taken := t.take_damage(30, atk)
	var dmg_ok := taken == 30 and t.current_hp == t.max_hp - 30
	print("[%s] take_damage(30)=%d, current_hp=%d (was %d)" % [
		"OK  " if dmg_ok else "FAIL", taken, t.current_hp, t.max_hp])
	if not dmg_ok: fail += 1
	t.take_damage(99999, atk)
	var overkill_ok := t.current_hp == 0
	print("[%s] overkill clamps to 0 (current_hp=%d)" % [
		"OK  " if overkill_ok else "FAIL", t.current_hp])
	if not overkill_ok: fail += 1

	# MP guard
	var t2 := Stats.from_class_data(Database.get_class_data(&"pythia") as ClassData, 1)
	var ok1 := t2.spend_mp(10)
	var ok2 := t2.spend_mp(99999)
	var mp_guard := ok1 and not ok2 and t2.current_mp == t2.max_mp - 10
	print("[%s] spend_mp guards underflow (ok1=%s ok2=%s current_mp=%d)" % [
		"OK  " if mp_guard else "FAIL", str(ok1), str(ok2), t2.current_mp])
	if not mp_guard: fail += 1

	# Level-up recompute
	var t3 := Stats.from_class_data(Database.get_class_data(&"myrmidon") as ClassData, 1)
	var hp1 := t3.max_hp
	t3.set_level(5)
	var hp5 := t3.max_hp
	var level_ok := hp5 > hp1 and t3.level == 5
	print("[%s] level 1->5 grows HP (%d -> %d)" % [
		"OK  " if level_ok else "FAIL", hp1, hp5])
	if not level_ok: fail += 1

	# Equipment contribution path (Stage 4 will populate; here we just
	# confirm the API exists and recompute responds)
	var t4 := Stats.from_class_data(Database.get_class_data(&"shade_hunter") as ClassData, 1)
	var ar_before := t4.attack_rating
	var def_before := t4.defense
	t4.set_equipment_contributions(20, 50, 30)
	var equip_ok := t4.attack_rating == ar_before + 50 \
		and t4.defense == def_before + 20 \
		and t4.resistance == 30
	print("[%s] equipment contributions apply (AR %d->%d, DEF %d->%d, RES=%d)" % [
		"OK  " if equip_ok else "FAIL",
		ar_before, t4.attack_rating, def_before, t4.defense, t4.resistance])
	if not equip_ok: fail += 1

	print("--- Stage 1 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)
