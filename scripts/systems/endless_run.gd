extends Node
## Stage 9.7 — endless-mode run state. Transient: an endless run does
## not write to the save file. The save on disk at portal-entry IS the
## rollback anchor; when the run ends (player death or summary dismiss)
## we just reload that save, which restores HP/inventory/zone bytes-for-
## bytes to the pre-portal moment.
##
## AD-08 — endless lifecycle signals live on EventBus.endless_*.
## This autoload owns run-scoped state only.

signal stats_changed
## Per-emitter (not on the bus — AD-08). Fired by `claim_milestone`
## when a not-yet-earned floor's payout is granted. Game.gd listens
## to drop the inline reward modal.
signal milestone_reached(floor: int, reward: Dictionary)

## Tower of Ascension milestone payouts. Floor -> reward dict:
##   { "kind": String, "label": String, plus kind-specific keys }
## - "stat":  { "attribute": String, "amount": int }
## - "item":  { "item_id": StringName }
## - "title": { "title": String }
## Procedural art placeholders ship for the two item rewards (Stage
## 9.7 polish charter; rules/asset-pipeline.md allows shipping
## procedural-only items into Act 1 demo).
const MILESTONES: Dictionary = {
	10: {
		"kind": "stat", "attribute": "vitality", "amount": 1,
		"label": "Vitality +1 (permanent)",
	},
	25: {
		"kind": "item", "item_id": &"depth_touched_charm",
		"label": "Depth-Touched Charm (Amulet, +20 HP)",
	},
	50: {
		"kind": "title", "title": "Delver",
		"label": "Title: Delver",
	},
	100: {
		"kind": "item", "item_id": &"crown_of_the_forsaken",
		"label": "Crown of the Forsaken (Helm, +1 all attributes)",
	},
}

var active: bool = false
var wave: int = 0
var kills: int = 0
var kills_this_wave: int = 0
var kills_required: int = 0
var gold_at_start: int = 0
var start_time_ms: int = 0
var seed: int = 0
## Milestones the player already had before this run started. Anything
## in GameState.endless_milestones that's NOT in this list is "new
## this run" and must be reapplied AFTER rollback wipes the save's
## state (rollback loads pre-portal save which has the old milestone
## list). game.gd queries milestones_new_this_run() during the
## summary-return chain to re-commit the rewards.
var _milestones_at_start: Array = []
## How the most-recent run ended. game.gd's summary-return chain
## reads this to decide whether to call Player.respawn() (true ->
## input was suppressed by Player._on_died) or leave the alive
## player as-is (AscentSpire path).
var ended_via_death: bool = false

const _SEED_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## Take the seed from the caller (Portal interact path randomises
## `randi()` and feeds it here so the seed-share string maps 1:1 to
## the actual generation seed). begin() also captures gold-at-start
## and start time for the run-summary diff.
func begin(run_seed: int) -> void:
	active = true
	wave = 0
	kills = 0
	kills_this_wave = 0
	kills_required = 0
	seed = run_seed
	start_time_ms = Time.get_ticks_msec()
	_milestones_at_start = GameState.endless_milestones.duplicate()
	var p: Node = GameState.player
	var wallet: Object = null
	if p != null and is_instance_valid(p):
		wallet = p.get_node_or_null(^"Wallet")
	gold_at_start = int(wallet.gold) if wallet != null else 0
	stats_changed.emit()
	DebugLog.write(&"endless", "begin seed=%d (%s)" % [
			run_seed, encode_seed(run_seed)])

func record_kill(counts_toward_wave: bool) -> void:
	if not active:
		return
	kills += 1
	if counts_toward_wave:
		kills_this_wave += 1
	stats_changed.emit()

func advance_wave(new_wave: int, required: int) -> void:
	if not active:
		return
	wave = new_wave
	kills_this_wave = 0
	kills_required = required
	stats_changed.emit()
	DebugLog.write(&"endless", "floor %d started (quota %d)" % [new_wave, required])
	_maybe_claim_milestone(new_wave)

func _maybe_claim_milestone(floor: int) -> void:
	if not MILESTONES.has(floor):
		return
	if GameState.endless_milestones.has(floor):
		return  # already earned in a prior run
	GameState.endless_milestones.append(floor)
	var reward: Dictionary = MILESTONES[floor]
	_apply_reward(reward)
	milestone_reached.emit(floor, reward)
	DebugLog.write(&"endless", "milestone floor %d -> %s" % [
			floor, String(reward.get("label", ""))])

func _apply_reward(reward: Dictionary) -> void:
	# Reward application is best-effort: if the player isn't in the
	# tree (e.g. verifier path), the GameState updates still land,
	# only the inventory grant skips. The save snapshot picks up
	# any persistent state on the next write.
	var kind := String(reward.get("kind", ""))
	if kind == "stat":
		_apply_stat_reward(String(reward.get("attribute", "")),
				int(reward.get("amount", 0)))
	elif kind == "title":
		var t := String(reward.get("title", ""))
		if t != "" and not GameState.titles.has(t):
			GameState.titles.append(t)
	elif kind == "item":
		_apply_item_reward(StringName(reward.get("item_id", &"")))

