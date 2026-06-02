class_name Npc extends StaticBody2D
## Base for in-town interactable characters. Player enters the
## InteractionArea -> "Press E" prompt appears -> KEY_E fires the
## subclass's open_panel(). Multiple NPCs in one zone is fine — the
## Player tracks the *nearest* in-range NPC and only sends E to it.

signal interacted(npc: Npc)

@export var display_name: String = "NPC"

@onready var _prompt: Label = $InteractPrompt
@onready var _area: Area2D = $InteractArea

var _player_in_range: bool = false
var _selection_ring: Node2D = null

func _ready() -> void:
	input_pickable = false
	_prompt.visible = false
	_prompt.text = "[E] %s" % display_name
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)
	# Selection ring under the NPC's feet — shown when the player
	# has click-targeted this NPC. Lives in the npc scene as a
	# "SelectionRing" child. Combat will reuse this on enemies.
	# We toggle via modulate.a rather than `.visible` because the
	# Node2D.visible flag can mis-interact with y-sort + z_index
	# grouping in nested scenes; alpha-fading is unambiguous.
	_selection_ring = get_node_or_null(^"SelectionRing")
	if _selection_ring == null:
		push_warning("Npc %s has no SelectionRing child — click-to-interact will work but won't show a ring." % display_name)
	else:
		_selection_ring.visible = true
		(_selection_ring as Node2D).modulate.a = 0.0

func _on_body_entered(body: Node) -> void:
	if body is Player:
		_player_in_range = true
		_prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body is Player:
		_player_in_range = false
		_prompt.visible = false

func is_in_range() -> bool:
	return _player_in_range

func set_selected(selected: bool) -> void:
	if _selection_ring != null:
		(_selection_ring as Node2D).modulate.a = 1.0 if selected else 0.0

## True if a world-space click at `world_pos` lands on this NPC's
## visible silhouette. Uses a rectangle tuned to the procedural
## sprite footprint (~14 wide, head at -50, feet at +6) rather than
## a circular radius — the round-radius variant caught ground clicks
## above the head and below the shadow. `_radius` is kept for API
## compatibility; ignored.
func click_hits(world_pos: Vector2, _radius: float) -> bool:
	var d := world_pos - global_position
	return absf(d.x) < 14.0 and d.y > -50.0 and d.y < 6.0

## Subclasses override to open their dialog/vendor/quest panel.
func interact() -> void:
	interacted.emit(self)

## Player workbench calls this when KEY_E is pressed and this NPC is
## in range (and is the chosen one if multiple are in range).
func try_interact() -> void:
	if _player_in_range:
		interact()
