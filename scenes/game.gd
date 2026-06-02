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

var _zone: Zone = null

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
	var cd: ClassData = Database.get_class_data(DEFAULT_CLASS) as ClassData
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	_inventory_panel.bind_inventory(_player.get_inventory())
	GameState.player = _player

	# Adopt the camp instance baked into the scene as the initial zone.
	_zone = $ThresholdCamp
	_zone.attach_player(_player)
	_wire_zone_npcs()

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

	_player.get_inventory().inventory_changed.connect(_reevaluate_quests)

	# Auto-load on entry: if a save exists, restore it; otherwise
	# stay on the fresh defaults. Always reports what happened so
	# the player can tell "no save" apart from "fresh Myrmidon".
	if SaveSystem.has_save():
		if SaveSystem.load_game():
			_inventory_panel.bind_inventory(_player.get_inventory())
			_overlay.bind_stats(_player.current_stats)
			_resume_saved_zone()
			_set_status("Resumed.", true)
		else:
			_set_status("Resume failed — starting fresh.", false)
	else:
		_set_status("New game — fresh Myrmidon.", true)

func _exit_tree() -> void:
	SceneRouter.clear_zone_host(self)

## Called by SceneRouter when a Portal asks to go somewhere. The
## actual subtree swap is deferred so we can be triggered safely
## from any context (physics flush, Area2D callback, etc.).
func transit_to_zone(zone_id: StringName) -> void:
	_do_transit.call_deferred(zone_id, true)

func _resume_saved_zone() -> void:
	# After a successful load, GameState.current_zone_id holds the
	# saved zone. If the player belonged in a different zone than
	# the one we booted into, swap to it — but preserve the saved
	# player position (don't snap to spawn).
	var saved: StringName = GameState.current_zone_id
	if saved == &"" or saved == _zone.zone_id:
		return
	_do_transit.call_deferred(saved, false)

func _do_transit(zone_id: StringName, place_at_spawn: bool) -> void:
	if _zone != null and _zone.zone_id == zone_id:
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
		remove_child(_zone)
		_zone.queue_free()
	# Instantiate + insert the new zone. Place it before the Player
	# in sibling order so y-sort layering matches the camp setup.
	var packed: PackedScene = load(path) as PackedScene
	_zone = packed.instantiate() as Zone
	add_child(_zone)
	move_child(_zone, _player.get_index())
	if place_at_spawn:
		_zone.attach_player(_player)
	else:
		# Saved-position restore handled by SaveSystem._apply already;
		# we just need to keep respawn_position aligned with this zone.
		_player.respawn_position = _zone.get_spawn_position()
	_wire_zone_npcs()
	_set_status("Entered %s." % _zone_display_name(zone_id), true)

func _zone_display_name(zone_id: StringName) -> String:
	match zone_id:
		&"threshold_camp": return "Threshold Camp"
		&"blighted_reach": return "Blighted Reach"
		_: return String(zone_id)

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
	_set_status("Saved." if ok else "Save failed.", ok)

func _on_load_pressed() -> void:
	var ok := SaveSystem.load_game()
	if ok:
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
