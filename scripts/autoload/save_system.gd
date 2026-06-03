extends Node
## Versioned JSON save/load. AD-06: stores item ids (Strings), never
## res:// paths. AD-07: SAVE_VERSION bumps on every schema change with a
## migrate() step. The on-disk format is human-readable so a tester can
## hand-edit corruption cases (rules/failure-modes.md #7 leans on this).

const SAVE_VERSION: int = 10
const SAVE_PATH: String = "user://save_slot_1.dat"

signal save_completed(success: bool)
signal load_completed(success: bool)

## Transient: filled by _apply on load, consumed once by Game after
## the zone rebuild. Holds {enemy_id, pos:{x,y}, hp} per snapshot
## entry. Never persisted at the field level.
var _pending_enemy_snapshot: Array = []
var _pending_loot_snapshot: Array = []

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
	if v < 4:
		old = _migrate_v3_to_v4(old)
	if v < 5:
		old = _migrate_v4_to_v5(old)
	if v < 6:
		old = _migrate_v5_to_v6(old)
	if v < 7:
		old = _migrate_v6_to_v7(old)
	if v < 8:
		old = _migrate_v7_to_v8(old)
	if v < 9:
		old = _migrate_v8_to_v9(old)
	if v < 10:
		old = _migrate_v9_to_v10(old)
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

func _migrate_v3_to_v4(old: Dictionary) -> Dictionary:
	# v3 had no Wallet. Seed zero gold.
	old["version"] = 4
	if not old.has("gold"):
		old["gold"] = 0
	return old

func _migrate_v4_to_v5(old: Dictionary) -> Dictionary:
	# v4 had no quest state. Seed empty.
	old["version"] = 5
	if not old.has("quests"):
		old["quests"] = {}
	return old

func _migrate_v5_to_v6(old: Dictionary) -> Dictionary:
	# v5 had no zone tracking. Default legacy saves to the
	# threshold camp — the only zone shipped in Act 1 so far.
	old["version"] = 6
	if not old.has("zone_id"):
		old["zone_id"] = "threshold_camp"
	return old

func _migrate_v6_to_v7(old: Dictionary) -> Dictionary:
	# v6 had no enemy persistence. Legacy saves get an empty list
	# so the zone's pre-placed enemies remain after rebuild — same
	# behaviour the player saw before Phase 2 introduced kills.
	old["version"] = 7
	if not old.has("enemies"):
		old["enemies"] = []
	return old

func _migrate_v7_to_v8(old: Dictionary) -> Dictionary:
	# v7 had no on-ground loot persistence. Legacy saves get an
	# empty list — old drops were already gone after reload anyway.
	old["version"] = 8
	if not old.has("loot"):
		old["loot"] = []
	return old

func _migrate_v8_to_v9(old: Dictionary) -> Dictionary:
	# v8 had no corpse-run state. Legacy saves get an empty corpse
	# — no penalty backfill, the player just hadn't died yet under
	# the new rules.
	old["version"] = 9
	if not old.has("corpse"):
		old["corpse"] = {}
	return old

func _migrate_v9_to_v10(old: Dictionary) -> Dictionary:
	# v9 stored a single active corpse. v10 stores a list (multi-
	# corpse design — see CorpseSystem). Convert any populated v9
	# corpse into a single-entry list with id=1; legacy saves with
	# no corpse get an empty list.
	old["version"] = 10
	var legacy: Dictionary = old.get("corpse", {})
	if not legacy.is_empty():
		var entry: Dictionary = legacy.duplicate(true)
		entry["id"] = 1
		old["corpse"] = { "corpses": [entry], "next_id": 2, "spills": [] }
	else:
		old["corpse"] = { "corpses": [], "next_id": 1, "spills": [] }
	return old

# ---- snapshot / apply ----------------------------------------------------

func _player() -> Node:
	return GameState.player

func _snapshot(player: Node) -> Dictionary:
	var stats: Stats = player.current_stats
	var cd: ClassData = player.class_data
	var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory
	var wallet: Wallet = player.get_node_or_null(^"Wallet") as Wallet
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
		"gold": wallet.gold if wallet != null else 0,
		"quests": QuestSystem.snapshot(),
		"zone_id": String(GameState.current_zone_id),
		"enemies": _snapshot_active_zone_enemies(),
		"loot": _snapshot_active_zone_loot(),
		"corpse": CorpseSystem.snapshot(),
	}
	return snap

func _snapshot_active_zone_loot() -> Array:
	# WorldItem and GoldPickup join the "loot" group in their _ready.
	# Each entry: { "kind": "item"|"gold", "pos": {x,y},
	#              and either "item_id" or "value" }.
	var out: Array = []
	for n in get_tree().get_nodes_in_group(&"loot"):
		var node := n as Node2D
		if node == null:
			continue
		var pos := { "x": node.global_position.x, "y": node.global_position.y }
		if "value" in node:
			out.append({ "kind": "gold", "pos": pos, "value": int(node.value) })
		elif "item_id" in node:
			out.append({ "kind": "item", "pos": pos,
					"item_id": String(node.item_id) })
	return out

## Public wrappers so Game can reuse the same "what's alive in
## this zone right now" capture for its in-memory zone cache
## (Stage 7 Phase 5+). Save's _snapshot routes through them too.
func snapshot_active_zone_enemies() -> Array:
	return _snapshot_active_zone_enemies()

func snapshot_active_zone_loot() -> Array:
	return _snapshot_active_zone_loot()

func set_pending_zone_state(enemies: Array, loot: Array) -> void:
	_pending_enemy_snapshot = enemies
	_pending_loot_snapshot = loot

func _snapshot_active_zone_enemies() -> Array:
	# Walk every enemy currently in the "enemies" group; record only
	# those with a registered enemy_id and that are not already
	# dead/dying. The list is per-zone — currently the active scene
	# is the only zone in the tree, so a flat group sweep is enough.
	var out: Array = []
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Enemy
		if e == null or e.enemy_id == &"":
			continue
		if e.current_stats != null and e.current_stats.is_dead():
			continue
		out.append({
			"id": String(e.enemy_id),
			"pos": { "x": e.global_position.x, "y": e.global_position.y },
			"hp": e.current_stats.current_hp if e.current_stats != null else int(e.max_hp),
		})
	return out

func consume_pending_enemy_snapshot() -> Array:
	var s := _pending_enemy_snapshot
	_pending_enemy_snapshot = []
	return s

func has_pending_enemy_snapshot() -> bool:
	return not _pending_enemy_snapshot.is_empty()

func consume_pending_loot_snapshot() -> Array:
	var s := _pending_loot_snapshot
	_pending_loot_snapshot = []
	return s

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
	var wallet: Wallet = player.get_node_or_null(^"Wallet") as Wallet
	if wallet != null:
		wallet.set_gold(int(data.get("gold", 0)))
	QuestSystem.restore(data.get("quests", {}))
	GameState.current_zone_id = StringName(data.get("zone_id", "threshold_camp"))
	_pending_enemy_snapshot = data.get("enemies", []) as Array
	_pending_loot_snapshot = data.get("loot", []) as Array
	CorpseSystem.restore(data.get("corpse", {}))
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
