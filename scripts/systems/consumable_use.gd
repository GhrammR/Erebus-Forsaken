extends Node
## Stage 9.8 — runtime dispatcher for consumable items.
##
## Owns three pieces of state:
##   - `_cooldowns`: shared-key cooldown timers (potion_health, potion_mana,
##     potion_ichor; hearth_ember has 0 cooldown so it never lands here)
##   - `_regens`: active HoT / MoT entries (flat amount restored linearly
##     over `duration` seconds)
##   - `_ember`: at most one Hearth Ember channel in flight per player
##
## Public surface:
##   try_use(player, item_id, inventory) -> bool
##   is_on_cooldown(cooldown_id) -> bool
##   get_cooldown_remaining/max(cooldown_id) -> float
##   is_channeling() -> bool
##   cancel_ember()
##   snapshot/restore — save schema v14 carries cooldown remainders + ember
##                       channel-in-flight state across save/load.
##
## Tied to:
##   - InventoryPanel.gd right-click path (calls try_use)
##   - PlayerInput potion hotkeys (2/3 select-and-use)
##   - Hud potion bar (reads cooldown state for veil)
##   - SaveSystem snapshot/restore_game

signal cooldown_started(cooldown_id: StringName, duration: float)
signal cooldown_expired(cooldown_id: StringName)
signal channel_started(item_id: StringName, duration: float)
signal channel_progress(item_id: StringName, remaining: float)
signal channel_completed(item_id: StringName)
signal channel_interrupted(item_id: StringName)

var _cooldowns: Dictionary = {}     # StringName cooldown_id -> { remaining: float, max: float }
var _regens: Array[Dictionary] = []  # { target: Node, kind: int, remaining: float, duration: float, total: int, restored: int }
var _ember: Dictionary = {}          # { player: Node, item_id, remaining, total, hp_conn_handle }
var _active_player: Node = null      # set by Player.on_ready_for_use

func _ready() -> void:
	set_process(true)

func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_regens(delta)
	_tick_ember(delta)

# ---- registration --------------------------------------------------------

func set_active_player(player: Node) -> void:
	_active_player = player
	DebugLog.write(&"consumables", "active_player <- %s" % (player.name if player != null else "<null>"))

func get_active_player() -> Node:
	return _active_player

# ---- public use entry ----------------------------------------------------

func try_use(player: Node, item_id: StringName, inventory: Inventory) -> bool:
	if player == null or inventory == null or item_id == &"":
		return false
	var item: ItemData = Database.get_item(item_id) as ItemData
	if item == null or item.kind != ItemData.Kind.EQUIPMENT and item.kind != ItemData.Kind.CONSUMABLE:
		return false
	if item.kind != ItemData.Kind.CONSUMABLE:
		return false
	if "is_dead" in player and player.is_dead():
		DebugLog.write(&"consumables", "try_use(%s) -> player dead" % item_id)
		return false
	if is_on_cooldown(item.cooldown_id):
		DebugLog.write(&"consumables", "try_use(%s) -> cooldown %s busy" % [item_id, item.cooldown_id])
		return false
	if is_channeling():
		DebugLog.write(&"consumables", "try_use(%s) -> already channeling" % item_id)
		return false
	if inventory.backpack.find(item_id) == -1:
		return false

	# Consume now. Ember channel will refund-fail by re-adding if interrupted
	# pre-channel-start; spec says damage during channel LOSES the ember, so
	# once consumed it does not come back.
	inventory.remove_item(item_id)

	match item.use_kind:
		ItemData.UseKind.HEARTH_EMBER:
			return _start_hearth_ember(player, item)
		ItemData.UseKind.HEAL_OVER_TIME:
			_apply_regen(player, item, &"hp")
			AudioBank.play_sfx(&"potion_drink")
			_start_cooldown(item.cooldown_id, item.cooldown_seconds)
			DebugLog.write(&"consumables", "use %s -> HoT %dhp/%ss" % [item_id, item.use_flat_amount, item.use_duration])
			return true
		ItemData.UseKind.MANA_OVER_TIME:
			_apply_regen(player, item, &"mp")
			AudioBank.play_sfx(&"potion_drink")
			_start_cooldown(item.cooldown_id, item.cooldown_seconds)
			DebugLog.write(&"consumables", "use %s -> MoT %dmp/%ss" % [item_id, item.use_flat_amount, item.use_duration])
			return true
		ItemData.UseKind.INSTANT_BOTH_PCT:
			_apply_instant_both(player, item)
			AudioBank.play_sfx(&"potion_ichor")
			_start_cooldown(item.cooldown_id, item.cooldown_seconds)
			DebugLog.write(&"consumables", "use %s -> Ichor %d%%hp/%d%%mp" % [
					item_id, int(item.use_hp_pct * 100.0), int(item.use_mp_pct * 100.0)])
			return true
		_:
			DebugLog.write(&"consumables", "use %s -> UNKNOWN use_kind=%d" % [item_id, item.use_kind])
			# Refund the consume since we couldn't actually use it.
			inventory.add_item(item_id)
			return false

