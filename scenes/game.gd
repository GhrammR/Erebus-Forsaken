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
@onready var _quest_chip: Label = $HUD/QuestChip
@onready var _zone_toast: Label = $HUD/ZoneNameToast
@onready var _kill_counter: Label = $HUD/KillCounter
@onready var _save_toast: Label = $HUD/SaveToast
@onready var _gold_hud: Label = $HUD/GoldHUD
@onready var _skill_icon: Control = $HUD/SkillIcon
@onready var _potion_bar: Control = $HUD/PotionBar
@onready var _wave_counter: Label = $HUD/WaveCounter
@onready var _endless_summary: CanvasLayer = $EndlessSummary
@onready var _milestone_modal: CanvasLayer = $MilestoneModal
@onready var _click_marker: Node2D = $ClickMarker
@onready var _dn_layer: Node2D = $DamageNumberLayer
@onready var _death_screen: CanvasLayer = $DeathScreen

# Stage 9.5 — HUD feel state.
var _kill_count: int = 0
var _kill_fade_tween: Tween = null
var _zone_toast_tween: Tween = null
var _quest_chip_tween: Tween = null
var _save_toast_tween: Tween = null
## Kill counter is **cumulative** across the run — it never resets
## inside a session. The fade is visibility only: the count keeps
## ticking, the label just dims so it doesn't sit at full brightness
## when nothing's happening.
const _KILL_VISIBLE_HOLD: float = 2.5
const _KILL_FADE_DURATION: float = 0.8
const _KILL_DIM_ALPHA: float = 0.25

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
	# Stage 9 polish — anything that spawns a combatant outside the
	# zone-load / SpawnDirector path (scripted dungeon spawns, runtime
	# summons like Bone Servant) looks Game up via this group and calls
	# wire_combatant_vfx() so its damage numbers fire.
	add_to_group(&"game_host")
	if DebugLog.is_enabled(&"class"):
		DebugLog.write(&"class", "Game._ready begin pending=%s has_save=%s" % [
				GameState.pending_class_id, SaveSystem.has_save()])
	# Trimmed after Stage 9.5 playtest — the full keymap pushed the
	# Help label across the top-centre and ate the KillCounter row.
	_help.text = "Click=move  WASD  E=interact  I=inv  F5/F9=save/load  Esc=pause"

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
	_wire_feel_hud()

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

	# Stage 9.7 — endless run lifecycle. Summary modal opens on death
	# during a run; its return button hands control back here, which
	# routes through EndlessRun.rollback() to the pre-portal save.
	_endless_summary.return_requested.connect(_on_endless_summary_return)
	_milestone_modal.continue_pressed.connect(_on_milestone_continue)
	if not EndlessRun.milestone_reached.is_connected(_on_milestone_reached):
		EndlessRun.milestone_reached.connect(_on_milestone_reached)
	if not EventBus.endless_wave_started.is_connected(_on_endless_wave_started):
		EventBus.endless_wave_started.connect(_on_endless_wave_started)
	if not EventBus.endless_wave_completed.is_connected(_on_endless_wave_completed):
		EventBus.endless_wave_completed.connect(_on_endless_wave_completed)
	if not EndlessRun.stats_changed.is_connected(_on_endless_stats_changed):
		EndlessRun.stats_changed.connect(_on_endless_stats_changed)
	# Stage 9.7/9.8 — voluntary run-exit (Hearth Ember channel) and
	# death both fire EndlessRun.end_run() which emits
	# endless_run_ended. Both paths converge on the summary modal.
	# (AscentSpire was the interim exit; Stage 9.8 retired it.)
	if not EventBus.endless_run_ended.is_connected(_on_endless_run_ended):
		EventBus.endless_run_ended.connect(_on_endless_run_ended)
	_refresh_wave_counter()

	_player.get_inventory().inventory_changed.connect(_reevaluate_quests)

	# Auto-load on entry: if a save exists, restore it; otherwise
	# stay on the fresh defaults. Always reports what happened so
	# the player can tell "no save" apart from "fresh Myrmidon".
	if SaveSystem.has_save():
		if SaveSystem.load_game():
			_zone_cache = SaveSystem.consume_pending_zone_caches()
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
		# Push budgets too so the destination's SpawnDirector picks
		# up the in-session decrement on its _ready instead of
		# re-reading its @export default.
		var cached_budgets: Dictionary = cached.get("director_budgets", {}) as Dictionary
		for k in cached_budgets.keys():
			SaveSystem.set_pending_director_budget(StringName(k), int(cached_budgets[k]))
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
	# Crypt-style scripted spawns happen via call_deferred from the
	# zone's _ready, so they aren't in the tree yet when the wire pass
	# above runs. Re-walk next frame to catch them. Idempotent —
	# already-connected signals are skipped.
	_wire_zone_combat_vfx.call_deferred()
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
		# Stage 9.7 polish — capture per-zone director budgets so a
		# wilderness re-entry doesn't reset the spawn count. Without
		# this, leaving Blighted Reach for town and coming back would
		# refresh the budget mid-session (the on-disk save only carries
		# it across save/load, not in-session transit).
		"director_budgets": _collect_director_budgets(zone),
	}