func _apply_stat_reward(attribute: String, amount: int) -> void:
	if amount == 0:
		return
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return
	var stats: Stats = p.current_stats
	if stats == null:
		return
	# Apply through the existing alloc_* field so the save's `alloc`
	# block carries the bonus forward without a schema add.
	match attribute:
		"strength":  stats.alloc_strength += amount
		"dexterity": stats.alloc_dexterity += amount
		"vitality":  stats.alloc_vitality += amount
		"pneuma":    stats.alloc_pneuma += amount
		_:
			push_warning("EndlessRun: unknown stat attribute '%s'" % attribute)
			return
	stats.recompute()

func _apply_item_reward(item_id: StringName) -> void:
	if item_id == &"":
		return
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return
	var inv: Inventory = p.get_node_or_null(^"Inventory") as Inventory
	if inv == null:
		return
	inv.add_item(item_id)

func elapsed_ms() -> int:
	if start_time_ms == 0:
		return 0
	return Time.get_ticks_msec() - start_time_ms

func gold_gained() -> int:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return 0
	var wallet: Object = p.get_node_or_null(^"Wallet")
	if wallet == null:
		return 0
	return int(wallet.gold) - gold_at_start

## Summary payload for EventBus.endless_run_ended.
func snapshot_stats() -> Dictionary:
	return {
		"wave": wave,
		"kills": kills,
		"gold_gained": gold_gained(),
		"elapsed_ms": elapsed_ms(),
		"seed": seed,
		"seed_string": encode_seed(seed),
	}

func end_run(via_death: bool = false) -> Dictionary:
	ended_via_death = via_death
	var stats := snapshot_stats()
	EventBus.endless_run_ended.emit(stats)
	DebugLog.write(&"endless", "end_run via=%s wave=%d kills=%d gold+%d time=%dms" % [
			"death" if via_death else "ascend",
			int(stats.get("wave", 0)), int(stats.get("kills", 0)),
			int(stats.get("gold_gained", 0)), int(stats.get("elapsed_ms", 0))])
	return stats

## Floors newly claimed during the current/most-recent run. The
## summary-return chain in game.gd reads this AFTER rollback's
## save-load (which restores the pre-portal milestone list) and
## reapplies these rewards so milestones survive the wipe.
func milestones_new_this_run() -> Array:
	var out: Array = []
	for f in GameState.endless_milestones:
		if not _milestones_at_start.has(f):
			out.append(f)
	return out

## Reapply a list of milestone rewards (by floor number) after a
## rollback has reset the player to the pre-portal save. Used by
## game.gd in the summary-return chain. Each floor here MUST also be
## (re)appended to GameState.endless_milestones so the post-rollback
## save persists it.
func recommit_milestones(floors: Array) -> void:
	for f_v in floors:
		var f := int(f_v)
		if not MILESTONES.has(f):
			continue
		if not GameState.endless_milestones.has(f):
			GameState.endless_milestones.append(f)
		_apply_reward(MILESTONES[f] as Dictionary)

## Clear run state. The caller is responsible for reloading the
## pre-portal save and resuming the saved zone (the Game host owns
## the resume chain — _zone_cache + _resume_saved_zone — that this
## autoload can't reach). Keeping rollback() side-effect-free here
## makes the verifier path easier too.
func rollback() -> void:
	# NOTE: do not clear `_milestones_at_start` here — game.gd reads
	# it after rollback (via milestones_new_this_run / recommit_
	# milestones) to recover floors earned during the run that the
	# save-load just wiped from GameState. The start snapshot is
	# reset on the NEXT begin().
	active = false
	wave = 0
	kills = 0
	kills_this_wave = 0
	kills_required = 0
	seed = 0
	gold_at_start = 0
	start_time_ms = 0
	stats_changed.emit()

## Deterministic int → display string. 8 base-32 chars hyphenated as
## `EREBUS-XXXX-XXXX` so it reads like a code, not a memory address.
## Alphabet drops I/O/0/1 to keep hand-transcription unambiguous.
func encode_seed(s: int) -> String:
	var n := s
	if n < 0:
		n = -n
	var out := ""
	for i in 8:
		var idx: int = n & 0x1F  # 5 bits
		out += _SEED_ALPHABET.substr(idx, 1)
		n >>= 5
	return "EREBUS-%s-%s" % [out.substr(0, 4), out.substr(4, 4)]

func decode_seed(text: String) -> int:
	var stripped := text.replace("EREBUS-", "").replace("-", "")
	if stripped.length() < 8:
		return 0
	var out: int = 0
	for i in 8:
		var ch := stripped.substr(7 - i, 1)
		var idx: int = _SEED_ALPHABET.find(ch)
		if idx < 0:
			return 0
		out = (out << 5) | idx
	return out
