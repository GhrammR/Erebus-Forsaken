extends CanvasLayer
## Pause menu. Lives in gameplay scenes (workbench / zones), not in
## main.tscn. Toggled by an external signal (typically
## PlayerInput.pause_pressed). Owns the `get_tree().paused` flip.

signal resumed
signal quit_requested

@onready var _resume_btn: Button = $Panel/VBox/ResumeButton
@onready var _quit_btn: Button = $Panel/VBox/QuitButton

func _ready() -> void:
	hide()
	_resume_btn.pressed.connect(_on_resume)
	_quit_btn.pressed.connect(_on_quit)
	_set_input_active(false)

## Godot 4 quirk: CanvasLayer.visible = false does NOT disable input
## on its child Controls. Combined with `process_mode = WHEN_PAUSED`
## on the CanvasLayer (.tscn), this belt-and-suspenders ensures the
## pause menu's Dimmer/Panel never absorb clicks while hidden.
## See failure-modes.md #14.
func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func toggle() -> void:
	if visible:
		_on_resume()
	else:
		open()

func open() -> void:
	get_tree().paused = true
	show()
	_set_input_active(true)
	_resume_btn.grab_focus()

func _on_resume() -> void:
	get_tree().paused = false
	hide()
	_set_input_active(false)
	resumed.emit()

func _on_quit() -> void:
	get_tree().paused = false
	quit_requested.emit()
	get_tree().quit()
