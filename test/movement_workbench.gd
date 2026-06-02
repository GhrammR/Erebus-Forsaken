extends Node2D
## Stage 2 movement workbench. Spawns the Player with the Myrmidon
## class assigned, lets you exercise click-to-move + WASD + pause +
## camera follow, all on an open plane with a grid for reference.

@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _info: Label = $HUD/DebugInfo
@onready var _help: Label = $HUD/Help
@onready var _click_marker: Node2D = $ClickMarker
@onready var _grid: Node2D = $GridGuides
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _inventory_panel: CanvasLayer = $InventoryPanel

func _ready() -> void:
	_help.text = "Click=move  |  WASD  |  I=inventory  |  F5=save  |  F9=load  |  Esc=pause"

	# Assign Myrmidon class — sprite, stats, and signals all flow from this.
	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	if cd == null:
		push_error("movement_workbench: missing Myrmidon ClassData")
		return
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	_inventory_panel.bind_inventory(_player.get_inventory())

	# Hook input -> pause menu, inventory, save/load.
	var pi := _player.get_input()
	pi.pause_pressed.connect(_pause.toggle)
	pi.click_target_set.connect(_on_click_target_set)
	pi.click_target_cleared.connect(_on_click_target_cleared)
	pi.inventory_toggle_pressed.connect(_inventory_panel.toggle)
	pi.save_pressed.connect(_on_save_pressed)
	pi.load_pressed.connect(_on_load_pressed)
	_click_marker.visible = false

	# Spawn player at world origin.
	_player.global_position = Vector2.ZERO

	_grid.queue_redraw()

func _process(_delta: float) -> void:
	if _player == null:
		return
	var pi := _player.get_input()
	var has_t := pi.has_click_target()
	var t := pi.get_click_target() if has_t else Vector2.ZERO
	_info.text = "pos=(%d, %d)   intent=(%.2f, %.2f)   facing=%s   click_target=%s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		_player.velocity.x / Player.WALK_SPEED, _player.velocity.y / Player.WALK_SPEED,
		"R" if _player.get_facing_right() else "L",
		("(%d, %d)" % [int(t.x), int(t.y)]) if has_t else "none",
	]
	if has_t:
		_click_marker.global_position = t

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false

func _on_save_pressed() -> void:
	SaveSystem.save_game()

func _on_load_pressed() -> void:
	if SaveSystem.load_game():
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
