extends Node
## Stage 11 — gate for whether bitmap polish layers render on top of
## the procedural baseline. Default ON. The procedural fallback always
## ships (hybrid-art contract in `rules/asset-pipeline.md`); this
## autoload decides whether the bitmap layer (when present) is shown
## on top, or whether the entity renders procedural-only.
##
## Off paths:
##   - `--procedural-only` on the command line (testing the fallback
##     path before a content stage ships).
##   - `BitmapMode.set_enabled(false)` from code (workbench, debug).
##
## Reading this from a sprite scene:
##   if BitmapMode.enabled and bitmap_node != null:
##       bitmap_node.show()
##   else:
##       bitmap_node.hide()
##
## The autoload owns no rendering itself — it's a flag + signal pair
## so listening sprites can react to a runtime toggle without polling.

signal mode_changed(enabled: bool)

var enabled: bool = true

func _ready() -> void:
	# CLI: passing `--procedural-only` (after `--`) forces bitmap layers
	# off for the entire process. Used by --verify11 to assert the
	# procedural fallback still renders, and by Stage 21's feel pass to
	# A/B procedural vs bitmap at scale.
	var args := OS.get_cmdline_user_args()
	if "--procedural-only" in args:
		enabled = false
		DebugLog.write(&"ui", "BitmapMode forced OFF via --procedural-only")

func set_enabled(value: bool) -> void:
	if value == enabled:
		return
	enabled = value
	mode_changed.emit(enabled)
	DebugLog.write(&"ui", "BitmapMode -> %s" % ("on" if enabled else "off"))
