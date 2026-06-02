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

## Esc closes the pause menu while paused. PlayerInput lives on the
## Player which uses the default pausable process mode, so its
## `_unhandled_input` stops firing while `get_tree().paused == true` —
## the open key never reaches it. The CanvasLayer for this scene is
## set to `WHEN_PAUSED`, so `_input` here continues to receive events.
## See testing.md "Modal UI — Esc-to-close contract".
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE:
		_on_resume()
		get_viewport().set_input_as_handled()
