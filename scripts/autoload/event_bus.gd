extends Node
## Global signal hub. WHITELIST — see AD-08 in
## .agent_governance/rules/architecture-decisions.md.
##
## Adding a signal here requires explicit user approval. Per-scene
## signals belong on the emitter, not on the bus.

signal enemy_died(enemy: Node, killer: Node)
signal item_dropped(item_id: StringName, world_pos: Vector2)
signal item_picked_up(item_id: StringName)
signal player_died
signal player_leveled(new_level: int)
signal zone_changed(zone_id: StringName)
signal stats_changed(owner: Node)
