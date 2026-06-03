extends Node2D

@onready var _build_label: Label = $BuildLabel
@onready var _hint_label: Label = $HintLabel
@onready var _background: ColorRect = $Background

func _ready() -> void:
	# Headless test runners. Pass after "--" so Godot ignores them.
	var args := OS.get_cmdline_user_args()
	# Hide the title-screen chrome by default; the --splash branch
	# re-shows it. Without this, any workbench launched through
	# main.tscn would render the splash Background ColorRect (a
	# 1280x720 dark box anchored at world (0,0)) on top of the
	# scene's geometry — exactly where the player ends up walking.
	_build_label.hide()
	_hint_label.hide()
	_background.hide()
	if "--verify" in args:
		add_child(load("res://test/stage1_verify.tscn").instantiate())
		return
	if "--verify3" in args:
		add_child(load("res://test/stage3_verify.tscn").instantiate())
		return
	if "--verify4" in args:
		add_child(load("res://test/stage4_verify.tscn").instantiate())
		return
	if "--verify5" in args:
		add_child(load("res://test/stage5_verify.tscn").instantiate())
		return
	if "--verify6" in args:
		add_child(load("res://test/stage6_verify.tscn").instantiate())
		return
	if "--verify7" in args:
		add_child(load("res://test/stage7_verify.tscn").instantiate())
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
	if "--skills" in args:
		add_child(load("res://test/skills_workbench.tscn").instantiate())
		return
	if "--town" in args:
		add_child(load("res://test/town_workbench.tscn").instantiate())
		return
	if "--splash" in args:
		_build_label.show()
		_hint_label.show()
		_background.show()
		_build_label.text = "Erebus Forsaken — build %s" % GameState.BUILD_VERSION
		_hint_label.text = "Splash. Pass --town for the dev town workbench. Esc quits."
		return
	# Default boot — straight into the game (threshold camp, town
	# auto-resumes from save if one exists). Pass --splash to keep
	# the title screen, or any workbench flag to bypass.
	add_child(load("res://scenes/game.tscn").instantiate())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_quit") or event.is_action_pressed("ui_cancel"):
		get_tree().quit()