func _collect_director_budgets(zone: Zone) -> Dictionary:
	# One entry per finite-budget director in the zone, keyed by the
	# director's parent name (matches SaveSystem's snapshot key).
	var out: Dictionary = {}
	for n in zone.find_children("*", "Node", true, false):
		var sd := n as SpawnDirector
		if sd == null or not sd.has_finite_budget():
			continue
		var parent := sd.get_parent()
		if parent == null:
			continue
		out[String(parent.name)] = sd.budget_remaining()
	return out

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
	# Stage 9.7 — endless death bypasses the corpse-run chain entirely.
	# No harvest, no corpse, no penalty: the rollback restores HP +
	# inventory + zone bytes-for-bytes from the pre-portal save when
	# the summary closes. end_run() emits endless_run_ended, and
	# _on_endless_run_ended below opens the summary; no need to call
	# show_summary directly.
	if EndlessRun.active:
		EndlessRun.end_run(true)
		return
	# Park the death context, surface the review screen, and wait.
	# The harvest + corpse + transit + respawn chain runs only when
	# the player clicks "Return to Town" on the screen.
	_pending_death_pos = _player.global_position
	_pending_death_zone = _zone.zone_id if _zone != null else DEFAULT_ZONE
	_death_screen.show_death()

func _on_endless_run_ended(stats: Dictionary) -> void:
	# Single summary entry point for both death and Hearth Ember
	# voluntary exit. Idempotent — if the modal is already up
	# (shouldn't happen but defensive), show_summary re-binds the
	# labels.
	_endless_summary.show_summary(stats)

