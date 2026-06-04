extends CanvasLayer
## Stage 9.7 — endless-run summary modal. Surfaces wave / kills / gold /
## time + the seed string for sharing. Opens on player death during
## an active endless run (game.gd routes here instead of DeathScreen);
## "Return to Crypt" calls EndlessRun.rollback() which reloads the
## pre-portal save and respawns the player in ForsakenCrypt R3.
##
## Esc-to-close matches the modal contract in rules/testing.md, but
## "close" here means "return to crypt" — there is no in-arena state
## to fall back into, the run is over either way.

@onready var _wave_label: Label = $Panel/Center/VBox/Stats/WaveValue
@onready var _kills_label: Label = $Panel/Center/VBox/Stats/KillsValue
@onready var _gold_label: Label = $Panel/Center/VBox/Stats/GoldValue
@onready var _time_label: Label = $Panel/Center/VBox/Stats/TimeValue
@onready var _seed_value: LineEdit = $Panel/Center/VBox/SeedRow/SeedValue
@onready var _copy_button: Button = $Panel/Center/VBox/SeedRow/CopyButton
@onready var _return_button: Button = $Panel/Center/VBox/ReturnButton

signal return_requested

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_copy_button.pressed.connect(_on_copy_pressed)
	_return_button.pressed.connect(_on_return_pressed)
	_set_input_active(false)

func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func show_summary(stats: Dictionary) -> void:
	_wave_label.text = str(int(stats.get("wave", 0)))
	_kills_label.text = str(int(stats.get("kills", 0)))
	_gold_label.text = "%d g" % int(stats.get("gold_gained", 0))
	_time_label.text = _format_time(int(stats.get("elapsed_ms", 0)))
	_seed_value.text = String(stats.get("seed_string", ""))
	show()
	_set_input_active(true)
	_return_button.grab_focus.call_deferred()

func hide_summary() -> void:
	hide()
	_set_input_active(false)

func _format_time(ms: int) -> String:
	var s: int = ms / 1000
	return "%02d:%02d" % [s / 60, s % 60]

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set(_seed_value.text)

func _on_return_pressed() -> void:
	return_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		return_requested.emit()
		get_viewport().set_input_as_handled()
