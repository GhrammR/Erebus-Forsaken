extends CanvasLayer
## Stage 16 — icon grid inventory. Equipment column is a 3-col paper-doll
## grid (Head top, Weapon bottom-left, Offhand bottom-right, etc.).
## Backpack is a 6×6 grid of ItemIcon cells. Single-click semantics
## persist from Stage 4: equipment equips/unequips, consumable uses.
## Drag/drop is parked.

const _BACK_COLUMNS: int = 6

# Equipment paper-doll layout (Diablo 2-style). 3 cols x 3 rows.
# Weapon/Offhand flank the Head (where main-hand/off-hand sit in D2);
# Amulet/Ring flank the Chest; Legs sits alone at the bottom-center.
const _EQUIP_LAYOUT: Array = [
	EquipmentSlot.Slot.WEAPON, EquipmentSlot.Slot.HEAD,  EquipmentSlot.Slot.OFFHAND,
	EquipmentSlot.Slot.AMULET, EquipmentSlot.Slot.CHEST, EquipmentSlot.Slot.RING,
	null,                      EquipmentSlot.Slot.LEGS,  null,
]

@onready var _panel: PanelContainer = $Panel
@onready var _equip_grid: GridContainer = $Panel/Margin/VBox/Cols/EquipCol/EquipGrid
@onready var _backpack_grid: GridContainer = $Panel/Margin/VBox/Cols/BackCol/BackGrid
@onready var _equip_title: Label = $Panel/Margin/VBox/Cols/EquipCol/Title
@onready var _back_title: Label = $Panel/Margin/VBox/Cols/BackCol/Title
@onready var _capacity_label: Label = $Panel/Margin/VBox/Header/Capacity

var _inventory: Inventory = null
var _tooltip: PanelContainer = null
var _tooltip_label: Label = null

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backpack_grid.columns = _BACK_COLUMNS
	_equip_grid.columns = 3
	_build_tooltip()
	_set_input_active(false)

func _build_tooltip() -> void:
	# Parent the tooltip directly under the CanvasLayer (not a cell) so
	# the GridContainer/ScrollContainer can't clip it. See failure-modes.
	_tooltip = PanelContainer.new()
	_tooltip.name = "Tooltip"
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 100
	_tooltip.hide()
	_tooltip_label = Label.new()
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.add_theme_color_override(&"font_color", Color(0.85, 0.78, 0.55))
	var m := MarginContainer.new()
	m.add_theme_constant_override(&"margin_left", 8)
	m.add_theme_constant_override(&"margin_right", 8)
	m.add_theme_constant_override(&"margin_top", 6)
	m.add_theme_constant_override(&"margin_bottom", 6)
	m.add_child(_tooltip_label)
	_tooltip.add_child(m)
	add_child(_tooltip)

func _set_input_active(active: bool) -> void:
	var target := Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
	_apply_filter_recursive(self, target)
	# Tooltip stays IGNORE so it never eats clicks.
	if _tooltip != null:
		_apply_filter_recursive(_tooltip, Control.MOUSE_FILTER_IGNORE)

func _apply_filter_recursive(n: Node, target: int) -> void:
	if n is Control:
		(n as Control).mouse_filter = target
	for child in n.get_children():
		_apply_filter_recursive(child, target)

func bind_inventory(inv: Inventory) -> void:
	if _inventory == inv:
		return
	if _inventory != null and _inventory.inventory_changed.is_connected(_refresh):
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
	else:
		_hide_tooltip()

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
	_capacity_label.text = "(%d / %d)" % [
		_inventory.backpack_size(), Inventory.BACKPACK_CAPACITY,
	]
	_render_equipment()
	_render_backpack()

