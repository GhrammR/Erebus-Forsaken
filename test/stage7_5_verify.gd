extends Node
## Stage 7.5 verifier — AudioBank + bus layout + settings persistence.
## Verifies the contracts the audio mini-stage stands up. Asset .oggs
## are not required to exist (placeholder rule applies to audio); the
## bank just needs the right keys.

const _SETTINGS_PATH: String = "user://settings.json"
const _AudioBankScript := preload("res://scripts/autoload/audio_bank.gd")
const _GameScript := preload("res://scenes/game.gd")
const _PlayerScript := preload("res://scripts/player/player.gd")
const _SkillScript := preload("res://scripts/systems/skill.gd")
const _EnemyScript := preload("res://scripts/enemies/enemy.gd")
const _PauseMenuScript := preload("res://scenes/ui/pause_menu.gd")

const _EXPECTED_SFX_KEYS: Array[StringName] = [
	&"swing", &"hit_flesh", &"hit_crit", &"player_hurt",
	&"death_player", &"death_enemy", &"skill_cast", &"skill_ready",
	&"pickup_item", &"pickup_gold", &"drop_rare", &"levelup",
	&"quest_accept", &"quest_complete", &"save", &"load",
]

func _ready() -> void:
	var fail := 0
	print("--- Stage 7.5 verify ---")

	fail = _verify_sfx_bank(fail)
	fail = _verify_ambient_bank(fail)
	fail = _verify_bus_layout(fail)
	fail = _verify_volume_roundtrip(fail)
	fail = _verify_settings_preserves_other_keys(fail)
	fail = _verify_defocus_handler(fail)
	fail = _verify_eventbus_wiring(fail)
	fail = _verify_call_sites(fail)

	print("--- Stage 7.5 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _verify_sfx_bank(fail: int) -> int:
	var keys: Array = AudioBank.sfx_bank_keys()
	# Stage 7.5 introduced 16 entries; later stages append more (Stage 9.8
	# added the Hearth Ember + potion cue family). Keep the floor instead
	# of a hard equality so future stages don't have to rewrite this line.
	var ok_size: bool = keys.size() >= 16
	print("[%s] AudioBank sfx bank has >=16 entries (got %d)" \
			% [("OK  " if ok_size else "FAIL"), keys.size()])
	if not ok_size: fail += 1
	for k in _EXPECTED_SFX_KEYS:
		var present: bool = keys.has(k)
		print("[%s]   sfx key '%s' present" % [("OK  " if present else "FAIL"), k])
		if not present: fail += 1
	return fail

func _verify_ambient_bank(fail: int) -> int:
	var keys: Array = AudioBank.ambient_bank_keys()
	var ok: bool = keys.has(&"threshold_camp") and keys.has(&"blighted_reach")
	print("[%s] ambient bank covers camp + wilderness (got %s)" \
			% [("OK  " if ok else "FAIL"), str(keys)])
	if not ok: fail += 1
	return fail

func _verify_bus_layout(fail: int) -> int:
	for bus in [&"Master", &"Sfx", &"Ambient"]:
		var idx := AudioServer.get_bus_index(bus)
		var ok: bool = idx >= 0
		print("[%s] bus '%s' present in layout (idx=%d)" \
				% [("OK  " if ok else "FAIL"), bus, idx])
		if not ok: fail += 1
	return fail

func _verify_volume_roundtrip(fail: int) -> int:
	_wipe_settings()
	AudioBank.set_master_volume(0.5)
	AudioBank.set_sfx_volume(0.25)
	AudioBank.set_ambient_volume(0.75)
	var m := AudioBank.get_master_volume()
	var s := AudioBank.get_sfx_volume()
	var a := AudioBank.get_ambient_volume()
	var ok_live: bool = absf(m - 0.5) < 0.02 and absf(s - 0.25) < 0.02 \
			and absf(a - 0.75) < 0.02
	print("[%s] bus volume round-trip live (m=%.2f s=%.2f a=%.2f)" \
			% [("OK  " if ok_live else "FAIL"), m, s, a])
	if not ok_live: fail += 1

	AudioBank.save_volumes()
	# Read raw JSON back; that's what the next session will see.
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	var d: Dictionary = parsed if parsed is Dictionary else {}
	var ok_persist: bool = d.has("master_volume") and d.has("sfx_volume") \
			and d.has("ambient_volume")
	print("[%s] save_volumes writes all three keys" \
			% ("OK  " if ok_persist else "FAIL"))
	if not ok_persist: fail += 1

	# Restore neutral so other tests don't run with muted audio.
	AudioBank.set_master_volume(1.0)
	AudioBank.set_sfx_volume(1.0)
	AudioBank.set_ambient_volume(1.0)
	_wipe_settings()
	return fail

func _verify_settings_preserves_other_keys(fail: int) -> int:
	_wipe_settings()
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "has_seen_tutorial": true }, "\t"))
	f.close()
	AudioBank.save_volumes()
	var rf := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	var d: Dictionary = JSON.parse_string(rf.get_as_text()) as Dictionary
	rf.close()
	var ok: bool = d.get("has_seen_tutorial", false) == true \
			and d.has("master_volume")
	print("[%s] save_volumes merges into existing settings dict" \
			% ("OK  " if ok else "FAIL"))
	if not ok: fail += 1
	_wipe_settings()
	return fail

