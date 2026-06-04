extends Node
## Stage 9.5 — Feel Pass hit-stop pulse. Crits only, per feel-pass.md.
## `pulse(frames := 3)` slams Engine.time_scale to 0.0 for ~frames at
## 60 Hz then restores to 1.0. A second pulse during a running one
## extends the freeze rather than stacking — the player's perception
## is "the world held its breath," not "the game lagged."
##
## Sleep with a one-shot SceneTreeTimer rather than awaiting frames,
## so the freeze doesn't depend on _process running (which it can't,
## since time_scale is zero). Timers tick on real time when paused-
## like behaviour is needed via `process_always`.

const _FRAME_SECONDS: float = 1.0 / 60.0

var _active_until_msec: int = -1

func pulse(frames: int = 3) -> void:
	if frames <= 0:
		return
	var duration_ms := int(round(float(frames) * _FRAME_SECONDS * 1000.0))
	var end_msec := Time.get_ticks_msec() + duration_ms
	if end_msec <= _active_until_msec:
		return  # already-running pulse covers this request
	_active_until_msec = end_msec
	Engine.time_scale = 0.0
	# Use a SceneTreeTimer with process_always=true so it ticks
	# regardless of time_scale.
	var t := get_tree().create_timer(float(duration_ms) / 1000.0, true, false, true)
	t.timeout.connect(_on_pulse_end.bind(end_msec))

func _on_pulse_end(end_msec: int) -> void:
	# Another pulse may have extended us; only restore if this is the
	# tail of the longest pulse.
	if end_msec < _active_until_msec:
		return
	Engine.time_scale = 1.0
	_active_until_msec = -1
