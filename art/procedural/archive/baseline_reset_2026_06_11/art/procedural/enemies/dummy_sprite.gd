extends "res://scripts/systems/sprite_runtime_2d.gd"
## Procedural training-dummy sprite. Scene-authored geometry plus the
## shared sprite runtime keeps it editable in pose_tuner like enemies/NPCs.

func _ready() -> void:
	sprite_id = &"training_dummy"
	stance_bucket = &"enemies"
	setup_sprite_runtime()