func _on_endless_summary_return() -> void:
	_endless_summary.hide_summary()
	# Capture milestones earned in THIS run before rollback wipes the
	# in-memory GameState (the pre-portal save has the pre-run
	# milestone list, so loading it removes the rewards we just
	# granted). Then: rollback -> load anchor -> reapply milestones
	# -> save -> resume zone. Milestones are the one piece of
	# permanent progress that survives an endless run.
	var new_milestones := EndlessRun.milestones_new_this_run()
	var via_ember: bool = EndlessRun.ended_via_ember
	var via_death: bool = EndlessRun.ended_via_death
	DebugLog.write(&"endless", "summary_return via=%s milestones_new=%d" % [
			"ember" if via_ember else ("death" if via_death else "?"),
			new_milestones.size()])
	EndlessRun.rollback()
	var ok := SaveSystem.load_game()
	if ok:
		_zone_cache = SaveSystem.consume_pending_zone_caches()
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
		if not new_milestones.is_empty():
			EndlessRun.recommit_milestones(new_milestones)
			# Persist the rolled-back-but-with-milestones state. Active
			# is already off, so the save guard doesn't trip.
			SaveSystem.save_game()
		# Stage 9.8.1 — Ember is the "go to town" affordance, NOT
		# "respawn at anchor." Override the resume-saved-zone path
		# (which today returns to crypt R3 because that's where the
		# pre-portal save lives) with a forced transit to Threshold
		# Camp. Persist the new zone so a subsequent reload doesn't
		# yank the player back to the crypt. Stage 19 moves the Maw
		# entrance to town and incidentally fixes the anchor too, but
		# Ember should always read as "town return" regardless.
		if via_ember:
			GameState.current_zone_id = &"threshold_camp"
			SaveSystem.save_game()
			DebugLog.write(&"endless", "ember exit -> threshold_camp/SpawnPoint")
			_do_transit.call_deferred(
					StringName("threshold_camp"), true,
					StringName("SpawnPoint"), true)
		else:
			_resume_saved_zone()
		# If the run ended via death the player's LifeState is DEAD and
		# input is suppressed (see Player._on_died); the load restored
		# HP/MP + position but not the input-process flags or life/
		# combat state. revive_in_place() flips those without yanking
		# the player away from the save-restored position (the south-
		# wall SpawnPoint would replace the boss-room rollback slot).
		# Hearth Ember path leaves the player alive — nothing to do.
		if via_death:
			_player.revive_in_place.call_deferred()
	_refresh_wave_counter()

func _on_endless_wave_started(_wave: int, _kills_required: int) -> void:
	_refresh_wave_counter()

func _on_endless_wave_completed(wave: int) -> void:
	_wave_counter.text = "Floor %d — clear!" % wave

func _on_milestone_reached(floor: int, reward: Dictionary) -> void:
	_milestone_modal.show_milestone(floor, reward)

func _on_milestone_continue() -> void:
	_milestone_modal.hide_milestone()

func _on_endless_stats_changed() -> void:
	_refresh_wave_counter()

func _refresh_wave_counter() -> void:
	if not EndlessRun.active or EndlessRun.wave <= 0:
		_wave_counter.text = ""
		_wave_counter.visible = false
		return
	_wave_counter.visible = true
	_wave_counter.text = "Floor %d — %d / %d" % [
			EndlessRun.wave,
			mini(EndlessRun.kills_this_wave, EndlessRun.kills_required),
			EndlessRun.kills_required]

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
		# failure-modes #25 — pre-position before add_child so the
		# enemy's collision never registers at world (0,0).
		var pos: Dictionary = entry.get("pos", {})
		inst.position = Vector2(float(pos.get("x", 0.0)), float(pos.get("y", 0.0)))
		container.add_child(inst)
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
	# Stage 9.7 polish — has_marker is an explicit node-existence
	# probe. The old `if mp != Vector2.ZERO` shortcut silently dropped
	# the override for any marker at the world origin (DepthsEntry at
	# (0, 0) read as "missing" and the player ended up at whatever
	# fallback get_spawn_position served).
	if arrival_marker != &"" and _zone.has_marker(arrival_marker):
		pos = _zone.get_marker_position(arrival_marker)
	# Teleport + immediate state wipe. Without zeroing velocity and
	# clearing the click target, a residual intent from BEFORE the
	# portal interaction (the click that walked the player toward
	# the portal in the OLD zone's world coords) survives into the
	# new zone — the player then walks toward a now-meaningless
	# stale position in the new zone's coordinate frame, which can
	# read as "spawning in a corner."
	_player.global_position = pos
	_player.velocity = Vector2.ZERO
	_player.respawn_position = _zone.get_spawn_position()
	var pi := _player.get_input()
	if pi != null:
		pi.clear_click_target()
	_set_pending_npc(null)
	# Stage 9.7 polish — failure-modes #23. Residual Camera2D.offset
	# from a CameraShake.kick fired just before the portal interact
	# carries into the new zone and renders the viewport off-centre.
	# Player ends up at the entry marker correctly, but the camera
	# shows them at a corner. Reset on every transit.
	CameraShake.reset()
	DebugLog.write(&"transit", "arrival zone=%s marker=%s target=%s -> player.gp=%s cam_offset=%s" % [
			_zone.zone_id, arrival_marker, pos, _player.global_position,
			CameraShake.current_offset()])
	# Movement watch (separate `movement` flag so it's opt-in and
	# doesn't dominate `transit`). Logs only deltas > 5px so normal
	# walking doesn't flood — anything large enough to be a teleport,
	# physics shove, or post-transit nudge surfaces with frame index.
	if DebugLog.is_enabled(&"movement"):
		_movement_watch_target = pos
		_movement_watch_frames = 300
		_movement_watch_last = pos
	# Deferred re-apply: AFTER all transit-frame work has settled.
	_settle_arrival.call_deferred(pos)

