extends CanvasLayer
## Stage 14 — Sundered Ferry travel menu. Opened when the player
## interacts with a Waypoint. Lists Threshold Camp (implicit hub —
## always present) plus every wilderness zone in
## GameState.discovered_waypoints. Picking a destination calls back
## up to the host (game.gd) with the chosen zone_id, which routes
## through SceneRouter with arrival_marker = "FromWaypoint".
##
## Stage 14.2 — menu does NOT pause time. The world keeps moving so
## the player has to either clear the area first or rush the menu
## while enemies are still active. Taking damage instantly closes
## the menu (parallels Hearth Ember's channel-interrupt semantics).
## Esc closes the menu without travelling.
##
## The backdrop is intentionally faint and mouse-pass-through so
## clicks on the world (movement, attacks) reach the player while
## the menu is open. Only the panel + buttons catch input.

signal travel_requested(zone_id: StringName)
signal close_requested

const _TITLE_TEXT: String = "The Sundered Ferry"

## Display labels for the menu. Threshold Camp always appears as the
## first option. Wilderness zones append in the discovery order.
const _CAMP_ZONE_ID: StringName = &"threshold_camp"
const _ZONE_DISPLAY_NAMES: Dictionary = {
	&"threshold_camp": "Threshold Camp",
	&"blighted_reach": "Blighted Reach",
}

@onready var _title: Label = $Panel/Center/VBox/Title
@onready var _list_container: VBoxContainer = $Panel/Center/VBox/Destinations
@onready var _close_button: Button = $Panel/Center/VBox/CloseButton
@onready var _backdrop: ColorRect = $Backdrop

var _origin_zone_id: StringName = &""
## Subscribed to the player's HealthComponent.damaged while the menu
## is visible so any hit closes the menu. Cleared on hide so we
## don't leak the connection across opens.
var _damage_hc: HealthComponent = null

func _ready() -> void:
	hide()
	_title.text = _TITLE_TEXT
	_close_button.pressed.connect(_on_close_pressed)
	_set_input_active(false)

## Open the menu from a waypoint in zone `origin_zone_id`. The origin
## is not surfaced in the list (no point ferrying to where you are);
## travel_requested fires when the player picks a destination.
##
## The menu does not pause — _hook_damage_interrupt subscribes to the
## player's HC so the first hit auto-closes it.
func show_menu(origin_zone_id: StringName) -> void:
	_origin_zone_id = origin_zone_id
	_rebuild_list()
	show()
	_set_input_active(true)
	_hook_damage_interrupt()

func hide_menu() -> void:
	hide()
	_set_input_active(false)
	_unhook_damage_interrupt()

func _hook_damage_interrupt() -> void:
	var p: Node = GameState.player
	if p == null or not is_instance_valid(p):
		return
	if not p.has_method("get_health_component"):
		return
	_damage_hc = p.get_health_component()
	if _damage_hc == null:
		return
	if not _damage_hc.damaged.is_connected(_on_player_damaged):
		_damage_hc.damaged.connect(_on_player_damaged)

func _unhook_damage_interrupt() -> void:
	if _damage_hc != null and is_instance_valid(_damage_hc) \
			and _damage_hc.damaged.is_connected(_on_player_damaged):
		_damage_hc.damaged.disconnect(_on_player_damaged)
	_damage_hc = null

func _on_player_damaged(amount: int, _source: Node) -> void:
	if amount <= 0:
		return
	DebugLog.write(&"transit", "waypoint_menu interrupted by damage")
	hide_menu()

func _rebuild_list() -> void:
	for c in _list_container.get_children():
		c.queue_free()
	# Camp always present (the hub). Skip when the player is already
	# there, though there's currently no Camp-side waypoint so this is
	# a defensive check for Stage 19 (Maw entrance moves to town).
	if _origin_zone_id != _CAMP_ZONE_ID:
		_add_destination_button(_CAMP_ZONE_ID)
	for zid_v in GameState.discovered_waypoints:
		var zid := StringName(zid_v)
		if zid == _origin_zone_id:
			continue
		_add_destination_button(zid)

func _add_destination_button(zid: StringName) -> void:
	var label_text: String = _ZONE_DISPLAY_NAMES.get(zid, String(zid))
	var b := Button.new()
	b.text = "↦  %s" % label_text
	b.custom_minimum_size = Vector2(280, 36)
	b.pressed.connect(_on_destination_pressed.bind(zid))
	_list_container.add_child(b)

func _on_destination_pressed(zid: StringName) -> void:
	AudioBank.play_sfx(&"waypoint_travel")
	hide_menu()
	travel_requested.emit(zid)

func _on_close_pressed() -> void:
	hide_menu()
	close_requested.emit()

func _set_input_active(active: bool) -> void:
	# Panel + buttons catch mouse input (so buttons are clickable),
	# but the Backdrop stays IGNORE so clicks on the world below
	# (movement, attacks) reach the player while the menu is up.
	var panel := get_node_or_null(^"Panel")
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	if panel != null:
		_apply_filter_recursive(panel, target)
	if _backdrop != null:
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()
