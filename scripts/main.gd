extends Node2D

@onready var _build_label: Label = $BuildLabel
@onready var _hint_label: Label = $HintLabel

func _ready() -> void:
	# Headless test runners. Pass after "--" so Godot ignores them.
	var args := OS.get_cmdline_user_args()
	if "--verify" in args:
		add_child(load("res://test/stage1_verify.tscn").instantiate())
		return
	if "--verify3" in args:
		add_child(load("res://test/stage3_verify.tscn").instantiate())
		return
	if "--verify4" in args:
		add_child(load("res://test/stage4_verify.tscn").instantiate())
		return
	if "--workbench" in args:
		add_child(load("res://test/stat_workbench.tscn").instantiate())
		return
	if "--movement" in args:
		add_child(load("res://test/movement_workbench.tscn").instantiate())
		return
	if "--combat" in args:
		add_child(load("res://test/combat_workbench.tscn").instantiate())
		return
	if "--loot" in args:
		add_child(load("res://test/loot_workbench.tscn").instantiate())
		return
	_build_label.text = "Erebus Forsaken — build %s" % GameState.BUILD_VERSION
	_hint_label.text = "Stage 4 — F6 on test/loot_workbench.tscn for loot/inventory/save. Esc quits."

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_quit") or event.is_action_pressed("ui_cancel"):
		get_tree().quit()