# ---- cooldowns -----------------------------------------------------------

func is_on_cooldown(cooldown_id: StringName) -> bool:
	if cooldown_id == &"":
		return false
	return _cooldowns.has(cooldown_id) and float(_cooldowns[cooldown_id].get("remaining", 0.0)) > 0.0

func get_cooldown_remaining(cooldown_id: StringName) -> float:
	if not _cooldowns.has(cooldown_id):
		return 0.0
	return float(_cooldowns[cooldown_id].get("remaining", 0.0))

func get_cooldown_max(cooldown_id: StringName) -> float:
	if not _cooldowns.has(cooldown_id):
		return 0.0
	return float(_cooldowns[cooldown_id].get("max", 0.0))

func _start_cooldown(cooldown_id: StringName, duration: float) -> void:
	if cooldown_id == &"" or duration <= 0.0:
		return
	_cooldowns[cooldown_id] = { "remaining": duration, "max": duration }
	cooldown_started.emit(cooldown_id, duration)
	DebugLog.write(&"consumables", "cooldown_start %s (%.1fs)" % [cooldown_id, duration])

func _tick_cooldowns(delta: float) -> void:
	if _cooldowns.is_empty():
		return
	var expired: Array[StringName] = []
	for cid in _cooldowns.keys():
		var entry: Dictionary = _cooldowns[cid]
		var rem: float = float(entry.get("remaining", 0.0)) - delta
		if rem <= 0.0:
			expired.append(cid)
		else:
			entry["remaining"] = rem
	for cid in expired:
		_cooldowns.erase(cid)
		cooldown_expired.emit(cid)
		DebugLog.write(&"consumables", "cooldown_expire %s" % cid)

# ---- HoT / MoT -----------------------------------------------------------

func _apply_regen(target: Node, item: ItemData, kind: StringName) -> void:
	_regens.append({
		"target": target,
		"kind": kind,
		"remaining": item.use_duration,
		"duration": item.use_duration,
		"total": item.use_flat_amount,
		"restored": 0,
	})

func _tick_regens(delta: float) -> void:
	if _regens.is_empty():
		return
	var keep: Array[Dictionary] = []
	for entry in _regens:
		var target: Node = entry["target"]
		if target == null or not is_instance_valid(target):
			continue
		if "is_dead" in target and target.is_dead():
			continue
		var duration: float = entry["duration"]
		var total: int = entry["total"]
		var restored: int = entry["restored"]
		var remaining: float = entry["remaining"] - delta
		var elapsed: float = duration - max(remaining, 0.0)
		var target_restored: int = int(round(total * (elapsed / max(duration, 0.001))))
		target_restored = clampi(target_restored, 0, total)
		var step: int = target_restored - restored
		if step > 0:
			var stats: Stats = target.current_stats if "current_stats" in target else null
			if stats != null:
				if entry["kind"] == &"hp":
					stats.restore_hp(step)
				else:
					stats.restore_mp(step)
			entry["restored"] = target_restored
		entry["remaining"] = remaining
		if remaining > 0.0 and restored < total:
			keep.append(entry)
	_regens = keep

# ---- Ichor (instant both %) ---------------------------------------------

