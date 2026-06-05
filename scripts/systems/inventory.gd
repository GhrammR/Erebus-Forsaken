class_name Inventory extends Node
## AD-10 — slot list backpack plus a fixed equipment-slot dictionary.
## Equip/unequip operations validate class_mask + level_req and roll
## up totals into Stats via apply_equipment_totals.

## Stage 8 bumped 24 -> 36 to absorb dungeon density (prefixed drops
## stack alongside base drops because each instance is its own
## StringName id). Backpack is a dynamic Array, so old 24-cap saves
## load cleanly with no migration step.
const BACKPACK_CAPACITY: int = 36

signal inventory_changed
signal equipment_changed(slot: int, item: ItemData)

## Owner sets these in _ready (Player.assign_class does it).
var stats: Stats = null
var class_id: StringName = &""

var backpack: Array[StringName] = []          # item ids (active class)
var equipped: Dictionary = {}                  # int slot -> StringName item_id (active class)

## Per-class loadouts. Keyed by class_id (StringName) -> Dictionary
## with shape { "backpack": Array[StringName], "equipped": Dictionary }.
## `backpack` and `equipped` above are the *active* class's live
## containers; on class swap we snapshot them back here and load the
## new class's pair. This is the source of item truth across class
## swaps — a Pythia staff never ends up on a Myrmidon.
var loadouts: Dictionary = {}

# ---- backpack -------------------------------------------------------------

func is_full() -> bool:
	return backpack.size() >= BACKPACK_CAPACITY

func add_item(item_id: StringName) -> bool:
	if is_full():
		DebugLog.write(&"items", "add_item(%s) -> FULL" % item_id)
		return false
	backpack.append(item_id)
	inventory_changed.emit()
	DebugLog.write(&"items", "add %s (backpack=%d/%d)" % [
			item_id, backpack.size(), BACKPACK_CAPACITY])
	return true

func remove_item(item_id: StringName) -> bool:
	var idx := backpack.find(item_id)
	if idx == -1:
		return false
	backpack.remove_at(idx)
	inventory_changed.emit()
	DebugLog.write(&"items", "remove %s (backpack=%d/%d)" % [
			item_id, backpack.size(), BACKPACK_CAPACITY])
	return true

func backpack_size() -> int:
	return backpack.size()

# ---- equipment ------------------------------------------------------------

func can_equip(item: ItemData) -> bool:
	if item == null:
		return false
	if item.kind != ItemData.Kind.EQUIPMENT:
		return false
	if item.level_req > 0 and stats != null and item.level_req > stats.level:
		return false
	if item.class_mask == EquipmentSlot.ClassMask.ALL:
		return true
	var bit := EquipmentSlot.class_id_to_bit(class_id)
	return (item.class_mask & bit) != 0

func equip(item_id: StringName) -> bool:
	var item: ItemData = Database.get_item(item_id) as ItemData
	if item == null:
		return false
	if not can_equip(item):
		return false
	if backpack.find(item_id) == -1:
		return false
	# If the slot is occupied, move the current item back to backpack.
	var slot := int(item.slot)
	var prev_id: StringName = equipped.get(slot, &"")
	if prev_id != &"":
		# Swap: take new out of backpack, put old in. Net inventory size unchanged.
		backpack.erase(item_id)
		backpack.append(prev_id)
	else:
		backpack.erase(item_id)
	equipped[slot] = item_id
	_recompute_totals()
	inventory_changed.emit()
	equipment_changed.emit(slot, item)
	DebugLog.write(&"items", "equip %s -> slot %d (replaced %s)" % [
			item_id, slot, prev_id if prev_id != &"" else "<empty>"])
	return true

func unequip(slot: int) -> bool:
	var item_id: StringName = equipped.get(slot, &"")
	if item_id == &"":
		return false
	if is_full():
		return false
	equipped.erase(slot)
	backpack.append(item_id)
	_recompute_totals()
	inventory_changed.emit()
	equipment_changed.emit(slot, null)
	DebugLog.write(&"items", "unequip slot %d -> %s" % [slot, item_id])
	return true

## Strips an equipped item without sending it back to the backpack
## — used by the corpse-run death penalty (Stage 7 Phase 5). The
## item is lost from the inventory entirely; the caller is
## responsible for handing it to whoever holds it next (the
## CorpseSystem). Returns the item id that was removed, or &"".
func discard_equipped(slot: int) -> StringName:
	var item_id: StringName = equipped.get(slot, &"")
	if item_id == &"":
		return &""
	equipped.erase(slot)
	_recompute_totals()
	inventory_changed.emit()
	equipment_changed.emit(slot, null)
	return item_id

## Returns a random currently-equipped slot, or -1 if nothing is
## equipped. Used by the death penalty to pick which slot drops
## into the corpse — uniform random per the Act 1 design call.
func pick_random_equipped_slot() -> int:
	if equipped.is_empty():
		return -1
	var keys: Array = equipped.keys()
	return int(keys[randi() % keys.size()])

