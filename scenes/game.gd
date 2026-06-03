extends Node2D
## Production game entry. Loads the threshold camp, places the
## Player at its SpawnPoint, wires the standard UI suite (pause,
## inventory, save/load, vendor, quest). No dev helpers — class
## cycling and seeded gold stay in workbenches. If a save exists,
## we auto-load it on _ready so the player resumes where they left
## off; otherwise fresh start as Myrmidon (character select is
## Stage 10).
##
## Zone transitions (Stage 7): the Game registers as SceneRouter's
## zone host. Portals call SceneRouter.go_to_zone(zone_id) which
## delegates to transit_to_zone() — we remove the current Zone
## child, instantiate the new one, re-attach the Player at the
## new SpawnPoint, and re-wire any NPC panels present in that
## zone. Player + UI persist across the swap; only the zone
## subtree changes.

const DEFAULT_CLASS: StringName = &"myrmidon"
const DEFAULT_ZONE: StringName = &"threshold_camp"

const _DAMAGE_NUMBER := preload("res://scenes/vfx/damage_number.tscn")
const _WORLD_ITEM := preload("res://scenes/items/world_item.tscn")
const _GOLD_PICKUP := preload("res://scenes/items/gold_pickup.tscn")
const _CORPSE := preload("res://scenes/world/corpse.tscn")
const _TUTORIAL_PROMPT := preload("res://scenes/ui/tutorial_prompt.tscn")
const _TUTORIAL_SCRIPT := preload("res://scripts/ui/tutorial_prompt.gd")

@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _inventory_panel: CanvasLayer = $InventoryPanel
@onready var _vendor_panel: CanvasLayer = $VendorPanel
@onready var _quest_panel: CanvasLayer = $QuestPanel
@onready var _help: Label = $HUD/Help
@onready var _status: Label = $HUD/Status
@onready var _info: Label = $HUD/DebugInfo
@onready var _click_marker: Node2D = $ClickMarker
@onready var _dn_layer: Node2D = $DamageNumberLayer
@onready var _death_screen: CanvasLayer = $DeathScreen

var _zone: Zone = null

## In-memory per-zone cache of enemies + loot. Captured when the
## player leaves a zone (portal transit, death-driven transit) and
## restored on next entry so monsters freeze in place instead of
## resetting to the spawn director's initial pack. Independent of
## save/load — F9 explicitly clears this so the on-disk save is
## the source of truth after a load.
##
## Shape: { zone_id: StringName -> { "enemies": Array, "loot": Array } }
var _zone_cache: Dictionary = {}

## Click-to-interact target — set when the player clicks on an NPC's
## (or portal's) body footprint, auto-fires interact() once the
## player walks into range. Tight per-target silhouette hit-test
## (sprite torso, not the wide "press E" InteractArea) so clicking
## adjacent ground walks there without engaging. The targeted Npc
## shows a SelectionRing under its feet until consumed or cleared.
const _CLICK_NPC_RADIUS: float = 22.0
var _pending_interact_npc: Npc = null

