extends Control
## Stage 9.8 — HUD potion bar. Three slots: HP (red), MP (blue), Ichor
## (gold). Each slot shows the current backpack count of that consumable
## and a CooldownVeil that shrinks as ConsumableUse counts down the
## per-type cooldown. Mirrors SkillIcon's veil pattern so the visual
## language stays consistent.
##
## The bar binds the player's inventory once via bind_player(); after
## that it polls counts in _process. Cheap (3 array scans, no allocs).
## Re-bind when the active class swaps.

const SLOT_SIZE: Vector2 = Vector2(40, 40)
const SLOT_GAP: float = 6.0

const _SLOTS: Array[Dictionary] = [
	{
		"item_id":     &"health_potion",
		"cooldown_id": &"potion_health",
		"hotkey":      "2",
		"fill_color":  Color(0.82, 0.18, 0.22, 0.85),
		"border":      Color(0.55, 0.15, 0.18, 1.0),
	},
	{
		"item_id":     &"mana_potion",
		"cooldown_id": &"potion_mana",
		"hotkey":      "3",
		"fill_color":  Color(0.32, 0.45, 0.92, 0.85),
		"border":      Color(0.22, 0.30, 0.62, 1.0),
	},
	{
		"item_id":     &"ichor_potion",
		"cooldown_id": &"potion_ichor",
		"hotkey":      "",
		"fill_color":  Color(0.98, 0.82, 0.32, 0.90),
		"border":      Color(0.62, 0.50, 0.18, 1.0),
	},
]

var _inventory: Inventory = null
var _slot_nodes: Array[Dictionary] = []  # { panel, fill, veil, count_label, hotkey_label }

func _ready() -> void:
	custom_minimum_size = Vector2(
		_SLOTS.size() * SLOT_SIZE.x + (_SLOTS.size() - 1) * SLOT_GAP,
		SLOT_SIZE.y + 12.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()

func bind_player(player: Node) -> void:
	if player == null or not ("get_inventory" in player):
		_inventory = null
		return
	_inventory = player.get_inventory()

func _build_slots() -> void:
	for c in get_children():
		c.queue_free()
	_slot_nodes.clear()
	for i in _SLOTS.size():
		var slot: Dictionary = _SLOTS[i]
		var x: float = i * (SLOT_SIZE.x + SLOT_GAP)
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.position = Vector2(x, 0.0)
		panel.size = SLOT_SIZE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.06, 0.06, 0.08, 0.92)
		bg.border_width_left = 1
		bg.border_width_top = 1
		bg.border_width_right = 1
		bg.border_width_bottom = 1
		bg.border_color = slot["border"]
		bg.corner_radius_top_left = 4
		bg.corner_radius_top_right = 4
		bg.corner_radius_bottom_left = 4
		bg.corner_radius_bottom_right = 4
		panel.add_theme_stylebox_override(&"panel", bg)
		add_child(panel)

		var fill := ColorRect.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.position = Vector2(4, 4)
		fill.size = SLOT_SIZE - Vector2(8, 8)
		fill.color = slot["fill_color"]
		panel.add_child(fill)

		var veil := ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.position = Vector2(1, 1)
		veil.size = SLOT_SIZE - Vector2(2, 2)
		veil.color = Color(0, 0, 0, 0.65)
		panel.add_child(veil)

		var hotkey_label := Label.new()
		hotkey_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotkey_label.position = Vector2(3, 1)
		hotkey_label.size = Vector2(14, 14)
		hotkey_label.add_theme_color_override(&"font_color", Color(0.85, 0.85, 0.7, 1))
		hotkey_label.text = slot["hotkey"]
		panel.add_child(hotkey_label)

		var count_label := Label.new()
		count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count_label.position = Vector2(0, 26)
		count_label.size = Vector2(SLOT_SIZE.x, 14)
		count_label.add_theme_color_override(&"font_color", Color(0.98, 0.95, 0.85, 1))
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.text = "0"
		panel.add_child(count_label)

		_slot_nodes.append({
			"panel":         panel,
			"veil":          veil,
			"count_label":   count_label,
		})

func _process(_delta: float) -> void:
	for i in _SLOTS.size():
		var slot: Dictionary = _SLOTS[i]
		var nodes: Dictionary = _slot_nodes[i]
		var count := _count_in_backpack(slot["item_id"])
		(nodes["count_label"] as Label).text = str(count)
		var cd_max := ConsumableUse.get_cooldown_max(slot["cooldown_id"])
		var cd_rem := ConsumableUse.get_cooldown_remaining(slot["cooldown_id"])
		var fraction := 0.0 if cd_max <= 0.0 else clampf(cd_rem / cd_max, 0.0, 1.0)
		(nodes["veil"] as ColorRect).color.a = 0.65 * fraction
		# Empty slots dim to half-opacity to read as "you have none".
		(nodes["panel"] as Panel).modulate = Color(1, 1, 1, 1) if count > 0 else Color(1, 1, 1, 0.45)

func _count_in_backpack(item_id: StringName) -> int:
	if _inventory == null:
		return 0
	var n := 0
	for id in _inventory.backpack:
		if id == item_id:
			n += 1
	return n
