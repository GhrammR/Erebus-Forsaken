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

func toggle() -> void:
	if visible:
		_on_resume()
	else:
		open()

func open() -> void:
	get_tree().paused = true
	show()
	_resume_btn.grab_focus()

func _on_resume() -> void:
	get_tree().paused = false
	hide()
	resumed.emit()

func _on_quit() -> void:
	get_tree().paused = false
	quit_requested.emit()
	get_tree().quit()
