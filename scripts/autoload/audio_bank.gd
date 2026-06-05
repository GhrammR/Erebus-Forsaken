extends Node
## AD-03 analogue for audio: every sfx / ambient lookup routes through
## here so paths can be renamed without rippling through call sites.
## Bank entries with missing .ogg files no-op silently (asset-pipeline
## placeholder rule applies to audio — see rules/feel-pass.md).

const _SFX_BANK: Dictionary = {
	&"swing":          "res://audio/sfx/swing.ogg",
	&"hit_flesh":      "res://audio/sfx/hit_flesh.ogg",
	&"hit_crit":       "res://audio/sfx/hit_crit.ogg",
	&"player_hurt":    "res://audio/sfx/player_hurt.ogg",
	&"death_player":   "res://audio/sfx/death_player.ogg",
	&"death_enemy":    "res://audio/sfx/death_enemy.ogg",
	&"skill_cast":     "res://audio/sfx/skill_cast.ogg",
	&"skill_ready":    "res://audio/sfx/skill_ready.ogg",
	&"pickup_item":    "res://audio/sfx/pickup_item.ogg",
	&"pickup_gold":    "res://audio/sfx/pickup_gold.ogg",
	&"drop_rare":      "res://audio/sfx/drop_rare.ogg",
	&"levelup":        "res://audio/sfx/levelup.ogg",
	&"quest_accept":   "res://audio/sfx/quest_accept.ogg",
	&"quest_complete": "res://audio/sfx/quest_complete.ogg",
	&"save":           "res://audio/sfx/save.ogg",
	&"load":           "res://audio/sfx/load.ogg",
	&"hearth_ember_channel":  "res://audio/sfx/hearth_ember_channel.ogg",
	&"hearth_ember_complete": "res://audio/sfx/hearth_ember_complete.ogg",
	&"hearth_ember_break":    "res://audio/sfx/hearth_ember_break.ogg",
	&"potion_drink":          "res://audio/sfx/potion_drink.ogg",
	&"potion_ichor":          "res://audio/sfx/potion_ichor.ogg",
	# Stage 14 — Sundered Ferry. Discover plays when the brazier first
	# lights; travel plays on every destination pick from the menu.
	&"waypoint_discover":     "res://audio/sfx/waypoint_discover.ogg",
	&"waypoint_travel":       "res://audio/sfx/waypoint_travel.ogg",
}

const _AMBIENT_BANK: Dictionary = {
	&"threshold_camp": "res://audio/ambient/threshold_camp.ogg",
	&"blighted_reach": "res://audio/ambient/blighted_reach.ogg",
	&"forsaken_crypt": "res://audio/ambient/forsaken_crypt.ogg",
}

const _SETTINGS_PATH: String = "user://settings.json"
const _SFX_PLAYER_COUNT: int = 6
const _MIN_DB: float = -60.0

## EventBus.item_picked_up emits a sentinel id for non-item pickups
## (gold, corpse). Route those to the right sfx; everything else
## falls through to the generic pickup cue.
const _PICKUP_SFX: Dictionary = {
	&"_gold":   &"pickup_gold",
	&"_corpse": &"pickup_gold",
}

var _stream_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _ambient_player: AudioStreamPlayer = null
var _current_ambient: StringName = &""
var _warned_ids: Dictionary = {}

func _ready() -> void:
	for i in _SFX_PLAYER_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_sfx_players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = &"Ambient"
	add_child(_ambient_player)
	_ambient_player.finished.connect(_on_ambient_finished)

	_apply_saved_volumes()

	EventBus.player_died.connect(_on_player_died)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.item_picked_up.connect(_on_item_picked_up)
	EventBus.zone_changed.connect(_on_zone_changed)

func play_sfx(id: StringName) -> void:
	var stream := _resolve_sfx(id)
	if stream == null:
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = stream
	p.play()

func play_ambient(zone_id: StringName) -> void:
	if zone_id == _current_ambient and _ambient_player.playing:
		return
	var path: String = _AMBIENT_BANK.get(zone_id, "")
	_current_ambient = zone_id
	if path == "" or not ResourceLoader.exists(path):
		_warn_once(zone_id, "ambient")
		_ambient_player.stop()
		return
	var stream := load(path) as AudioStream
	if stream == null:
		_ambient_player.stop()
		return
	_ambient_player.stream = stream
	_ambient_player.play()

