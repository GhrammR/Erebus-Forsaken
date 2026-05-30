extends Node2D

const RISE_PX: float = 30.0
const DURATION: float = 0.6

@export var text: String = "0"
@export var is_miss: bool = false
@export var color: Color = Color(1, 1, 1, 1)

@onready var _label: Label = $Label

func _ready() -> void:
	if is_miss:
		_label.text = "MISS"
		_label.modulate = Color(0.75, 0.75, 0.78, 1)
	else:
		_label.text = text
		_label.modulate = color

	var start_y := position.y
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position:y", start_y - RISE_PX, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_label, "modulate:a", 0.0, DURATION * 0.6) \
		.set_delay(DURATION * 0.4)
	tw.chain().tween_callback(queue_free)
