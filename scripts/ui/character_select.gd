extends CanvasLayer
## Stage 10 — first-launch class select. Boots from main.gd when
## SaveSystem.has_save() is false. Stashes the picked class id in
## GameState.pending_class_id and swaps to game.tscn, which consumes
## the id on its _ready (see scenes/game.gd). If the player closes
## the window from here the run never starts — no save side-effects.

const _GAME_SCENE: String = "res://scenes/game.tscn"

## One-line marketing pitch — must match CLAUDE.md exactly. Do not
## rewrite without explicit user approval (rules/scope-lock + the
## "One-line pitch" section in CLAUDE.md).
const _PITCH: String = (
	"An ARPG where every death is a heirloom — your corpse stays "
	+ "where it fell, and so does what you were carrying.")

@onready var _grid: GridContainer = $Root/VBox/Grid
@onready var _selection_label: Label = $Root/VBox/SelectionLabel
@onready var _begin_button: Button = $Root/VBox/BeginButton
@onready var _footer: Label = $Root/VBox/Footer

var _selected_id: StringName = &""
var _cards: Dictionary = {}  # StringName -> Button

func _ready() -> void:
	_footer.text = _PITCH
	_begin_button.disabled = true
	_begin_button.pressed.connect(_on_begin_pressed)
	_populate_cards()

func _populate_cards() -> void:
	for cd_v in Database.get_all_classes():
		var cd: ClassData = cd_v as ClassData
		if cd == null:
			continue
		var card := _build_card(cd)
		_grid.add_child(card)
		_cards[cd.id] = card

func _build_card(cd: ClassData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(260, 180)
	btn.clip_text = false
	btn.text = "%s\n\n%s\n\nSTR %d  DEX %d\nVIT %d  PNE %d" % [
		cd.display_name,
		_primary_blurb(cd.primary_attribute),
		cd.base_strength, cd.base_dexterity,
		cd.base_vitality, cd.base_pneuma,
	]
	btn.pressed.connect(_on_card_pressed.bind(cd.id))
	return btn

func _primary_blurb(attr: StringName) -> String:
	match attr:
		&"strength":  return "Primary: Strength"
		&"dexterity": return "Primary: Dexterity"
		&"vitality":  return "Primary: Vitality"
		&"pneuma":    return "Primary: Pneuma"
		_: return ""

func _on_card_pressed(id: StringName) -> void:
	_selected_id = id
	for k in _cards.keys():
		var b: Button = _cards[k]
		b.button_pressed = (k == id)
	var cd := Database.get_class_data(id) as ClassData
	_selection_label.text = "Selected: %s" % (cd.display_name if cd != null else String(id))
	_begin_button.disabled = false

func _on_begin_pressed() -> void:
	if _selected_id == &"":
		return
	GameState.pending_class_id = _selected_id
	get_tree().change_scene_to_file(_GAME_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
