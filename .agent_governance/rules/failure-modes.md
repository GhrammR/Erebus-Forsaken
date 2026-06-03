# Failure Modes — Known Collapse Vectors

Every entry below has killed a solo indie ARPG before. Read this before
agreeing to anything that smells like one of them.

---

## 1. Scope creep

**Symptom:** "While we're here, let's also add..." Three weeks later, Act 1
has 80% of Act 2's features and none of Act 1's polish.

**Prevention:**
- `rules/scope-lock.md` is the bouncer. Cite it.
- Track every "nice-to-have" in a `parking_lot.md` outside scope, not in
  active task lists.
- Stages do not overlap. Stage N+1 does not begin until Stage N is signed off.

**Recovery:** If creep already happened, list every in-flight feature, rank
by Act 1 necessity, finish the top three, delete the rest.

---

## 2. Art blocking mechanics

**Symptom:** "I can't tell if this skill feels right because the animation
isn't done." Mechanic stalls waiting for visuals.

**Prevention:**
- Procedural sprites ship with every mechanic. See `rules/asset-pipeline.md`.
- "Looks ugly" is never a reason to halt combat tuning.
- Bitmaps integrate *after* the underlying system is signed off.

**Recovery:** Rip out the half-finished bitmap, restore the procedural
sprite, finish the mechanic, then revisit.

---

## 3. Shallow systems rushed for content

**Symptom:** Five enemy types exist, but none have death animations,
attack telegraphs, or distinct AI. Six skills exist, none feel different.

**Prevention:**
- `rules/testing.md` definition of done — full checklist per feature.
- One enemy, finished, before two enemies. One skill, finished, before two.
- Depth before breadth, always.

**Recovery:** Pick the one most-used enemy/skill, polish it to ship quality,
use that as the template, then redo the rest.

---

## 4. Context loss between sessions

**Symptom:** Claude rewrites stat formulas because it forgot the existing
ones. Or builds a new SaveSystem because it didn't know one existed.

**Prevention:**
- Session start protocol in `CLAUDE.md` (read charter + status + relevant
  rules).
- `commands/act1-status.md` is the source of truth for "what is done."
- One source of truth per system. Stat math lives in `Stats`. Save format
  lives in `SaveSystem`. Don't reinvent.
- When uncertain whether something exists, search before writing.

**Recovery:** Audit (`commands/audit.md`). Find duplicates, delete the
weaker one, document the survivor.

---

## 5. Stat system fragmentation

**Symptom:** Damage math in three different scripts, none agree. UI shows
different numbers than the damage that lands.

**Prevention:** `rules/stat-system.md`. Anything that touches a derived
stat goes through the `Stats` resource. No exceptions.

**Recovery:** Grep for arithmetic on attribute names, route every hit
through `Stats`, delete the inline math.

---

## 6. Signal spaghetti

**Symptom:** A loot drop fires events that cascade through six listeners,
two of which mutate the player. Bug repro requires a sequence of five
actions in order.

**Prevention:**
- `EventBus` declares signals; emitters are explicit; listeners are few.
- Signal handlers do one thing. If a handler is over 20 lines, extract a
  function.
- Past-tense names only — handlers react, they do not command.

**Recovery:** Draw the signal graph. Cut every edge that has only one
caller and one listener — replace with a direct method call.

---

## 7. Save/load drift

**Symptom:** New feature added, save format not updated, old saves crash on
load or silently lose data.

**Prevention:**
- `SaveSystem` versioned from day one (`version: int` in save dict).
- Every persisted field declared in one place per entity type.
- Testing checklist includes save→quit→load on every feature.

**Recovery:** Bump save version, write a migration function, test against
saved files from previous version.

---

## 8. The "Act 2 stat trap"

**Symptom:** Someone (Claude, future-you) adds `cast_speed: 0` to the Stats
resource "for later." Now it appears in tooltips, item rolls, and balance
math, polluting Act 1.

**Prevention:** `rules/stat-system.md` — the three deferred stats do not
exist in any file during Act 1.

**Recovery:** Grep for `block_chance`, `cast_speed`, `hit_recovery`. Delete
every occurrence. No mercy.

