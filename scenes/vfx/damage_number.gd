extends Node2D

const RISE_PX: float = 50.0
const DURATION: float = 1.10
## Stage 9.5 — crit variant: golden color, 1.4x scale, slightly longer
## rise so the eye lingers on the hit. Triggered by HC.crit_landed.
## Gold is RESERVED for crits — non-crit numbers stay pale/cream so
## a regular hit reads as "neutral damage" and a crit reads as "ooh."
const CRIT_RISE_PX: float = 72.0
const CRIT_DURATION: float = 1.30
const CRIT_SCALE: float = 1.5
const CRIT_COLOR: Color = Color(1.0, 0.86, 0.30, 1.0)

@export var text: String = "0"
@export var is_miss: bool = false
@export var is_crit: bool = false
@export var color: Color = Color(1, 1, 1, 1)

@onready var _label: Label = $Label

func _ready() -> void:
	# Override the theme font_color directly rather than tinting via
	# modulate. The scene's default theme used to bake a gold tint
	# which silently multiplied with the modulate "cream" and rendered
	# every hit gold. Resetting the scene's font_color to white and
	# applying the real colour via theme override here gives exact
	# control: cream is cream, golden crits are crit-gold.
	if is_miss:
		_label.text = "MISS"
		_label.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.78, 1))
	elif is_crit:
		_label.text = text
		_label.add_theme_color_override(&"font_color", CRIT_COLOR)
		scale = Vector2(CRIT_SCALE, CRIT_SCALE)
	else:
		_label.text = text
		_label.add_theme_color_override(&"font_color", color)

	var rise := CRIT_RISE_PX if is_crit else RISE_PX
	var dur := CRIT_DURATION if is_crit else DURATION
	var start_y := position.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", start_y - rise, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "modulate:a", 0.0, dur * 0.6) \
		.set_delay(dur * 0.4)
	tw.chain().tween_callback(queue_free)
