extends CanvasLayer
## Reusable read-only stat overlay. Bind via bind_stats(); the panel
## re-renders on `Stats.changed` and on EventBus.stats_changed when the
## owner matches.

@onready var _label: RichTextLabel = $Panel/Margin/Label

var _stats: Stats = null
var _title: String = ""

func bind_stats(stats: Stats, title: String = "") -> void:
	if _stats == stats:
		return
	if _stats != null and _stats.recomputed.is_connected(_refresh):
		_stats.recomputed.disconnect(_refresh)
	_stats = stats
	_title = title
	if _stats != null:
		_stats.recomputed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	if _stats == null:
		_label.text = "[i]no stats bound[/i]"
		return
	var cd: ClassData = Database.get_class_data(_stats.class_id) as ClassData
	var class_name_str := cd.display_name if cd != null else String(_stats.class_id)
	var header := _title if _title != "" else class_name_str
	var lines: PackedStringArray = []
	lines.append("[b]%s[/b]  lvl %d" % [header, _stats.level])
	lines.append("")
	lines.append("[u]Attributes[/u]")
	lines.append("STR  %3d   (base %d  +alloc %d  +buff %d)" % [
		_stats.strength, _stats.base_strength, _stats.alloc_strength, _stats.buff_strength])
	lines.append("DEX  %3d   (base %d  +alloc %d  +buff %d)" % [
		_stats.dexterity, _stats.base_dexterity, _stats.alloc_dexterity, _stats.buff_dexterity])
	lines.append("VIT  %3d   (base %d  +alloc %d  +buff %d)" % [
		_stats.vitality, _stats.base_vitality, _stats.alloc_vitality, _stats.buff_vitality])
	lines.append("PNE  %3d   (base %d  +alloc %d  +buff %d)" % [
		_stats.pneuma, _stats.base_pneuma, _stats.alloc_pneuma, _stats.buff_pneuma])
	lines.append("")
	lines.append("[u]Derived[/u]")
	lines.append("HP    %4d / %4d" % [_stats.current_hp, _stats.max_hp])
	lines.append("MP    %4d / %4d" % [_stats.current_mp, _stats.max_mp])
	lines.append("DEF   %4d" % _stats.defense)
	lines.append("AR    %4d" % _stats.attack_rating)
	lines.append("RES   %3d%% (cap %d)" % [_stats.resistance, Stats.RESIST_CAP])
	_label.text = "\n".join(lines)
