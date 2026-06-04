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

## Stage 9.7 — endless mode lifecycle. `started` fires each time a
## new wave begins (including wave 1 on portal entry); the HUD reads
## both wave number + per-wave kill quota off this. `completed` fires
## when the quota is met and the lull starts. `ended` fires on player
## death or rollback with the run's final stats dictionary.
signal endless_wave_started(wave: int, kills_required: int)
signal endless_wave_completed(wave: int)
signal endless_run_ended(stats: Dictionary)
