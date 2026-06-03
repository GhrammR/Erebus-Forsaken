extends Node
## Corpse-run death penalty store. Stage 7 Phase 5.
##
## Each death drops a corpse holding all carried gold plus one
## random equipped slot. Multiple corpses may exist at once (max
## MAX_CORPSES), so a single brutal death streak doesn't
## permanently void the player's build. When that cap is exceeded
## the *oldest* corpse is forfeit — design pressure to clean up
## before stacking too many.
##
## Each corpse is a Dictionary:
##   { "id": int, "zone_id": String, "pos": {x,y},
##     "gold": int, "item_id": String, "slot": int }
##
## "id" is a monotonically increasing handle so a Corpse scene
## instance can identify which entry to remove on reclaim. Two
## corpses at the same coordinate are still distinguishable.

signal corpse_changed

const MAX_CORPSES: int = 3

var corpses: Array = []
var _next_id: int = 1
## Evicted-corpse spill queue. When a death pushes the oldest
## corpse off the FIFO, its gold + item don't vanish — they queue
## here as loot waiting to be dropped at the original corpse spot
## the next time the player enters that zone. "The corpse decayed,
## its things stayed." Drained on zone entry by Game.
##
## Entry shape: { "zone_id": String, "pos": {x,y},
##                "gold": int, "item_id": String }
var spills: Array = []

## Adds a new corpse. Any corpses pushed off by FIFO past
## MAX_CORPSES are converted into spill entries so their contents
## reappear as world loot at the original corpse position the
## next time that zone loads. Caller does not need to handle
## evicted contents — the spill queue + Game on transit do.
func add_corpse(zone_id: StringName, pos: Vector2,
		gold: int, item_id: StringName, slot: int) -> Dictionary:
	var entry: Dictionary = {
		"id": _next_id,
		"zone_id": String(zone_id),
		"pos": { "x": pos.x, "y": pos.y },
		"gold": int(gold),
		"item_id": String(item_id),
		"slot": int(slot),
	}
	_next_id += 1
	corpses.append(entry)
	while corpses.size() > MAX_CORPSES:
		var ev: Dictionary = corpses.pop_front()
		spills.append({
			"zone_id": String(ev.get("zone_id", "")),
			"pos": (ev.get("pos", {}) as Dictionary).duplicate(true),
			"gold": int(ev.get("gold", 0)),
			"item_id": String(ev.get("item_id", "")),
		})
	corpse_changed.emit()
	return entry

## Drain and return spill entries belonging to the given zone.
## Caller spawns the world loot, then the entries are gone — saved
## as regular WorldItem/GoldPickup state from that point on.
func consume_spills_in_zone(zone_id: StringName) -> Array:
	var out: Array = []
	var i := 0
	while i < spills.size():
		if StringName(spills[i].get("zone_id", "")) == zone_id:
			out.append(spills[i])
			spills.remove_at(i)
		else:
			i += 1
	return out

func remove_corpse(corpse_id: int) -> void:
	var i := 0
	while i < corpses.size():
		if int(corpses[i].get("id", -1)) == corpse_id:
			corpses.remove_at(i)
			corpse_changed.emit()
			return
		i += 1

func clear_all() -> void:
	corpses.clear()
	spills.clear()
	_next_id = 1
	corpse_changed.emit()

func has_any() -> bool:
	return not corpses.is_empty()

func corpses_in_zone(zone_id: StringName) -> Array:
	var out: Array = []
	for c in corpses:
		if StringName(c.get("zone_id", "")) == zone_id:
			out.append(c)
	return out

func snapshot() -> Dictionary:
	return {
		"corpses": corpses.duplicate(true),
		"next_id": _next_id,
		"spills": spills.duplicate(true),
	}

func restore(d: Dictionary) -> void:
	if d == null or d.is_empty():
		corpses = []
		spills = []
		_next_id = 1
	else:
		corpses = ((d.get("corpses", []) as Array)).duplicate(true)
		spills = ((d.get("spills", []) as Array)).duplicate(true)
		_next_id = int(d.get("next_id", corpses.size() + 1))
	corpse_changed.emit()
