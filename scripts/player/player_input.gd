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
signal skill_1_pressed           ## Stage 5: 1 fires the class's primary skill
signal debug_kill_self_pressed   ## Stage 3 workbench: K to demo death/respawn
signal inventory_toggle_pressed  ## Stage 4: I toggles inventory
signal save_pressed              ## Stage 4: F5
signal load_pressed              ## Stage 4: F9
signal interact_pressed          ## Stage 6: E to talk to nearest in-range NPC

const ARRIVE_THRESHOLD: float = 4.0
## Stuck detection: if click-to-move is active but the body hasn't moved
## STUCK_MIN_MOVEMENT pixels per physics frame for STUCK_FRAMES in a row,
## the target is considered unreachable (e.g., the player clicked on a
## dummy or inside a wall). The target is cleared.
const STUCK_FRAMES: int = 20            ## ~0.33 s at 60 fps
const STUCK_MIN_MOVEMENT: float = 1.0   ## px per physics frame

@export var owner_body: CharacterBody2D

var _click_target: Vector2 = Vector2.ZERO
var _has_click_target: bool = false
var _last_intent: Vector2 = Vector2.ZERO
var _stuck_frames: int = 0
var _prev_pos: Vector2 = Vector2.ZERO

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
		elif ke.keycode == KEY_1:
			skill_1_pressed.emit()
		elif ke.keycode == KEY_K:
			debug_kill_self_pressed.emit()
		elif ke.keycode == KEY_I:
			inventory_toggle_pressed.emit()
		elif ke.keycode == KEY_F5:
			save_pressed.emit()
		elif ke.keycode == KEY_F9:
			load_pressed.emit()
		elif ke.keycode == KEY_E:
			interact_pressed.emit()
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
		_stuck_frames = 0
	elif _has_click_target:
		var to_target := _click_target - owner_body.global_position
		if to_target.length() <= ARRIVE_THRESHOLD:
			_has_click_target = false
			click_target_cleared.emit()
			_stuck_frames = 0
			dir = Vector2.ZERO
		else:
			dir = to_target.normalized()
			# Stuck detection: tried to move but isn't actually moving.
			# Cause: collision with something between us and the target
			# (e.g., clicking on a dummy or inside a wall).
			var moved := (owner_body.global_position - _prev_pos).length()
			if moved < STUCK_MIN_MOVEMENT:
				_stuck_frames += 1
				if _stuck_frames >= STUCK_FRAMES:
					_has_click_target = false
					click_target_cleared.emit()
					_stuck_frames = 0
					dir = Vector2.ZERO
			else:
				_stuck_frames = 0
	else:
		dir = Vector2.ZERO
		_stuck_frames = 0

	_prev_pos = owner_body.global_position

	if dir != _last_intent:
		_last_intent = dir
		move_intent_changed.emit(dir)

func get_click_target() -> Vector2:
	return _click_target

func has_click_target() -> bool:
	return _has_click_target

## Drop any pending click-to-move target. Called on death/respawn
## (so the player doesn't keep walking toward their pre-death click)
## and during scene transitions. Emits click_target_cleared if a
## target was active so the marker hides too.
func clear_click_target() -> void:
	if not _has_click_target:
		return
	_has_click_target = false
	_stuck_frames = 0
	_last_intent = Vector2.ZERO
	move_intent_changed.emit(Vector2.ZERO)
	click_target_cleared.emit()
