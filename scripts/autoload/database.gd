extends Node
## Read-only registry. THE only legal way to look up content at
## runtime. See AD-03 in
## .agent_governance/rules/architecture-decisions.md.
##
## Populated at boot by scanning data/ directories. No load() calls to
## res://data/ outside this file.

const CLASSES_DIR: String = "res://data/classes/"
const ITEMS_DIRS: Array[String] = [
	"res://data/items/weapons/",
	"res://data/items/armor/",
	"res://data/items/uniques/",
]
const ENEMIES_DIR: String = "res://data/enemies/"
const SKILLS_DIR: String = "res://data/skills/"

var classes: Dictionary = {}    # StringName -> Resource (ClassData)
var items: Dictionary = {}      # StringName -> Resource (ItemData)
var enemies: Dictionary = {}    # StringName -> Resource (EnemyData)
var skills: Dictionary = {}     # StringName -> Resource (SkillData)

func _ready() -> void:
	_load_dir(CLASSES_DIR, classes)
	for d in ITEMS_DIRS:
		_load_dir(d, items)
	_load_dir(ENEMIES_DIR, enemies)
	_load_dir(SKILLS_DIR, skills)
	print("Database loaded: %d classes, %d items, %d enemies, %d skills" % [
		classes.size(), items.size(), enemies.size(), skills.size()
	])

func _load_dir(dir_path: String, target: Dictionary) -> void:
	if not DirAccess.dir_exists_absolute(dir_path):
		return
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(dir_path + file_name)
			if res != null and "id" in res:
				target[StringName(res.id)] = res
		file_name = dir.get_next()
	dir.list_dir_end()

func get_class_data(id: StringName) -> Resource:
	return classes.get(id, null)

func get_item(id: StringName) -> Resource:
	return items.get(id, null)

func get_enemy(id: StringName) -> Resource:
	return enemies.get(id, null)

func get_skill(id: StringName) -> Resource:
	return skills.get(id, null)