---

---

## 9. Control nodes silently eating gameplay input

**Symptom:** Click-to-move "doesn't work." Mouse clicks register nowhere
in `_unhandled_input`. Often appears after adding a fullscreen background
`ColorRect`, a HUD `Label`, a `PanelContainer` overlay, or a `Margin`/
`RichTextLabel`. The symptom is silence — no error, no warning, the
click just vanishes.

**Root cause:** Every Godot `Control` defaults `mouse_filter = STOP`.
A `Control` with `STOP` consumes mouse events in its rect before
`_unhandled_input` ever runs. Passive HUD/overlay/background `Control`s
are usually not meant to be interactive — but they consume input
anyway.

**Prevention:**
- Any `Control` that exists for *display only* must set
  `mouse_filter = MOUSE_FILTER_IGNORE` (value `2`) in its `.tscn`.
- This includes: backgrounds (`ColorRect`), HUD `Label`s, debug
  overlays (`PanelContainer` + children), tooltips, decorative
  panels.
- Buttons, scroll bars, and *intentional* click absorbers (the pause
  menu's dimmer) keep the default `STOP`.
- Audit: see `skills/scene-auditor/` check #6.

**Recovery:** Find every Control in the offending scene. Decide for
each whether it should absorb input. For the no's, set
`mouse_filter = 2`. Re-test the gameplay click path immediately —
don't trust scenes you haven't clicked through.

**First incident:** Stage 2 movement workbench. The fullscreen
`Background` `ColorRect`, HUD `Help` and `DebugInfo` labels, and the
stat overlay's `Panel`/`Margin`/`Label` all defaulted to `STOP`.
Workbench appeared to ignore mouse clicks entirely until each Control
was switched to `IGNORE`.

---

## 10. Click-to-move on a collidable target

**Symptom:** Click-to-move on an enemy, an NPC, a prop, or near a wall
causes the player to walk into the target and then orbit it or jitter
in place forever. The click marker stays lit; the player visibly tries
to keep moving.

**Root cause:** The click target is a world position. Collision between
the player's body and the target's body prevents the player from
reaching the target within `ARRIVE_THRESHOLD`. `move_and_slide()`
slides the player along the contact normal — toward the click direction
but tangent to the obstacle — producing an orbit. The arrive check
never trips, so the click target is never cleared.

**Prevention:**
- Pair `ARRIVE_THRESHOLD` with **stuck detection**: if a click target
  is active and the body's actual movement per physics frame falls below
  a threshold for several frames in a row, drop the target. See
  `scripts/player/player_input.gd` constants `STUCK_FRAMES`,
  `STUCK_MIN_MOVEMENT`.
- WASD movement must also reset the stuck counter on every active frame.
- Once Stage 5's click-on-enemy auto-attack lands, the click handler
  should detect clicks landing on an enemy hurtbox and switch from
  "move to point" to "move to attack range then swing." That removes
  the bug at the source for the enemy case; stuck detection still
  protects the wall/prop cases.

**Recovery:** Add stuck detection per above. Verify by clicking on a
training dummy: player should drift toward it for ~1/3 s, then stop
cleanly with the click marker hidden.

**First incident:** Stage 3 combat workbench. Clicking on a dummy.

---

## 11. Animation leaves persistent transform state on the sprite root

**Symptom:** After a one-shot animation (death, hit, cast) finishes,
the sprite stays in its end pose — rotated, faded, recolored — even
when a fresh animation (`idle`, `walk`) starts playing. The character
respawns "lying down" or semi-transparent.

**Root cause:** `AnimationPlayer` tracks only modify the properties
they animate. If `die` keys `rotation: 0 → PI/2` and `modulate.a: 1 → 0.3`,
those endpoint values stay on the node after the animation ends. The
follow-up animation (`idle`) doesn't reset them because its tracks
don't touch those properties.

**Prevention:**
- For respawn/revive paths: explicitly reset the sprite root's
  `rotation`, `position`, `modulate`, and any other property a destructive
  one-shot animation might have keyed, *before* playing the resume
  animation.
- Stop the AnimationPlayer (`anim.stop()`) before playing the resume
  animation so the previous track values fully release.
- Alternative: make every destructive one-shot animation key its
  properties back to their resting values in a final frame. Less
  flexible (resting values can drift) — explicit reset on revive is
  more robust.

**Recovery:** In the revive function, reset every property the
destructive animation touched. For the Myrmidon: `sprite_root.rotation
= 0`, `sprite_root.modulate = Color(1,1,1,1)`, then `anim.stop()`,
then `anim.play("idle")`.

**First incident:** Stage 3 K-kill-self self-test. Player visibly
respawned on its side and faded.

---

## 12. Directional hitbox + insufficient facing model = dead-angle attacks

**Symptom:** Player can attack enemies on the left or right but not
above or below. The hit registers in some screen directions only.

**Root cause:** A `HitboxComponent` rectangle (or any non-circular shape)
parented under a Node whose facing transform only encodes L/R (boolean
`_facing_right` + `scale.x = ±1`). The hitbox mirrors horizontally with
the sprite, but no rotation / up/down translation happens — the box
literally has no presence on the up/down axis at swing time.

**Prevention:**
- For *non-directional* basic attacks (ARPG melee cleave, AoE-around-self),
  use a `CircleShape2D` centered on the actor's chest. The hitbox is
  geometrically symmetric so facing does not matter.
- For *directional* skills (lunge, swing, projectile), introduce a
  `facing_dir: Vector2` (not a `facing_right: bool`) tracked from the
  most recent non-zero `_intent` (or click target / aim cursor). Rotate
  the hitbox to match. This is required for Stage 5 skills (Spear
  Lunge, Volley, etc.).
- Sprite art that only ships L/R poses limits the *visual* facing, but
  do not let that limitation cascade into the *gameplay* hit geometry.

**Recovery:** Replace the directional rectangle with a circle centered
on the actor; verify by attacking enemies directly above and below.

**First incident:** Stage 4 loot workbench playtest. Player could
attack dummies to the left/right of the Myrmidon but not above/below.
Resolved by switching the basic-attack hitbox to a `CircleShape2D`
(radius 40, centered at player chest). Sprite remained L/R-only; that
is documented Stage 12 polish, not a regression.

---

## 13. CollisionObject2D silently eating gameplay mouse clicks

**Symptom:** Click-to-move "dead zones" appear around things. The
biggest, most visible one is the area around the player; smaller ones
appear wherever enemies stand. Apparently "random patches" of unclickable
ground is the giveaway — those patches are the bodies' colliders.
Clicks inside the dead zone do nothing; clicks just outside work. No
errors fire.

**Root cause:** `CollisionObject2D` — the parent of `Area2D`, `StaticBody2D`,
`RigidBody2D`, **and `CharacterBody2D`** — defaults `input_pickable = true`.
Any picked collider consumes mouse events before they reach
`_unhandled_input`, even when no `input_event` handler is connected.
This means *every* physics body silently swallows click-to-move events
within its collision shape, not just `Area2D`s.

This is the physics analogue of failure-modes #9 (passive Controls
swallowing input via `mouse_filter = STOP`).

