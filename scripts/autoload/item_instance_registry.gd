extends Node
## Stage 8 — per-drop affix-tier instance registry. Strategic Review
## D3.A: a drop has a 25% chance to roll one fixed prefix. The rolled
## item is registered here keyed by a synthetic instance_id (e.g.
## "shade_blade#a7c"); Database.get_item(instance_id) returns a
## synthesized ItemData clone with the prefix merged into affixes,
## a blue glyph_color, and the prefix word prepended to display_name.
##
## Why an instance registry instead of mutating ItemData arrays into
## Dictionaries everywhere: backpack + equipped + save schema all
## carry StringName item ids today. Treating the prefix as a parallel
## lookup keeps the rest of the codebase untouched — the synthesized
## clone *is* an ItemData, so Inventory._recompute_totals, the
## VendorPanel, and the tooltip all keep working unchanged.
##
## Scope-lock: this only ever rolls a SINGLE prefix from PrefixTable.
## No suffixes, no variable rolls, no ranges. The "gold" rarity tier
## (2+ prefixes) is wired in the color logic but no drop produces it
## — that's Stage 9 unique-item territory, not Stage 8.

const PREFIX_TABLE_PATH: String = "res://data/affixes/prefix_table.tres"
const PREFIX_ROLL_CHANCE: float = 0.25

## Rare-tier (1 prefix) color. Matches the AD-11 palette family used
## by the wilderness wretch glow so it reads as "elevated loot" at a
## glance without needing the tooltip open.
const RARE_TINT: Color = Color(0.45, 0.65, 1.0, 1.0)
const COMMON_TINT_FALLBACK: Color = Color(0.85, 0.78, 0.55, 1.0)

var _table: PrefixTable = null

## instance_id (StringName) -> { "base_item_id": StringName,
##                               "prefix_key": StringName,
##                               "prefix_value": int,
##                               "prefix_word": String }
var _instances: Dictionary = {}

var _next_serial: int = 1

func _ready() -> void:
	_table = load(PREFIX_TABLE_PATH) as PrefixTable
	if _table == null:
		push_warning("ItemInstanceRegistry: prefix table missing at %s" % PREFIX_TABLE_PATH)

## Test/verifier seam: force the next roll outcome. Pass -1 to clear.
## When >= 0 and < table size, maybe_roll_prefix uses this index
## directly instead of randf/randi. Production code never sets this.
var _forced_index: int = -1

func force_next_index(idx: int) -> void:
	_forced_index = idx

## Returns either base_id (no prefix rolled) or a freshly-minted
## instance_id (prefix rolled and registered). Either StringName
## is a valid Database.get_item key — call sites don't care which.
func maybe_roll_prefix(base_id: StringName) -> StringName:
	if base_id == &"":
		return base_id
	if _table == null or _table.size() == 0:
		return base_id
	var prefix: Dictionary
	if _forced_index >= 0 and _forced_index < _table.size():
		prefix = _table.entries[_forced_index] as Dictionary
		_forced_index = -1
	else:
		if randf() >= PREFIX_ROLL_CHANCE:
			return base_id
		prefix = _table.roll()
	if prefix.is_empty():
		return base_id
	var instance_id := _mint_instance_id(base_id)
	_instances[instance_id] = {
		"base_item_id": base_id,
		"prefix_key": StringName(prefix.get("stat", &"")),
		"prefix_value": int(prefix.get("value", 0)),
		"prefix_word": String(prefix.get("word", "")),
	}
	AudioBank.play_sfx(&"drop_rare")
	return instance_id

func is_instance(id: StringName) -> bool:
	return _instances.has(id)

## Synthesizes a one-off ItemData clone for the registered instance.
## Caller is Database.get_item; everything downstream treats the
## return value as a normal ItemData (it IS an ItemData; the affix
## dict and display_name are just mutated on the clone).
func synthesize(instance_id: StringName) -> ItemData:
	var rec: Dictionary = _instances.get(instance_id, {})
	if rec.is_empty():
		return null
	var base_id := StringName(rec.get("base_item_id", &""))
	var base: ItemData = Database.items.get(base_id, null) as ItemData
	if base == null:
		return null
	var clone: ItemData = base.duplicate(true) as ItemData
	# Carry the synthetic id so save/load round-trips through the
	# inventory snapshot identify this as the instance, not the base.
	clone.id = instance_id
	var word := String(rec.get("prefix_word", ""))
	if word != "":
		clone.display_name = "%s %s" % [word, base.display_name]
	var key := StringName(rec.get("prefix_key", &""))
	var value := int(rec.get("prefix_value", 0))
	if key != &"" and value != 0:
		var merged: Dictionary = (clone.affixes as Dictionary).duplicate(true)
		merged[key] = int(merged.get(key, 0)) + value
		clone.affixes = merged
	clone.glyph_color = RARE_TINT
	return clone

func _mint_instance_id(base_id: StringName) -> StringName:
	var serial := _next_serial
	_next_serial += 1
	return StringName("%s#%d" % [String(base_id), serial])

# ---- save/load -----------------------------------------------------------

func snapshot() -> Dictionary:
	var out: Dictionary = { "next_serial": _next_serial, "instances": {} }
	for iid in _instances.keys():
		var rec: Dictionary = _instances[iid]
		out["instances"][String(iid)] = {
			"base_item_id": String(rec.get("base_item_id", "")),
			"prefix_key": String(rec.get("prefix_key", "")),
			"prefix_value": int(rec.get("prefix_value", 0)),
			"prefix_word": String(rec.get("prefix_word", "")),
		}
	return out

func restore(data: Dictionary) -> void:
	_instances.clear()
	_next_serial = int(data.get("next_serial", 1))
	var raw: Dictionary = data.get("instances", {})
	for iid_s in raw.keys():
		var rec: Dictionary = raw[iid_s]
		_instances[StringName(iid_s)] = {
			"base_item_id": StringName(rec.get("base_item_id", "")),
			"prefix_key": StringName(rec.get("prefix_key", "")),
			"prefix_value": int(rec.get("prefix_value", 0)),
			"prefix_word": String(rec.get("prefix_word", "")),
		}

func clear_instances() -> void:
	_instances.clear()
	_next_serial = 1
	_forced_index = -1

# ---- verifier introspection ---------------------------------------------

func instance_count() -> int:
	return _instances.size()

func get_record(instance_id: StringName) -> Dictionary:
	return _instances.get(instance_id, {})
