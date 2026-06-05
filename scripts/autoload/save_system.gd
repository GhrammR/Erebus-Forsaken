extends Node
## Versioned JSON save/load. AD-06: stores item ids (Strings), never
## res:// paths. AD-07: SAVE_VERSION bumps on every schema change with a
## migrate() step. The on-disk format is human-readable so a tester can
## hand-edit corruption cases (rules/failure-modes.md #7 leans on this).

const SAVE_VERSION: int = 14
const SAVE_PATH: String = "user://save_slot_1.dat"

signal save_completed(success: bool)
signal load_completed(success: bool)

## Transient: filled by _apply on load, consumed once by Game after
## the zone rebuild. Holds {enemy_id, pos:{x,y}, hp} per snapshot
## entry. Never persisted at the field level.
var _pending_enemy_snapshot: Array = []
var _pending_loot_snapshot: Array = []
## Stage 9.7 polish — per-zone SpawnDirector budgets. Keyed by zone
## name (zone scene root, which equals the SpawnDirector's parent's
## name). SpawnDirector._ready consumes once via the
## consume_pending_director_budget() pop.
var _pending_director_budgets: Dictionary = {}
## Stage 9.7 polish — endless milestones the player has already
## claimed. Persisted across runs (they're permanent). Read by
## EndlessDirector on _advance_wave_to.
var _pending_milestones: Array = []

func save_game() -> bool:
	# Stage 9.7 — endless runs are explicitly NOT saved. The save on
	# disk from before portal entry IS the rollback anchor; writing
	# again during a run would destroy it. The path no-ops silently
	# so existing callers (zone auto-save, manual S) don't need to
	# branch on run mode.
	if EndlessRun.active:
		save_completed.emit(false)
		return false
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
	DebugLog.write(&"save", "save_game OK (zone=%s pos=(%d,%d) v=%d)" % [
			String(GameState.current_zone_id),
			int(player.global_position.x), int(player.global_position.y),
			SAVE_VERSION])
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
	DebugLog.write(&"save", "load_game OK (zone=%s v_from_disk=%d)" % [
			String(GameState.current_zone_id),
			int(data.get("version", 0))])
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
	if v < 11:
		old = _migrate_v10_to_v11(old)
	if v < 12:
		old = _migrate_v11_to_v12(old)
	if v < 13:
		old = _migrate_v12_to_v13(old)
	if v < 14:
		old = _migrate_v13_to_v14(old)
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

func _migrate_v13_to_v14(old: Dictionary) -> Dictionary:
	# Stage 9.8 — consumable cooldowns persist across save/load to block
	# quit-and-load spam. Legacy v13 saves predate ConsumableUse; default
	# to no cooldowns in flight.
	old["version"] = 14
	if not old.has("consumable_cooldowns"):
		old["consumable_cooldowns"] = { "cooldowns": {} }
	return old

func _migrate_v12_to_v13(old: Dictionary) -> Dictionary:
	# v12 had no per-zone spawn budget or claimed-milestone state.
	# Legacy saves default to empty dicts/lists — directors run at
	# their @export budget (or unlimited for pre-existing zones), and
	# no milestones have been earned yet.
	old["version"] = 13
	if not old.has("director_budgets"):
		old["director_budgets"] = {}
	if not old.has("endless_milestones"):
		old["endless_milestones"] = []
	if not old.has("titles"):
		old["titles"] = []
	# Stale endless zone id from a pre-rename save (Stage 9.7 polish
	# changed endless_arena -> forsaken_depths). Saves never persist
	# endless zones because of the SaveSystem guard, but the cache
	# could carry one across — map old to new defensively.
	if old.get("zone_id", "") == "endless_arena":
		old["zone_id"] = "forsaken_depths"
	return old

func _migrate_v11_to_v12(old: Dictionary) -> Dictionary:
	# v11 had no Act-boss completion flags. Legacy saves predate the
	# boss landing, so both default false — the player simply hasn't
	# killed it yet under the new state machine.
	old["version"] = 12
	if not old.has("act_1_complete"):
		old["act_1_complete"] = false
	if not old.has("boss_first_kill"):
		old["boss_first_kill"] = false
	return old

