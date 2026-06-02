extends Node2D
## Ground-drop pickup. Walk-over auto-pickup via Area2D body_entered.
## Inventory is found by walking the player body's tree for an Inventory
## sibling. If the player's inventory is full, the name label flashes
## red and the item stays.

const FULL_FLASH_DURATION: float = 0.6

@export var item_id: StringName = &""

@onready var _glyph: Node2D = $Glyph
@onready var _label: Label = $NameLabel
@onready var _pickup: Area2D = $PickupArea
@onready var _shadow: Polygon2D = $Shadow

var _item: ItemData = null
var _picked: bool = false

func _ready() -> void:
	# Pickup area is walk-over only; never consume mouse clicks.
	# See failure-modes.md #13.
	_pickup.input_pickable = false

	# Shadow ellipse at feet
	var sh: PackedVector2Array = []
	var n := 14
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(10.0 * cos(t), 1.0 + 3.0 * sin(t)))
	_shadow.polygon = sh
	_shadow.color = Color(0, 0, 0, 0.4)

	_apply_item()
	_pickup.body_entered.connect(_on_body_entered)

func set_item(id: StringName) -> void:
	item_id = id
	if is_inside_tree():
		_apply_item()

func _apply_item() -> void:
	_item = Database.get_item(item_id) as ItemData
	if _item == null:
		push_warning("WorldItem: unknown item id %s" % item_id)
		_label.text = "?"
		return
	_label.text = _item.display_name
	_label.modulate = Color(1, 1, 1, 1)
	if _glyph is ItemGlyph:
		(_glyph as ItemGlyph).set_color_glyph(_item.glyph_color)
		(_glyph as ItemGlyph).set_shape(_item.glyph_shape)

func _on_body_entered(body: Node) -> void:
	if _picked or _item == null:
		return
	var inv := _find_inventory(body)
	if inv == null:
		return
	if inv.is_full():
		_flash_full()
		return
	if inv.add_item(item_id):
		_picked = true
		EventBus.item_picked_up.emit(item_id)
		queue_free()

func _find_inventory(body: Node) -> Inventory:
	# Player body is a sibling of an Inventory node on the same parent.
	var p: Node = body
	while p != null:
		var inv := p.get_node_or_null(^"Inventory") as Inventory
		if inv != null:
			return inv
		p = p.get_parent()
	return null

func _flash_full() -> void:
	_label.modulate = Color(1, 0.3, 0.3, 1)
	await get_tree().create_timer(FULL_FLASH_DURATION).timeout
	if is_instance_valid(_label):
		_label.modulate = Color(1, 1, 1, 1)
