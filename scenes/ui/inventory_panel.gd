extends CanvasLayer
## Stage 4 inventory UI — text + buttons. Click a backpack row to equip.
## Click an equipment row to unequip. Drag-drop paper-doll is Stage 12.

@onready var _panel: PanelContainer = $Panel
@onready var _equip_box: VBoxContainer = $Panel/Margin/VBox/Cols/EquipCol/EquipList
@onready var _backpack_box: VBoxContainer = $Panel/Margin/VBox/Cols/BackCol/BackList
@onready var _equip_title: Label = $Panel/Margin/VBox/Cols/EquipCol/Title
@onready var _back_title: Label = $Panel/Margin/VBox/Cols/BackCol/Title
@onready var _capacity_label: Label = $Panel/Margin/VBox/Header/Capacity

var _inventory: Inventory = null

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS  # inventory accessible even when paused

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
	if visible:
		_refresh()

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
		else:
			row.text = "[%d] %s%s" % [i + 1, item.display_name, _format_brief(item)]
			var can := _inventory.can_equip(item)
			row.disabled = not can
			if can:
				row.pressed.connect(_inventory.equip.bind(id))
		_backpack_box.add_child(row)

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
