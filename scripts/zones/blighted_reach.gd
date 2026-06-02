class_name BlightedReach extends Zone
## The Blighted Reach — first wilderness zone outside the threshold
## camp. Wider, darker, sparse dead trees, no fire-pit safety. The
## player enters via the south portal from camp and exits via the
## same portal back (Stage 7 Phase 1 is traversal only — spawn
## director and enemies land in Phase 2/3).
##
## Spawn anchors for the future spawn director live in a
## "SpawnAnchors" Node2D as Marker2D children; Phase 3 will scan
## them. Phase 1 ignores them entirely.

func _ready() -> void:
	zone_id = &"blighted_reach"
	super._ready()
