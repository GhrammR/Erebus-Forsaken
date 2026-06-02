extends Node2D
## Stage 6 — town workbench. Loads the threshold camp scene with the
## Player attached so we can walk the layout, validate collision,
## and confirm the perimeter contains us. NPCs come in Phase 3/4.

@onready var _camp: Zone = $ThresholdCamp
@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _inventory_panel: CanvasLayer = $InventoryPanel
@onready var _vendor_panel: CanvasLayer = $VendorPanel
@onready var _quest_panel: CanvasLayer = $QuestPanel
@onready var _help: Label = $HUD/Help
@onready var _info: Label = $HUD/DebugInfo
@onready var _status: Label = $HUD/Status
@onready var _click_marker: Node2D = $ClickMarker

func _ready() -> void:
	_help.text = "Click=move  |  WASD  |  E=interact  |  I=inventory  |  M/P/H/O=class  |  F5=save  |  F9=load  |  Esc=pause"

	# Bind player to Myrmidon for first walk-through.
	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	_inventory_panel.bind_inventory(_player.get_inventory())
	GameState.player = _player

	# Park player at the camp's spawn marker.
	_camp.attach_player(_player)

	var pi := _player.get_input()
	pi.pause_pressed.connect(_pause.toggle)
	pi.inventory_toggle_pressed.connect(_inventory_panel.toggle)
	pi.save_pressed.connect(_on_save_pressed)
	pi.load_pressed.connect(_on_load_pressed)
	pi.click_target_set.connect(_on_click_target_set)
	pi.click_target_cleared.connect(_on_click_target_cleared)
	pi.interact_pressed.connect(_on_interact_pressed)
	_click_marker.visible = false

	# Seed gold so the vendor loop is immediately testable.
	_player.get_wallet().add_gold(80)

	# Wire any Kallias NPC in the camp to the VendorPanel.
	for n in get_tree().get_nodes_in_group(&"vendors"):
		if n is Kallias:
			(n as Kallias).vendor_open_requested.connect(_on_vendor_open)
	# The camp's Kallias isn't in a group yet — connect by name as a
	# fallback.
	var k := _camp.get_node_or_null(^"Kallias") as Kallias
	if k != null and not k.vendor_open_requested.is_connected(_on_vendor_open):
		k.vendor_open_requested.connect(_on_vendor_open)

	var eur := _camp.get_node_or_null(^"Eurynome") as Eurynome
	if eur != null and not eur.quest_open_requested.is_connected(_on_quest_open):
		eur.quest_open_requested.connect(_on_quest_open)

	# Keep the QuestSystem's completion flag in sync as the player
	# acquires/loses the required item out of vendor flow.
	_player.get_inventory().inventory_changed.connect(_reevaluate_quests)

func _on_save_pressed() -> void:
	var ok := SaveSystem.save_game()
	_set_status("Saved." if ok else "Save failed.", ok)

func _on_load_pressed() -> void:
	var ok := SaveSystem.load_game()
	if ok:
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
	_set_status("Loaded." if ok else "No save / load failed.", ok)

func _set_status(msg: String, ok: bool) -> void:
	_status.text = msg
	_status.modulate = Color(0.85, 0.95, 0.65, 1) if ok else Color(0.95, 0.55, 0.45, 1)

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false

func _on_interact_pressed() -> void:
	# Forward E to the nearest in-range NPC. Range checks are owned
	# by the NPC's InteractArea; we just iterate the camp's NPCs.
	var npcs := _camp.find_children("*", "Npc", true, false)
	for n in npcs:
		var npc := n as Npc
		if npc != null and npc.is_in_range():
			npc.interact()
			return

func _on_vendor_open(npc: Kallias) -> void:
	if npc == null or npc.stock == null:
		return
	_vendor_panel.open_for(npc.display_name, npc.stock, _player.get_inventory(), _player.get_wallet())

func _on_quest_open(npc: Eurynome) -> void:
	if npc == null:
		return
	_quest_panel.open_for(npc.quest_id, _player.get_inventory(), _player.get_wallet())

func _reevaluate_quests() -> void:
	# Cheap pass: evaluate the only known quest. With more quests
	# we'd track active ids on QuestSystem and iterate them.
	QuestSystem.evaluate(&"eurynome_relic", _player.get_inventory())

func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_M: _switch_class(&"myrmidon")
		KEY_P: _switch_class(&"pythia")
		KEY_H: _switch_class(&"shade_hunter")
		KEY_O: _switch_class(&"ossuary_priest")

func _switch_class(id: StringName) -> void:
	var cd: ClassData = Database.get_class_data(id) as ClassData
	if cd == null:
		return
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	# set_active_class on the inventory already fired; rebind the
	# panel so the visible columns refresh for the new class.
	_inventory_panel.bind_inventory(_player.get_inventory())

func _process(_delta: float) -> void:
	if _player == null:
		return
	var w := _player.get_wallet()
	var gold_str := "%d g" % w.gold if w != null else "0 g"
	_info.text = "pos=(%d,%d)   zone=%s   %s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		String(_camp.zone_id), gold_str,
	]
