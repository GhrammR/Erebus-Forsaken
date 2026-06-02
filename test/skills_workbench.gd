extends Node2D
## Stage 5 skills workbench. Player + 3 respawning dummies + class
## switcher (M/P/H/O cycles class) + skill HUD (current skill name,
## MP cost, cooldown, last result).

const DAMAGE_NUMBER := preload("res://scenes/vfx/damage_number.tscn")
const DUMMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")
const DUMMY_RESPAWN_DELAY: float = 2.5

@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _info: Label = $HUD/DebugInfo
@onready var _help: Label = $HUD/Help
@onready var _click_marker: Node2D = $ClickMarker
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _dn_layer: Node2D = $DamageNumberLayer
@onready var _grid: Node2D = $GridGuides
@onready var _skill_label: Label = $HUD/SkillLabel
@onready var _skill_status: Label = $HUD/SkillStatus
@onready var _inventory_panel: CanvasLayer = $InventoryPanel

const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(160, 0),
	Vector2(-160, 0),
	Vector2(0, 160),
]

const CLASS_CYCLE: Array[StringName] = [
	&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
]
var _current_class_idx: int = 0

func _ready() -> void:
	_help.text = "Click=move  |  WASD  |  Space=attack  |  1=skill  |  I=inventory  |  F5=save  |  F9=load  |  M/P/H/O=class  |  Esc=pause"
	_grid.queue_redraw()
	_apply_class(CLASS_CYCLE[_current_class_idx])
	_player.global_position = Vector2.ZERO
	_player.respawn_position = Vector2.ZERO
	GameState.player = _player
	_inventory_panel.bind_inventory(_player.get_inventory())

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

func _apply_class(class_id: StringName) -> void:
	var cd: ClassData = Database.get_class_data(class_id) as ClassData
	if cd == null:
		push_error("skills_workbench: missing ClassData %s" % class_id); return
	_player.assign_class(cd)
	_overlay.bind_stats(_player.current_stats)
	# Re-wire the skill's signals (the skill node was just swapped).
	var skill := _player.get_skill_1()
	if skill != null:
		if not skill.skill_used.is_connected(_on_skill_used):
			skill.skill_used.connect(_on_skill_used)
		if not skill.skill_failed.is_connected(_on_skill_failed):
			skill.skill_failed.connect(_on_skill_failed)
	_refresh_skill_label()

func _refresh_skill_label() -> void:
	var skill := _player.get_skill_1()
	if skill == null:
		_skill_label.text = "[1] (no skill)"
		return
	_skill_label.text = "[1] %s   MP %d   CD %.1fs   BaseDmg %d" % [
		skill.display_name, skill.mp_cost, skill.cooldown, skill.base_damage]

func _spawn_dummy(spawn_position: Vector2) -> void:
	var d := DUMMY_SCENE.instantiate()
	add_child(d)
	d.global_position = spawn_position
	_wire_combatant(d)
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
	_skill_status.text = "You died — respawning…"
	await get_tree().create_timer(1.4).timeout
	_skill_status.text = ""

func _on_skill_used(name: String) -> void:
	_skill_status.text = "%s cast" % name
	_skill_status.modulate = Color(0.9, 0.85, 0.5, 1)

func _on_skill_failed(reason: String) -> void:
	_skill_status.text = "Skill failed: %s" % reason
	_skill_status.modulate = Color(0.9, 0.4, 0.4, 1)

func _on_save_pressed() -> void:
	var ok := SaveSystem.save_game()
	_skill_status.text = "Saved." if ok else "Save failed."
	_skill_status.modulate = Color(0.9, 0.85, 0.5, 1) if ok else Color(0.9, 0.4, 0.4, 1)

func _on_load_pressed() -> void:
	var ok := SaveSystem.load_game()
	if ok:
		_inventory_panel.bind_inventory(_player.get_inventory())
		_overlay.bind_stats(_player.current_stats)
		# Re-wire the skill — the load path re-ran assign_class which
		# replaced the skill node.
		var skill := _player.get_skill_1()
		if skill != null:
			if not skill.skill_used.is_connected(_on_skill_used):
				skill.skill_used.connect(_on_skill_used)
			if not skill.skill_failed.is_connected(_on_skill_failed):
				skill.skill_failed.connect(_on_skill_failed)
		_refresh_skill_label()
	_skill_status.text = "Loaded." if ok else "No save / load failed."
	_skill_status.modulate = Color(0.9, 0.85, 0.5, 1) if ok else Color(0.9, 0.4, 0.4, 1)

func _unhandled_input(event: InputEvent) -> void:
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	match ke.keycode:
		KEY_M: _set_class_by_id(&"myrmidon")
		KEY_P: _set_class_by_id(&"pythia")
		KEY_H: _set_class_by_id(&"shade_hunter")
		KEY_O: _set_class_by_id(&"ossuary_priest")

func _set_class_by_id(id: StringName) -> void:
	var idx := CLASS_CYCLE.find(id)
	if idx < 0: return
	_current_class_idx = idx
	_apply_class(id)
	_skill_status.text = "Switched to %s" % _player.class_data.display_name
	_skill_status.modulate = Color(0.7, 0.95, 0.7, 1)

func _process(_delta: float) -> void:
	if _player == null:
		return
	var pi := _player.get_input()
	var has_t := pi.has_click_target()
	var t := pi.get_click_target() if has_t else Vector2.ZERO
	var hp_str := "%d/%d  MP %d/%d" % [
		_player.current_stats.current_hp, _player.current_stats.max_hp,
		_player.current_stats.current_mp, _player.current_stats.max_mp,
	] if _player.current_stats != null else "-/-"
	var skill := _player.get_skill_1()
	var cd_str := "CD %.2fs" % skill.cooldown_remaining() if skill != null else "no skill"
	_info.text = "pos=(%d,%d)  facing=(%.2f,%.2f)  HP=%s  %s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		_player.facing_dir.x, _player.facing_dir.y, hp_str, cd_str,
	]
	if has_t:
		_click_marker.global_position = t

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false