func _verify_defocus_handler(fail: int) -> int:
	# Code-inspection check: the script source mentions the focus
	# notification constants. Triggering window focus events in
	# headless mode isn't reliable.
	var src := FileAccess.get_file_as_string("res://scripts/autoload/audio_bank.gd")
	var ok: bool = "NOTIFICATION_APPLICATION_FOCUS_OUT" in src \
			and "NOTIFICATION_APPLICATION_FOCUS_IN" in src \
			and "set_bus_mute" in src
	print("[%s] AudioBank handles window focus out/in -> bus mute" \
			% ("OK  " if ok else "FAIL"))
	if not ok: fail += 1
	return fail

func _verify_eventbus_wiring(fail: int) -> int:
	var ok_player := EventBus.player_died.is_connected(AudioBank._on_player_died)
	var ok_enemy := EventBus.enemy_died.is_connected(AudioBank._on_enemy_died)
	var ok_item := EventBus.item_picked_up.is_connected(AudioBank._on_item_picked_up)
	var ok_zone := EventBus.zone_changed.is_connected(AudioBank._on_zone_changed)
	for pair in [["player_died", ok_player], ["enemy_died", ok_enemy],
			["item_picked_up", ok_item], ["zone_changed", ok_zone]]:
		print("[%s] AudioBank listens on EventBus.%s" \
				% [("OK  " if pair[1] else "FAIL"), pair[0]])
		if not pair[1]: fail += 1
	return fail

func _verify_call_sites(fail: int) -> int:
	# Code-inspection: the events that already exist have an
	# AudioBank.play_sfx call alongside their existing emit/play.
	var pairs := [
		["scripts/player/player.gd",       "AudioBank.play_sfx(&\"swing\")"],
		["scripts/player/player.gd",       "AudioBank.play_sfx(&\"player_hurt\")"],
		["scripts/enemies/enemy.gd",       "AudioBank.play_sfx(&\"hit_flesh\")"],
		["scripts/enemies/enemy.gd",       "EventBus.enemy_died.emit"],
		["scripts/systems/skill.gd",       "AudioBank.play_sfx(&\"skill_cast\")"],
		["scenes/game.gd",                 "AudioBank.play_sfx(&\"save\")"],
		["scenes/game.gd",                 "AudioBank.play_sfx(&\"load\")"],
		["scenes/game.gd",                 "EventBus.zone_changed.emit(zone_id)"],
	]
	for entry in pairs:
		var path: String = "res://" + entry[0]
		var needle: String = entry[1]
		var src := FileAccess.get_file_as_string(path)
		var ok: bool = needle in src
		print("[%s] %s wired in %s" \
				% [("OK  " if ok else "FAIL"), needle, entry[0]])
		if not ok: fail += 1
	return fail

func _wipe_settings() -> void:
	if FileAccess.file_exists(_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SETTINGS_PATH))