func _migrate_v10_to_v11(old: Dictionary) -> Dictionary:
	# v10 had no item-instance registry. Legacy saves get an empty
	# block — no prefixed items had ever rolled. Old inventories
	# remain valid since unprefixed items pass through unchanged.
	old["version"] = 11
	if not old.has("item_instances"):
		old["item_instances"] = { "next_serial": 1, "instances": {} }
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
		"item_instances": ItemInstanceRegistry.snapshot(),
		"act_1_complete": GameState.act_1_complete,
		"boss_first_kill": GameState.boss_first_kill,
		"director_budgets": _snapshot_director_budgets(),
		"endless_milestones": GameState.endless_milestones.duplicate(),
		"titles": GameState.titles.duplicate(),
		# v14 (Stage 9.8): persist potion-type cooldown remainders so
		# quit-and-load can't reset them. Active Ember channels are
		# dropped on save — matches the "interrupted -> lose the ember"
		# semantics; quitting mid-channel costs you the ember.
		"consumable_cooldowns": ConsumableUse.snapshot(),
	}
	return snap

func _snapshot_director_budgets() -> Dictionary:
	# Per-zone SpawnDirector budget remaining. Keyed by zone name so a
	# load route can pop the matching value when each zone's director
	# _readys. Unlimited (-1) budgets are omitted to keep saves clean.
	var out: Dictionary = {}
	for n in get_tree().get_nodes_in_group(&"spawn_director"):
		var sd := n as SpawnDirector
		if sd == null or not sd.has_finite_budget():
			continue
		var parent := sd.get_parent()
		if parent == null:
			continue
		out[String(parent.name)] = sd.budget_remaining()
	return out

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
		var entry: Dictionary = {
			"id": String(e.enemy_id),
			"pos": { "x": e.global_position.x, "y": e.global_position.y },
			"hp": e.current_stats.current_hp if e.current_stats != null else int(e.max_hp),
		}
		if e.elite_modifier != null and e.elite_modifier.id != &"":
			entry["elite_id"] = String(e.elite_modifier.id)
		out.append(entry)
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

## Game.gd uses this to push an in-session budget for the destination
## zone before its SpawnDirector _readys. Same key contract as the
## save snapshot — zone-scene-root name.
func set_pending_director_budget(zone_name: StringName, budget: int) -> void:
	_pending_director_budgets[String(zone_name)] = budget

## Pop the saved budget for a given zone name (the SpawnDirector's
## parent's name). Returns null when no entry exists — the director
## then falls through to its @export default. Variant return so
## "no entry" and "budget=0" stay distinguishable.
func consume_pending_director_budget(zone_name: StringName) -> Variant:
	var key := String(zone_name)
	if not _pending_director_budgets.has(key):
		return null
	var v: int = int(_pending_director_budgets[key])
	_pending_director_budgets.erase(key)
	return v

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
	# Item-instance registry must restore BEFORE Inventory.restore so
	# the inventory's _recompute_totals lookup synthesizes prefixed
	# items via Database.get_item and feeds their equip totals into
	# Stats. Order matters — a late restore would silently drop the
	# equipment bonus on the first equip-totals pass.
	ItemInstanceRegistry.restore(data.get("item_instances", {}))
	var inv: Inventory = player.get_node_or_null(^"Inventory") as Inventory
	if inv != null:
		inv.restore(data.get("inventory", {}))
	var wallet: Wallet = player.get_node_or_null(^"Wallet") as Wallet
	if wallet != null:
		wallet.set_gold(int(data.get("gold", 0)))
	QuestSystem.restore(data.get("quests", {}))
	GameState.current_zone_id = StringName(data.get("zone_id", "threshold_camp"))
	GameState.act_1_complete = bool(data.get("act_1_complete", false))
	GameState.boss_first_kill = bool(data.get("boss_first_kill", false))
	GameState.endless_milestones = (data.get("endless_milestones", []) as Array).duplicate()
	GameState.titles = (data.get("titles", []) as Array).duplicate()
	# v14 (Stage 9.8): restore potion-type cooldown remainders.
	ConsumableUse.restore(data.get("consumable_cooldowns", {}))
	_pending_enemy_snapshot = data.get("enemies", []) as Array
	_pending_loot_snapshot = data.get("loot", []) as Array
	_pending_director_budgets = (data.get("director_budgets", {}) as Dictionary).duplicate()
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
