class_name PrefixTable extends Resource
## Fixed-roll prefix tier (Strategic Review D3.A). Each entry is a
## deterministic word + stat key + integer value. No ranges, no
## variable rolls, no suffixes — those remain Act 2 scope and are
## forbidden by rules/scope-lock.md.

## Each entry: { "word": String, "stat": StringName, "value": int }
## "word" is the adjective prepended to the item display_name on a
## successful roll ("Mighty Shade Blade"). "stat" is the
## apply_equipment_totals key the value is added under.
@export var entries: Array[Dictionary] = []

func size() -> int:
	return entries.size()

func roll() -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[randi() % entries.size()] as Dictionary
