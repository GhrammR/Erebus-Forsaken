extends Node2D
## Stage 6 — town workbench. Loads the threshold camp scene with the
## Player attached so we can walk the layout, validate collision,
## and confirm the perimeter contains us. NPCs come in Phase 3/4.

@onready var _camp: Zone = $ThresholdCamp
@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _inventory_panel: CanvasLayer = $InventoryPanel
@onready var _help: Label = $HUD/Help
@onready var _info: Label = $HUD/DebugInfo
@onready var _click_marker: Node2D = $ClickMarker

func _ready() -> void:
	_help.text = "Click=move  |  WASD  |  I=inventory  |  F5=save  |  F9=load  |  Esc=pause"

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
	_click_marker.visible = false

func _on_save_pressed() -> void:
	SaveSystem.save_game()

func _on_load_pressed() -> void:
	if SaveSystem.load_game():
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false

func _process(_delta: float) -> void:
	if _player == null:
		return
	var w := _player.get_wallet()
	var gold_str := "%d g" % w.gold if w != null else "0 g"
	_info.text = "pos=(%d,%d)   zone=%s   %s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		String(_camp.zone_id), gold_str,
	]
