class_name Zone extends Node2D
## Base class for any persistent area the player can walk in
## (threshold camp, wilderness, dungeons). A zone owns its geometry,
## colliders, decorative elements, and a set of named markers (spawn
## point, NPC slots). It does NOT own the Player — the Player is
## passed in from outside via attach_player(). This keeps zones
## decoupled from save state and lets workbenches inject their own
## test players.

## Per AD-08, zone_changed is on the EventBus whitelist. Zone subclasses
## emit it from _ready so HUD/quest/save listeners can react.

@export var zone_id: StringName = &""

func _ready() -> void:
	if zone_id != &"":
		GameState.current_zone_id = zone_id
		EventBus.zone_changed.emit(zone_id)

## Where the player appears on first entry / after death. Subclasses
## set this via a Marker2D node named "SpawnPoint" by convention.
func get_spawn_position() -> Vector2:
	var m := get_node_or_null(^"SpawnPoint") as Marker2D
	return m.global_position if m != null else global_position

## Generic lookup for named NPC slots (Marker2D children named e.g.
## "VendorSpot", "QuestSpot"). Returns ZERO if not found — callers
## who need to distinguish "not found" from "marker at world origin"
## should use `has_marker()` first.
func get_marker_position(marker_name: StringName) -> Vector2:
	var m := get_node_or_null(NodePath(String(marker_name))) as Marker2D
	if m == null:
		return Vector2.ZERO
	return m.global_position

## Explicit existence check. Stage 9.7 polish — `_place_player_for_arrival`
## used `mp != Vector2.ZERO` as a "marker exists" probe, which silently
## failed for `DepthsEntry` at (0, 0) and dropped the player at a
## fallback position instead of dead-centre in The Maw.
func has_marker(marker_name: StringName) -> bool:
	return get_node_or_null(NodePath(String(marker_name))) != null

## Inject the active player. The zone places the player at its spawn
## point and ensures the player's respawn_position is wired to the
## zone — so dying in this zone returns the player here, not to a
## stale world-origin position.
func attach_player(player: Node) -> void:
	if player == null:
		return
	var spawn := get_spawn_position()
	if player is Node2D:
		(player as Node2D).global_position = spawn
	if "respawn_position" in player:
		player.respawn_position = spawn
