extends CanvasLayer
## Stage 4 inventory UI — text + buttons. Click a backpack row to equip.
## Click an equipment row to unequip. Drag-drop paper-doll is Stage 12.

@onready var _panel: PanelContainer = $Panel
@onready var _equip_box: VBoxContainer = $Panel/Margin/VBox/Cols/EquipCol/EquipScroll/EquipList
@onready var _backpack_box: VBoxContainer = $Panel/Margin/VBox/Cols/BackCol/BackScroll/BackList
@onready var _equip_title: Label = $Panel/Margin/VBox/Cols/EquipCol/Title
@onready var _back_title: Label = $Panel/Margin/VBox/Cols/BackCol/Title
@onready var _capacity_label: Label = $Panel/Margin/VBox/Header/Capacity

var _inventory: Inventory = null

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS  # inventory accessible even when paused
	_set_input_active(false)

## Godot 4 quirk: CanvasLayer.visible = false does NOT disable input
## handling on child Controls. We must also disable mouse_filter
## everywhere or those Controls eat clicks behind the curtain. See
## failure-modes.md #14.
func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func bind_inventory(inv: Inventory) -> void:
	if _inventory == inv:
		return
	if _inventory != null:
		if _inventory.inventory_changed.is_connected(_refresh):
			_inventory.inventory_changed.disconnect(_refresh)
	_inventory = inv
	if _inventory != null:
		_inventory.inventory_changed.connect(_refresh)
	_refresh()

func toggle() -> void:
	visible = not visible
	_set_input_active(visible)
	if visible:
		_refresh()

## Esc closes the inventory without opening the pause menu. We use
## `_input` (priority above `_unhandled_input`) so we can mark the
## event handled before PlayerInput sees it and emits pause_pressed.
## Same pattern applies to any future modal UI — close yourself on
## Esc and mark the event handled.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var ke := event as InputEventKey
	if ke == null or not ke.pressed or ke.echo:
		return
	if ke.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()

func _refresh() -> void:
	if _inventory == null:
		return
	_capacity_label.text = "(%d / %d)" % [_inventory.backpack_size(), Inventory.BACKPACK_CAPACITY]
	_render_equipment()
	_render_backpack()

func _render_equipment() -> void:
	_equip_title.text = "EQUIPPED"
	for c in _equip_box.get_children():
		c.queue_free()
	for slot in EquipmentSlot.ALL_SLOTS:
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(280, 0)
		var item: ItemData = _inventory.get_equipped_item(slot)
		if item == null:
			row.text = "%-10s —" % (EquipmentSlot.slot_name(slot) + ":")
			row.disabled = true
		else:
			row.text = "%-10s %s%s" % [
				EquipmentSlot.slot_name(slot) + ":",
				item.display_name,
				_format_brief(item)
			]
			row.pressed.connect(_inventory.unequip.bind(slot))
		_equip_box.add_child(row)

func _render_backpack() -> void:
	_back_title.text = "BACKPACK"
	for c in _backpack_box.get_children():
		c.queue_free()
	for i in _inventory.backpack.size():
		var id: StringName = _inventory.backpack[i]
		var item: ItemData = Database.get_item(id) as ItemData
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(260, 0)
		if item == null:
			row.text = "[%d] ?" % (i + 1)
			row.disabled = true
		elif item.kind == ItemData.Kind.CONSUMABLE:
			# Stage 9.8 — single-click to use, matching the equipment row
			# semantics. Cooldown / channel checks happen in ConsumableUse,
			# which logs the rejection reason via &"consumables" flag.
			row.text = "[%d] %s%s" % [i + 1, item.display_name, _format_consumable_brief(item)]
			var blocked := ConsumableUse.is_on_cooldown(item.cooldown_id) or ConsumableUse.is_channeling()
			row.disabled = blocked
			row.pressed.connect(_on_consumable_pressed.bind(id))
		else:
			row.text = "[%d] %s%s" % [i + 1, item.display_name, _format_brief(item)]
			var can := _inventory.can_equip(item)
			row.disabled = not can
			if can:
				row.pressed.connect(_inventory.equip.bind(id))
		_backpack_box.add_child(row)

func _on_consumable_pressed(item_id: StringName) -> void:
	var player: Node = ConsumableUse.get_active_player()
	if player == null:
		return
	ConsumableUse.try_use(player, item_id, _inventory)
	_refresh()

func _format_consumable_brief(item: ItemData) -> String:
	match item.use_kind:
		ItemData.UseKind.HEARTH_EMBER:
			return "  (channel %.0fs → town)" % item.use_channel_seconds
		ItemData.UseKind.HEAL_OVER_TIME:
			return "  (+%d HP / %.0fs)" % [item.use_flat_amount, item.use_duration]
		ItemData.UseKind.MANA_OVER_TIME:
			return "  (+%d MP / %.0fs)" % [item.use_flat_amount, item.use_duration]
		ItemData.UseKind.INSTANT_BOTH_PCT:
			return "  (+%d%% HP / +%d%% MP)" % [int(item.use_hp_pct * 100.0), int(item.use_mp_pct * 100.0)]
		_:
			return ""

func _format_brief(item: ItemData) -> String:
	var parts: PackedStringArray = []
	if item.base_armor_defense != 0:
		parts.append("+%d DEF" % item.base_armor_defense)
	if item.base_weapon_ar != 0:
		parts.append("+%d AR" % item.base_weapon_ar)
	if item.base_resist != 0:
		parts.append("+%d RES" % item.base_resist)
	for k in item.affixes.keys():
		parts.append("+%d %s" % [int(item.affixes[k]), String(k).to_upper().substr(0, 3)])
	if parts.is_empty():
		return ""
	return "  (" + ", ".join(parts) + ")"
