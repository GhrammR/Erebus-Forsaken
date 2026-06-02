extends Node
## Versioned JSON save/load. AD-06: stores item ids (Strings), never
## res:// paths. AD-07: SAVE_VERSION bumps on every schema change with a
## migrate() step. The on-disk format is human-readable so a tester can
## hand-edit corruption cases (rules/failure-modes.md #7 leans on this).

const SAVE_VERSION: int = 3
const SAVE_PATH: String = "user://save_slot_1.dat"

signal save_completed(success: bool)
signal load_completed(success: bool)

func save_game() -> bool:
	var player := _player()
	if player == null:
		push_warning("SaveSystem.save_game: no player in GameState")
		save_completed.emit(false)
		return false
	var data := _snapshot(player)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem.save_game: could not open %s" % SAVE_PATH)
		save_completed.emit(false)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_completed.emit(true)
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		load_completed.emit(false)
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveSystem.load_game: could not open %s" % SAVE_PATH)
		load_completed.emit(false)
		return false
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("SaveSystem.load_game: malformed JSON")
		load_completed.emit(false)
		return false
	var data: Dictionary = parsed as Dictionary
	data = migrate(data)
	var player := _player()
	if player == null:
		push_warning("SaveSystem.load_game: no player in GameState")
		load_completed.emit(false)
		return false
	_apply(player, data)
	load_completed.emit(true)
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# ---- migration -----------------------------------------------------------

func migrate(old: Dictionary) -> Dictionary:
	var v: int = int(old.get("version", 0))
	if v >= SAVE_VERSION:
		return old
	if v < 2:
		old = _migrate_v1_to_v2(old)
	if v < 3:
		old = _migrate_v2_to_v3(old)
	return old

func _migrate_v1_to_v2(old: Dictionary) -> Dictionary:
	# v1 had no inventory or equipment. Seed empty containers.
	old["version"] = 2
	if not old.has("inventory"):
		old["inventory"] = { "backpack": [], "equipped": {} }
	return old

func _migrate_v2_to_v3(old: Dictionary) -> Dictionary:
	# v2 had a single inventory block shared across class swaps. v3
	# replaces it with per-class loadouts. The v2 block becomes the
	# loadout for whichever class the save was last on.
	old["version"] = 3
	var legacy: Dictionary = old.get("inventory", {})
	var active := String(old.get("class_id", ""))
	var new_inv: Dictionary = {
		"active_class": active,
		"loadouts": {},
	}
	if active != "":
		new_inv["loadouts"][active] = {
			"backpack": legacy.get("backpack", []),
			"equipped": legacy.get("equipped", {}),
		}
	old["inventory"] = new_inv
	return old

# ---- snapshot / apply ----------------------------------------------------

func _player() -> Node:
	return GameState.player

func _snapshot(player: Node) -> Dictionary:
	var stats: Stats = player.current_stats
	var cd: ClassData = player.class_data
	var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory
	var snap: Dictionary = {
		"version": SAVE_VERSION,
		"class_id": String(cd.id) if cd != null else "",
		"level": stats.level if stats != null else 1,
		"alloc": {
			"strength":  stats.alloc_strength if stats != null else 0,
			"dexterity": stats.alloc_dexterity if stats != null else 0,
			"vitality":  stats.alloc_vitality if stats != null else 0,
			"pneuma":    stats.alloc_pneuma if stats != null else 0,
		},
		"current_hp": stats.current_hp if stats != null else 0,
		"current_mp": stats.current_mp if stats != null else 0,
		"position": { "x": player.global_position.x, "y": player.global_position.y },
		"inventory": inv.snapshot() if inv != null else { "backpack": [], "equipped": {} },
	}
	return snap

func _apply(player: Node, data: Dictionary) -> void:
	var class_id := StringName(data.get("class_id", ""))
	var cd: ClassData = Database.get_class_data(class_id) as ClassData
	if cd != null:
		# Re-assign class so the sprite/Stats/HC rewire cleanly.
		player.assign_class(cd)
	var stats: Stats = player.current_stats
	if stats != null:
		stats.set_level(int(data.get("level", 1)))
		var alloc: Dictionary = data.get("alloc", {})
		stats.alloc_strength  = int(alloc.get("strength", 0))
		stats.alloc_dexterity = int(alloc.get("dexterity", 0))
		stats.alloc_vitality  = int(alloc.get("vitality", 0))
		stats.alloc_pneuma    = int(alloc.get("pneuma", 0))
		stats.recompute()
	var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory
	if inv != null:
		inv.restore(data.get("inventory", {}))
	# Stats restore needs to happen AFTER inventory restore so equip
	# bonuses are applied before we set current_hp / mp.
	if stats != null:
		stats.restore_pools(
			int(data.get("current_hp", stats.max_hp)),
			int(data.get("current_mp", stats.max_mp))
		)
	var pos: Dictionary = data.get("position", {})
	if pos.has("x") and pos.has("y"):
		player.global_position = Vector2(float(pos["x"]), float(pos["y"]))
