extends Control
## Stage 9.5 — HUD skill icon. Dark slate panel with a cooldown VEIL
## that shrinks from full opacity (just used / on CD) to transparent
## (ready). Subtle border ring tints gold on the ready edge.
##
## The previous build used a TextureProgressBar with a radial gold
## gradient that filled an entire orange square — visually shouty
## and confusable for a generic UI button. The veil model reads
## immediately as "I'm waiting on this" without competing with
## damage numbers or other gold cues.
##
## Ready-edge sfx fires only for skill.cooldown >= READY_SFX_MIN_CD
## so the 0.9-1.2s spam skills don't chatter.

const READY_SFX_MIN_CD: float = 1.0

@onready var _frame: Panel = $Frame
@onready var _veil: ColorRect = $CooldownVeil
@onready var _ring: Polygon2D = $ReadyRing
@onready var _label: Label = $Label
@onready var _name: Label = $Name

var _skill: Skill = null
var _was_ready: bool = true
var _ready_tween: Tween = null

func _ready() -> void:
	# Build a thin ring polygon once (annulus, 22 outer / 19 inner).
	_ring.polygon = _make_ring(22.0, 19.0, 32)

func bind(skill: Skill) -> void:
	_skill = skill
	if _skill != null:
		_label.text = _skill.display_name.substr(0, 1)
		_name.text = _skill.display_name
	_was_ready = _skill == null or _skill.is_ready()
	_veil.color.a = 0.0 if _was_ready else 0.65

func _process(_delta: float) -> void:
	if _skill == null:
		_veil.color.a = 0.0
		return
	# Veil opacity tracks cooldown: full when freshly cast, none
	# when ready. cooldown_fraction is 1 right after cast → 0 ready.
	_veil.color.a = 0.65 * _skill.cooldown_fraction()
	var ready_now := _skill.is_ready()
	if ready_now and not _was_ready:
		_on_ready_edge()
	_was_ready = ready_now

func _on_ready_edge() -> void:
	if _skill.cooldown >= READY_SFX_MIN_CD:
		AudioBank.play_sfx(&"skill_ready")
	# Pulse the ring border so the "ready!" moment lands without
	# flashing the whole tile.
	if _ready_tween != null and _ready_tween.is_valid():
		_ready_tween.kill()
	_ring.modulate = Color(1.4, 1.2, 0.6, 1.0)
	_ready_tween = create_tween()
	_ready_tween.tween_property(_ring, "modulate",
			Color(1.0, 0.85, 0.35, 0.6), 0.28)

static func _make_ring(outer_r: float, inner_r: float, segments: int) -> PackedVector2Array:
	# Annulus traced clockwise on the outer arc, counter-clockwise on
	# the inner arc, so Polygon2D fills the band between.
	var pts: PackedVector2Array = []
	for i in segments + 1:
		var t := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(t), sin(t)) * outer_r)
	for i in segments + 1:
		var t := TAU * (1.0 - float(i) / float(segments))
		pts.append(Vector2(cos(t), sin(t)) * inner_r)
	return pts
