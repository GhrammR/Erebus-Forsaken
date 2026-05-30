class_name PlayerInput extends Node
## AD-09 — click-to-move primary, WASD secondary. Both feed the same
## movement state machine (the Player's `_intent` vector). WASD wins
## the moment any movement key is pressed: it clears any pending click
## target.
##
## Esc is captured directly here (not as an input action) so that
## main.tscn's quit-on-Esc keeps working — main does not include a
## PlayerInput, only gameplay scenes do.

signal move_intent_changed(direction: Vector2)
signal pause_pressed
signal click_target_set(world_pos: Vector2)
signal click_target_cleared
signal attack_pressed
signal debug_kill_self_pressed   ## Stage 3 workbench: K to demo death/respawn

const ARRIVE_THRESHOLD: float = 4.0

@export var owner_body: CharacterBody2D

var _click_target: Vector2 = Vector2.ZERO
var _has_click_target: bool = false
var _last_intent: Vector2 = Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and owner_body != null:
			_click_target = owner_body.get_global_mouse_position()
			_has_click_target = true
			click_target_set.emit(_click_target)
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		if ke.keycode == KEY_ESCAPE:
			pause_pressed.emit()
			get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_SPACE:
			attack_pressed.emit()
		elif ke.keycode == KEY_K:
			debug_kill_self_pressed.emit()
		elif ke.keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
			# WASD overrides click target the moment a key is pressed.
			if _has_click_target:
				_has_click_target = false
				click_target_cleared.emit()

func _physics_process(_delta: float) -> void:
	if owner_body == null:
		return
	var wasd := Vector2(
		Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
		Input.get_action_strength(&"move_down")  - Input.get_action_strength(&"move_up")
	)
	var dir: Vector2
	if wasd != Vector2.ZERO:
		dir = wasd.normalized()
		if _has_click_target:
			_has_click_target = false
			click_target_cleared.emit()
	elif _has_click_target:
		var to_target := _click_target - owner_body.global_position
		if to_target.length() <= ARRIVE_THRESHOLD:
			_has_click_target = false
			click_target_cleared.emit()
			dir = Vector2.ZERO
		else:
			dir = to_target.normalized()
	else:
		dir = Vector2.ZERO

	if dir != _last_intent:
		_last_intent = dir
		move_intent_changed.emit(dir)

func get_click_target() -> Vector2:
	return _click_target

func has_click_target() -> bool:
	return _has_click_target
