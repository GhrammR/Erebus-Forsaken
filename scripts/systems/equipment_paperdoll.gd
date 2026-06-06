class_name EquipmentPaperdoll extends Node
## Stage 15 — listens to Inventory.equipment_changed and maintains the
## procedural overlay nodes on the class sprite.
##
## Ownership:
##   - Armor overlays (HEAD/CHEST/LEGS/OFFHAND) live as children of the
##     class sprite's `Body` node so they walk with the idle/walk bob
##     animations.
##   - WEAPON visibility is the class sprite's own weapon-arm node
##     (SpearArm/StaffArm/BowArm/WandArm) — paperdoll toggles .visible
##     rather than building a new node, preserving the existing
##     AnimationPlayer tracks that already animate it.
##
## Bare-hands rule:
##   - WEAPON slot empty -> weapon arm hidden.
##   - WEAPON slot occupied -> weapon arm shown (re-tinted via modulate).

const _ARMOR_SLOTS: Array[int] = [
	EquipmentSlot.Slot.HEAD,
	EquipmentSlot.Slot.CHEST,
	EquipmentSlot.Slot.LEGS,
	EquipmentSlot.Slot.OFFHAND,
]

var _inventory: Inventory = null
var _sprite_root: Node = null
var _class_id: StringName = &""

## slot -> Array[Polygon2D] (empty when slot is unequipped / no visual).
## Multiple parts per slot supports anatomy-following overlays like
## per-leg greaves mounted under each KneePivot.
var _armor_overlays: Dictionary = {}
## Cached original modulate for the built-in weapon arm and offhand
## node, so we can restore them when a slot is unequipped.
var _weapon_arm_default_modulate: Color = Color(1, 1, 1, 1)
var _builtin_offhand_default_modulate: Color = Color(1, 1, 1, 1)
var _builtin_offhand_path: NodePath = NodePath("")

func bind(sprite_root: Node, inv: Inventory, class_id: StringName) -> void:
	# Drop any prior binding cleanly so swapping classes mid-run doesn't
	# leave a stale overlay on the previous sprite (which is queue_freed
	# anyway, but be paranoid).
	if _inventory != null and _inventory.equipment_changed.is_connected(_on_equipment_changed):
		_inventory.equipment_changed.disconnect(_on_equipment_changed)
	for slot_id in _armor_overlays.keys():
		var parts: Array = _armor_overlays[slot_id]
		for node in parts:
			if is_instance_valid(node):
				node.queue_free()
	_armor_overlays.clear()

	_sprite_root = sprite_root
	_inventory = inv
	_class_id = class_id
	_builtin_offhand_path = EquipmentVisuals.builtin_offhand_path_for(class_id)
	_cache_default_modulates()

	if _inventory != null:
		_inventory.equipment_changed.connect(_on_equipment_changed)
		_refresh_all()

func _cache_default_modulates() -> void:
	# Weapon arm default modulate
	var arm_name: StringName = EquipmentVisuals.weapon_arm_for(_class_id)
	if arm_name != &"" and _sprite_root != null:
		var arm: Node2D = _sprite_root.get_node_or_null(NodePath(String(arm_name))) as Node2D
		if arm != null:
			_weapon_arm_default_modulate = arm.modulate
	# Built-in offhand default modulate (Myrmidon Buckler)
	if _builtin_offhand_path != NodePath("") and _sprite_root != null:
		var bn: CanvasItem = _sprite_root.get_node_or_null(_builtin_offhand_path) as CanvasItem
		if bn != null:
			_builtin_offhand_default_modulate = bn.modulate

func _refresh_all() -> void:
	_apply_weapon(_inventory.get_equipped_item(EquipmentSlot.Slot.WEAPON))
	for slot in _ARMOR_SLOTS:
		_apply_armor(slot, _inventory.get_equipped_item(slot))

func _on_equipment_changed(slot: int, item: ItemData) -> void:
	if slot == EquipmentSlot.Slot.WEAPON:
		_apply_weapon(item)
		return
	if slot in _ARMOR_SLOTS:
		_apply_armor(slot, item)
		# Offhand changes the shield-on/off attack variant — rebuild
		# the profile so the next attack uses the right animation.
		if slot == EquipmentSlot.Slot.OFFHAND:
			var weapon: ItemData = _inventory.get_equipped_item(EquipmentSlot.Slot.WEAPON)
			_install_weapon_profile(weapon)

