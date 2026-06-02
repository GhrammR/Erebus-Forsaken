extends Node2D
## Walk-over gold pickup. Spawned by Enemy._try_drop_gold on a roll.
## On overlap with the player body, transfers `value` into the
## player's Wallet, emits EventBus.item_picked_up with a sentinel id,
## then frees itself. Mirrors WorldItem.gd's pickup pattern.

const SENTINEL_ID: StringName = &"_gold"
const PICKUP_RADIUS: float = 28.0
const COIN_COLOR := Color(0.95, 0.84, 0.35, 1)

@export var value: int = 1

var _picked: bool = false

@onready var _pickup: Area2D = $PickupArea
@onready var _label: Label = $ValueLabel
@onready var _visual: Polygon2D = $Visual

func _ready() -> void:
	_pickup.input_pickable = false
	_visual.color = COIN_COLOR
	_label.text = "%d g" % value
	_pickup.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _picked:
		return
	var wallet := _find_wallet(body)
	if wallet == null:
		return
	wallet.add_gold(value)
	_picked = true
	EventBus.item_picked_up.emit(SENTINEL_ID)
	queue_free()

func _find_wallet(body: Node) -> Wallet:
	var p: Node = body
	while p != null:
		var w := p.get_node_or_null(^"Wallet") as Wallet
		if w != null:
			return w
		p = p.get_parent()
	return null
