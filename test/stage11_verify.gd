extends Node
## Stage 11 verifier — AI asset-generation pipeline scaffolding.
##
## This stage ships infrastructure only — no actual generated assets
## land yet. The verifier exercises the contract end-to-end:
##   - tools/asset_gen/ wrappers exist and are executable
##   - sidecar validator exists and accepts a known-good fixture
##   - sidecar validator rejects a known-bad fixture
##   - dry-run sprite generation produces a passing sidecar
##   - .gitattributes is configured for LFS
##   - BitmapMode autoload is registered and starts enabled
##   - --procedural-only CLI flag is wired through main.gd
##   - rules/asset-generation.md exists
##   - audit.md contains the hybrid-baseline assertion

const REPO_PREFIX := "res://"

func _ready() -> void:
	var fail := 0
	print("--- Stage 11 verify ---")

	fail = _verify_wrappers_exist(fail)
	fail = _verify_validator(fail)
	fail = _verify_validator_accepts_good(fail)
	fail = _verify_validator_rejects_bad(fail)
	fail = _verify_dry_run_sprite(fail)
	fail = _verify_gitattributes(fail)
	fail = _verify_bitmap_mode(fail)
	fail = _verify_procedural_only_wired(fail)
	fail = _verify_governance_docs(fail)
	fail = _verify_replicate_defaults(fail)

	print("--- Stage 11 verify: %s ---" % ("ALL PASS" if fail == 0 else "%d FAIL" % fail))
	get_tree().quit(fail)

func _expect(cond: bool, label: String, fail: int) -> int:
	if cond:
		print("  PASS  %s" % label)
		return fail
	print("  FAIL  %s" % label)
	return fail + 1

# ---- wrappers -----------------------------------------------------------

func _verify_wrappers_exist(fail: int) -> int:
	var wrappers := [
		"tools/asset_gen/gen_sprite.sh",
		"tools/asset_gen/gen_voice.sh",
		"tools/asset_gen/gen_sfx.sh",
		"tools/asset_gen/gen_video.sh",
		"tools/asset_gen/lib/common.sh",
		"tools/asset_gen/README.md",
	]
	var root := _repo_root()
	for rel in wrappers:
		var abs := root.path_join(rel)
		fail = _expect(FileAccess.file_exists(abs),
				"wrapper present: %s" % rel, fail)
	# Executable bit on the four shells.
	for rel in ["tools/asset_gen/gen_sprite.sh",
			"tools/asset_gen/gen_voice.sh",
			"tools/asset_gen/gen_sfx.sh",
			"tools/asset_gen/gen_video.sh"]:
		var out: Array = []
		var rc := OS.execute("test", ["-x", _repo_root().path_join(rel)], out)
		fail = _expect(rc == 0, "executable: %s" % rel, fail)
	return fail

# ---- validator ----------------------------------------------------------

func _verify_validator(fail: int) -> int:
	var v := _repo_root().path_join("tools/asset_gen/validate_sidecar.py")
	fail = _expect(FileAccess.file_exists(v), "validate_sidecar.py exists", fail)
	var out: Array = []
	var rc := OS.execute("test", ["-x", v], out)
	fail = _expect(rc == 0, "validate_sidecar.py executable", fail)
	return fail

func _verify_validator_accepts_good(fail: int) -> int:
	# Compose a known-good sidecar in /tmp, run validator, expect exit 0.
	var path := "/tmp/erebus_v11_good.json"
	var good := {
		"tool": "replicate",
		"model": "test-model",
		"prompt": "verifier fixture",
		"seed": 1,
		"params": {"width": 64, "height": 64},
		"output_sha256": "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
		"generated_at": "2026-06-04T12:00:00Z",
		"generated_by": "verifier",
		"purpose": "Stage 11 verifier good-case fixture",
		"license": "test",
		"cost_usd": 0,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(good))
	f.close()
	var out: Array = []
	var rc := OS.execute(
			_repo_root().path_join("tools/asset_gen/validate_sidecar.py"),
			[path], out, true)
	fail = _expect(rc == 0,
			"validator accepts a well-formed sidecar (rc=%d)" % rc, fail)
	return fail

func _verify_validator_rejects_bad(fail: int) -> int:
	var path := "/tmp/erebus_v11_bad.json"
	var bad := {"tool": "replicate"}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(bad))
	f.close()
	var out: Array = []
	var rc := OS.execute(
			_repo_root().path_join("tools/asset_gen/validate_sidecar.py"),
			[path], out, true)
	fail = _expect(rc != 0,
			"validator rejects a sidecar missing required keys (rc=%d)" % rc, fail)
	return fail

func _verify_dry_run_sprite(fail: int) -> int:
	# End-to-end dry run of gen_sprite.sh, then validate the produced
	# sidecar. Exercises emit_sidecar_json + write_sidecar + validator.
	var out_path := "/tmp/erebus_v11_dry_run.png"
	var sidecar_path := "/tmp/erebus_v11_dry_run.json"
	# Pre-clean.
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	if FileAccess.file_exists(sidecar_path):
		DirAccess.remove_absolute(sidecar_path)
	var script := _repo_root().path_join("tools/asset_gen/gen_sprite.sh")
	var args := [
		script,
		"--out", out_path,
		"--prompt", "verifier dry run",
		"--seed", "42",
		"--purpose", "Stage 11 dry-run sprite",
	]
	var out: Array = []
	var rc := OS.execute("bash", args, out, true)
	fail = _expect(rc == 0, "gen_sprite.sh dry-run rc==0", fail)
	fail = _expect(FileAccess.file_exists(out_path),
			"gen_sprite.sh wrote asset stub", fail)
	fail = _expect(FileAccess.file_exists(sidecar_path),
			"gen_sprite.sh wrote sidecar", fail)
	# Re-run validator on the produced sidecar.
	var v_out: Array = []
	var v_rc := OS.execute(
			_repo_root().path_join("tools/asset_gen/validate_sidecar.py"),
			[sidecar_path], v_out, true)
	fail = _expect(v_rc == 0, "produced sidecar validates", fail)
	return fail

