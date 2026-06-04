extends Node
## Stage 9.7 polish diagnostic — instantiate Forsaken Depths in a
## verifier context, simulate the portal entry path, and print exactly
## where the player would land. Repro for the "spawn at corner" bug
## that wasn't being caught by --verify9_7 structural checks.

func _ready() -> void:
	print("--- Maw spawn diag ---")
	# Load + instantiate the depths the way Game.transit_to_zone does.
	var packed: PackedScene = load("res://scenes/zones/forsaken_depths.tscn") as PackedScene
	var depths := packed.instantiate() as Zone
	add_child(depths)
	# Direct probe — what does the marker resolution return?
	var has_entry: bool = depths.has_marker(&"DepthsEntry")
	var entry_pos: Vector2 = depths.get_marker_position(&"DepthsEntry")
	var spawn_pos: Vector2 = depths.get_spawn_position()
	var entry_node: Marker2D = depths.get_node_or_null(^"DepthsEntry") as Marker2D
	print("has_marker('DepthsEntry') = %s" % has_entry)
	print("get_marker_position('DepthsEntry') = %s" % str(entry_pos))
	print("get_spawn_position() = %s" % str(spawn_pos))
	if entry_node != null:
		print("DepthsEntry.position (local) = %s" % str(entry_node.position))
		print("DepthsEntry.global_position = %s" % str(entry_node.global_position))
	# Spire reference
	var spire := depths.get_node_or_null(^"AscentSpire") as Node2D
	if spire != null:
		print("AscentSpire.global_position = %s" % str(spire.global_position))
	# Anchor positions
	var anchors := depths.get_node_or_null(^"SpawnAnchors")
	if anchors != null:
		for c in anchors.get_children():
			var m := c as Marker2D
			if m != null:
				print("Anchor %s @ %s" % [m.name, str(m.global_position)])
	print("--- end diag ---")
	get_tree().quit()