# Movement-watch state. Declared at class scope, populated by
# _place_player_for_arrival when the `movement` debug flag is on,
# read by _process. _movement_watch_target is currently unused but
# kept around so a future check can compare against the spawn
# anchor (e.g. "did the player drift more than X px from target?").
var _movement_watch_target: Vector2 = Vector2.ZERO
var _movement_watch_frames: int = 0
var _movement_watch_last: Vector2 = Vector2.ZERO

func _settle_arrival(target: Vector2) -> void:
	if not is_instance_valid(_player) or _player.is_dead():
		return
	DebugLog.write(&"transit", "settle before=%s -> target=%s" % [
			_player.global_position, target])
	_player.global_position = target
	_player.velocity = Vector2.ZERO
	var pi := _player.get_input()
	if pi != null:
		pi.clear_click_target()

func _zone_display_name(zone_id: StringName) -> String:
	# Internal zone_id stays `forsaken_depths` (it's referenced by
	# the EndlessPortal target, save migration, and SceneRouter
	# registration — churn-not-worth-it to rename). User-facing
	# strings use "The Maw" after the Stage 9.7 polish naming pass —
	# distinct from the Forsaken Crypt, fits the swallowed-descent
	# read for the wave climb.
	match zone_id:
		&"threshold_camp":  return "Threshold Camp"
		&"blighted_reach":  return "Blighted Reach"
		&"forsaken_crypt":  return "Forsaken Crypt"
		&"forsaken_depths": return "The Maw"
		_: return String(zone_id)

func _wire_player_combat_vfx() -> void:
	var hc := _player.get_health_component()
	if hc != null and not hc.damaged.is_connected(_on_combatant_damaged):
		hc.damaged.connect(_on_combatant_damaged.bind(_player))
	if hc != null and not hc.crit_landed.is_connected(_on_combatant_crit):
		hc.crit_landed.connect(_on_combatant_crit.bind(_player))

# ---------------------------------------------------------------- Stage 9.5
# Feel-pass HUD wiring. All listeners route through this one place so
# the scene-auditor #10 check has a single grep target.

