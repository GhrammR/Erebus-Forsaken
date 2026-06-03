extends Node
## Stage 10 verifier — class select + tutorial flag. Headless: avoids
## instantiating the full select scene (it leans on its onready @children
## which need a tree the verifier never builds). Asserts the contracts
## the scene depends on:
##   1. Database exposes all four classes in design-intent order
##   2. GameState.pending_class_id round-trips a class pick
##   3. The four ClassData resources resolve cleanly with display names
##   4. TutorialPrompt persistence: mark_seen → has_seen_tutorial true
##   5. Settings file survives an unrelated key being present already
##
## Boot-fork behaviour (main.gd: has_save → game.tscn, no save →
## select.tscn) is asserted by code inspection only — instantiating
## main.tscn from a verifier would re-enter the dispatcher recursively.

const _SETTINGS_PATH: String = "user://settings.json"
const _FLAG_KEY: String = "has_seen_tutorial"
const _TutorialPromptScript := preload("res://scripts/ui/tutorial_prompt.gd")

func _ready() -> void:
	var fail := 0
	print("--- Stage 10 verify ---")

	fail = _verify_class_roster(fail)
	fail = _verify_class_resources(fail)
	fail = _verify_pending_class_roundtrip(fail)
	fail = _verify_tutorial_flag_roundtrip(fail)
	fail = _verify_tutorial_flag_preserves_other_keys(fail)

	print("--- Stage 10 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _verify_class_roster(fail: int) -> int:
	var all: Array = Database.get_all_classes()
	var ok_count: bool = all.size() == 4
	print("[%s] Database.get_all_classes returns 4 classes (got %d)" \
			% [("OK  " if ok_count else "FAIL"), all.size()])
	if not ok_count: fail += 1

	var expected: Array[StringName] = [
		&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
	]
	var ids: Array = []
	for cd in all:
		ids.append((cd as ClassData).id)
	var ok_order: bool = ids == expected
	print("[%s] class order = M/P/H/O (got %s)" \
			% [("OK  " if ok_order else "FAIL"), str(ids)])
	if not ok_order: fail += 1
	return fail

func _verify_class_resources(fail: int) -> int:
	for id in [&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest"]:
		var cd := Database.get_class_data(id) as ClassData
		var ok: bool = cd != null and cd.display_name != "" and cd.sprite_scene != null
		print("[%s] %s ClassData loads (display=%s, sprite=%s)" % [
			("OK  " if ok else "FAIL"), id,
			cd.display_name if cd != null else "<null>",
			"yes" if cd != null and cd.sprite_scene != null else "no",
		])
		if not ok: fail += 1
	return fail

func _verify_pending_class_roundtrip(fail: int) -> int:
	GameState.pending_class_id = &""
	GameState.pending_class_id = &"pythia"
	var consumed: StringName = GameState.pending_class_id
	GameState.pending_class_id = &""
	var ok: bool = consumed == &"pythia" and GameState.pending_class_id == &""
	print("[%s] GameState.pending_class_id set/consume round-trip" \
			% ("OK  " if ok else "FAIL"))
	if not ok: fail += 1
	return fail

func _verify_tutorial_flag_roundtrip(fail: int) -> int:
	_wipe_settings()
	var clean: bool = not _TutorialPromptScript.has_seen_tutorial()
	print("[%s] tutorial flag absent before mark_seen" \
			% ("OK  " if clean else "FAIL"))
	if not clean: fail += 1

	_TutorialPromptScript.mark_seen()
	var set_ok: bool = _TutorialPromptScript.has_seen_tutorial()
	print("[%s] tutorial flag persists after mark_seen" \
			% ("OK  " if set_ok else "FAIL"))
	if not set_ok: fail += 1
	return fail

func _verify_tutorial_flag_preserves_other_keys(fail: int) -> int:
	_wipe_settings()
	# Pre-seed an unrelated key — mark_seen must not stomp it.
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({ "audio_volume": 0.7 }, "\t"))
	f.close()

	_TutorialPromptScript.mark_seen()

	var rf := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(rf.get_as_text())
	rf.close()
	var d: Dictionary = parsed as Dictionary
	var ok: bool = d.get("audio_volume", null) == 0.7 \
			and d.get(_FLAG_KEY, false) == true
	print("[%s] mark_seen merges into existing settings dict" \
			% ("OK  " if ok else "FAIL"))
	if not ok: fail += 1
	_wipe_settings()
	return fail

func _wipe_settings() -> void:
	if FileAccess.file_exists(_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_SETTINGS_PATH))
