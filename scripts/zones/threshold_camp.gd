class_name ThresholdCamp extends Zone
## The threshold camp — last lit ground before the primordial void.
## Layout is roughly a flattened oval: central fire pit, 2-3 tents
## arranged around it, perimeter ring of braziers casting a thin halo
## of light into the dark. Player walks freely inside; perimeter
## braziers and a thin invisible wall ring keep the player from
## strolling into the void (no zone exits exist yet — Stage 7 portal).

func _ready() -> void:
	zone_id = &"threshold_camp"
	super._ready()
	_animate_fire_pit()

func _animate_fire_pit() -> void:
	var pit := get_node_or_null(^"FirePit") as Node2D
	if pit == null:
		return
	var ap := pit.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if ap == null:
		return
	if ap.has_animation(&"flicker"):
		ap.play(&"flicker")
