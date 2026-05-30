class_name DamageType extends RefCounted
## AD-05 — damage type enum reserved from day one. Act 1 has only
## PHYSICAL; Act 2 adds elemental types here additively. Changing this
## file does not require touching call sites because everything is
## indexed by the enum value.

enum Type {
	PHYSICAL,
}