func _ready() -> void:
	_help.text = "Click=move  |  WASD  |  E=interact  |  I=inventory  |  F5=save  |  F9=load  |  Esc=pause"

	# Default class on first launch; load_game below may overwrite it.
	# Stage 10: character_select.tscn stashes the player's pick in
	# GameState.pending_class_id before swapping here. Consume it
	# (and clear it) so a subsequent zone reload doesn't re-apply it.
	var first_class: StringName = DEFAULT_CLASS
	if GameState.pending_class_id != &"":
		first_class = GameState.pending_class_id
		GameState.pending_class_id = &""
	var cd: ClassData = Database.get_class_data(first_class) as ClassData
	if cd == null:
		cd = Database.get_class_data(DEFAULT_CLASS) as ClassData
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	_inventory_panel.bind_inventory(_player.get_inventory())
	GameState.player = _player

	# Adopt the camp instance baked into the scene as the initial zone.
	_zone = $ThresholdCamp
	_zone.attach_player(_player)
	_wire_zone_npcs()
	_wire_player_combat_vfx()
	_wire_zone_combat_vfx()

	SceneRouter.set_zone_host(self)

	var pi := _player.get_input()
	pi.pause_pressed.connect(_pause.toggle)
	pi.inventory_toggle_pressed.connect(_inventory_panel.toggle)
	pi.save_pressed.connect(_on_save_pressed)
	pi.load_pressed.connect(_on_load_pressed)
	pi.click_target_set.connect(_on_click_target_set)
	pi.click_target_cleared.connect(_on_click_target_cleared)
	pi.interact_pressed.connect(_on_interact_pressed)
	_click_marker.visible = false

	# Stage 7 Phase 5 — corpse-run. On death, harvest gold + a
	# random equipped slot into CorpseSystem, then transit back
	# to the threshold camp. The corpse waits for the player in
	# the zone where they died.
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	# Game owns the post-death timing: show the review screen, then
	# transit + respawn on the player's click. Player no longer
	# self-respawns after a fixed timer.
	_player.external_respawn_handler = true
	_death_screen.return_to_town_requested.connect(_on_return_to_town)

	_player.get_inventory().inventory_changed.connect(_reevaluate_quests)

	# Auto-load on entry: if a save exists, restore it; otherwise
	# stay on the fresh defaults. Always reports what happened so
	# the player can tell "no save" apart from "fresh Myrmidon".
	if SaveSystem.has_save():
		if SaveSystem.load_game():
			_zone_cache.clear()
			_inventory_panel.bind_inventory(_player.get_inventory())
			_overlay.bind_stats(_player.current_stats)
			_resume_saved_zone()
			_set_status("Resumed.", true)
		else:
			_set_status("Resume failed — starting fresh.", false)
	else:
		_set_status("New game — fresh start.", true)
		_maybe_show_tutorial()

func _maybe_show_tutorial() -> void:
	# First-launch only: skip if the player has already dismissed it
	# in any prior session (flag lives in user://settings.json).
	if _TUTORIAL_SCRIPT.has_seen_tutorial():
		return
	add_child(_TUTORIAL_PROMPT.instantiate())

func _exit_tree() -> void:
	SceneRouter.clear_zone_host(self)

## Called by SceneRouter when a Portal asks to go somewhere. The
## actual subtree swap is deferred so we can be triggered safely
## from any context (physics flush, Area2D callback, etc.).
func transit_to_zone(zone_id: StringName, arrival_marker: StringName = &"") -> void:
	_do_transit.call_deferred(zone_id, true, arrival_marker, false)

func _resume_saved_zone() -> void:
	# After a successful load, GameState.current_zone_id holds the
	# saved zone. Always rebuild the zone subtree — even if it
	# matches the current one — so enemies, dropped loot, and any
	# other zone-scoped state reset to the saved snapshot. The
	# player keeps the position SaveSystem._apply just restored
	# (we pass place_at_spawn = false).
	var saved: StringName = GameState.current_zone_id
	if saved == &"":
		saved = _zone.zone_id if _zone != null else DEFAULT_ZONE
	_do_transit.call_deferred(saved, false, &"", true)

