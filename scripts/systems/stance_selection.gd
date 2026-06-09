class_name StanceSelection extends Object
## Dev stance adoption helper. Reads pose_tuner's selected stance file
## and falls back instead of crashing when the file is missing, malformed,
## or names a stance outside the active catalog.

const SELECTED_STANCES_FILE: String = "res://tmp/selected_stances.json"

static func selected_for_class(class_id: StringName, fallback: StringName,
		valid_ids: Array) -> StringName:
	return selected_for_key(String(class_id), fallback, valid_ids)

## Enemy prep: future enemy editors can write either a root key
## (`shade_wretch`) or a bucketed key (`enemies/shade_wretch`) without
## changing runtime consumers.
static func selected_for_enemy(enemy_id: StringName, fallback: StringName,
		valid_ids: Array) -> StringName:
	return selected_for_entity(&"enemies", enemy_id, fallback, valid_ids)

static func selected_for_npc(npc_id: StringName, fallback: StringName,
		valid_ids: Array) -> StringName:
	return selected_for_entity(&"npcs", npc_id, fallback, valid_ids)

static func selected_for_entity(bucket: StringName, entity_id: StringName,
		fallback: StringName, valid_ids: Array) -> StringName:
	var nested := _selected_from_bucket(String(bucket), String(entity_id), fallback, valid_ids)
	if nested != fallback:
		return nested
	return selected_for_key(String(entity_id), fallback, valid_ids)

static func selected_for_key(key: String, fallback: StringName,
		valid_ids: Array) -> StringName:
	var classes := _read_selection_file()
	if classes.is_empty():
		return fallback
	return _resolve_record(classes.get(key, {}), key, fallback, valid_ids)

static func _selected_from_bucket(bucket: String, key: String, fallback: StringName,
		valid_ids: Array) -> StringName:
	var root := _read_selection_file()
	var bucket_v: Variant = root.get(bucket, {})
	if typeof(bucket_v) != TYPE_DICTIONARY:
		return fallback
	return _resolve_record((bucket_v as Dictionary).get(key, {}),
		"%s/%s" % [bucket, key], fallback, valid_ids)

static func _read_selection_file() -> Dictionary:
	var f := FileAccess.open(SELECTED_STANCES_FILE, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		print("StanceSelection: bad selected_stances.json; using defaults")
		return {}
	return parsed

static func _resolve_record(rec_v: Variant, label: String, fallback: StringName,
		valid_ids: Array) -> StringName:
	if typeof(rec_v) != TYPE_DICTIONARY:
		return fallback
	var stance_id := StringName((rec_v as Dictionary).get("stance", ""))
	if stance_id == &"":
		return fallback
	if not valid_ids.has(stance_id):
		print("StanceSelection: %s selected unknown stance %s; using %s" % [
			label, stance_id, fallback])
		return fallback
	return stance_id
