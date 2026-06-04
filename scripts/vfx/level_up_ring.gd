extends Node2D
## Stage 9.5 — Feel Pass level-up VFX. Screen-wide expanding ring +
## floating "+N" popup. Wired to EventBus.player_leveled by game.gd.
## No XP system emits in Act 1 — the call site exists per the
## feel-pass.md contract, ready for the moment Act 2 lands leveling.

const DURATION: float = 0.9

@export var level_text: String = "+1"

@onready var _ring: Polygon2D = $Ring
@onready var _label: Label = $Label

func _ready() -> void:
	_label.text = level_text
	_ring.scale = Vector2(0.1, 0.1)
	_ring.modulate = Color(1.0, 0.95, 0.7, 0.9)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_ring, "scale", Vector2(3.0, 3.0), DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ring, "modulate:a", 0.0, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "position:y", _label.position.y - 24.0, DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "modulate:a", 0.0, DURATION * 0.6) \
			.set_delay(DURATION * 0.4)
	tw.chain().tween_callback(queue_free)