func _do_transit(zone_id: StringName, place_at_spawn: bool, arrival_marker: StringName, force: bool = false) -> void:
	if not force and _zone != null and _zone.zone_id == zone_id:
		return
	var path := SceneRouter.zone_scene_path(zone_id)
	if path == "" or not ResourceLoader.exists(path):
		push_warning("Game.transit_to_zone: missing scene for %s (%s)" % [zone_id, path])
		return
	# Clear any stale click-target / pending NPC from the old zone.
	_set_pending_npc(null)
	var pi := _player.get_input()
	pi.clear_click_target()
	_click_marker.visible = false

	# Detach the old zone.
	_set_pending_npc(null)
	if _zone != null:
		# Snapshot before tearing down so the player can "leave the
		# world running" — enemies they didn't kill and loot they
		# didn't grab will be exactly where they left them on
		# return. Skip when a save load is in flight (the on-disk
		# pending snapshot is authoritative in that case).
		if not SaveSystem.has_pending_enemy_snapshot():
			_snapshot_zone_to_cache(_zone)
		remove_child(_zone)
		_zone.queue_free()
	# If we have a cached snapshot for the destination zone AND no
	# save-load is overriding, push it into SaveSystem's pending
	# slots so the SpawnDirector skips its initial spawn and the
	# subsequent rehydrate pulls the cached entities in instead.
	if not SaveSystem.has_pending_enemy_snapshot() and _zone_cache.has(zone_id):
		var cached: Dictionary = _zone_cache[zone_id]
		SaveSystem.set_pending_zone_state(
				(cached.get("enemies", []) as Array).duplicate(true),
				(cached.get("loot", []) as Array).duplicate(true))
	# Instantiate + insert the new zone. Place it before the Player
	# in sibling order so y-sort layering matches the camp setup.
	var packed: PackedScene = load(path) as PackedScene
	_zone = packed.instantiate() as Zone
	add_child(_zone)
	move_child(_zone, _player.get_index())
	if place_at_spawn:
		_place_player_for_arrival(arrival_marker)
	else:
		# Saved-position restore handled by SaveSystem._apply already;
		# we just need to keep respawn_position aligned with this zone.
		_player.respawn_position = _zone.get_spawn_position()
	_apply_pending_enemy_snapshot()
	_apply_pending_loot_snapshot()
	_spawn_corpses_in_zone()
	_spawn_pending_spills_in_zone()
	_wire_zone_npcs()
	_wire_zone_combat_vfx()
	# AudioBank listens for zone_changed and swaps the ambient loop.
	# SceneRouter only emits in the fallback (non-host) path, so the
	# production transit_to_zone flow re-emits here.
	EventBus.zone_changed.emit(zone_id)
	_set_status("Entered %s." % _zone_display_name(zone_id), true)

func _apply_pending_enemy_snapshot() -> void:
	# A load operation parked the saved enemy state on SaveSystem;
	# consume it (consuming clears the buffer so a subsequent
	# non-load transit doesn't re-trigger). Empty list = no save
	# data for this transit, leave the zone's pre-placed enemies
	# alone — that's the normal portal-walk case.
	var snap := SaveSystem.consume_pending_enemy_snapshot()
	if snap.is_empty():
		return
	# Free every pre-placed Enemy in the zone — the snapshot is now
	# the source of truth for what should be alive.
	for n in _zone.find_children("*", "Enemy", true, false):
		var e := n as Enemy
		if e == null:
			continue
		e.queue_free()
	# Spawn the saved enemies. Done call_deferred so we don't add
	# Area2D bodies while a previous queue_free is still settling
	# the physics state (failure-modes #17).
	_spawn_enemy_snapshot.call_deferred(snap)

func _snapshot_zone_to_cache(zone: Zone) -> void:
	if zone == null:
		return
	_zone_cache[zone.zone_id] = {
		"enemies": SaveSystem.snapshot_active_zone_enemies(),
		"loot": SaveSystem.snapshot_active_zone_loot(),
	}

func _spawn_corpses_in_zone() -> void:
	if _zone == null:
		return
	var entries := CorpseSystem.corpses_in_zone(_zone.zone_id)
	for entry_v in entries:
		var entry: Dictionary = entry_v as Dictionary
		var corpse := _CORPSE.instantiate() as Corpse
		_zone.add_child(corpse)
		corpse.set_corpse_data(entry)
		var pos_d: Dictionary = entry.get("pos", {})
		corpse.global_position = Vector2(
				float(pos_d.get("x", 0.0)),
				float(pos_d.get("y", 0.0)))

func _spawn_pending_spills_in_zone() -> void:
	# Evicted-corpse contents become world loot at the original
	# corpse position. From there they're regular pickups — they
	# join the "loot" group and round-trip through SaveSystem like
	# any other dropped item.
	if _zone == null:
		return
	for s in CorpseSystem.consume_spills_in_zone(_zone.zone_id):
		_spawn_spill(s as Dictionary)

