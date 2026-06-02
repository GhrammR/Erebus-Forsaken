class_name Portal extends Npc
## A zone-transit interactable. Behaves exactly like an Npc for the
## purposes of click-to-interact, proximity prompt, and selection
## ring — the player walks up, sees "[E] Threshold Camp" (or whatever
## display_name is set to), and pressing E (or arriving at a click-
## targeted portal) routes through SceneRouter.go_to_zone(target_zone).
##
## Extending Npc is a deliberate reuse: the interaction contract is
## identical, and rebuilding it would duplicate the silhouette hit
## test, range tracking, and selection-ring wiring already proven in
## Stage 6. Semantically the base class is "in-world interactable" —
## the name Npc just happens to be where the pattern was first paid
## for.

@export var target_zone: StringName = &""

## Portal silhouette is wider/taller than an Npc character — override
## the click hit-test rectangle so ground-clicks adjacent to the stone
## don't engage, but clicks on the stone or glyph do.
func click_hits(world_pos: Vector2, _radius: float) -> bool:
	var d := world_pos - global_position
	return absf(d.x) < 22.0 and d.y > -52.0 and d.y < 14.0

func interact() -> void:
	if target_zone == &"":
		push_warning("Portal '%s' has no target_zone set." % display_name)
		return
	interacted.emit(self)
	SceneRouter.go_to_zone(target_zone)
