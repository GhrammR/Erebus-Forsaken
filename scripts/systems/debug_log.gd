extends Node
## Stage 9.7 polish — flag-gated debug logging. CLI:
##
##   godot -- --debug=transit,combat        # enable named flags
##   godot -- --debug=all                    # enable everything
##   godot -- --debug=transit --debug-file=run.log
##
## Each call site tags itself with a StringName flag. Messages are
## printed only when that flag (or `all`) is enabled. Silent by
## default, so production builds are unaffected.
##
## Categories (extend as new systems land):
##   transit  — zone changes, player teleport, settle, marker resolution
##   combat   — attacks, damage applied/taken, kills
##   input    — clicks, keys, click target lifecycle
##   items    — pickups, drops, equip / unequip
##   save     — save / load / migration
##   endless  — wave start/complete, milestone grants, run lifecycle
##   ai       — enemy state transitions, target acquisition, LOS
##   physics  — collisions, position deltas, push-out events
##   skills   — cast, cooldown ticks, MP spends
##   ui       — modal open/close, HUD updates
##   consumables — potion use, cooldown start/expire, ember channel state, regen ticks
##
## Format on stdout (and the optional log file):
##   [T+12345ms][flag] message
##
## Add new flags by simply calling `log(&"newflag", ...)` — the
## allow-list is implicit and `all` always enables them.

var enabled_flags: Dictionary = {}  # StringName -> true
var _log_file: FileAccess = null
var _start_ms: int = 0

func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	_parse_cli_args()

func _parse_cli_args() -> void:
	for arg in OS.get_cmdline_user_args():
		var s := String(arg)
		if s.begins_with("--debug="):
			var rhs := s.substr(8)
			for raw in rhs.split(",", false):
				var name := raw.strip_edges()
				if name == "":
					continue
				enabled_flags[StringName(name)] = true
		elif s.begins_with("--debug-file="):
			var path := s.substr(13).strip_edges()
			if path != "":
				_open_log_file(path)
	# Surface the enabled set at startup so the user can confirm
	# their flags parsed.
	if not enabled_flags.is_empty():
		print("[DebugLog] enabled flags: %s" % str(enabled_flags.keys()))
		if _log_file != null:
			print("[DebugLog] log file: %s" % _log_file.get_path())

func _open_log_file(path: String) -> void:
	_log_file = FileAccess.open(path, FileAccess.WRITE)
	if _log_file == null:
		push_warning("DebugLog: could not open log file %s" % path)

## True if this flag (or `all`) is on. Cheap — call site can guard
## an expensive serialise.
func is_enabled(flag: StringName) -> bool:
	return enabled_flags.has(&"all") or enabled_flags.has(flag)

## Emit a tagged message. Silent if flag isn't enabled.
## Method named `write` (not `log`) because GDScript's `log()` is the
## global natural-logarithm function — defining `func log(...)` on
## an autoload shadows it project-wide and breaks any script that
## calls `log()` for math. Lesson saved in
## `rules/failure-modes.md` for future autoload authors.
func write(flag: StringName, msg: String) -> void:
	if not is_enabled(flag):
		return
	var line := "[T+%dms][%s] %s" % [
			Time.get_ticks_msec() - _start_ms, String(flag), msg]
	print(line)
	if _log_file != null:
		_log_file.store_line(line)
		_log_file.flush()

func warn(flag: StringName, msg: String) -> void:
	write(flag, "WARN: " + msg)

func error(flag: StringName, msg: String) -> void:
	write(flag, "ERROR: " + msg)
