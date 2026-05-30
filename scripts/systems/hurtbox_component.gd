class_name HurtboxComponent extends Area2D
## Receives hits from HitboxComponents. Routes through the owning
## HealthComponent so the audit-mandated path (HC.take_damage ->
## DamageResolver -> stats.take_damage) is the only damage path.

@export var health: HealthComponent

func _ready() -> void:
	# Convention: HurtboxComponent and HealthComponent are siblings on
	# the same entity. Allow explicit override via @export, but default
	# to the sibling lookup so .tscn authoring stays simple.
	if health == null and get_parent() != null:
		health = get_parent().get_node_or_null(^"HealthComponent") as HealthComponent
	area_entered.connect(_on_area_entered)

func _on_area_entered(other: Area2D) -> void:
	var hb := other as HitboxComponent
	if hb == null or health == null:
		return
	if hb.has_hit(owner):
		return
	hb.register_hit(owner)
	health.take_damage(hb.spawn_attack())
