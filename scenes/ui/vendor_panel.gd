extends CanvasLayer
## Vendor UI. Two columns: vendor wares (left, buy) and player
## backpack (right, sell). Top bar shows player gold + vendor name.
## Esc closes per the testing.md modal contract.

@onready var _panel: PanelContainer = $Panel
@onready var _title: Label = $Panel/Margin/VBox/Header/Title
@onready var _gold_label: Label = $Panel/Margin/VBox/Header/Gold
@onready var _wares_box: VBoxContainer = $Panel/Margin/VBox/Cols/WaresCol/WaresList
@onready var _backpack_box: VBoxContainer = $Panel/Margin/VBox/Cols/BackCol/BackList
@onready var _status: Label = $Panel/Margin/VBox/Footer/Status

var _stock: MerchantStock = null
var _inventory: Inventory = null
var _wallet: Wallet = null

func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_input_active(false)

func open_for(npc_name: String, stock: MerchantStock, inv: Inventory, w: Wallet) -> void:
	_stock = stock
	_inventory = inv
	_wallet = w
	_title.text = npc_name
	if _wallet != null and not _wallet.gold_changed.is_connected(_on_gold_changed):
		_wallet.gold_changed.connect(_on_gold_changed)
	if _inventory != null and not _inventory.inventory_changed.is_connected(_refresh):
		_inventory.inventory_changed.connect(_refresh)
	visible = true
	_set_input_active(true)
	_status.text = ""
	_refresh()

func close() -> void:
	visible = false
	_set_input_active(false)

func toggle() -> void:
	if visible:
		close()

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

func _on_gold_changed(_amt: int) -> void:
	_refresh_gold()

func _refresh_gold() -> void:
	_gold_label.text = "%d g" % (_wallet.gold if _wallet != null else 0)

func _refresh() -> void:
	_refresh_gold()
	_render_wares()
	_render_backpack()

func _render_wares() -> void:
	for c in _wares_box.get_children():
		c.queue_free()
	if _stock == null:
		return
	for id in _stock.item_ids():
		var item: ItemData = Database.get_item(id) as ItemData
		if item == null:
			continue
		var price := _stock.buy_price(id)
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(320, 0)
		row.text = "%-22s  %d g" % [item.display_name, price]
		var affordable := _wallet != null and _wallet.gold >= price
		var has_room := _inventory != null and not _inventory.is_full()
		row.disabled = not (affordable and has_room and price > 0)
		row.pressed.connect(_on_buy.bind(id, price))
		_wares_box.add_child(row)

func _render_backpack() -> void:
	for c in _backpack_box.get_children():
		c.queue_free()
	if _inventory == null:
		return
	for i in _inventory.backpack.size():
		var id: StringName = _inventory.backpack[i]
		var item: ItemData = Database.get_item(id) as ItemData
		var row := Button.new()
		row.flat = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(300, 0)
		if item == null:
			row.text = "[%d] ?" % (i + 1)
			row.disabled = true
		else:
			var price := _stock.sell_price(id) if _stock != null else 0
			row.text = "[%d] %-20s  +%d g" % [i + 1, item.display_name, price]
			row.disabled = price <= 0
			if price > 0:
				row.pressed.connect(_on_sell.bind(id, price))
		_backpack_box.add_child(row)

func _on_buy(id: StringName, price: int) -> void:
	if _wallet == null or _inventory == null:
		return
	if _inventory.is_full():
		_set_status("Backpack is full.", false)
		return
	if not _wallet.spend_gold(price):
		_set_status("Not enough gold.", false)
		return
	_inventory.add_item(id)
	var item: ItemData = Database.get_item(id) as ItemData
	_set_status("Bought %s for %d g." % [item.display_name if item != null else String(id), price], true)

func _on_sell(id: StringName, price: int) -> void:
	if _wallet == null or _inventory == null:
		return
	if not _inventory.remove_item(id):
		_set_status("Could not remove item.", false)
		return
	_wallet.add_gold(price)
	var item: ItemData = Database.get_item(id) as ItemData
	_set_status("Sold %s for %d g." % [item.display_name if item != null else String(id), price], true)

func _set_status(msg: String, ok: bool) -> void:
	_status.text = msg
	_status.modulate = Color(0.85, 0.95, 0.65, 1) if ok else Color(0.95, 0.55, 0.45, 1)
