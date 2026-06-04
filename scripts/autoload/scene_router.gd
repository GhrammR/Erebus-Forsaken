extends Node
## Owns zone transitions. No script may call
## get_tree().change_scene_to_file() directly — go through here.
##
## In Act 1 the Game host (scenes/game.gd) keeps Player + UI alive
## across zone changes and swaps the zone subtree in-place. The host
## registers itself via set_zone_host(); SceneRouter then delegates
## go_to_zone to host.transit_to_zone(zone_id). Workbenches and dev
## scenes may register a stub host to opt out cleanly.
##
## See .agent_governance/rules/scene-architecture.md.

const ZONE_PATHS: Dictionary = {
	&"threshold_camp": "res://scenes/zones/threshold_camp.tscn",
	&"blighted_reach": "res://scenes/zones/blighted_reach.tscn",
	&"forsaken_crypt": "res://scenes/zones/forsaken_crypt.tscn",
	&"forsaken_depths": "res://scenes/zones/forsaken_depths.tscn",
}

var _host: Object = null

func set_zone_host(host: Object) -> void:
	_host = host

func clear_zone_host(host: Object) -> void:
	if _host == host:
		_host = null

func zone_scene_path(zone_id: StringName) -> String:
	return String(ZONE_PATHS.get(zone_id, ""))

func go_to_zone(zone_id: StringName, arrival_marker: StringName = &"") -> void:
	if not ZONE_PATHS.has(zone_id):
		push_error("SceneRouter: unknown zone_id %s" % zone_id)
		return
	if _host != null and _host.has_method(&"transit_to_zone"):
		_host.transit_to_zone(zone_id, arrival_marker)
		return
	# Fallback: standalone scene swap. Loses Player + UI, so only
	# usable from dev scenes that explicitly want it.
	var path: String = ZONE_PATHS[zone_id]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: zone scene not yet built: %s" % path)
		return
	GameState.current_zone_id = zone_id
	EventBus.zone_changed.emit(zone_id)
	get_tree().change_scene_to_file(path)
