class_name HitboxComponent extends Area2D
## Carries an Attack template. Disabled by default; arm() enables the
## collision shape during a swing, disarm() turns it off again. Tracks
## targets hit during the current swing so a single swing cannot hit
## the same Hurtbox twice.

@export var owner_body: Node
@export var base_damage: int = 0
@export var damage_type: DamageType.Type = DamageType.Type.PHYSICAL
@export var flags: int = 0

@onready var _shape: CollisionShape2D = $CollisionShape2D

var _hit_this_swing: Array[Node] = []

func _ready() -> void:
	# Always defer collision-shape state changes. If a hitbox is added
	# to the tree during a physics callback (e.g., a skill spawning a
	# follow-up hitbox from a hit signal), a synchronous `disabled = ...`
	# triggers "Can't change this state while flushing queries". See
	# failure-modes #17.
	_shape.set_deferred(&"disabled", true)
	# AD-09 lives or dies by this: Area2D.input_pickable defaults to true
	# and would silently consume mouse clicks within the hitbox.
	# A 40-radius cleave circle around the player would otherwise create
	# an 80-pixel dead zone for click-to-move. See failure-modes.md #13.
	input_pickable = false
	# Default owner_body to the enclosing entity (typical case).
	if owner_body == null:
		owner_body = _find_entity_owner()

func _find_entity_owner() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n is CharacterBody2D:
			return n
		n = n.get_parent()
	return null

func arm() -> void:
	_hit_this_swing.clear()
	_shape.set_deferred(&"disabled", false)

func disarm() -> void:
	_shape.set_deferred(&"disabled", true)

func spawn_attack() -> Attack:
	var a := Attack.new()
	a.source = owner_body
	a.base_damage = base_damage
	a.damage_type = damage_type
	a.flags = flags
	return a

## Called by HurtboxComponent on overlap. Returns true if this swing
## already registered a hit on the given target.
func has_hit(target: Node) -> bool:
	return target in _hit_this_swing

func register_hit(target: Node) -> void:
	if not target in _hit_this_swing:
		_hit_this_swing.append(target)