func _wire_feel_hud() -> void:
	_skill_icon.bind(_player.get_skill_1())
	# Stage 9.8 — potion HUD bar polls cooldowns from ConsumableUse and
	# counts from the player's Inventory. Re-bind after class swap because
	# the inventory reference is per-loadout.
	if _potion_bar != null and _potion_bar.has_method(&"bind_player"):
		_potion_bar.bind_player(_player)
	var w := _player.get_node_or_null(^"Wallet") as Wallet
	if w != null:
		_last_gold_seen = w.gold
		_gold_hud.text = "%d g" % w.gold
	# Quest chip: slides in on accept, flashes gold + clears on complete.
	if not QuestSystem.quest_state_changed.is_connected(_on_quest_state_changed):
		QuestSystem.quest_state_changed.connect(_on_quest_state_changed)
	# Zone-name fade-in on every zone transit. EventBus.zone_changed
	# already fires from _do_transit.
	if not EventBus.zone_changed.is_connected(_on_zone_changed_feel):
		EventBus.zone_changed.connect(_on_zone_changed_feel)
	# Kill counter ticks on enemy death.
	if not EventBus.enemy_died.is_connected(_on_enemy_died_feel):
		EventBus.enemy_died.connect(_on_enemy_died_feel)
	# Save / load toasts route through SaveSystem signals so we get
	# both the manual F5/F9 path and any future auto-save path.
	if not SaveSystem.save_completed.is_connected(_on_save_completed_feel):
		SaveSystem.save_completed.connect(_on_save_completed_feel)
	if not SaveSystem.load_completed.is_connected(_on_load_completed_feel):
		SaveSystem.load_completed.connect(_on_load_completed_feel)
	# Wallet pulse: positive deltas only (vendor purchases skip).
	var wallet := _player.get_node_or_null(^"Wallet") as Wallet
	if wallet != null and not wallet.gold_changed.is_connected(_on_wallet_pulse):
		wallet.gold_changed.connect(_on_wallet_pulse)
	# Level-up ring — wired even though no XP system emits today; the
	# call site exists per feel-pass.md contract.
	if not EventBus.player_leveled.is_connected(_on_player_leveled_feel):
		EventBus.player_leveled.connect(_on_player_leveled_feel)
	# Kill counter decay is folded into _process which is already
	# running for the auto-interact / debug-info pass.

func _on_quest_state_changed(quest_id: StringName, new_state: int) -> void:
	# QuestSystem.QuestState enum: NOT_STARTED=0, ACCEPTED=1,
	# COMPLETED=2, TURNED_IN=3.
	if _quest_chip_tween != null and _quest_chip_tween.is_valid():
		_quest_chip_tween.kill()
	match new_state:
		1:  # ACCEPTED
			_quest_chip.text = "● %s" % String(quest_id)
			_quest_chip.modulate = Color(1, 1, 1, 0)
			_quest_chip_tween = create_tween()
			_quest_chip_tween.tween_property(_quest_chip, "modulate",
					Color(1, 1, 1, 1), 0.35)
			AudioBank.play_sfx(&"quest_accept")
		2, 3:  # COMPLETED / TURNED_IN
			AudioBank.play_sfx(&"quest_complete")
			_quest_chip.modulate = Color(1.4, 1.2, 0.6, 1)
			_quest_chip_tween = create_tween()
			_quest_chip_tween.tween_property(_quest_chip, "modulate",
					Color(1, 1, 1, 0), 0.9)
			_quest_chip_tween.tween_callback(func(): _quest_chip.text = "")

func _on_zone_changed_feel(zone_id: StringName) -> void:
	_zone_toast.text = _zone_display_name(zone_id)
	_zone_toast.modulate = Color(1, 1, 1, 0)
	if _zone_toast_tween != null and _zone_toast_tween.is_valid():
		_zone_toast_tween.kill()
	_zone_toast_tween = create_tween()
	_zone_toast_tween.tween_property(_zone_toast, "modulate",
			Color(1, 1, 1, 1), 0.35)
	_zone_toast_tween.tween_interval(0.9)
	_zone_toast_tween.tween_property(_zone_toast, "modulate",
			Color(1, 1, 1, 0), 0.5)

func _on_enemy_died_feel(_enemy: Node, _killer: Node) -> void:
	if DebugLog.is_enabled(&"combat") and _enemy != null:
		var k: String = String(_killer.name) if _killer != null else "<?>"
		DebugLog.write(&"combat", "%s died (killer=%s)" % [_enemy.name, k])
	_on_enemy_died_feel_real(_enemy, _killer)

func _on_enemy_died_feel_real(_enemy: Node, _killer: Node) -> void:
	_kill_count += 1
	_kill_counter.text = "kills %d" % _kill_count
	# Bring the label back to full brightness on every new kill, then
	# fade to a dim "still tracking" alpha after the hold window. The
	# count itself never resets — the run total persists.
	if _kill_fade_tween != null and _kill_fade_tween.is_valid():
		_kill_fade_tween.kill()
	_kill_counter.modulate.a = 1.0
	_kill_fade_tween = create_tween()
	_kill_fade_tween.tween_interval(_KILL_VISIBLE_HOLD)
	_kill_fade_tween.tween_property(_kill_counter, "modulate:a",
			_KILL_DIM_ALPHA, _KILL_FADE_DURATION)