func _apply_instant_both(target: Node, item: ItemData) -> void:
	if target == null or not ("current_stats" in target):
		return
	var stats: Stats = target.current_stats
	if stats == null:
		return
	var hp_amt: int = int(round(stats.max_hp * item.use_hp_pct))
	var mp_amt: int = int(round(stats.max_mp * item.use_mp_pct))
	if hp_amt > 0:
		stats.restore_hp(hp_amt)
	if mp_amt > 0:
		stats.restore_mp(mp_amt)

# ---- Hearth Ember channel ------------------------------------------------

func is_channeling() -> bool:
	return not _ember.is_empty()

func _start_hearth_ember(player: Node, item: ItemData) -> bool:
	var health: HealthComponent = null
	if "get_health_component" in player:
		health = player.get_health_component()
	_ember = {
		"player": player,
		"item_id": item.id,
		"remaining": item.use_channel_seconds,
		"total": item.use_channel_seconds,
	}
	if "set_channeling" in player:
		player.set_channeling(true)
	if health != null and not health.damaged.is_connected(_on_player_damaged_during_channel):
		health.damaged.connect(_on_player_damaged_during_channel)
	AudioBank.play_sfx(&"hearth_ember_channel")
	channel_started.emit(item.id, item.use_channel_seconds)
	DebugLog.write(&"consumables", "ember_channel_start (%.1fs)" % item.use_channel_seconds)
	return true

func _tick_ember(delta: float) -> void:
	if _ember.is_empty():
		return
	var rem: float = float(_ember["remaining"]) - delta
	_ember["remaining"] = rem
	channel_progress.emit(_ember["item_id"], max(rem, 0.0))
	if rem <= 0.0:
		_complete_ember()

func _complete_ember() -> void:
	if _ember.is_empty():
		return
	var player: Node = _ember["player"]
	var item_id: StringName = _ember["item_id"]
	_release_ember_state()
	AudioBank.play_sfx(&"hearth_ember_complete")
	channel_completed.emit(item_id)
	DebugLog.write(&"consumables", "ember_channel_complete -> route")
	if EndlessRun.active:
		EndlessRun.end_run(false)
	else:
		SceneRouter.go_to_zone(&"threshold_camp", &"SpawnPoint")

func cancel_ember() -> void:
	if _ember.is_empty():
		return
	var item_id: StringName = _ember["item_id"]
	_release_ember_state()
	AudioBank.play_sfx(&"hearth_ember_break")
	channel_interrupted.emit(item_id)
	DebugLog.write(&"consumables", "ember_channel_cancel (item lost)")

func _on_player_damaged_during_channel(amount: int, _source: Node) -> void:
	if amount <= 0 or _ember.is_empty():
		return
	cancel_ember()

func _release_ember_state() -> void:
	var player: Node = _ember.get("player", null)
	if player != null and "set_channeling" in player:
		player.set_channeling(false)
	if player != null and "get_health_component" in player:
		var health: HealthComponent = player.get_health_component()
		if health != null and health.damaged.is_connected(_on_player_damaged_during_channel):
			health.damaged.disconnect(_on_player_damaged_during_channel)
	_ember.clear()

# ---- save / load --------------------------------------------------------
# v14: cooldown remainders persist so quit-and-load can't reset them. Active
# ember channel is dropped on save (treat quit-mid-channel as cancel — losing
# the ember matches the "channel interrupted" semantics).

func snapshot() -> Dictionary:
	var cd_out: Dictionary = {}
	for cid in _cooldowns.keys():
		cd_out[String(cid)] = {
			"remaining": float(_cooldowns[cid].get("remaining", 0.0)),
			"max":       float(_cooldowns[cid].get("max", 0.0)),
		}
	return { "cooldowns": cd_out }

func restore(data: Dictionary) -> void:
	_cooldowns.clear()
	var raw: Dictionary = data.get("cooldowns", {})
	for cid_s in raw.keys():
		var entry: Dictionary = raw[cid_s]
		_cooldowns[StringName(cid_s)] = {
			"remaining": float(entry.get("remaining", 0.0)),
			"max":       float(entry.get("max", 0.0)),
		}

func clear_runtime() -> void:
	_cooldowns.clear()
	_regens.clear()
	if not _ember.is_empty():
		_release_ember_state()
