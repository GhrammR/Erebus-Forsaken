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

## Summon lifecycle

Any node that represents something the player summoned — currently
only `BoneServantMinion`, future totems / pets / spirits / etc. —
MUST tie its lifetime to the summoner:

1. Add itself to a `*_summons`-style group on `_ready` so the player
   (and `Player.assign_class`) can sweep all active summons.
2. Subscribe to `EventBus.player_died` and route through its own
   `HealthComponent.kill(self)` so the die animation + cleanup path
   runs identically to a regular lethal hit.
3. Be excluded from `SaveSystem` snapshots. Summons re-spawn from
   skill use after load, never from save data.

Why: in-game expectation is that the player's death ends their
support entities. Mechanically also avoids zombie minions outliving
their context (e.g., player dies, respawns, two of the same summon
now exist). Reference: `scripts/enemies/bone_servant_minion.gd`.

## Comments

Default to none. Write one only when the *why* is non-obvious — a workaround,
a Godot quirk, a balance constraint. Do not narrate what the code does.