func stop_ambient() -> void:
	_ambient_player.stop()
	_current_ambient = &""

func _on_ambient_finished() -> void:
	# Fallback loop in case the .ogg import didn't carry loop=true.
	if _current_ambient != &"" and _ambient_player.stream != null:
		_ambient_player.play()

# ---- EventBus routing ------------------------------------------------------

func _on_player_died() -> void:
	play_sfx(&"death_player")

func _on_enemy_died(_enemy: Node, _killer: Node) -> void:
	play_sfx(&"death_enemy")

func _on_item_picked_up(item_id: StringName) -> void:
	play_sfx(_PICKUP_SFX.get(item_id, &"pickup_item"))

func _on_zone_changed(zone_id: StringName) -> void:
	play_ambient(zone_id)

# ---- Volumes ---------------------------------------------------------------

func set_master_volume(linear: float) -> void: _set_bus_volume(&"Master", linear)
func set_sfx_volume(linear: float) -> void: _set_bus_volume(&"Sfx", linear)
func set_ambient_volume(linear: float) -> void: _set_bus_volume(&"Ambient", linear)

func get_master_volume() -> float: return _get_bus_linear(&"Master")
func get_sfx_volume() -> float: return _get_bus_linear(&"Sfx")
func get_ambient_volume() -> float: return _get_bus_linear(&"Ambient")

## Persists the three live bus values into user://settings.json. Merges
## into the existing dict so the tutorial flag (and anything else) is
## preserved. Call this on slider drag_ended, not on every value_changed.
func save_volumes() -> void:
	var d := _read_settings()
	d["master_volume"] = _get_bus_linear(&"Master")
	d["sfx_volume"] = _get_bus_linear(&"Sfx")
	d["ambient_volume"] = _get_bus_linear(&"Ambient")
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))
		f.close()

func _apply_saved_volumes() -> void:
	var d := _read_settings()
	_set_bus_volume(&"Master", float(d.get("master_volume", 1.0)))
	_set_bus_volume(&"Sfx", float(d.get("sfx_volume", 1.0)))
	_set_bus_volume(&"Ambient", float(d.get("ambient_volume", 1.0)))

func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(_SETTINGS_PATH):
		return {}
	var f := FileAccess.open(_SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(raw)
	return parsed if parsed is Dictionary else {}

func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	linear = clampf(linear, 0.0, 1.0)
	if linear <= 0.0001:
		AudioServer.set_bus_volume_db(idx, _MIN_DB)
	else:
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))

func _get_bus_linear(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return 0.0
	var db := AudioServer.get_bus_volume_db(idx)
	if db <= _MIN_DB + 0.01:
		return 0.0
	return clampf(db_to_linear(db), 0.0, 1.0)

# ---- Defocus mute ---------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_set_master_muted(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_set_master_muted(false)

func _set_master_muted(muted: bool) -> void:
	var idx := AudioServer.get_bus_index(&"Master")
	if idx >= 0:
		AudioServer.set_bus_mute(idx, muted)

# ---- Internals ------------------------------------------------------------

func _resolve_sfx(id: StringName) -> AudioStream:
	if _stream_cache.has(id):
		return _stream_cache[id]
	var path: String = _SFX_BANK.get(id, "")
	if path == "" or not ResourceLoader.exists(path):
		_warn_once(id, "sfx")
		_stream_cache[id] = null
		return null
	var stream := load(path) as AudioStream
	_stream_cache[id] = stream
	return stream

func _warn_once(id: StringName, kind: String) -> void:
	if _warned_ids.has(id):
		return
	_warned_ids[id] = true
	push_warning("AudioBank: missing %s for '%s' (placeholder ok)" % [kind, id])

# ---- Verifier hooks -------------------------------------------------------

func sfx_bank_keys() -> Array: return _SFX_BANK.keys()
func ambient_bank_keys() -> Array: return _AMBIENT_BANK.keys()