func get_equipped_id(slot: int) -> StringName:
	return equipped.get(slot, &"")

func get_equipped_item(slot: int) -> ItemData:
	var id: StringName = get_equipped_id(slot)
	if id == &"":
		return null
	return Database.get_item(id) as ItemData

# ---- totals ---------------------------------------------------------------

func _recompute_totals() -> void:
	if stats == null:
		return
	var totals: Dictionary = {}
	for slot_id in equipped.keys():
		var item: ItemData = Database.get_item(equipped[slot_id]) as ItemData
		if item == null:
			continue
		_add(totals, &"armor_defense",        item.base_armor_defense)
		_add(totals, &"weapon_attack_rating", item.base_weapon_ar)
		_add(totals, &"weapon_damage",        item.base_weapon_damage)
		_add(totals, &"resistance",           item.base_resist)
		for key in item.affixes.keys():
			_add(totals, StringName(key), int(item.affixes[key]))
	stats.apply_equipment_totals(totals)

static func _add(d: Dictionary, key: StringName, value: int) -> void:
	if value == 0:
		return
	d[key] = int(d.get(key, 0)) + value

# ---- per-class loadouts ----------------------------------------------------

## Snapshot the active backpack + equipped pair into loadouts[class_id].
## Called before swapping the active class.
func _stash_active_loadout() -> void:
	if class_id == &"":
		return
	loadouts[class_id] = {
		"backpack": backpack.duplicate(),
		"equipped": equipped.duplicate(),
	}

## Load loadouts[new_class_id] into the active backpack + equipped, or
## clear them if this class has no saved loadout yet. Does NOT stash
## the current active set — caller must do that first if needed.
func _load_loadout(new_class_id: StringName) -> void:
	backpack.clear()
	equipped.clear()
	var saved: Dictionary = loadouts.get(new_class_id, {})
	var bp: Array = saved.get("backpack", [])
	for id in bp:
		backpack.append(id)
	var eq: Dictionary = saved.get("equipped", {})
	for k in eq.keys():
		equipped[int(k)] = eq[k]

## Atomic class-swap entry point. Stash the outgoing class's loadout,
## switch active class_id, load the incoming class's loadout (or empty
## if first time), recompute totals against the (now new) Stats, and
## re-emit signals so any bound UI rebuilds. Player.assign_class calls
## this after re-binding `stats`.
func set_active_class(new_class_id: StringName) -> void:
	if new_class_id == class_id and not loadouts.is_empty():
		# Same class as before — just recompute against (possibly new) Stats.
		_recompute_totals()
		inventory_changed.emit()
		return
	_stash_active_loadout()
	class_id = new_class_id
	_load_loadout(new_class_id)
	_recompute_totals()
	inventory_changed.emit()
	for slot_id in equipped.keys():
		var item: ItemData = Database.get_item(equipped[slot_id]) as ItemData
		equipment_changed.emit(int(slot_id), item)

# ---- serialization (used by SaveSystem) ------------------------------------

func snapshot() -> Dictionary:
	# Make sure the live containers are reflected in loadouts before we
	# serialize, so the active class's current state isn't lost.
	_stash_active_loadout()
	var out_loadouts: Dictionary = {}
	for cid in loadouts.keys():
		var entry: Dictionary = loadouts[cid]
		var eq_out: Dictionary = {}
		for slot_id in entry.get("equipped", {}).keys():
			eq_out[str(slot_id)] = String(entry["equipped"][slot_id])
		var bp_out: Array = []
		for id in entry.get("backpack", []):
			bp_out.append(String(id))
		out_loadouts[String(cid)] = { "backpack": bp_out, "equipped": eq_out }
	return {
		"active_class": String(class_id),
		"loadouts": out_loadouts,
	}

func restore(data: Dictionary) -> void:
	loadouts.clear()
	backpack.clear()
	equipped.clear()
	var raw: Dictionary = data.get("loadouts", {})
	for cid_s in raw.keys():
		var entry: Dictionary = raw[cid_s]
		var bp_in: Array[StringName] = []
		for s in entry.get("backpack", []):
			bp_in.append(StringName(s))
		var eq_in: Dictionary = {}
		var eq_raw: Dictionary = entry.get("equipped", {})
		for k in eq_raw.keys():
			eq_in[int(k)] = StringName(eq_raw[k])
		loadouts[StringName(cid_s)] = { "backpack": bp_in, "equipped": eq_in }
	# The caller (SaveSystem) already re-ran assign_class which will
	# have called set_active_class. We re-load against the restored
	# loadouts dict to pick up the freshly-deserialized contents.
	var active := StringName(data.get("active_class", class_id))
	class_id = active
	_load_loadout(active)
	_recompute_totals()
	inventory_changed.emit()
	for slot_id in equipped.keys():
		var item: ItemData = Database.get_item(equipped[slot_id]) as ItemData
		equipment_changed.emit(int(slot_id), item)