func _on_save_completed_feel(success: bool) -> void:
	_show_save_toast("Saved." if success else "Save failed.", success)

func _on_load_completed_feel(success: bool) -> void:
	_show_save_toast("Loaded." if success else "Load failed.", success)

func _show_save_toast(msg: String, success: bool) -> void:
	_save_toast.text = msg
	_save_toast.modulate = Color(0.7, 0.95, 0.7, 1) if success else Color(0.95, 0.6, 0.6, 1)
	if _save_toast_tween != null and _save_toast_tween.is_valid():
		_save_toast_tween.kill()
	_save_toast_tween = create_tween()
	_save_toast_tween.tween_interval(1.0)
	_save_toast_tween.tween_property(_save_toast, "modulate:a", 0.0, 0.5)

var _last_gold_seen: int = 0
var _gold_pulse_tween: Tween = null

func _on_wallet_pulse(new_total: int) -> void:
	# Wallet emits the running total, not a delta — track our own
	# previous value so vendor purchases (negative delta) skip the
	# pulse + sfx and only pickups trigger feel.
	var delta := new_total - _last_gold_seen
	_last_gold_seen = new_total
	_gold_hud.text = "%d g" % new_total
	if delta <= 0:
		return
	# Pivot at label centre so the scale grows in place rather than
	# from the top-left corner (which would shove the label off the
	# bottom-right edge and look like nothing happened).
	_gold_hud.pivot_offset = Vector2(_gold_hud.size.x * 0.5,
			_gold_hud.size.y * 0.5)
	if _gold_pulse_tween != null and _gold_pulse_tween.is_valid():
		_gold_pulse_tween.kill()
	_gold_hud.scale = Vector2(1.8, 1.8)
	_gold_hud.modulate = Color(1.6, 1.4, 0.6, 1.0)
	_gold_pulse_tween = create_tween().set_parallel(true)
	_gold_pulse_tween.tween_property(_gold_hud, "scale",
			Vector2.ONE, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_gold_pulse_tween.tween_property(_gold_hud, "modulate",
			Color(1.0, 0.85, 0.35, 1.0), 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioBank.play_sfx(&"pickup_gold")

const _LEVEL_UP_RING := preload("res://scenes/vfx/level_up_ring.tscn")

func _on_player_leveled_feel(new_level: int) -> void:
	AudioBank.play_sfx(&"levelup")
	var ring := _LEVEL_UP_RING.instantiate()
	add_child(ring)
	(ring as Node2D).global_position = _player.global_position
	if "level_text" in ring:
		ring.level_text = "+%d" % new_level

func _wire_zone_combat_vfx() -> void:
	# Every HealthComponent inside the active zone gets its damaged
	# signal piped into the shared DamageNumberLayer. Latecomers
	# (SpawnDirector output, save-snapshot rehydration) flow through
	# wire_combatant_vfx() — see SpawnDirector hookup below.
	if _zone == null:
		return
	for n in _zone.find_children("*", "HealthComponent", true, false):
		wire_combatant_vfx(n.get_parent())
	# Subscribe to every SpawnDirector (including subclasses like
	# EndlessDirector in Forsaken Depths) so newly-spawned enemies
	# get their damage numbers without us re-walking the tree every
	# frame. Lookup-by-class instead of hardcoded `^"SpawnDirector"`
	# name — the depths' director node is named "EndlessDirector"
	# and the old name-based lookup silently missed it, leaving
	# wave-spawned wretches with no damage-number wiring.
	for n in _zone.find_children("*", "Node", true, false):
		var dir := n as SpawnDirector
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
	# Stage 9.5 — crits get the golden DamageNumber + hit_crit sfx +
	# 3-frame HitStop pulse + tiny camera kick. Bound separately from
	# `damaged` so a non-crit hit doesn't pay the kick cost.
	if not hc.crit_landed.is_connected(_on_combatant_crit):
		hc.crit_landed.connect(_on_combatant_crit.bind(target))

func _on_director_spawned(enemy: Enemy) -> void:
	wire_combatant_vfx(enemy)

func _on_combatant_damaged(amount: int, _source: Node, target: Node) -> void:
	if DebugLog.is_enabled(&"combat") and target != null:
		var src_name: String = String(_source.name) if _source != null else "<?>"
		DebugLog.write(&"combat", "%s -> %s  dmg=%d" % [
				src_name, target.name, amount])
	_on_combatant_damaged_vfx(amount, _source, target)

func _on_combatant_damaged_vfx(amount: int, _source: Node, target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	var dn := _DAMAGE_NUMBER.instantiate()
	if amount <= 0:
		dn.is_miss = true
	else:
		dn.text = str(amount)
		# Pale cream for normal hits, soft pale-red for heavier ones.
		# Golden is RESERVED for crits (the crit handler spawns its
		# own DamageNumber with is_crit=true).
		dn.color = Color(0.98, 0.80, 0.70, 1) if amount >= 20 else Color(0.96, 0.94, 0.86, 1)
	_dn_layer.add_child(dn)
	dn.global_position = (target as Node2D).global_position + Vector2(randf_range(-6, 6), -56)

func _on_combatant_crit(amount: int, _source: Node, target: Node) -> void:
	# The matching `damaged` signal already fired (we ignore that one's
	# DN spawn for crits by replacing it here — they overlap visually
	# but the golden one wins z-order via larger scale + sequence).
	if target == null or not is_instance_valid(target):
		return
	var dn := _DAMAGE_NUMBER.instantiate()
	dn.is_crit = true
	dn.text = str(amount)
	_dn_layer.add_child(dn)
	dn.global_position = (target as Node2D).global_position + Vector2(randf_range(-4, 4), -64)
	AudioBank.play_sfx(&"hit_crit")
	HitStop.pulse(3)
	CameraShake.kick(7.0, 0.16)

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
		_zone_cache = SaveSystem.consume_pending_zone_caches()
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
		_resume_saved_zone()
	_set_status("Loaded." if ok else "No save / load failed.", ok)

## Stage 13 hotfix — SaveSystem.save_game queries this via
## SceneRouter.snapshot_zone_caches so the upcoming snapshot
## includes every zone the player has visited in this session,
## not just the currently-active one. Without this, saving in town
## silently drops the wilderness's last-visited enemy/loot state.
## The active zone's state is NOT included here — it rides on the
## top-level "enemies"/"loot"/"director_budgets" snapshot keys.
func snapshot_zone_cache_for_save() -> Dictionary:
	return _zone_cache.duplicate(true)

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
	# Stage 9.5 — kill counter is cumulative; the fade is on the
	# label's modulate alpha only, driven by the _kill_fade_tween
	# below. Nothing to tick here per-frame.
	if _player == null:
		return
	# Movement watch (failure-modes #23 + future spawn issues): only
	# fires when --debug=movement and only for ~5s after a transit.
	# Skips per-frame walking by only printing deltas > 5px AND
	# always prints camera offset so a phantom teleport that's
	# really a camera offset stands out.
	if _movement_watch_frames > 0:
		var gp: Vector2 = _player.global_position
		var d := gp - _movement_watch_last
		if d.length() > 5.0:
			DebugLog.write(&"movement",
					"frame=%d gp=%s delta=%s vel=%s cam_offset=%s" % [
							300 - _movement_watch_frames,
							gp, d, _player.velocity,
							CameraShake.current_offset()])
			_movement_watch_last = gp
		_movement_watch_frames -= 1
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
