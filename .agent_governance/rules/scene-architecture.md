# Scene Architecture

Godot punishes scene sprawl. A 200-node scene with implicit cross-references
is unfixable by stage 4. These rules keep scenes composable.

## Scene boundaries

A scene file (`.tscn`) represents one **self-contained, instantiable thing**:
- A character (player, enemy, NPC)
- A room or zone
- A UI panel
- A projectile / VFX
- An item pickup

If a scene's root node has knowledge of more than one of the above, split it.

## Node tree rules

- **Root is always typed.** No bare `Node` roots. `Player` roots as
  `CharacterBody2D`, `Enemy` as `CharacterBody2D`, UI as `Control`, etc.
- **Composition over inheritance for behavior.** Use child nodes
  (`HealthComponent`, `HitboxComponent`, `LootDropper`) rather than deep
  class hierarchies.
- **No `get_node("../../..")` past one parent.** Children may reference their
  direct parent. Anything further goes through signals or an autoload.
- **Exported NodePaths over hardcoded paths.** If a script needs a sibling,
  expose `@export var target: NodePath` so the wiring is visible in the editor.

## Autoloads (singletons)

Use sparingly. Approved autoloads for Act 1:

| Autoload      | Role                                                  |
|---------------|-------------------------------------------------------|
| `GameState`   | Current player ref, current zone, run-scoped data     |
| `SaveSystem`  | Serialize/deserialize, file I/O                       |
| `EventBus`    | Global signals (loot dropped, enemy died, level up)   |
| `SceneRouter` | Zone transitions, town↔wilderness↔dungeon            |
| `Database`    | Read-only lookups: items, enemies, classes            |

No business logic in autoloads beyond what their name implies. `GameState`
does not handle combat. `EventBus` declares signals; it does not emit them
on behalf of others.

## Signals

- Connect signals in `_ready()`. Never in `_process()`.
- Disconnect in `_exit_tree()` only if the source outlives the listener
  (rare with EventBus; common with parent → child).
- Signal names are past-tense events: `enemy_died`, `item_dropped`,
  `stats_changed`. Not `kill_enemy` or `do_drop`.
- One signal per logical event. Do not overload `state_changed(what)` with
  string discriminators.

## Forbidden patterns

- `get_tree().root.get_node("Main/UI/HUD/HealthBar")` — use EventBus.
- `if owner is Player:` — query a component, not the type.
- Scene files committed with absolute paths.
- `@onready` chains longer than two levels deep into a foreign subtree.
- Mutating another scene's nodes from outside its root script.

## Isometric specifics

- Y-sort enabled on the gameplay root for depth ordering.
- All gameplay sprites pivot at the bottom-center (the "feet").
- Collision shapes are flattened ellipses at the feet, not full sprite boxes.
- Camera is `Camera2D` with integer snap to avoid sub-pixel shimmer.
