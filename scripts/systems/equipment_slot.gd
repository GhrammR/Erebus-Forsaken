class_name EquipmentSlot extends RefCounted
## Act 1 equipment slot taxonomy and class restriction bitmask.
## Slot count is locked at 7. Adding slots is parking-lot territory.

enum Slot {
	WEAPON,
	OFFHAND,
	HEAD,
	CHEST,
	LEGS,
	RING,
	AMULET,
}

enum ClassMask {
	NONE           = 0,
	MYRMIDON       = 1,
	PYTHIA         = 2,
	SHADE_HUNTER   = 4,
	OSSUARY_PRIEST = 8,
	ALL            = 15,
}

const SLOT_NAMES: Dictionary = {
	Slot.WEAPON:  "Weapon",
	Slot.OFFHAND: "Offhand",
	Slot.HEAD:    "Head",
	Slot.CHEST:   "Chest",
	Slot.LEGS:    "Legs",
	Slot.RING:    "Ring",
	Slot.AMULET:  "Amulet",
}

const ALL_SLOTS: Array[int] = [
	Slot.WEAPON, Slot.OFFHAND, Slot.HEAD,
	Slot.CHEST, Slot.LEGS, Slot.RING, Slot.AMULET,
]

static func slot_name(slot: int) -> String:
	return SLOT_NAMES.get(slot, "?")

static func class_id_to_bit(class_id: StringName) -> int:
	match class_id:
		&"myrmidon":       return ClassMask.MYRMIDON
		&"pythia":         return ClassMask.PYTHIA
		&"shade_hunter":   return ClassMask.SHADE_HUNTER
		&"ossuary_priest": return ClassMask.OSSUARY_PRIEST
	return ClassMask.NONE
