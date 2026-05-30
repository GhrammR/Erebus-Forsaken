extends Node2D
## Stage 3 combat workbench. Player (Myrmidon) + 3 training dummies
## on an open plane. Exercises the full damage path:
## Player swing -> HitboxComponent -> HurtboxComponent -> HealthComponent
## -> DamageResolver -> Stats.take_damage. Spawns floating damage
## numbers on every hit (incl. MISS).

const DAMAGE_NUMBER := preload("res://scenes/vfx/damage_number.tscn")

@onready var _player: Player = $Player
@onready var _pause: CanvasLayer = $PauseMenu
@onready var _info: Label = $HUD/DebugInfo
@onready var _help: Label = $HUD/Help
@onready var _click_marker: Node2D = $ClickMarker
@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _dn_layer: Node2D = $DamageNumberLayer
@onready var _grid: Node2D = $GridGuides
@onready var _death_label: Label = $HUD/DeathLabel

const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(160, 0),
	Vector2(-160, 0),
	Vector2(0, 160),
]

func _ready() -> void:
	_help.text = "Click to move  |  WASD secondary  |  Space attack  |  K self-kill  |  Esc pauses"
	_death_label.visible = false
	_grid.queue_redraw()

	var cd: ClassData = Database.get_class_data(&"myrmidon") as ClassData
	if cd == null:
		push_error("combat_workbench: missing Myrmidon ClassData"); return
	_player.assign_class(cd)
	_player.global_position = Vector2.ZERO
	_player.respawn_position = Vector2.ZERO
	_overlay.bind_stats(_player.current_stats)

	# Wire player input to pause + click marker.
	var pi := _player.get_input()
	pi.pause_pressed.connect(_pause.toggle)
	pi.click_target_set.connect(_on_click_target_set)
	pi.click_target_cleared.connect(_on_click_target_cleared)
	_click_marker.visible = false

	# Spawn dummies and wire their damage/death signals for VFX.
	var dummy_scene: PackedScene = preload("res://scenes/enemies/training_dummy.tscn")
	for offset in SPAWN_OFFSETS:
		var d := dummy_scene.instantiate()
		add_child(d)
		d.global_position = offset
		_wire_combatant(d)

	# Player damage/death VFX
	_wire_combatant(_player)
	EventBus.player_died.connect(_on_player_died)

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
		# Bigger numbers tint hotter
		if amount >= 20:
			dn.color = Color(1.0, 0.55, 0.35, 1)
		else:
			dn.color = Color(1.0, 0.92, 0.65, 1)
	_dn_layer.add_child(dn)
	dn.global_position = target.global_position + Vector2(randf_range(-6, 6), -56)

func _on_player_died() -> void:
	_death_label.visible = true
	await get_tree().create_timer(1.4).timeout
	_death_label.visible = false

func _process(_delta: float) -> void:
	if _player == null:
		return
	var pi := _player.get_input()
	var has_t := pi.has_click_target()
	var t := pi.get_click_target() if has_t else Vector2.ZERO
	var hp_str := "%d/%d" % [_player.current_stats.current_hp, _player.current_stats.max_hp] \
		if _player.current_stats != null else "-/-"
	_info.text = "pos=(%d, %d)   intent=(%.2f, %.2f)   facing=%s   HP=%s   click=%s" % [
		int(_player.global_position.x), int(_player.global_position.y),
		_player.velocity.x / Player.WALK_SPEED, _player.velocity.y / Player.WALK_SPEED,
		"R" if _player.get_facing_right() else "L",
		hp_str,
		("(%d, %d)" % [int(t.x), int(t.y)]) if has_t else "none",
	]
	if has_t:
		_click_marker.global_position = t

func _on_click_target_set(world_pos: Vector2) -> void:
	_click_marker.global_position = world_pos
	_click_marker.visible = true

func _on_click_target_cleared() -> void:
	_click_marker.visible = false