# ---- WEAPON --------------------------------------------------------------

func _apply_weapon(item: ItemData) -> void:
	if _sprite_root == null:
		return
	var arm_name: StringName = EquipmentVisuals.weapon_arm_for(_class_id)
	if arm_name == &"":
		_install_weapon_profile(item)
		return
	var arm: Node2D = _sprite_root.get_node_or_null(NodePath(String(arm_name))) as Node2D
	if arm == null:
		_install_weapon_profile(item)
		return
	if item == null:
		arm.visible = false
	else:
		arm.visible = true
		# Light retint so weapon brightness reads at a glance. The hit-flash
		# tween targets the sprite root's modulate, so a per-arm modulate is
		# safe to stomp here without fighting the feel pass.
		arm.modulate = EquipmentVisuals.tier_color(EquipmentVisuals.tier_for(item))
	_install_weapon_profile(item)

## Stage 17.5 — rebuild the sprite's "attack" animation from the
## WeaponProfiles registry whenever weapon OR offhand changes. The
## profile reads weapon_type from the equipped weapon and shield
## state from the equipped offhand.
func _install_weapon_profile(weapon_item: ItemData) -> void:
	if _sprite_root == null or _inventory == null:
		return
	var offhand: ItemData = _inventory.get_equipped_item(EquipmentSlot.Slot.OFFHAND)
	WeaponProfiles.install(_sprite_root as Node2D, weapon_item, offhand)

# ---- ARMOR ---------------------------------------------------------------

func _apply_armor(slot: int, item: ItemData) -> void:
	# Built-in offhand (Myrmidon Buckler) — retint the existing node
	# instead of building an overlay.
	if slot == EquipmentSlot.Slot.OFFHAND and _builtin_offhand_path != NodePath("") and _sprite_root != null:
		var bn: CanvasItem = _sprite_root.get_node_or_null(_builtin_offhand_path) as CanvasItem
		if bn != null:
			if item == null:
				bn.visible = false
				bn.modulate = _builtin_offhand_default_modulate
			else:
				bn.visible = true
				bn.modulate = EquipmentVisuals.tier_color(EquipmentVisuals.tier_for(item))
		return
	# Clear any prior overlay parts for this slot.
	var prev_parts: Array = _armor_overlays.get(slot, [])
	for prev_node in prev_parts:
		if is_instance_valid(prev_node):
			prev_node.queue_free()
	_armor_overlays.erase(slot)
	if item == null or _sprite_root == null:
		return
	# Multi-part overlay path. Each part declares its mount anatomy
	# node so the overlay articulates with that limb instead of
	# floating at body-fixed coords (the greaves-over-walking-legs
	# bug).
	var parts: Array = EquipmentVisuals.build_overlay_parts(slot, _class_id, item)
	if parts.is_empty():
		return
	var mounted: Array = []
	for part in parts:
		var mount_path: NodePath = part["mount"]
		var poly: Polygon2D = part["poly"]
		var mount: Node = _sprite_root.get_node_or_null(mount_path)
		if mount == null:
			# Mount missing (e.g. sprite hasn't been re-authored on
			# the new anatomy yet). Fall back to sprite root so the
			# part is at least visible somewhere.
			_sprite_root.add_child(poly)
		else:
			mount.add_child(poly)
		mounted.append(poly)
	_armor_overlays[slot] = mounted

# ---- Test introspection --------------------------------------------------

## Returns the FIRST live overlay node for a slot, or null. Used by
## stage15_verify (legacy single-overlay assertion path).
func get_overlay_for(slot: int) -> Polygon2D:
	var parts: Array = _armor_overlays.get(slot, [])
	if parts.is_empty():
		return null
	return parts[0] as Polygon2D

## Returns all live overlay nodes for a slot (multi-part).
func get_overlay_parts_for(slot: int) -> Array:
	return _armor_overlays.get(slot, [])

## Returns the weapon arm node (visible state queryable by tests).
func get_weapon_arm() -> Node2D:
	if _sprite_root == null:
		return null
	var arm_name: StringName = EquipmentVisuals.weapon_arm_for(_class_id)
	if arm_name == &"":
		return null
	return _sprite_root.get_node_or_null(NodePath(String(arm_name))) as Node2D
