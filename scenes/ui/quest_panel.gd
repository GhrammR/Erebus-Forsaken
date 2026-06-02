extends CanvasLayer
## Quest dialog UI. Shows the current quest's title + appropriate
## text based on QuestSystem state, and exposes Accept / Turn In
## buttons that drive the state forward. Esc / E closes per the
## modal contract.

@onready var _title: Label = $Panel/Margin/VBox/Title
@onready var _body: RichTextLabel = $Panel/Margin/VBox/Body
@onready var _accept_btn: Button = $Panel/Margin/VBox/Buttons/AcceptBtn
@onready var _turnin_btn: Button = $Panel/Margin/VBox/Buttons/TurnInBtn
@onready var _close_btn: Button = $Panel/Margin/VBox/Buttons/CloseBtn
@onready var _status: Label = $Panel/Margin/VBox/Status

var _quest_id: StringName = &""
var _inventory: Inventory = null
var _wallet: Wallet = null

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_accept_btn.pressed.connect(_on_accept)
	_turnin_btn.pressed.connect(_on_turnin)
	_close_btn.pressed.connect(close)
	QuestSystem.quest_state_changed.connect(_on_quest_state_changed)
	_set_input_active(false)

func open_for(quest_id: StringName, inv: Inventory, w: Wallet) -> void:
	_quest_id = quest_id
	_inventory = inv
	_wallet = w
	# Make sure completion state reflects the player's current
	# inventory before we decide which buttons to show.
	QuestSystem.evaluate(_quest_id, _inventory)
	visible = true
	_set_input_active(true)
	_status.text = ""
	_refresh()

func close() -> void:
	visible = false
	_set_input_active(false)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE or ke.keycode == KEY_E:
		close()
		get_viewport().set_input_as_handled()

func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func _on_quest_state_changed(_id: StringName, _state: int) -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	var q: QuestData = QuestSystem.get_quest(_quest_id)
	if q == null:
		_title.text = "(unknown quest)"
		_body.text = ""
		return
	_title.text = q.title
	var state := QuestSystem.get_state(_quest_id)
	var item_name := ""
	if q.required_item_id != &"":
		var item: ItemData = Database.get_item(q.required_item_id) as ItemData
		if item != null:
			item_name = item.display_name
	match state:
		QuestSystem.State.NOT_OFFERED, QuestSystem.State.OFFERED:
			_body.text = q.offer_text + _objective_line(q, item_name)
			_accept_btn.visible = true
			_turnin_btn.visible = false
		QuestSystem.State.ACCEPTED:
			_body.text = q.in_progress_text + _objective_line(q, item_name)
			_accept_btn.visible = false
			_turnin_btn.visible = false
		QuestSystem.State.COMPLETED:
			_body.text = q.turn_in_text + _reward_line(q)
			_accept_btn.visible = false
			_turnin_btn.visible = true
		QuestSystem.State.TURNED_IN:
			_body.text = "[i]" + q.turn_in_text + "[/i]\n\n(completed)"
			_accept_btn.visible = false
			_turnin_btn.visible = false

func _objective_line(q: QuestData, item_name: String) -> String:
	if q.required_item_id == &"":
		return ""
	return "\n\n[i]Objective:[/i] Bring %s × %d." % [item_name, q.required_count]

func _reward_line(q: QuestData) -> String:
	var parts: PackedStringArray = []
	if q.reward_gold > 0:
		parts.append("%d g" % q.reward_gold)
	if q.reward_item_id != &"":
		var item: ItemData = Database.get_item(q.reward_item_id) as ItemData
		if item != null:
			parts.append(item.display_name)
	if parts.is_empty():
		return ""
	return "\n\n[i]Reward:[/i] " + ", ".join(parts)

func _on_accept() -> void:
	QuestSystem.accept(_quest_id)
	_status.text = "Quest accepted."
	_status.modulate = Color(0.85, 0.95, 0.65, 1)

func _on_turnin() -> void:
	if QuestSystem.turn_in(_quest_id, _inventory, _wallet):
		_status.text = "Quest complete."
		_status.modulate = Color(0.85, 0.95, 0.65, 1)
	else:
		_status.text = "Cannot turn in right now."
		_status.modulate = Color(0.95, 0.55, 0.45, 1)
