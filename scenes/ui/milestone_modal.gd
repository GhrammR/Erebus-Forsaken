extends CanvasLayer
## Stage 9.7 polish — inline milestone reward modal. Pops during an
## active descent when EndlessRun.milestone_reached fires on a floor
## the player just crossed. Pauses the run via Engine.time_scale = 0
## while visible; resumes on the Continue button. The reward itself
## was already applied by EndlessRun._apply_reward before this modal
## opens — the modal is purely the announcement / dopamine beat.

@onready var _title: Label = $Panel/Center/VBox/Title
@onready var _floor_label: Label = $Panel/Center/VBox/FloorLabel
@onready var _reward_label: Label = $Panel/Center/VBox/RewardLabel
@onready var _continue_button: Button = $Panel/Center/VBox/ContinueButton

signal continue_pressed

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_continue_button.pressed.connect(_on_continue)
	_set_input_active(false)

func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func show_milestone(floor: int, reward: Dictionary) -> void:
	_floor_label.text = "Floor %d cleared" % floor
	_reward_label.text = String(reward.get("label", ""))
	show()
	_set_input_active(true)
	Engine.time_scale = 0.0
	_continue_button.grab_focus.call_deferred()

func hide_milestone() -> void:
	hide()
	_set_input_active(false)
	Engine.time_scale = 1.0

func _on_continue() -> void:
	continue_pressed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		continue_pressed.emit()
		get_viewport().set_input_as_handled()