# ---- LFS + governance ---------------------------------------------------

func _verify_gitattributes(fail: int) -> int:
	var path := _repo_root().path_join(".gitattributes")
	fail = _expect(FileAccess.file_exists(path), ".gitattributes exists", fail)
	if not FileAccess.file_exists(path):
		return fail
	var text := FileAccess.get_file_as_string(path)
	for ext in ["*.ogg", "*.webm", "*.mp4"]:
		fail = _expect(text.contains(ext) and text.contains("filter=lfs"),
				".gitattributes tracks %s through LFS" % ext, fail)
	fail = _expect(text.contains("*.json") and text.contains("-filter"),
			".gitattributes keeps *.json on plain git", fail)
	return fail

func _verify_governance_docs(fail: int) -> int:
	fail = _expect(FileAccess.file_exists(
			"res://.agent_governance/rules/asset-generation.md"),
			"rules/asset-generation.md present", fail)
	var audit := FileAccess.get_file_as_string(
			"res://.agent_governance/commands/audit.md")
	fail = _expect(audit.contains("Hybrid-baseline assertion"),
			"audit.md contains hybrid-baseline assertion", fail)
	fail = _expect(audit.contains("MISSING SIDECAR"),
			"audit.md contains sidecar sweep", fail)
	return fail

# ---- BitmapMode ---------------------------------------------------------

func _verify_bitmap_mode(fail: int) -> int:
	var root: Node = Engine.get_main_loop().root
	var bm: Node = root.get_node_or_null(^"BitmapMode")
	fail = _expect(bm != null, "BitmapMode autoload registered", fail)
	if bm == null:
		return fail
	fail = _expect(bool(bm.enabled) == true,
			"BitmapMode enabled defaults true", fail)
	fail = _expect(bm.has_signal("mode_changed"),
			"BitmapMode emits mode_changed", fail)
	# Round-trip the setter.
	var fired := [false]
	var cb := func(_v: bool): fired[0] = true
	bm.mode_changed.connect(cb)
	bm.set_enabled(false)
	fail = _expect(bool(bm.enabled) == false,
			"BitmapMode.set_enabled(false) flips flag", fail)
	fail = _expect(fired[0] == true,
			"BitmapMode.set_enabled emits mode_changed", fail)
	bm.set_enabled(true)
	return fail

func _verify_procedural_only_wired(fail: int) -> int:
	var src := FileAccess.get_file_as_string("res://scripts/systems/bitmap_mode.gd")
	fail = _expect(src.contains("--procedural-only"),
			"BitmapMode reads --procedural-only", fail)
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	fail = _expect(main_src.contains("--verify11"),
			"main.gd routes --verify11", fail)
	return fail

func _verify_replicate_defaults(fail: int) -> int:
	# Stage 11 follow-up: every wrapper defaults to Replicate so cost
	# discipline and key management live on one vendor. Deferred
	# fallbacks (ElevenLabs / Runway / HeyGen) remain selectable via
	# --backend but are not the defaults.
	var root := _repo_root()
	var sprite := FileAccess.get_file_as_string(
			root.path_join("tools/asset_gen/gen_sprite.sh"))
	fail = _expect(sprite.contains("black-forest-labs/flux-2-pro"),
			"gen_sprite.sh defaults to flux-2-pro", fail)
	var voice := FileAccess.get_file_as_string(
			root.path_join("tools/asset_gen/gen_voice.sh"))
	fail = _expect(voice.contains("BACKEND=\"replicate\""),
			"gen_voice.sh defaults to replicate backend", fail)
	fail = _expect(voice.contains("kokoro"),
			"gen_voice.sh names a Replicate TTS default model", fail)
	var video := FileAccess.get_file_as_string(
			root.path_join("tools/asset_gen/gen_video.sh"))
	fail = _expect(video.contains("BACKEND=\"replicate\""),
			"gen_video.sh defaults to replicate backend", fail)
	fail = _expect(video.contains("lightricks/ltx-video"),
			"gen_video.sh names a Replicate video default model", fail)
	# Governance reflects the consolidation.
	var rule := FileAccess.get_file_as_string(
			"res://.agent_governance/rules/asset-generation.md")
	fail = _expect(rule.contains("flux-2-pro"),
			"asset-generation.md lists flux-2-pro as default", fail)
	fail = _expect(rule.contains("Deferred fallback"),
			"asset-generation.md marks fallbacks as deferred", fail)
	return fail

# ---- helpers ------------------------------------------------------------

func _repo_root() -> String:
	# OS.get_executable_path is the engine binary, not the project. Use
	# ProjectSettings.globalize_path to resolve res:// → abs.
	return ProjectSettings.globalize_path("res://")