**Prevention:**
- Every `CollisionObject2D` subclass that is *not* meant to receive
  mouse input must set `input_pickable = false` — either in `.tscn` or
  in `_ready()`.
- Applies to **all** `CharacterBody2D` (player, enemies, NPCs),
  **all** `Area2D` (hitboxes, hurtboxes, pickup zones, triggers),
  **all** `StaticBody2D`/`RigidBody2D` (props, walls). Until a body
  *needs* mouse picking, default to off.
- For project-wide actors, do it in the actor's base script `_ready`
  so every subclass and instance gets the override automatically.
  This project does it in `Player._ready`, `Enemy._ready`,
  `HitboxComponent._ready`, `HurtboxComponent._ready`,
  and `WorldItem._ready`.
- Reserve `input_pickable = true` for cases where you actively *want*
  the body to be clickable (e.g., a future "click on enemy to attack"
  handler — Stage 5+ may opt into this, deliberately, on enemy hurtboxes).
- Audit: scene-auditor check #8.

**Recovery:** Find every gameplay `CollisionObject2D` in the scene
tree (grep for `type="CharacterBody2D"`, `type="Area2D"`,
`type="StaticBody2D"`, `type="RigidBody2D"`). For each, decide
whether it needs to receive mouse input. For the no's, set
`input_pickable = false` (script `_ready` if it's a reusable actor;
`.tscn` property if it's a one-off). Re-test click movement directly
on top of every collider in the scene.

**First incident:** Stage 4 close. Triggered by two layers — first,
the 40-radius `CircleShape2D` hitbox change (failure-modes #12) made
the dead zone around the player large and obvious; second, after
patching the Area2D components, the player's and dummies' own
`CharacterBody2D` colliders still consumed clicks. The first fix
covered `HitboxComponent` / `HurtboxComponent` / `WorldItem.PickupArea`;
the second fix added `input_pickable = false` to `Player._ready`
and `Enemy._ready`. **Lesson:** treat `CollisionObject2D` as the
unit of concern, not `Area2D` specifically.

---

## 14. CanvasLayer.visible = false does not disable child Control input

**Symptom:** A pause menu, inventory panel, or any other CanvasLayer-
based UI is hidden via `hide()` / `visible = false` and looks gone, but
its Control children **still consume mouse clicks within their rects**.
The result is invisible click dead zones, often fullscreen ones when
a Dimmer ColorRect with `anchors_preset = 15` is involved.

This is failure-mode #9 (Control mouse_filter STOP) and #13
(CollisionObject2D input_pickable) compounded into one. The bug is
that the *visible flag on the CanvasLayer* affects rendering but not
the input-handling status of its child Controls — they keep absorbing
clicks even while invisible.

Confirmed by Stage 4 close diagnostic: walking the scene tree and
listing every Control whose `mouse_filter != IGNORE` surfaced:
- `Main/Background` (1280×720, STOP, visible) — main scene background.
- `PauseMenu/Dimmer` (1280×720, STOP, visible — *but inside a hidden
  CanvasLayer*).
- `PauseMenu/Panel` (240×160, STOP, visible — same).

The "fullscreen dead zone" reported in the workbench was the union of
the Background and the still-active hidden-PauseMenu Dimmer.

**Root cause:** In Godot 4 the `CanvasLayer.visible` flag controls
drawing, not input. The CanvasLayer skips its render pass, but the
underlying Control nodes still report themselves to the GUI input
pipeline and consume events as their `mouse_filter` dictates.
`mouse_filter = STOP` (the Control default) eats every click within
the rect.

**Prevention:**
- Every Control in a hideable UI scene (pause menu, inventory panel,
  dialog, tooltip, modal) must either:
  1. Set `mouse_filter = MOUSE_FILTER_IGNORE` in `.tscn` AND keep it
     that way while hidden, OR
  2. Have its script flip `mouse_filter` between STOP and IGNORE in
     concert with `show()` / `hide()` via an `_set_input_active()`
     helper that walks the subtree recursively (see `pause_menu.gd`
     and `inventory_panel.gd` for the pattern).
- For the *pause menu specifically*, set the CanvasLayer's
  `process_mode = PROCESS_MODE_WHEN_PAUSED` (value `2` in `.tscn`).
  When the game isn't paused, the menu and all its children stop
  processing input entirely. Combine with the `_set_input_active`
  toggle as belt-and-suspenders.
- For *backgrounds* and *decorative panels*, set `mouse_filter = 2`
  in the `.tscn` from the start. There is no reason for a background
  to be a STOP filter.

**Recovery:** Walk the entire scene tree at startup and print every
Control whose `mouse_filter != IGNORE`, including its rect and parent
chain. That diagnostic surfaces the culprits instantly:

```gdscript
func _walk_for_input_culprits(n: Node) -> void:
    if n is Control:
        var c := n as Control
        if c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
            print(c.get_path(), " filter=", c.mouse_filter,
                  " rect=", c.get_global_rect())
    for child in n.get_children():
        _walk_for_input_culprits(child)
```

**First incident:** Stage 4 close. Took five separate sessions of
diagnosis spanning click-on-collider stuck loops (#10), post-die
transform reset (#11), directional hitbox (#12), and CollisionObject2D
input_pickable (#13) before this one surfaced as the actual primary
cause of "click-to-move has dead zones near the player." Each prior
fix was a real bug, but none was the root of the screen-edge dead
zones — those were the main-scene Background and the hidden pause
menu's Dimmer. The walk-the-tree diagnostic identified all three
culprits in a single pass.

**Lessons applied to governance:**
- scene-auditor check #9 added: walk the tree at workbench startup,
  fail on any Control with `mouse_filter != IGNORE` that isn't either
  an active button or explicitly opt-in.
- `pause_menu.gd` and `inventory_panel.gd` now own their input-active
  state through an `_set_input_active(bool)` method that recurses
  into children; called from `_ready`, `open`, and `hide` paths.
- `scenes/main.tscn` Background + labels: `mouse_filter = 2`.
- `pause_menu.tscn` CanvasLayer: `process_mode = 2 (WHEN_PAUSED)`.

---

## 15. Per-frame anim updater clobbers one-shot animations

**Symptom:** A skill, basic attack, or hit-reaction visibly doesn't
animate. The character stays in idle or walk. The AnimationPlayer is
correctly receiving `.play("attack")` calls — you can confirm it with
a print — but the animation never actually plays a single frame on
screen. Often the only animation that "works" is the one that already
forces a movement lock (so the per-frame updater bails out before
overwriting).

**Root cause:** Many actor scripts (`Player`, future `Enemy` with
behavior) call an `_update_anim()` from `_physics_process`, which
picks `walk` or `idle` based on movement intent and immediately
plays it. This runs ~60×/second. A one-shot call like
`play("attack")` survives for a single frame before the per-frame
update re-plays `idle`/`walk` from the top — the one-shot never gets
a chance to render.

**Prevention:**
- The per-frame anim updater must guard against in-progress one-shot
  anims:
  ```gdscript
  const _ONESHOT_ANIMS: Array[StringName] = [&"attack", &"cast", &"hit", &"die"]
  func _update_anim() -> void:
      if _sprite_anim == null: return
      if _sprite_anim.current_animation in _ONESHOT_ANIMS \
              and _sprite_anim.is_playing():
          return  # let the one-shot finish before resuming idle/walk
      var anim_name := &"walk" if _intent != Vector2.ZERO else &"idle"
      if _sprite_anim.current_animation != anim_name:
          _sprite_anim.play(anim_name)
  ```
- Why this works: idle and walk are loop anims; `is_playing()` stays
  true forever, so they never short-circuit themselves. Attack/cast/
  hit/die are one-shots; `is_playing()` flips to false the moment the
  animation ends, and the updater resumes idle/walk seamlessly.
- This is the **only** AD-11-mandated guard for movement-not-locked
  skills. If the skill DOES lock movement (sets a combat state and
  early-returns from `_physics_process`), the guard is redundant but
  doesn't hurt.

**Recovery:** Add the `_ONESHOT_ANIMS` constant + early-return
to every actor's `_update_anim` function. Visually verify each
canonical anim (attack/cast/hit/die) by triggering it in the workbench.

**First incident:** Stage 5 close. Skills called
`play_sprite_anim("cast")` / `"attack"` on every class but no
animation ever played because `Player._update_anim` was re-firing
idle/walk every physics frame. The basic-attack animation worked
because the player's `_combat = ATTACKING` state caused
`_physics_process` to early-return before calling `_update_anim` —
masking the bug entirely. Fix: the guard above on `Player._update_anim`.
Skills now visibly animate.

---

## 16. Paused PlayerInput swallows the unpause key

**Symptom:** Pressing Esc opens the pause menu. Pressing Esc again
does nothing — the pause menu stays up. The Resume button still works.
Same pattern would apply to any "modal opens via PlayerInput, then
pauses the tree" UI.

**Root cause:** `PlayerInput` is a child of `Player` which inherits
the default `PROCESS_MODE_PAUSABLE`. The moment something sets
`get_tree().paused = true`, `PlayerInput._unhandled_input` stops
firing. The signal that opened the modal can never fire to close it
because the input source is itself paused.

**Prevention:**
- Modals that pause the tree (currently just PauseMenu) MUST close
  themselves on Esc via their own `_input` override. The CanvasLayer
  hosting the modal must have `process_mode = WHEN_PAUSED` (or
  `ALWAYS`) so `_input` still fires while paused.
- See testing.md "Modal UI — Esc-to-close contract" for the
  reference pattern. Both `inventory_panel.gd` (non-pausing modal)
  and `pause_menu.gd` (pausing modal) implement it.

**Recovery:** If a future pausing modal exhibits this symptom, add
`_input(event)` that consumes Esc while `visible` and calls
`get_viewport().set_input_as_handled()`. Verify the modal's
CanvasLayer is `WHEN_PAUSED` in the .tscn.

**First incident:** Visual playtest after Stage 5 cleanup. Pause
menu opened on Esc but Esc failed to close it because PlayerInput
was paused. Fix: `PauseMenu._input` handles Esc directly.

---

## 17. Area2D added (or its state changed) mid-physics-flush

**Symptom:** Errors printed during combat:
`ERROR: Can't change this state while flushing queries. Use
call_deferred() or set_deferred() to change monitoring state instead.`
Gameplay continues — usually nothing visibly breaks — but the log
fills up. The errors typically come in bursts that correlate with
something dying or a hit landing.

**Root cause:** A node tree containing an `Area2D` is added to the
scene tree (or an `Area2D`'s `monitoring` / `monitorable` /
`collision_layer` / `collision_mask` / shape `disabled` is mutated
synchronously) from inside a callback chain that originated in a
physics flush. The chain looks like:
`Area2D.area_entered/body_entered (physics flush)` →
`HealthComponent.take_damage` → `died` signal →
`_on_died` handler → `add_child(thing_with_an_Area2D)` — and the new
Area2D's automatic registration with the physics server happens
synchronously while the server is still flushing the prior query.

**Prevention:**
- Any `add_child` of a scene that contains an `Area2D` (HurtboxComponent,
  HitboxComponent, PickupArea, etc.) inside a damage/death callback
  must be wrapped in `call_deferred`:
  ```gdscript
  _spawn_thing.call_deferred(args...)
  func _spawn_thing(...): get_parent().add_child(thing)
  ```
- Any direct mutation of an Area2D's `monitoring`, `monitorable`,
  `collision_layer`, `collision_mask`, or a CollisionShape2D's
  `disabled` must use `set_deferred` if it could conceivably run
  inside a physics callback. Default to deferred in component
  `_ready`s as well, since the component author can't predict whether
  the component will later be spawned mid-flush.

**Recovery:** Search for direct (non-deferred) physics-state writes:
```
grep -rn "\.disabled\s*=\|\.monitoring\s*=\|\.monitorable\s*=\
\|\.collision_layer\s*=\|\.collision_mask\s*=" scripts scenes \
  | grep -vE "set_deferred|^\s*#"
```
For `add_child` calls of Area2D-bearing scenes, audit each
`_on_died` / `_on_damaged` / `area_entered` / `body_entered`
handler and any signal handler reachable from them.

**First incident:** Stage 5 visual playtest. `Enemy._try_drop` was
called from `_on_died` (fired during a physics flush) and
synchronously `add_child`ed a `WorldItem` whose `PickupArea` Area2D
registered with the physics server mid-flush. Fix: route the spawn
through `_spawn_world_item.call_deferred(...)`. Also tightened
`HitboxComponent._ready` to set its shape's `disabled` deferred,
since hitbox components are spawned from skill code and may run
under callback contexts in future skills.

---

## 18. New `class_name`s not picked up in headless verifier runs

**Symptom:** Add a new GDScript with `class_name Foo extends Node`,
reference `Foo` from another script, then run a headless verifier:
`SCRIPT ERROR: Parse Error: Could not find type "Foo" in the
current scope.` The editor (if opened separately) finds the class
fine; only the headless run breaks.

**Root cause:** Godot 4 maintains a `class_name` registry in
`.godot/global_script_class_cache.cfg`. Headless invocations
(`godot --headless …`) do not refresh this cache; only an editor
session does. New `class_name` declarations are invisible to a
headless run until the editor has scanned the project once.

**Prevention:**
- After adding any new `class_name` declaration, run
  `godot --headless --editor --path . --quit` once before invoking
  the headless verifier. The editor refreshes the cache and exits
  cleanly in roughly the time it would take to import any new
  binary assets.
- Do **not** hand-edit `.godot/global_script_class_cache.cfg`. It's
  a generated file; manual edits work locally but never persist
  (the `.godot/` directory is gitignored) and they can desync if
  the file is touched by both you and the engine.

**Recovery:** If a headless run is throwing "Identifier X not
declared" or "Could not find type X" for a class that obviously
exists, run the one-shot editor bootstrap above and retry.

**First incident:** Stage 6 Phase 3. Added `Wallet`, `Zone`,
`ThresholdCamp`, `Npc`, `Kallias`, `MerchantStock` — none resolved
in headless tests until `godot --editor --quit` rebuilt the cache.

---

## 19. Stale input state survives respawn

**Symptom:** Player dies (K self-kill, lethal hit, etc.), the death
sequence plays, the player respawns at the zone's spawn point — and
immediately starts walking back toward where they were headed
before death. Same pattern would apply to any "modal off, fresh
state" transition (scene change, fast-travel).

**Root cause:** `PlayerInput` holds click-to-move state
(`_click_target`, `_has_click_target`, `_intent`) that is logically
"input the player wants" — but the engine has no idea this should
clear when the player's life resets. The death path sets process
flags off then on again on respawn; the click-target dictionary in
between is preserved.

**Prevention:** Any "fresh start" transition on the Player
(respawn, scene transition, character swap mid-zone) must call
`PlayerInput.clear_click_target()` (also resets `_intent` and
emits `click_target_cleared` so the click marker hides). The
Player should zero `_intent` and `velocity` at the same time so
the very next physics frame doesn't carry residual motion.

**Recovery:** Add the `clear_click_target` call at the bottom of
`Player._respawn()` and zero `_intent` / `velocity` immediately
above it. Verify by self-killing while a click target is active
in the workbench — the respawned player should stand still.

**First incident:** Stage 6 final playtest. K self-kill while
walking toward an NPC caused the respawned player to keep walking
to the pre-death click target. Fix as above.

---

## 20. Load restores Player but not zone-scoped state

**Symptom:** Player kills three enemies in a zone, presses F5 to
save, kills more, presses F9 to load. The player snapshot restores
(HP, gold, inventory, position) but the already-killed enemies stay
dead and the new kills are still gone. Anything else owned by the
zone subtree (dropped loot, spawned projectiles, world items, NPC
panel state) behaves the same way.

**Root cause:** `SaveSystem._apply` writes player-shaped fields
back into the live Player node. Zones are subtree-shaped and not
part of the save snapshot — they're rebuilt only on zone transit.
A same-zone load therefore restores the player against a stale
zone tree.

**Prevention:** Treat "load" as "reset the world, restore the
player on top of it." `Game._resume_saved_zone()` always calls
`_do_transit(saved_zone, place_at_spawn=false, force=true)` after
SaveSystem.load_game so the active zone is reinstantiated even
when its id matches the current one. Zones must therefore be
cheap to instantiate and re-instantiate; do not stash per-zone
runtime state outside the zone subtree.

**Recovery:** Remove any same-zone short-circuit in the load
path. Pass `force=true` to the transit so its internal
`zone_id == zone_id` early return is bypassed. Save loads only
ever pass `place_at_spawn=false` so the player keeps the position
SaveSystem._apply just wrote.

**First incident:** Stage 7 Phase 2 playtest. F9 in the
wilderness restored the player but left the dead Shade-Wretches
dead. Fix landed alongside the Phase 2 polish commit.

---

## When you spot a new failure mode

Add it here with: symptom, prevention, recovery. Future-you will thank you.
