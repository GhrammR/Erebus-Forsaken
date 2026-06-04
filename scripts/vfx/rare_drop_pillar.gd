extends Node2D
## Stage 9.5 — Feel Pass column-of-light for rare+ drops. A short
## upward burst of golden particles spawned at the drop position the
## moment the item lands, plus a soft glow that fades over the
## particles' lifetime. The persistent outline shader on the WorldItem
## glyph itself keeps the loot legible after the pillar fades.

const DURATION: float = 1.6

func _ready() -> void:
	# Auto-cleanup after the pillar's particles have died.
	get_tree().create_timer(DURATION + 0.2).timeout.connect(queue_free)