func _spawn_spill(spill: Dictionary) -> void:
	var pos_d: Dictionary = spill.get("pos", {})
	var base := Vector2(float(pos_d.get("x", 0.0)), float(pos_d.get("y", 0.0)))
	var gold := int(spill.get("gold", 0))
	if gold > 0:
		var coin := _GOLD_PICKUP.instantiate()
		coin.value = gold
		_zone.add_child(coin)
		coin.global_position = base + Vector2(randf_range(-10, 10), randf_range(8, 22))
	var item_id := StringName(spill.get("item_id", ""))
	if item_id != &"":
		var w := _WORLD_ITEM.instantiate()
		w.item_id = item_id
		_zone.add_child(w)
		w.global_position = base + Vector2(randf_range(-10, 10), randf_range(-18, -4))

# Cached at death-time so the post-screen handler knows where the
# corpse should land — the player will have transit-teleported by
# then.
var _pending_death_pos: Vector2 = Vector2.ZERO
var _pending_death_zone: StringName = &""

func _on_player_died() -> void:
	# Park the death context, surface the review screen, and wait.
	# The harvest + corpse + transit + respawn chain runs only when
	# the player clicks "Return to Town" on the screen.
	_pending_death_pos = _player.global_position
	_pending_death_zone = _zone.zone_id if _zone != null else DEFAULT_ZONE
	_death_screen.show_death()

func _on_return_to_town() -> void:
	_death_screen.hide_death()
	var harvest := _player.harvest_for_corpse()
	if harvest["gold"] > 0 or StringName(harvest["item_id"]) != &"":
		# add_corpse handles eviction itself — anything pushed off
		# the cap becomes a "spill" entry on CorpseSystem and lands
		# as world loot the next time we enter its zone (see
		# _spawn_pending_spills_in_zone). No auto-return.
		CorpseSystem.add_corpse(_pending_death_zone, _pending_death_pos,
				int(harvest["gold"]),
				StringName(harvest["item_id"]),
				int(harvest["slot"]))
	# Camp-side death (K self-kill demo): no transit needed — spawn
	# the corpse visual here, then respawn the player.
	if _pending_death_zone == DEFAULT_ZONE:
		_spawn_corpses_in_zone.call_deferred()
		_spawn_pending_spills_in_zone.call_deferred()
	else:
		SceneRouter.go_to_zone(DEFAULT_ZONE, &"")
	# Respawn last — call_deferred so any pending transit completes
	# before HP/MP restore and input re-enable fire.
	_player.respawn.call_deferred()

func _apply_pending_loot_snapshot() -> void:
	# A load operation parked the saved loot state on SaveSystem;
	# consume it. Empty list = nothing to do (the fresh zone has
	# no ground drops yet). Otherwise free any pre-existing loot
	# in the new zone (defensive — zones shouldn't ship pre-placed
	# drops, but if they do the snapshot is the source of truth)
	# and respawn from the snapshot.
	var snap := SaveSystem.consume_pending_loot_snapshot()
	if snap.is_empty():
		return
	for n in _zone.find_children("*", "Node2D", true, false):
		if n.is_in_group(&"loot"):
			n.queue_free()
	_spawn_loot_snapshot.call_deferred(snap)

func _spawn_loot_snapshot(snap: Array) -> void:
	if _zone == null or not is_instance_valid(_zone):
		return
	for entry_v in snap:
		var entry: Dictionary = entry_v as Dictionary
		var pos_d: Dictionary = entry.get("pos", {})
		var pos := Vector2(float(pos_d.get("x", 0.0)), float(pos_d.get("y", 0.0)))
		var kind := String(entry.get("kind", ""))
		var node: Node2D = null
		if kind == "gold":
			var coin := _GOLD_PICKUP.instantiate()
			coin.value = int(entry.get("value", 1))
			node = coin
		elif kind == "item":
			var item := _WORLD_ITEM.instantiate()
			item.item_id = StringName(entry.get("item_id", ""))
			node = item
		if node == null:
			continue
		_zone.add_child(node)
		node.global_position = pos

