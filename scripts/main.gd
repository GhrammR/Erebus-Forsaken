extends Node2D

@onready var _build_label: Label = $BuildLabel
@onready var _hint_label: Label = $HintLabel

func _ready() -> void:
	_build_label.text = "Erebus Forsaken — build %s" % GameState.BUILD_VERSION
	_hint_label.text = "Stage 0 bootstrap — Esc to quit"

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_quit") or event.is_action_pressed("ui_cancel"):
		get_tree().quit()
