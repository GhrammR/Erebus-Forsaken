# Parking Lot

Ideas explicitly **not** in Act 1 scope. Recorded so they are not lost
and so they do not silently leak into active work. Items here move into
scope only via explicit user approval and only when an Act 1 item is
fully complete.

## Format

```
### <slug> — <one-line idea>
- Why parked: <reason>
- Earliest revisit: <act / milestone>
- Notes: <freeform>
```

---

### grid-inventory — Diablo-style grid inventory
- Why parked: AD-10 — slot list ships Act 1; grid doubles UI complexity.
- Earliest revisit: post-Act-1 polish, before Act 2.

### second-skill-per-class — Second starter skill per class
- Why parked: rules/scope-lock.md permits this only after every other
  Act 1 checklist item is complete.
- Earliest revisit: between Stage 10 and Stage 11.

### elemental-damage-types — Fire/Cold/Lightning/Poison split
- Why parked: Act 2 scope; Resistance is a single combined % in Act 1.
- Earliest revisit: Act 2 design.

### swarm-enemy — "Looks inert, bursts into a cluster on hit" wilderness archetype
- Why parked: Stage 7 ships only Shade-Wretch (melee) and Bog-Caller
  (ranged); a third archetype is a content addition, not a polish
  pass. Decided 2026-06-03 while debugging monster-stacking visuals.
- Earliest revisit: post-Steam-EA content drop or expansion pack.
- Notes: parent has low HP, `died` signal fan-outs N children via
  `call_deferred` with jitter. Children inherit a reduced-weight
  drop table so loot doesn't explode. Cap child count so a chain
  reaction can't blow past SpawnDirector.concurrent_cap. Theme
  candidates that fit the primordial-void lexicon: Tomb-Spawn,
  Ichor Pod, Spartoi Husk.

### smart-ai-presence — Summon & monster AI that feels alive in idle moments
- Why parked: Stage 9 ships a minimum-viable patrol on the Bone
  Servant (random points in a ring + look-around pause). Idle
  monster wandering and richer summon behaviour (bias away from
  recently-occupied points, head-turns toward sound events, brief
  inspect-the-corpse routines) belong to a dedicated AI polish
  pass after Act 1 ships — the verifier surface alone for "AI
  feels alive" is a week of work.
- Earliest revisit: between Steam EA launch and first content drop.
- Notes: applies to all current and future summons, all standard
  enemies, plus the Act boss between phases. Single shared
  behaviour-tree skeleton, parameterised per entity. Bone Servant's
  `_pick_patrol_point` already has a TODO pointer here.

### clickable-skill-hud — Click-to-cast on HUD skill tiles
- Why parked: Stage 9.5 ships the cooldown indicator as
  display-only (`mouse_filter = IGNORE`) so it doesn't eat
  click-to-move (failure-modes.md #14). Letting the tile accept
  clicks needs careful input precedence: a click on the tile
  should cast the skill, a click anywhere else should still
  move. The implementation is small but the testing matrix
  isn't (tile + modal-open + skill-on-cooldown + dead player +
  click-and-drag), so it's polish, not Feel Pass scope.
- Earliest revisit: Stage 12 (pre-launch polish), alongside
  the title-screen and options-menu pass.
- Notes: same Esc-to-close + mouse-filter discipline as the
  modal contract. The HUD tile would be hover-highlighted
  (tween modulate on `mouse_entered`), `gui_input` consumes
  `MOUSE_BUTTON_LEFT` only when over the tile, and `try_activate`
  routes through the existing skill path. The keybind ("1") and
  the click do the same thing — no parallel cooldown state.

### walk-run-toggle — Movement-mode switch with a small stat trade
- Why parked: Act 1 ships one movement speed per entity. Toggling
  between walk and run is a UX hook that wants its own input
  binding, a HUD indicator, and balance work on the trade-off.
  Worth nothing until the core feel is settled.
- Earliest revisit: between Stage 11 (save hardening) and Stage 12.
- Notes: Diablo 2 precedent — running was faster but cost stamina
  and reduced block chance; walking was slower but defensively
  better. Our Act 1 equivalent (BlockChance is forbidden by
  stat-system.md until Act 2) could be a small armor/mitigation
  bump while walking, or a faster MP regen, or a quieter aggro
  radius so walking lets the player scout. Apply the same toggle
  to AI summons: walk-speed while idle/patrolling, run-speed to
  catch up to the player or close on a target. Keybind candidate:
  `caps_lock` (toggle) or `shift` (held).

### character-sheet — Production stats screen
- Why parked: today only the dev `DebugStatOverlay` (Stage 1)
  shows live stats. A real character sheet — attribute breakdown,
  damage range, hit chance, mitigation, equipment-derived
  contributions broken out by source — wants its own UI scene
  and stays in scope-creep risk until the four classes and
  itemization are stable.
