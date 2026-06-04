class_name ForsakenDepths extends Zone
## Stage 9.7 polish — the endless trial reframed as a procedurally
## scaling descent below the crypt's boss room. Lore-coherent with
## the dungeon theme (the player broke the seal; what crawls up from
## below is what they fight). Mechanically identical to the original
## endless_arena — a single fixed room hosted by an EndlessDirector
## with per-floor scaling — but the framing reads as "floors of a
## descent" so HUD strings, summary modal, and reward language can
## all use that lexicon.
##
## Player enters via the `DepthsEntry` marker (set by SceneRouter on
## arrival from the crypt's descent portal). No in-world exit: the
## run ends on death, both routing through the summary modal +
## `EndlessRun.rollback()` to the pre-portal save.

func _ready() -> void:
	zone_id = &"forsaken_depths"
	super._ready()

func get_spawn_position() -> Vector2:
	var entry := get_node_or_null(^"DepthsEntry") as Marker2D
	if entry != null:
		return entry.global_position
	return super.get_spawn_position()
