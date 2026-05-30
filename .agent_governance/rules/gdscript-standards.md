# GDScript Standards

These exist to keep the codebase legible to one person across many sessions
and to prevent the most common Godot 4 footguns.

## File layout (every script)

```
class_name SomeName extends BaseType   # if reusable
## Optional one-line description.

# 1. signals
signal stats_changed

# 2. enums / constants
const MAX_RESIST := 75
enum State { IDLE, ATTACK, DEAD }

# 3. exports
@export var move_speed: float = 120.0

# 4. public vars
var current_state: State = State.IDLE

# 5. private vars (leading underscore)
var _attack_timer: float = 0.0

# 6. onready
@onready var _sprite: Node2D = $Sprite

# 7. lifecycle: _ready, _process, _physics_process, _exit_tree
# 8. public methods
# 9. private methods (leading underscore)
# 10. signal handlers (_on_xxx)
```

## Naming

- `snake_case` for variables, functions, files, signals.
- `PascalCase` for classes, enums, enum values, nodes in scene tree.
- `SCREAMING_SNAKE_CASE` for constants only.
- Boolean variables read as predicates: `is_dead`, `has_target`, `can_cast`.
- Signal handlers: `_on_<source>_<event>`. Example: `_on_health_depleted`.

## Typing

- **Always type** function signatures, exports, and member vars.
- Use `-> void` on functions that return nothing.
- Prefer typed arrays: `Array[Item]` not `Array`.
- Use `:=` for type inference on locals where the type is obvious.

## Magic numbers

Forbidden in combat, stats, and economy code. If a number has meaning, name
it as a `const` in the file or pull it from a `Resource`. Tuning constants
that designers will touch live in `.tres` files, not code.

UI pixel offsets and shader constants are allowed as locals if commented.

## Signals discipline

- Declare signals at the top of the emitting script, never on the listener.
- Connect via code in `_ready()`, not in the editor inspector. (Editor
  connections are invisible during code review and break under rename.)
- Use `Callable` form: `enemy.died.connect(_on_enemy_died)`.
- Disconnect only when necessary; freeing a node disconnects automatically.

## Error handling

- `assert()` for invariants ("this can't happen if code is correct").
- `push_error()` for problems that should not happen but might during dev.
- `push_warning()` for recoverable oddities.
- Never silently `return` on bad state. Either assert or log.

## Forbidden

- `func _process(delta):` without a type hint on delta.
- `yield(...)` — Godot 4 uses `await`.
- `tool` scripts unless explicitly approved.
- `preload()` of scenes inside `_ready()` — preload at script load time.
- `get_tree().change_scene_to_file()` from arbitrary scripts. Go through
  `SceneRouter` autoload.
- `var foo = {}` with no schema — define a class or Resource.

## Comments

Default to none. Write one only when the *why* is non-obvious — a workaround,
a Godot quirk, a balance constraint. Do not narrate what the code does.
