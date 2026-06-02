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

func _ready() -> void:
	input_pickable = false
	_prompt.visible = false
	_prompt.text = "[E] %s" % display_name
	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)

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

## Subclasses override to open their dialog/vendor/quest panel.
func interact() -> void:
	interacted.emit(self)

## Player workbench calls this when KEY_E is pressed and this NPC is
## in range (and is the chosen one if multiple are in range).
func try_interact() -> void:
	if _player_in_range:
		interact()
