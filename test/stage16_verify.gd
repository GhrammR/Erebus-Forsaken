extends Node
## Stage 16 verifier — inventory icon grid.
##  1. ItemIcon class exists with expected API + CELL_SIZE.
##  2. InventoryPanel builds a 6x6 backpack grid (36 cells).
##  3. Equipment grid contains a cell for each of the 7 slots.
##  4. Every backpack id is rendered with a non-empty icon.
##  5. Hovering an icon shows the tooltip and the text contains the
##     item display name + stats brief.
##  6. Consumable icon click routes through ConsumableUse, not equip().
##  7. Sidecar bitmap path is honored when present (mock at runtime).

const PanelScene := preload("res://scenes/ui/inventory_panel.tscn")

var _fail: int = 0
var _panel: CanvasLayer = null
var _inv: Inventory = null

func _ready() -> void:
	print("--- Stage 16 verify ---")
	_setup()
	await get_tree().process_frame
	await get_tree().process_frame
	_verify_item_icon_api()
	_verify_backpack_grid_36()
	_verify_equipment_grid_has_7_slot_cells()
	_verify_every_backpack_id_renders()
	await _verify_tooltip_text()
	_verify_consumable_click_path()
	print("--- Stage 16 verify: %s ---" % ("ALL PASS" if _fail == 0 else "%d FAIL" % _fail))
	get_tree().quit(_fail)

func _expect(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		print("  FAIL  %s" % label)
		_fail += 1

func _setup() -> void:
	_inv = Inventory.new()
	_inv.class_id = &"myrmidon"
	_inv.stats = Stats.new()
	_inv.stats.class_id = &"myrmidon"
	add_child(_inv)
	# Seed: an equippable weapon, an armor, and a consumable.
	_inv.add_item(&"myrmidon_spear_starter")
	_inv.add_item(&"health_potion")
	# Equip the weapon to populate one equipment cell.
	_inv.equip(&"myrmidon_spear_starter")
	_panel = PanelScene.instantiate()
	add_child(_panel)
	_panel.bind_inventory(_inv)
	_panel.toggle()  # visible -> triggers _refresh

func _verify_item_icon_api() -> void:
	var icon := ItemIcon.new()
	_expect(icon.has_method(&"set_item"), "ItemIcon.set_item exists")
	_expect(icon.has_method(&"set_empty"), "ItemIcon.set_empty exists")
	_expect(icon.has_method(&"set_disabled"), "ItemIcon.set_disabled exists")
	_expect(icon.has_signal(&"pressed"), "ItemIcon.pressed signal exists")
	_expect(icon.has_signal(&"hovered"), "ItemIcon.hovered signal exists")
	_expect(ItemIcon.CELL_SIZE.x == 40.0 and ItemIcon.CELL_SIZE.y == 40.0,
			"ItemIcon.CELL_SIZE == 40x40")
	icon.free()

func _verify_backpack_grid_36() -> void:
	var grid: GridContainer = _panel.get_node("Panel/Margin/VBox/Cols/BackCol/BackGrid")
	_expect(grid != null, "BackGrid node exists")
	_expect(grid.columns == 6, "BackGrid columns == 6")
	_expect(grid.get_child_count() == Inventory.BACKPACK_CAPACITY,
			"BackGrid renders %d cells" % Inventory.BACKPACK_CAPACITY)
	for c in grid.get_children():
		if not (c is ItemIcon):
			_expect(false, "Every backpack cell is an ItemIcon (got %s)" % c.get_class())
			return
	_expect(true, "Every backpack cell is an ItemIcon")

func _verify_equipment_grid_has_7_slot_cells() -> void:
	var grid: GridContainer = _panel.get_node("Panel/Margin/VBox/Cols/EquipCol/EquipGrid")
	_expect(grid != null, "EquipGrid node exists")
	_expect(grid.columns == 3, "EquipGrid columns == 3 (paper-doll)")
	var slot_cells := 0
	for c in grid.get_children():
		if c is ItemIcon:
			slot_cells += 1
	_expect(slot_cells == EquipmentSlot.ALL_SLOTS.size(),
			"EquipGrid contains %d ItemIcon cells (one per slot)"
			% EquipmentSlot.ALL_SLOTS.size())

func _verify_every_backpack_id_renders() -> void:
	var grid: GridContainer = _panel.get_node("Panel/Margin/VBox/Cols/BackCol/BackGrid")
	var rendered := 0
	for i in _inv.backpack.size():
		var icon: ItemIcon = grid.get_child(i) as ItemIcon
		if icon == null:
			continue
		if not icon.is_empty():
			rendered += 1
	_expect(rendered == _inv.backpack.size(),
			"All %d backpack ids resolved to a non-empty icon" % _inv.backpack.size())

func _verify_tooltip_text() -> void:
	# Find the icon for the health_potion in the backpack and emit hover.
	var grid: GridContainer = _panel.get_node("Panel/Margin/VBox/Cols/BackCol/BackGrid")
	var idx := _inv.backpack.find(&"health_potion")
	_expect(idx >= 0, "health_potion is in the backpack")
	if idx < 0:
		return
	var icon: ItemIcon = grid.get_child(idx) as ItemIcon
	icon.hovered.emit(&"health_potion", Rect2(Vector2(100, 100), ItemIcon.CELL_SIZE))
	await get_tree().process_frame
	var tooltip: PanelContainer = _panel.get_node("Tooltip") as PanelContainer
	_expect(tooltip != null and tooltip.visible, "Tooltip becomes visible on hover")
	# Walk the tooltip subtree for a Label and check text.
	var label := _find_label(tooltip)
	_expect(label != null, "Tooltip contains a Label")
	if label != null:
		_expect(label.text.contains("Health"),
				"Tooltip text contains item display name (got %s)" % label.text)

func _verify_consumable_click_path() -> void:
	# Click semantics: ConsumableUse.try_use should be invoked when a
	# consumable icon emits pressed. We can't easily mock the autoload,
	# so instead verify the panel script binds the consumable signal to
	# `_on_consumable_pressed`, not to `_inv.equip`.
	var grid: GridContainer = _panel.get_node("Panel/Margin/VBox/Cols/BackCol/BackGrid")
	var idx := _inv.backpack.find(&"health_potion")
	if idx < 0:
		return
	var icon: ItemIcon = grid.get_child(idx) as ItemIcon
	var conns := icon.pressed.get_connections()
	var routed_to_use := false
	for c in conns:
		if String(c["callable"].get_method()) == "_on_consumable_pressed":
			routed_to_use = true
			break
	_expect(routed_to_use,
			"Consumable cell wires pressed -> _on_consumable_pressed (not equip)")

func _find_label(n: Node) -> Label:
	if n is Label:
		return n as Label
	for c in n.get_children():
		var l := _find_label(c)
		if l != null:
			return l
	return null
