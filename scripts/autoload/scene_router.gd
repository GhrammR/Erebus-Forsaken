extends Node
## Owns zone transitions. No script may call
## get_tree().change_scene_to_file() directly — go through here.
##
## See .agent_governance/rules/scene-architecture.md.

const ZONE_PATHS: Dictionary = {
	&"town": "res://scenes/zones/town.tscn",
	&"wilderness": "res://scenes/zones/wilderness.tscn",
	&"dungeon": "res://scenes/zones/dungeon.tscn",
}

func go_to_zone(zone_id: StringName) -> void:
	if not ZONE_PATHS.has(zone_id):
		push_error("SceneRouter: unknown zone_id %s" % zone_id)
		return
	var path: String = ZONE_PATHS[zone_id]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: zone scene not yet built: %s" % path)
		return
	GameState.current_zone_id = zone_id
	EventBus.zone_changed.emit(zone_id)
	get_tree().change_scene_to_file(path)