func _render_equipment() -> void:
	_equip_title.text = "EQUIPPED"
	for c in _equip_grid.get_children():
		c.queue_free()
	for entry in _EQUIP_LAYOUT:
		if entry == null:
			var spacer := Control.new()
			spacer.custom_minimum_size = ItemIcon.CELL_SIZE
			spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_equip_grid.add_child(spacer)
			continue
		var slot: int = entry
		var icon := ItemIcon.new()
		icon.name = "Slot_%s" % EquipmentSlot.slot_name(slot)
		_equip_grid.add_child(icon)
		var item: ItemData = _inventory.get_equipped_item(slot)
		if item == null:
			icon.set_empty()
			icon.set_disabled(true)
		else:
			icon.set_item(_inventory.get_equipped_id(slot), item, EquipmentVisuals.tier_for(item))
			# Local handler — Godot's Callable.bind() appends args, so
			# `unequip.bind(slot)` connected to `pressed(item_id)` would
			# call `unequip(item_id, slot)` and silently fail.
			icon.pressed.connect(_on_unequip_slot.bind(slot))
			icon.hovered.connect(_on_icon_hover)
			icon.unhovered.connect(_hide_tooltip)

func _render_backpack() -> void:
	_back_title.text = "BACKPACK"
	for c in _backpack_grid.get_children():
		c.queue_free()
	var ids := _inventory.backpack
	var total := Inventory.BACKPACK_CAPACITY
	for i in total:
		var icon := ItemIcon.new()
		_backpack_grid.add_child(icon)
		if i >= ids.size():
			icon.set_empty()
			continue
		var id: StringName = ids[i]
		var item: ItemData = Database.get_item(id) as ItemData
		if item == null:
			icon.set_empty()
			continue
		icon.set_item(id, item, EquipmentVisuals.tier_for(item))
		icon.hovered.connect(_on_icon_hover)
		icon.unhovered.connect(_hide_tooltip)
		if item.kind == ItemData.Kind.CONSUMABLE:
			var blocked := ConsumableUse.is_on_cooldown(item.cooldown_id) or ConsumableUse.is_channeling()
			icon.set_disabled(blocked)
			if not blocked:
				icon.pressed.connect(_on_consumable_pressed)
		else:
			var can := _inventory.can_equip(item)
			icon.set_disabled(not can)
			if can:
				icon.pressed.connect(_on_equip_pressed)

func _on_icon_hover(item_id: StringName, screen_rect: Rect2) -> void:
	var item: ItemData = Database.get_item(item_id) as ItemData
	if item == null:
		_hide_tooltip()
		return
	_tooltip_label.text = _tooltip_text_for(item)
	_position_tooltip(screen_rect)
	_tooltip.show()

func _position_tooltip(anchor: Rect2) -> void:
	# Place tooltip just below the cell; if it overflows, place it above.
	_tooltip.reset_size()
	var sz := _tooltip.size
	var vp := get_viewport().get_visible_rect().size
	var pos := Vector2(anchor.position.x, anchor.position.y + anchor.size.y + 4)
	if pos.y + sz.y > vp.y:
		pos.y = anchor.position.y - sz.y - 4
	pos.x = clamp(pos.x, 4.0, vp.x - sz.x - 4.0)
	_tooltip.position = pos

func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.hide()

func _on_equip_pressed(item_id: StringName) -> void:
	if _inventory != null:
		_inventory.equip(item_id)

func _on_unequip_slot(_item_id: StringName, slot: int) -> void:
	if _inventory != null:
		_inventory.unequip(slot)

func _on_consumable_pressed(item_id: StringName) -> void:
	var player: Node = ConsumableUse.get_active_player()
	if player == null:
		return
	ConsumableUse.try_use(player, item_id, _inventory)
	_refresh()

func _tooltip_text_for(item: ItemData) -> String:
	var lines: PackedStringArray = [item.display_name]
	if item.kind == ItemData.Kind.CONSUMABLE:
		var brief := _format_consumable_brief(item)
		if brief != "":
			lines.append(brief.strip_edges())
	else:
		var brief := _format_brief(item)
		if brief != "":
			lines.append(brief.strip_edges())
		lines.append("Slot: %s" % EquipmentSlot.slot_name(item.slot))
	return "\n".join(lines)

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
	if item.base_weapon_damage != 0:
		parts.append("+%d DMG" % item.base_weapon_damage)
	if item.base_resist != 0:
		parts.append("+%d RES" % item.base_resist)
	for k in item.affixes.keys():
		parts.append("+%d %s" % [int(item.affixes[k]), String(k).to_upper().substr(0, 3)])
	if parts.is_empty():
		return ""
	return "  (" + ", ".join(parts) + ")"