func _spawn_enemy_snapshot(snap: Array) -> void:
	if _zone == null or not is_instance_valid(_zone):
		return
	# Re-use the zone's Enemies container if it has one; otherwise
	# drop the saved enemies directly under the zone root. Either
	# way, they participate in the zone's y-sort group.
	var container: Node = _zone.get_node_or_null(^"Enemies")
	if container == null:
		container = _zone
	for entry_v in snap:
		var entry: Dictionary = entry_v as Dictionary
		var id := StringName(entry.get("id", ""))
		var packed := EnemyRegistry.scene_for(id)
		if packed == null:
			push_warning("Game: no scene for saved enemy_id '%s'" % id)
			continue
		var inst := packed.instantiate() as Enemy
		if inst == null:
			continue
		# Stage 8 — restore the elite modifier BEFORE add_child so
		# Enemy._ready applies the mults during stats construction
		# (same contract as SpawnDirector spawns).
		var elite_id := StringName(entry.get("elite_id", ""))
		if elite_id != &"":
			inst.elite_modifier = EnemyRegistry.elite_modifier_for(elite_id)
		container.add_child(inst)
		var pos: Dictionary = entry.get("pos", {})
		inst.global_position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
		# Apply HP after the enemy's _ready built its Stats.
		var hp := int(entry.get("hp", inst.max_hp))
		if inst.current_stats != null and hp > 0:
			inst.current_stats.restore_pools(hp, 0)
	# Hand the rehydrated roster over to the spawn director (if any)
	# so cap + respawn accounting picks up where the save left off,
	# and re-wire damage numbers for the new crew.
	var dir := _zone.get_node_or_null(^"SpawnDirector") as SpawnDirector
	if dir != null:
		dir.claim_existing_enemies()
	else:
		_wire_zone_combat_vfx()

func _place_player_for_arrival(arrival_marker: StringName) -> void:
	var pos := _zone.get_spawn_position()
	if arrival_marker != &"":
		var mp := _zone.get_marker_position(arrival_marker)
		if mp != Vector2.ZERO:
			pos = mp
	_player.global_position = pos
	_player.respawn_position = _zone.get_spawn_position()

func _zone_display_name(zone_id: StringName) -> String:
	match zone_id:
		&"threshold_camp": return "Threshold Camp"
		&"blighted_reach": return "Blighted Reach"
		&"forsaken_crypt": return "Forsaken Crypt"
		_: return String(zone_id)

func _wire_player_combat_vfx() -> void:
	var hc := _player.get_health_component()
	if hc != null and not hc.damaged.is_connected(_on_combatant_damaged):
		hc.damaged.connect(_on_combatant_damaged.bind(_player))

func _wire_zone_combat_vfx() -> void:
	# Every HealthComponent inside the active zone gets its damaged
	# signal piped into the shared DamageNumberLayer. Latecomers
	# (SpawnDirector output, save-snapshot rehydration) flow through
	# wire_combatant_vfx() — see SpawnDirector hookup below.
	if _zone == null:
		return
	for n in _zone.find_children("*", "HealthComponent", true, false):
		wire_combatant_vfx(n.get_parent())
	# Subscribe to the zone's spawn director (if any) so newly-
	# spawned enemies get their damage numbers without us re-
	# walking the tree every frame.
	var dir := _zone.get_node_or_null(^"SpawnDirector") as SpawnDirector
	if dir != null and not dir.enemy_spawned.is_connected(_on_director_spawned):
		dir.enemy_spawned.connect(_on_director_spawned)

