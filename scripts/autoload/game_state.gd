extends Node
## Run-scoped state. Holds references that the player session needs but
## that should not be sprinkled across scripts via get_node chains.
##
## See .agent_governance/rules/scene-architecture.md — this autoload is
## state, not behavior. No combat math, no save logic, no zone routing.

var player: Node = null
var current_zone_id: StringName = &""

const BUILD_VERSION: String = "0.0.1"

func reset_run() -> void:
	player = null
	current_zone_id = &""
