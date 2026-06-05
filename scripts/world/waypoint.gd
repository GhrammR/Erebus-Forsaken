class_name Waypoint extends Portal
## Stage 14 — Sundered Ferry waypoint. Charon's old ferry-paths still
## cross the underworld; the player lights a brazier at each waypoint
## they find, and a spectral ferryman returns to take them back.
##
## Extends Portal so it inherits the click-to-interact, proximity
## prompt, selection-ring, and per-instance hit-test contract. We
## override `interact()` to mark the zone discovered and surface the
## WaypointMenu instead of running a direct zone transit; the menu
## then routes the actual SceneRouter.go_to_zone call when the player
## picks a destination.
##
## The brazier visual lights on first discover (cold-grey -> amber +
## faint glow tween). Subsequent re-interacts skip the discover anim
## and go straight to the menu.

const DISCOVER_TWEEN_SECONDS: float = 0.6

signal menu_requested(waypoint: Waypoint)

## Stage 14.1 — town hub brazier flag. Town's Sundered Ferry is part
## of the permanent home dock; it's lit at all times and does not
## need the discover anim/SFX. Wilderness braziers default `false`
## and gate on the discovery array.
@export var starts_lit: bool = false

@onready var _flame: Polygon2D = $Body/Flame
@onready var _flame_inner: Polygon2D = $Body/FlameInner
@onready var _glow: Polygon2D = $Body/Glow

func _ready() -> void:
	super._ready()
	display_name = "The Sundered Ferry"
	_refresh_lit_state(false)

## The waypoint's zone_id is its parent's `zone_id` if the parent is
## a Zone — that's the zone the waypoint belongs to. We don't store
## a copy on the waypoint itself because the truth lives on the
## Zone (avoids the two-sources-of-truth drift problem when a
## waypoint is hot-replaced).
func zone_id() -> StringName:
	var p := get_parent()
	while p != null:
		if p is Zone:
			return (p as Zone).zone_id
		p = p.get_parent()
	return &""

## Override Portal.interact — Waypoint never transits directly. It
## opens a menu that the player picks a destination from. The menu
## is owned by game.gd so the same modal handles every zone's
## waypoint.
func interact() -> void:
	interacted.emit(self)
	var zid := zone_id()
	# starts_lit braziers (the town hub) skip the discovery flow
	# entirely. They're not part of the wilderness discovery array;
	# the menu always includes Threshold Camp as a destination
	# regardless of array contents.
	if not starts_lit:
		var was_discovered := GameState.discovered_waypoints.has(String(zid))
		if not was_discovered and zid != &"":
			GameState.discovered_waypoints.append(String(zid))
			AudioBank.play_sfx(&"waypoint_discover")
			DebugLog.write(&"transit", "waypoint_discovered %s" % String(zid))
			_play_discover_tween()
	menu_requested.emit(self)

func _refresh_lit_state(animate: bool) -> void:
	# Cold (undiscovered): muted blue-grey flame, no glow.
	# Lit (discovered, or starts_lit override): warm amber + soft halo.
	var lit: bool = starts_lit \
			or GameState.discovered_waypoints.has(String(zone_id()))
	if not lit:
		_flame.color = Color(0.20, 0.25, 0.32, 1.0)
		_flame_inner.color = Color(0.40, 0.48, 0.55, 1.0)
		_glow.modulate = Color(0.30, 0.50, 0.80, 0.0)
		return
	if animate:
		# Tween from cold to warm. Glow ramps in.
		var tw := create_tween().set_parallel(true)
		tw.tween_property(_flame, "color", Color(0.95, 0.55, 0.20, 1.0),
				DISCOVER_TWEEN_SECONDS)
		tw.tween_property(_flame_inner, "color", Color(1.0, 0.85, 0.45, 1.0),
				DISCOVER_TWEEN_SECONDS)
		tw.tween_property(_glow, "modulate", Color(1.0, 0.7, 0.4, 0.40),
				DISCOVER_TWEEN_SECONDS)
	else:
		_flame.color = Color(0.95, 0.55, 0.20, 1.0)
		_flame_inner.color = Color(1.0, 0.85, 0.45, 1.0)
		_glow.modulate = Color(1.0, 0.7, 0.4, 0.40)

func _play_discover_tween() -> void:
	_refresh_lit_state(true)
