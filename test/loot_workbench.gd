extends Node2D
## Stage 4 loot workbench. Player + 3 respawning dummies + drops on the
## floor + inventory panel + save/load. Single workbench that exercises
## the full Stage 4 loop.

const DAMAGE_NUMBER := preload("res://scenes/vfx/damage_number.tscn")
const DUMMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const DUMMY_RESPAWN_DELAY: float = 2.5

@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _info: Label = $HUD/DebugInfo
@onready var _help: Label = $HUD/Help
@onready var _save_label: Label = $HUD/SaveLabel
@onready var _click_marker: Node2D = $ClickMarker
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _dn_layer: Node2D = $DamageNumberLayer
@onready var _grid: Node2D = $GridGuides
@onready var _death_label: Label = $HUD/DeathLabel
@onready var _inventory_panel: CanvasLayer = $InventoryPanel

const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(160, 0),
	Vector2(-160, 0),
	Vector2(0, 160),
]

func _ready() -> void:
	_help.text = "Click=move  |  WASD=move  |  Space=attack  |  I=inventory  |  F5=save  |  F9=load  |  K=self-kill  |  Esc=pause"
	_death_label.visible = false
	_save_label.visible = false
	_grid.queue_redraw()

	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	if cd == null:
		push_error("loot_workbench: missing Myrmidon ClassData"); return
	_player.assign_class(cd)
	_player.global_position = Vector2.ZERO
	_player.respawn_position = Vector2.ZERO
	GameState.player = _player
	_overlay.bind_stats(_player.current_stats)
	_inventory_panel.bind_inventory(_player.get_inventory())

	# Wire player input.
	var pi := _player.get_input()
	pi.pause_pressed.connect(_pause.toggle)
	pi.click_target_set.connect(_on_click_target_set)
	pi.click_target_cleared.connect(_on_click_target_cleared)
	pi.inventory_toggle_pressed.connect(_inventory_panel.toggle)
	pi.save_pressed.connect(_on_save_pressed)
	pi.load_pressed.connect(_on_load_pressed)
	_click_marker.visible = false

	for offset in SPAWN_OFFSETS:
		_spawn_dummy(offset)

	_wire_combatant(_player)
	EventBus.player_died.connect(_on_player_died)
	EventBus.item_picked_up.connect(_on_item_picked_up)

func _spawn_dummy(spawn_position: Vector2) -> void:
	var d := DUMMY_SCENE.instantiate()
	add_child(d)
	d.global_position = spawn_position
	_wire_combatant(d)
	# Auto-respawn on death so the player can grind drops.
	var hc: HealthComponent = d.get_node(^"HealthComponent") as HealthComponent
	hc.died.connect(_schedule_dummy_respawn.bind(spawn_position))

func _schedule_dummy_respawn(_killer: Node, where: Vector2) -> void:
	get_tree().create_timer(DUMMY_RESPAWN_DELAY).timeout.connect(
		_spawn_dummy.bind(where), CONNECT_ONE_SHOT)

func _wire_combatant(node: Node) -> void:
	var hc: HealthComponent = node.get_node_or_null(^"HealthComponent") as HealthComponent
	if hc == null:
		return
	hc.damaged.connect(_on_damaged.bind(node))

func _on_damaged(amount: int, _source: Node, target: Node) -> void:
	if target == null:
		return
	var dn := DAMAGE_NUMBER.instantiate()
	if amount <= 0:
		dn.is_miss = true
	else:
		dn.text = str(amount)
		dn.color = Color(1.0, 0.55, 0.35, 1) if amount >= 20 else Color(1.0, 0.92, 0.65, 1)
	_dn_layer.add_child(dn)
	dn.global_position = target.global_position + Vector2(randf_range(-6, 6), -56)

func _on_player_died() -> void:
	_death_label.visible = true
	await get_tree().create_timer(1.4).timeout
	_death_label.visible = false

func _on_item_picked_up(item_id: StringName) -> void:
	var item: ItemData = Database.get_item(item_id) as ItemData
	if item == null: return
	_flash_save_label("Picked up: %s" % item.display_name, Color(0.7, 0.95, 0.7, 1))

func _on_save_pressed() -> void:
	var ok := SaveSystem.save_game()
	_flash_save_label("Saved." if ok else "Save failed.", Color(0.9, 0.85, 0.5, 1) if ok else Color(0.9, 0.4, 0.4, 1))

func _on_load_pressed() -> void:
	var ok := SaveSystem.load_game()
	_flash_save_label("Loaded." if ok else "No save / load failed.", Color(0.9, 0.85, 0.5, 1) if ok else Color(0.9, 0.4, 0.4, 1))

func _flash_save_label(text: String, color: Color) -> void:
	_save_label.text = text
	_save_label.modulate = color
	_save_label.visible = true
	await get_tree().create_timer(1.6).timeout
	if is_instance_valid(_save_label):
		_save_label.visible = false

func _process(_delta: float) -> void:
	if _player == null:
		return
	var pi := _player.get_input()
	var has_t := pi.has_click_target()
	var t := pi.get_click_target() if has_t else Vector2.ZERO
	var hp_str := "%d/%d" % [_player.current_stats.current_hp, _player.current_stats.max_hp] \
		if _player.current_stats != null else "-/-"
	_info.text = "pos=(%d,%d)  HP=%s  STR=%d DEX=%d VIT=%d PNE=%d  DEF=%d AR=%d RES=%d%%  facing=%s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		hp_str,
		_player.current_stats.strength,  _player.current_stats.dexterity,
		_player.current_stats.vitality,  _player.current_stats.pneuma,
		_player.current_stats.defense,   _player.current_stats.attack_rating,
		_player.current_stats.resistance,
		"R" if _player.get_facing_right() else "L",
	]
	if has_t:
		_click_marker.global_position = t

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false
