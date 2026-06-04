class_name AscentSpire extends Npc
## Stage 9.7 polish — temporary in-world exit for The Maw. Without
## this, the descent has no non-death exit and the player gets
## trapped on a run they can't push further. Interact ends the
## current EndlessRun, which the Game host listens for via
## EventBus.endless_run_ended and routes through the summary modal +
## rollback chain.
##
## TEMPORARY. The Stage 9.8 Hearth Ember (consumable, works from
## anywhere) is the intended long-term answer; once Embers ship the
## spire can stay as flavour or get retired.

func _ready() -> void:
	display_name = "Ascend"
	super._ready()

func interact() -> void:
	interacted.emit(self)
	if EndlessRun.active:
		EndlessRun.end_run()

## Tighter click hit-rect than the default Npc — the spire is taller
## and narrower than a humanoid silhouette.
func click_hits(world_pos: Vector2, _radius: float) -> bool:
	var d := world_pos - global_position
	return absf(d.x) < 18.0 and d.y > -56.0 and d.y < 8.0
