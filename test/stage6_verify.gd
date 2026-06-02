extends Node
## Stage 6 verifier — currency, vendor stock, quest state machine,
## save round-trip of all new fields.
##
## Headless; no scene tree dependencies beyond the autoloads.

func _ready() -> void:
	var fail := 0
	print("--- Stage 6 verify ---")

	fail = _verify_wallet(fail)
	fail = _verify_merchant_stock(fail)
	fail = _verify_quest_state_machine(fail)
	fail = _verify_save_roundtrip(fail)

	print("--- Stage 6 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

# ---- Wallet --------------------------------------------------------------

func _verify_wallet(fail: int) -> int:
	var w := Wallet.new()
	add_child(w)
	var ok_start: bool = w.gold == 0
	print("[%s] Wallet starts at 0" % ("OK  " if ok_start else "FAIL"))
	if not ok_start: fail += 1

	w.add_gold(50)
	w.add_gold(25)
	var ok_add: bool = w.gold == 75
	print("[%s] add_gold accumulates (75)" % ("OK  " if ok_add else "FAIL"))
	if not ok_add: fail += 1

	var ok_spend_ok: bool = w.spend_gold(30) and w.gold == 45
	print("[%s] spend_gold success deducts (45)" % ("OK  " if ok_spend_ok else "FAIL"))
	if not ok_spend_ok: fail += 1

	var ok_spend_reject: bool = (not w.spend_gold(999)) and w.gold == 45
	print("[%s] spend_gold rejects insufficient and leaves balance" \
		% ("OK  " if ok_spend_reject else "FAIL"))
	if not ok_spend_reject: fail += 1

	var ok_set: bool = true
	w.set_gold(100)
	if w.gold != 100: ok_set = false
	w.set_gold(-5)
	if w.gold != 0: ok_set = false
	print("[%s] set_gold clamps non-negative" % ("OK  " if ok_set else "FAIL"))
	if not ok_set: fail += 1

	w.queue_free()
	return fail

# ---- MerchantStock -------------------------------------------------------

func _verify_merchant_stock(fail: int) -> int:
	var stock: MerchantStock = load("res://data/npc/kallias_stock.tres") as MerchantStock
	var ok_load: bool = stock != null
	print("[%s] Kallias stock resource loads" % ("OK  " if ok_load else "FAIL"))
	if not ok_load:
		return fail + 1

	var ok_has_amulet: bool = stock.has(&"silver_amulet")
	print("[%s] stock includes silver_amulet (needed by Eurynome quest)" \
		% ("OK  " if ok_has_amulet else "FAIL"))
	if not ok_has_amulet: fail += 1

	# Buy price falls back to ItemData.base_price when override is 0.
	var amulet: ItemData = Database.get_item(&"silver_amulet") as ItemData
	var ok_buy: bool = stock.buy_price(&"silver_amulet") == amulet.base_price
	print("[%s] buy_price uses ItemData.base_price when override is 0 (=%d)" \
		% ["OK  " if ok_buy else "FAIL", amulet.base_price])
	if not ok_buy: fail += 1

	# Sell-back is half by default (0.5 ratio).
	var expected_sell: int = max(int(round(amulet.base_price * 0.5)), 1)
	var ok_sell: bool = stock.sell_price(&"silver_amulet") == expected_sell
	print("[%s] sell_price = round(base * 0.5) = %d" \
		% ["OK  " if ok_sell else "FAIL", expected_sell])
	if not ok_sell: fail += 1

	# Items not in the stock list still have sell value via base_price.
	var ok_sell_unstocked: bool = stock.sell_price(&"bronze_plate") > 0
	print("[%s] sell_price works for items not in vendor's stock" \
		% ("OK  " if ok_sell_unstocked else "FAIL"))
	if not ok_sell_unstocked: fail += 1

	return fail

# ---- QuestSystem state machine -------------------------------------------

func _verify_quest_state_machine(fail: int) -> int:
	var qid := &"eurynome_relic"
	QuestSystem.reset()

	var q: QuestData = QuestSystem.get_quest(qid)
	var ok_def: bool = q != null and q.required_item_id == &"silver_amulet" \
		and q.reward_gold > 0
	print("[%s] eurynome_relic QuestData loads with required + reward" \
		% ("OK  " if ok_def else "FAIL"))
	if not ok_def: return fail + 1

	# Build a fake player-sized rig: Inventory + Wallet under a Node.
	var stats := Stats.from_class_data(Database.get_class_data(&"myrmidon"), 1)
	var inv := Inventory.new(); inv.stats = stats
	var wallet := Wallet.new()
	var holder := Node2D.new()
	add_child(holder); holder.add_child(inv); holder.add_child(wallet)
	inv.set_active_class(&"myrmidon")

	var ok_init: bool = QuestSystem.get_state(qid) == QuestSystem.State.NOT_OFFERED
	print("[%s] state starts NOT_OFFERED" % ("OK  " if ok_init else "FAIL"))
	if not ok_init: fail += 1

	QuestSystem.offer(qid)
	var ok_offered: bool = QuestSystem.get_state(qid) == QuestSystem.State.OFFERED
	print("[%s] offer() moves to OFFERED" % ("OK  " if ok_offered else "FAIL"))
	if not ok_offered: fail += 1

	QuestSystem.accept(qid)
	var ok_accepted: bool = QuestSystem.get_state(qid) == QuestSystem.State.ACCEPTED
	print("[%s] accept() moves to ACCEPTED" % ("OK  " if ok_accepted else "FAIL"))
	if not ok_accepted: fail += 1

	# Evaluating before the item is in the backpack stays ACCEPTED.
	QuestSystem.evaluate(qid, inv)
	var ok_still_accepted: bool = QuestSystem.get_state(qid) == QuestSystem.State.ACCEPTED
	print("[%s] evaluate() without item stays ACCEPTED" \
		% ("OK  " if ok_still_accepted else "FAIL"))
	if not ok_still_accepted: fail += 1

	# Add the required item — evaluate moves to COMPLETED.
	inv.add_item(&"silver_amulet")
	QuestSystem.evaluate(qid, inv)
	var ok_completed: bool = QuestSystem.get_state(qid) == QuestSystem.State.COMPLETED
	print("[%s] evaluate() with required item moves to COMPLETED" \
		% ("OK  " if ok_completed else "FAIL"))
	if not ok_completed: fail += 1

	# Removing the item before turn-in drops back to ACCEPTED.
	inv.remove_item(&"silver_amulet")
	QuestSystem.evaluate(qid, inv)
	var ok_reverted: bool = QuestSystem.get_state(qid) == QuestSystem.State.ACCEPTED
	print("[%s] removing required item reverts COMPLETED -> ACCEPTED" \
		% ("OK  " if ok_reverted else "FAIL"))
	if not ok_reverted: fail += 1

	# Re-add, complete, and turn in.
	inv.add_item(&"silver_amulet")
	QuestSystem.evaluate(qid, inv)
	var gold_before := wallet.gold
	var backpack_size_before := inv.backpack_size()
	var ok_turn: bool = QuestSystem.turn_in(qid, inv, wallet)
	var ok_state: bool = QuestSystem.get_state(qid) == QuestSystem.State.TURNED_IN
	var ok_reward_gold: bool = wallet.gold == gold_before + q.reward_gold
	# Net backpack: -1 amulet, +1 reward item = same size, but
	# different contents. Easier: check the reward item is present.
	var ok_reward_item: bool = inv.backpack.find(q.reward_item_id) != -1
	var ok_amulet_consumed: bool = inv.backpack.find(&"silver_amulet") == -1
	var ok_full_turn_in: bool = ok_turn and ok_state and ok_reward_gold \
		and ok_reward_item and ok_amulet_consumed
	print("[%s] turn_in: state=TURNED_IN, +%d gold, reward item added, amulet consumed" \
		% ["OK  " if ok_full_turn_in else "FAIL", q.reward_gold])
	if not ok_full_turn_in: fail += 1

	# Idempotency: turning in again should fail without changing state.
	var ok_idem: bool = (not QuestSystem.turn_in(qid, inv, wallet)) \
		and QuestSystem.get_state(qid) == QuestSystem.State.TURNED_IN
	print("[%s] second turn_in rejected and state stays TURNED_IN" \
		% ("OK  " if ok_idem else "FAIL"))
	if not ok_idem: fail += 1

	holder.queue_free()
	QuestSystem.reset()
	return fail

# ---- Save round-trip with all Stage 6 fields -----------------------------

func _verify_save_roundtrip(fail: int) -> int:
	# Build a fake player rig that SaveSystem can snapshot.
	var fp := preload("res://test/_save_test_player.gd").new()
	add_child(fp); fp.setup(&"myrmidon")
	GameState.player = fp
	GameState.current_zone_id = &"threshold_camp"

	fp.get_wallet().add_gold(42)
	fp.get_inventory().add_item(&"silver_amulet")
	QuestSystem.reset()
	QuestSystem.offer(&"eurynome_relic")
	QuestSystem.accept(&"eurynome_relic")

	var ok_save: bool = SaveSystem.save_game()
	print("[%s] save_game returns true with gold + quest + zone" \
		% ("OK  " if ok_save else "FAIL"))
	if not ok_save: fail += 1

	# Mutate everything.
	fp.get_wallet().set_gold(0)
	fp.get_inventory().backpack.clear()
	fp.get_inventory().equipped.clear()
	QuestSystem.reset()
	GameState.current_zone_id = &""

	var ok_load: bool = SaveSystem.load_game()
	var ok_gold: bool = fp.get_wallet().gold == 42
	var ok_item: bool = fp.get_inventory().backpack.find(&"silver_amulet") != -1
	var ok_quest: bool = QuestSystem.get_state(&"eurynome_relic") == QuestSystem.State.ACCEPTED
	var ok_zone: bool = GameState.current_zone_id == &"threshold_camp"
	var ok_full: bool = ok_load and ok_gold and ok_item and ok_quest and ok_zone
	print("[%s] round-trip: gold=%d, amulet=%s, quest=%s, zone=%s" % [
		"OK  " if ok_full else "FAIL",
		fp.get_wallet().gold,
		"yes" if ok_item else "no",
		"ACCEPTED" if ok_quest else "?",
		String(GameState.current_zone_id),
	])
	if not ok_full: fail += 1

	# Cleanup so the dev save isn't left over.
	SaveSystem.delete_save()
	QuestSystem.reset()
	fp.queue_free()
	return fail
