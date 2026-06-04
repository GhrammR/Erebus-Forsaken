extends Node
## Build-flag autoload. Reads project settings under
## `application/feature_flags/*` so a single project.godot toggle
## flips between demo and full builds without touching scenes.
##
## Demo build: hides the endless-mode portal in the boss room
## (Stage 9.7) and any other post-launch content gated explicitly
## on the flag. `launch-plan.md` is the source of truth for what
## demo_mode covers.

var demo_mode: bool = false

func _ready() -> void:
	demo_mode = bool(ProjectSettings.get_setting(
			"application/feature_flags/demo_mode", false))
