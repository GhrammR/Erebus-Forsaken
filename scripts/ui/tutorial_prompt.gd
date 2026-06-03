class_name TutorialPrompt extends CanvasLayer
## Stage 10 — first-launch tutorial. Non-modal: the player can walk,
## attack, and open menus while it's up. Esc or the "Got it" button
## dismisses it. Once dismissed it never comes back — the flag is
## stored in user://settings.json so a save wipe doesn't re-trigger it.
##
## Spawned by game.gd only on the new-game path (when
## SaveSystem.has_save() was false at boot and the player came in
## through character select).

const _SETTINGS_PATH: String = "user://settings.json"
const _FLAG_KEY: String = "has_seen_tutorial"

@onready var _panel: PanelContainer = $Panel
@onready var _got_it_button: Button = $Panel/VBox/GotItButton

func _ready() -> void:
	_got_it_button.pressed.connect(dismiss)
	visible = true

static func has_seen_tutorial() -> bool:
	if not FileAccess.file_exists(_SETTINGS_PATH):
		return false
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return false
	return bool((parsed as Dictionary).get(_FLAG_KEY, false))

static func mark_seen() -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(_SETTINGS_PATH):
		var rf := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
		if rf != null:
			var parsed: Variant = JSON.parse_string(rf.get_as_text())
			rf.close()
			if parsed is Dictionary:
				data = parsed
	data[_FLAG_KEY] = true
	var wf := FileAccess.open(_SETTINGS_PATH, FileAccess.WRITE)
	if wf == null:
		push_warning("TutorialPrompt: could not write %s" % _SETTINGS_PATH)
		return
	wf.store_string(JSON.stringify(data, "\t"))
	wf.close()

func dismiss() -> void:
	mark_seen()
	queue_free()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		# Eat Esc so the pause menu doesn't open at the same time.
		get_viewport().set_input_as_handled()
		dismiss()
