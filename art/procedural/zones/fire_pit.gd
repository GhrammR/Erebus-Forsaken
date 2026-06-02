extends Node2D
## Central fire pit. Stone ring + flickering flame polygons driven by
## a looping AnimationPlayer "flicker" animation.

@onready var _flame_lo: Polygon2D = $FlameLo
@onready var _flame_hi: Polygon2D = $FlameHi
@onready var _glow: Polygon2D = $Glow
