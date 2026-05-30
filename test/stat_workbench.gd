extends Node2D
## Stage 1 workbench. Not shipped. Proves Stats works without the
## Player (Stage 2) or items (Stage 4).
##
## Controls:
##   1 / 2 / 3 / 4   bind overlay to Myrmidon / Pythia / Shade-Hunter / Ossuary Priest
##   +  /  -         level up / down (recompute + visible delta)
##   Q               take_damage(20) via a temp Attack
##   E               spend_mp(10)
##   R               restore current HP + MP to max
##   Esc             quit

const CLASS_IDS: Array[StringName] = [
	&"myrmidon", &"pythia", &"shade_hunter", &"ossuary_priest",
]

@onready var _overlay: CanvasLayer = $DebugStatOverlay
@onready var _help: Label = $HelpLabel
@onready var _ev_log: Label = $EventLog

var _stats_by_class: Dictionary = {}   # StringName -> Stats
var _selected: int = 0
var _ev_count: int = 0

func _ready() -> void:
	for id in CLASS_IDS:
		var cd: ClassData = Database.get_class_data(id) as ClassData
		if cd == null:
			push_error("stat_workbench: missing ClassData %s" % id)
			continue
		_stats_by_class[id] = Stats.from_class_data(cd, 1)
	EventBus.stats_changed.connect(_on_event_stats_changed)
	_help.text = "[1-4] class   [+/-] level   [Q] dmg 20   [E] -10 MP   [R] heal   [Esc] quit"
	_bind_selected()

func _bind_selected() -> void:
	var id: StringName = CLASS_IDS[_selected]
	var s: Stats = _stats_by_class.get(id)
	_overlay.bind_stats(s)
	# Re-emit through EventBus so we can observe the forward path even
	# without a Node owning the Stats yet.
	EventBus.stats_changed.emit(self)

func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	var k: int = key_event.keycode
	var s: Stats = _stats_by_class[CLASS_IDS[_selected]]
	match k:
		KEY_1: _selected = 0; _bind_selected()
		KEY_2: _selected = 1; _bind_selected()
		KEY_3: _selected = 2; _bind_selected()
		KEY_4: _selected = 3; _bind_selected()
		KEY_EQUAL, KEY_KP_ADD:
			s.set_level(s.level + 1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			if s.level > 1:
				s.set_level(s.level - 1)
		KEY_Q:
			var atk := Attack.new()
			atk.base_damage = 20
			atk.source = self
			s.take_damage(20, atk)
		KEY_E:
			var ok := s.spend_mp(10)
			_push_event("spend_mp(10) -> %s" % ("OK" if ok else "INSUFFICIENT"))
		KEY_R:
			s.restore_hp(s.max_hp)
			s.restore_mp(s.max_mp)
		KEY_ESCAPE:
			get_tree().quit()

func _on_event_stats_changed(_owner: Node) -> void:
	_ev_count += 1
	_push_event("EventBus.stats_changed #%d" % _ev_count)

func _push_event(msg: String) -> void:
	_ev_log.text = msg