func wire_combatant_vfx(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var hc := target.get_node_or_null(^"HealthComponent") as HealthComponent
	if hc == null:
		return
	if not hc.damaged.is_connected(_on_combatant_damaged):
		hc.damaged.connect(_on_combatant_damaged.bind(target))

func _on_director_spawned(enemy: Enemy) -> void:
	wire_combatant_vfx(enemy)

func _on_combatant_damaged(amount: int, _source: Node, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dn := _DAMAGE_NUMBER.instantiate()
	if amount <= 0:
		dn.is_miss = true
	else:
		dn.text = str(amount)
		dn.color = Color(1.0, 0.55, 0.35, 1) if amount >= 20 else Color(1.0, 0.92, 0.65, 1)
	_dn_layer.add_child(dn)
	dn.global_position = (target as Node2D).global_position + Vector2(randf_range(-6, 6), -56)

func _wire_zone_npcs() -> void:
	# Vendor and quest panels live above the zone; we connect to
	# whatever NPCs the current zone happens to ship with. Zones
	# without these NPCs (wilderness, dungeons) just have nothing
	# to wire — that's fine.
	var k := _zone.get_node_or_null(^"Kallias") as Kallias
	if k != null and not k.vendor_open_requested.is_connected(_on_vendor_open):
		k.vendor_open_requested.connect(_on_vendor_open)
	var eur := _zone.get_node_or_null(^"Eurynome") as Eurynome
	if eur != null and not eur.quest_open_requested.is_connected(_on_quest_open):
		eur.quest_open_requested.connect(_on_quest_open)

func _on_save_pressed() -> void:
	var ok := SaveSystem.save_game()
	if ok:
		AudioBank.play_sfx(&"save")
	_set_status("Saved." if ok else "Save failed.", ok)

func _on_load_pressed() -> void:
	var ok := SaveSystem.load_game()
	if ok:
		AudioBank.play_sfx(&"load")
		_zone_cache.clear()
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
		_resume_saved_zone()
	_set_status("Loaded." if ok else "No save / load failed.", ok)

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true
	# Did this click land on an NPC's / portal's body footprint? If
	# so queue auto-interact + show the selection ring. Otherwise
	# clear any prior pending Npc (player redirected with a fresh
	# click on open ground).
	_set_pending_npc(_find_npc_at(world_pos))

func _on_click_target_cleared() -> void:
	_click_marker.visible = false

func _find_npc_at(world_pos: Vector2) -> Npc:
	if _zone == null:
		return null
	var npcs := _zone.find_children("*", "Npc", true, false)
	for n in npcs:
		var npc := n as Npc
		if npc == null:
			continue
		if npc.click_hits(world_pos, _CLICK_NPC_RADIUS):
			return npc
	return null

func _set_pending_npc(npc: Npc) -> void:
	if _pending_interact_npc == npc:
		return
	if _pending_interact_npc != null and is_instance_valid(_pending_interact_npc):
		_pending_interact_npc.set_selected(false)
	_pending_interact_npc = npc
	if npc != null:
		npc.set_selected(true)
		_status.text = "Targeting %s" % npc.display_name
		_status.modulate = Color(1.0, 0.85, 0.30, 1)

func _on_interact_pressed() -> void:
	if _zone == null:
		return
	var npcs := _zone.find_children("*", "Npc", true, false)
	for n in npcs:
		var npc := n as Npc
		if npc != null and npc.is_in_range():
			npc.interact()
			return

func _on_vendor_open(npc: Kallias) -> void:
	if npc == null or npc.stock == null:
		return
	_vendor_panel.open_for(npc.display_name, npc.stock,
			_player.get_inventory(), _player.get_wallet())

func _on_quest_open(npc: Eurynome) -> void:
	if npc == null:
		return
	_quest_panel.open_for(npc.quest_id, _player.get_inventory(), _player.get_wallet())

func _reevaluate_quests() -> void:
	QuestSystem.evaluate(&"eurynome_relic", _player.get_inventory())

func _set_status(msg: String, ok: bool) -> void:
	_status.text = msg
	_status.modulate = Color(0.85, 0.95, 0.65, 1) if ok else Color(0.95, 0.55, 0.45, 1)

func _process(_delta: float) -> void:
	if _player == null:
		return
	# Auto-interact once the player arrives at a clicked Npc/Portal.
	if _pending_interact_npc != null:
		if not is_instance_valid(_pending_interact_npc):
			_pending_interact_npc = null
		elif _pending_interact_npc.is_in_range():
			var n := _pending_interact_npc
			_set_pending_npc(null)
			n.interact()
	var w := _player.get_wallet()
	var gold_str := "%d g" % w.gold if w != null else "0 g"
	var zid := String(_zone.zone_id) if _zone != null else "?"
	_info.text = "pos=(%d,%d)   zone=%s   %s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		zid, gold_str,
	]
