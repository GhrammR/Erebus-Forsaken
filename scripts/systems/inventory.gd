class_name Inventory extends Node
## AD-10 — slot list backpack plus a fixed equipment-slot dictionary.
## Equip/unequip operations validate class_mask + level_req and roll
## up totals into Stats via apply_equipment_totals.

const BACKPACK_CAPACITY: int = 24

signal inventory_changed
signal equipment_changed(slot: int, item: ItemData)

## Owner sets these in _ready (Player.assign_class does it).
var stats: Stats = null
var class_id: StringName = &""

var backpack: Array[StringName] = []          # item ids
var equipped: Dictionary = {}                  # int slot -> StringName item_id

# ---- backpack -------------------------------------------------------------

func is_full() -> bool:
	return backpack.size() >= BACKPACK_CAPACITY

func add_item(item_id: StringName) -> bool:
	if is_full():
		return false
	backpack.append(item_id)
	inventory_changed.emit()
	return true

func remove_item(item_id: StringName) -> bool:
	var idx := backpack.find(item_id)
	if idx == -1:
		return false
	backpack.remove_at(idx)
	inventory_changed.emit()
	return true

func backpack_size() -> int:
	return backpack.size()

# ---- equipment ------------------------------------------------------------

func can_equip(item: ItemData) -> bool:
	if item == null:
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
	return true

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
		_add(totals, &"resistance",           item.base_resist)
		for key in item.affixes.keys():
			_add(totals, StringName(key), int(item.affixes[key]))
	stats.apply_equipment_totals(totals)

static func _add(d: Dictionary, key: StringName, value: int) -> void:
	if value == 0:
		return
	d[key] = int(d.get(key, 0)) + value

# ---- serialization (used by SaveSystem) ------------------------------------

func snapshot() -> Dictionary:
	var eq: Dictionary = {}
	for slot_id in equipped.keys():
		eq[str(slot_id)] = String(equipped[slot_id])
	var bp: Array = []
	for id in backpack:
		bp.append(String(id))
	return { "backpack": bp, "equipped": eq }

func restore(data: Dictionary) -> void:
	backpack.clear()
	equipped.clear()
	for s in data.get("backpack", []):
		backpack.append(StringName(s))
	var eq: Dictionary = data.get("equipped", {})
	for k in eq.keys():
		equipped[int(k)] = StringName(eq[k])
	_recompute_totals()
	inventory_changed.emit()
	for slot_id in equipped.keys():
		var item: ItemData = Database.get_item(equipped[slot_id]) as ItemData
		equipment_changed.emit(int(slot_id), item)