- Earliest revisit: Stage 12 (pre-launch polish) — fits the same
  pass as the title screen and options menu.
- Notes: keybind `C`. The Esc-to-close modal contract from
  `rules/testing.md` applies. Source breakdown rows ("STR 18 =
  10 base + 5 level + 3 from Hoplon Spear") are the win
  condition — anyone can show a stat total; surfacing
  *where it came from* is what makes the sheet useful.

### skill-page — Production skill screen
- Why parked: same reasoning as character-sheet. The one-skill-
  per-class scope-lock means the page would have one tile to
  display in Act 1; not worth a dedicated scene until the second
  skill per class lands (parking_lot.md::second-skill-per-class).
- Earliest revisit: same window as second-skill-per-class.
- Notes: keybind `K`. Hosts the cooldown ring, MP cost, current
  effective damage (including unique-item skill_bonus_*),
  description.

### other-ui-pages — Quest log + map + lore codex
- Why parked: Act 1 has one quest (Stage 6 Phase 4) and
  hand-placed zones. A quest log adds inventory complexity for
  one row of content; a minimap requires zone-aware rendering
  that isn't free. Lore codex is content-gated by Act 2's
  narrative scope.
- Earliest revisit: post-Act-1, alongside Act 2 zone work.
- Notes: keybinds `J` (quest log), `M` (map), `L` (codex).
  Mutually-exclusive modal contract applies — one open at a
  time, all close on Esc per `rules/testing.md`.

### monster-pathfinding — Proper navmesh pathfinding for AI
- Why parked: Stage 9 wretches and the Bone Servant just steer
  toward their target. With walls between, they walk into the
  wall. LOS-gate on target acquisition (Stage 9 polish, hardened
  in Stage 9.5 with `hit_from_inside = true` so chest-inside-wall
  doesn't false-positive "clear") papered over the worst case
  (no LOS = no target = idle), but two derived behaviours remain
  parked:
  - **"Player runs behind a wall, enemy gives up entirely"** —
    currently intended fallback. Without navmesh the enemy can't
    route around; idle is the only readable outcome. Navmesh
    should replace this with a "path to last known position,
    then search briefly" routine before deaggro.
  - **"Enemy stuck against a wall doesn't retarget when a
    Bone Servant attacks it"** — without pathing the wretch
    can't re-evaluate while pressed against an unreachable
    target's wall. Navmesh + a "took damage from someone I'm
    not targeting → retarget" hook on `HealthComponent.damaged`
    would close this. Today the minion gets free swings on a
    stuck wretch — known and parked.
  - Real fix: `NavigationRegion2D` per zone (baked on zone load,
    not editor-time, so procedurally adjusted zones still work),
    `NavigationAgent2D` per enemy, `set_target_position` instead
    of raw steering, plus the damage-retarget hook above.
- Earliest revisit: post-Stage-9.7. Feel Pass first, then endless
  mode, then pathfinding before itch.io demo.
- Notes: boss is exempt — phases are scripted, raw steering is
  fine for an arena encounter. Linked: [[smart-ai-presence]] for
  the "what does the enemy do between actions" pass that would
  ride alongside navmesh.

### modular-sprite-polish — Per-part replacement polish pass
- Why parked: every procedural sprite already follows the
  modular subtree contract (rules/asset-pipeline.md), so a
  polish pass can replace individual parts without touching
  silhouette or animation. The pass itself — adding bone
  textures, flowing cloth shaders, facial detail, weapon
  details — is a deliberate Stage 12 (or post-launch content
  drop) item, not something to drift into now.
- Earliest revisit: Stage 12, after the title screen lands.
- Notes: priority order based on screen time — Player classes,
  then standard enemies (wretch, bog-caller), then Act boss,
  then Bone Servant, then NPCs. Each part swap is its own
  PR-sized unit. Bitmap and detailed-procedural treatments
  can coexist via the same subnode names.

### flying-summons — Summons that traverse ledges/cliffs but not solid walls
- Why parked: zone geometry is single-plane in Act 1 (no cliffs or
  pits — perimeter walls are the only verticality concept). A
  flying-vs-grounded distinction needs both new collision layers and
  new zone authoring conventions. Worth nothing until Act 2's
  vertical zone (planned Hades-style descending shafts) lands.
- Earliest revisit: Act 2 zone design.
- Notes: layer split — ground summons mask {walls + ledges},
  flying summons mask {walls only}. Pathfinding nav-mesh would
  carry a `ledge` polygon class flying summons ignore. Both still
  blocked by walls (no walking through a closed gate at any altitude).
