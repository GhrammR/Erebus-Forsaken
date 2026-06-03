class_name ShadeWretch extends WildernessEnemy
## Hunched melee predator from the Reach. Closes fast, swings a
## short claw arc, retreats only when dead. Cheapest threat in the
## wilderness — designed to be killable in 2-3 player swings while
## chip-damaging an unaware target.
##
## Damage delivery uses the standard Enemy hitbox (configured in the
## .tscn) — we arm it briefly inside the attack window and disarm
## via deferred timers (failure-modes #17).

const SWING_LEAD: float = 0.12
const SWING_WINDOW: float = 0.18

@onready var _hitbox: HitboxComponent = $HitboxComponent

func _ready() -> void:
	super._ready()
	if _hitbox != null:
		_hitbox.owner_body = self

func _perform_attack(dir: Vector2) -> void:
	if _hitbox == null:
		return
	# Park the hitbox in front of the wretch, aligned with attack dir.
	_hitbox.position = dir * 22.0
	_hitbox.rotation = dir.angle()
	get_tree().create_timer(SWING_LEAD).timeout.connect(_hitbox.arm)
	get_tree().create_timer(SWING_LEAD + SWING_WINDOW).timeout.connect(_hitbox.disarm)
