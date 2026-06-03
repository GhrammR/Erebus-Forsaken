extends CanvasLayer
## Stage 7 Phase 5 — between-deaths review screen. Shows when the
## player dies, parks the player at the death point so they can
## see what killed them and remember where the corpse will land,
## and waits for the player to click "Return to Town" before the
## actual transit + respawn happens.
##
## Game.gd listens for `return_to_town_requested` and runs the
## harvest + corpse + transit + Player.respawn chain.

signal return_to_town_requested

@onready var _button: Button = $Panel/Center/VBox/ReturnButton

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_button.pressed.connect(_on_button_pressed)
	_set_input_active(false)

## Failure-modes #14: hidden CanvasLayer children still consume
## input. Toggle mouse_filter to IGNORE while invisible so the
## panel never silently eats clicks meant for the world.
func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func show_death() -> void:
	show()
	_set_input_active(true)
	# Defer focus so the button is keyboard-actionable as soon as
	# the layer becomes visible.
	_button.grab_focus.call_deferred()

func hide_death() -> void:
	hide()
	_set_input_active(false)

func _on_button_pressed() -> void:
	return_to_town_requested.emit()
