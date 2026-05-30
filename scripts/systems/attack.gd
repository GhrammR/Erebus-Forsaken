class_name Attack extends Resource
## AD-05 — every incoming hit carries an Attack. DamageResolver
## (Stage 3) consumes this against a defender's Stats. Stage 1 only
## records the shape; resolution is a no-op pass-through.

## NB: source is not @export because Resources cannot serialize Node refs.
## Attacks are constructed in code per-hit, not authored as .tres files.
var source: Node = null
@export var base_damage: int = 0
@export var damage_type: DamageType.Type = DamageType.Type.PHYSICAL
@export var flags: int = 0
