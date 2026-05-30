# Architecture Decisions — Locked

These calls were made at project genesis to avoid expensive retrofits.
They are binding. Do not re-litigate them in later sessions without
explicit user approval. If a request would violate one, surface the
conflict and cite this file.

---

## AD-01 — `Stats` is a `Resource`, not a `Node`

`Stats extends Resource` so it serializes cleanly, swaps trivially, and
is referenced by `Player`, `Enemy`, and indirectly by `Item` (via
deltas). Combatant scenes own a `Stats` instance in a `current_stats`
property.

**Why:** Resources duplicate cleanly, save without scene-tree gymnastics,
and survive the "snapshot for buff layering" use-case without extra
allocation patterns.

---

## AD-02 — One `player.tscn`, class data injected at runtime

There is one `Player` scene with one `Player` script. The four classes
are `ClassData` resources (`data/classes/*.tres`) loaded at character
select and assigned to `Player.class_data`.

**Why:** Four divergent player scenes drift. Skills and stats already
vary per class via resources — the scene does not need to vary too.
The procedural sprite is a child `Node2D` whose subtree is swapped
based on `class_data.sprite_scene`.

---

## AD-03 — `Database` autoload preloads `data/` at boot

`Database` is the only legal way to look up items, enemies, classes,
and skills at runtime. No `load("res://data/items/foo.tres")` outside
`Database._ready()`. Everything is keyed by `StringName` ID.

**Why:** Centralizes paths so renames don't ripple. Enables save-by-ID
(see AD-06). Surfaces missing data at boot, not mid-combat.

---

## AD-04 — All damage routes through `DamageResolver`

Skills, basic attacks, DoTs, environmental hazards — all call
`DamageResolver.resolve(attack: Attack, defender: Stats) -> int`. No
script does damage math inline.

**Why:** The most common ARPG bug is two damage paths that subtly
disagree. One entry point. One bug surface.

---

## AD-05 — `Attack` is a Resource with a `damage_type` enum from day one

`Attack extends Resource` carries: `source`, `base_damage`,
`damage_type: DamageType`, `flags: int`. The enum exists in Stage 0
with **one value: `PHYSICAL`**. A comment notes more arrive in Act 2.

**Why:** This is the *only* permitted Act-2-aware stub. Changing a
function signature later costs more than reserving the field. The
forbidden stats (Block/Cast/Hit) get no such accommodation because
they pollute UI and balance math; an enum value does not.

---

## AD-06 — Saves store item IDs, not resource paths

`SaveSystem` writes `StringName` IDs into the save dict. Load resolves
IDs via `Database`. No serialized `res://` paths.

**Why:** Moving a `.tres` file breaks old saves if paths are baked in.
IDs survive reorganization.

---

## AD-07 — `SaveSystem` versioned from Stage 0

`SAVE_VERSION: int` and `migrate(old: Dictionary) -> Dictionary` exist
from the bootstrap stub. Every schema change bumps the version and
adds a migration step. No exceptions.

**Why:** Retrofitting migrations after the fact means losing every
test save and every player save in the wild.

---

## AD-08 — EventBus signal whitelist (cap)

`EventBus` carries exactly these signals in Act 1:

- `enemy_died(enemy, killer)`
- `item_dropped(item_id, world_pos)`
- `item_picked_up(item_id)`
- `player_died`
- `player_leveled(new_level)`
- `zone_changed(zone_id)`
- `stats_changed(owner)`

Adding a new EventBus signal requires user approval. Per-scene signals
go on the emitter, not the bus.

**Why:** EventBus grows like kudzu without a cap. Once everything is
global, nothing is debuggable.

---

## AD-09 — Click-to-move primary, WASD secondary

Input model: click-to-move is the canonical Diablo-lineage control.
WASD is exposed in the options menu as an alternative. Both paths feed
the same `Player` movement state machine — not two independent
implementations.

**Why:** Building both fully is wasted work; building neither leads to
indecision. Click-to-move drives the genre fantasy.

---

## AD-10 — Inventory is a slot list, not a grid (Act 1)

Inventory uses fixed-slot lists with type filters (weapon/armor/consumable).
The Diablo-style grid is parked in `parking_lot.md` for post-launch.

**Why:** Grid inventory doubles UI complexity (rotation, packing, drag
math) for marginal Act 1 value. Slot list ships.

---

## AD-11 — Procedural sprite scenes expose canonical animation names

Every procedural sprite implements the same `AnimationPlayer` track
names: `idle`, `walk`, `attack`, `cast`, `hit`, `die`. Bitmap
replacements implement the same names. Calling code (`play("attack")`)
never changes during the swap.

**Why:** The art swap (Stage 12) becomes a node-type change, not a
code rewrite.

---

## When to revisit

These decisions are revisitable only when:
- A specific concrete bug or scope problem forces it, AND
- The user explicitly approves the change, AND
- The replacement decision is added to this file with an `AD-NN-superseded`
  marker on the old one, not silently mutated.
