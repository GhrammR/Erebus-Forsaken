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

## #20 — Autoload method named `log()` shadows GDScript's built-in

**Symptom:** Every script that calls `log(x)` (natural-log
math) fails to parse with `Too many arguments for "log()" call.
Expected at most 1 but received 2.` once an autoload defines
`func log(flag, msg)`. Cascade: the autoload fails to load,
so EVERY call to `AutoloadName.log(...)` in the project errors
`Nonexistent function 'log' in base 'Nil'`.

**Root cause:** `log()` is a global GDScript function (returns
the natural log of a float). Method names on autoloads share the
global namespace because autoloads are name-resolved at script
parse time. Defining a same-name method on an autoload shadows
the global for any script that calls it as a bare function call
without the autoload qualifier — and at the parse level the
parser sees the wrong signature.

**Prevention:** Never name an autoload method after a GDScript
built-in. The hot list includes `log`, `print`, `printerr`,
`push_warning`, `push_error`, `sin`, `cos`, `sqrt`, `abs`,
`min`, `max`, `clamp`, `floor`, `ceil`, `round`, `sign`,
`hash`, `is_inf`, `is_nan`, `len`, `range`, `str`. Pick
verbs that don't collide: `write`, `emit_event`, `record`,
`note`. DebugLog landed on `write(flag, msg)`.

**Recovery:** Rename the method, then sweep all callers
(`grep -rn "AutoloadName.old_name("`). Land both changes in
the same commit so the parse error window is zero.

**First incident:** Stage 9.7 polish — `DebugLog.log(...)`
shipped, broke every autoload reference project-wide, took out
the transit instrumentation that was the whole point of building
DebugLog in the first place.

---

## #21 — Adding ANY conditional block to HealthComponent.take_damage silently breaks ActBoss phase transitions

**Symptom:** Adding a no-op `if DebugLog.is_enabled(&"combat"): ...`
block inside `HealthComponent.take_damage` (after `damaged.emit`,
before the `_was_dead` check) caused `stage9_verify`'s phase-2
and phase-3 threshold checks to fail, even though the block is
completely skipped at runtime (no flag enabled). `stage5_verify`
broke at the same time (minion despawn check failed). Both
tests pass again the moment the block is removed.

**Root cause:** Best guess is a Godot 4.6.3 GDScript optimization
quirk where adding any control flow to `take_damage` re-orders
the signal-emit / `_was_dead` latch sequence in a way that
desynchronises observers — specifically, `ActBoss._on_damaged`
(which calls `_check_phase_transition`) ends up seeing stale
`current_stats.current_hp` because the new branch sits in
between the `damaged.emit(...)` and the next read. The hot path
is delicate. The `is_enabled` guard's runtime no-op doesn't
matter — what matters is that the function shape changed.

**Prevention:** `HealthComponent.take_damage` is a hot path with
signal-driven observers. Do not add ANY new control flow or
debug calls between `damaged.emit` and the `_was_dead` check.
If you need debug logging for combat, instrument at the
*signal handler* level (Game.gd's `_on_combatant_damaged` /
`_on_enemy_died_feel`) where the observer already paid the
context-switch cost.

**Recovery:** Strip the block, re-run `--verify9` and
`--verify5` until they pass. Move the instrumentation to a
signal handler.

**First incident:** Stage 9.7 polish — adding combat logging
for the new `DebugLog` flag system. Took two bisects to confirm
even the `is_enabled`-guarded branch was the trigger.

---

## #22 — `var x := A.name if cond else "literal"` infers Variant → parse error

**Symptom:** Adding a one-liner like
```gdscript
var k := _killer.name if _killer != null else "<?>"
```
breaks the entire script: `Parse Error: The variable type is being
inferred from a Variant value, so it will be typed as Variant.
(Warning treated as error.)`. The host scene (game.tscn) can't load,
so its `_ready` never runs — symptoms downstream look like "the
character has no sprite" or "interact doesn't work" rather than a
parse error, because earlier autoloads + the Player node still
spawn.

**Root cause:** `Node.name` is `StringName`. String literals like
`"<?>"` are `String`. A ternary with mixed branches has no common
inferred type, so `:=` defaults to Variant — which the project's
strict warning settings treat as an error (correctly — Variant
inference is almost always unintentional).

**Prevention:** When writing a ternary that mixes `StringName` and
`String`, annotate the variable type explicitly and wrap one side
to match. Idiom:
```gdscript
var k: String = String(_killer.name) if _killer != null else "<?>"
```
The `String(...)` cast on the StringName side forces a uniform
String result. Same trick works for `NodePath`/`String` mixes.

**Recovery:** If a sprite, NPC, or modal mysteriously stops
appearing on a fresh launch with no obvious error, *check the
terminal output, not the godot.log file*. Godot's GUI process
buffers only boot lines to the log; parse errors print to stderr
in real time and are missed if you only read the file. Run the
game from a terminal redirected via `2>&1 | tee /tmp/erebus.log`
to capture them.

**First incident:** Stage 9.7 polish — added `var k := _killer.name
if _killer != null else "<?>"` to game.gd inside DebugLog
instrumentation. Parse failed, game.gd never loaded, Player
spawned with no sprite + no input wiring. Hours lost diagnosing
"sprite system" before the terminal output revealed the parse
error.

---

## #23 — Residual `Camera2D.offset` from CameraShake carries across zone transit

**Symptom:** Player teleports into a new zone (e.g. The Maw) but
appears to spawn "at a corner" instead of the entry marker. Logs
show `player.global_position == DepthsEntry` exactly — the position
is correct. The CAMERA is what's off-centre. Player at world
`(0, 0)` renders at the bottom-right of the visible viewport because
the camera's `offset` is still at some leftover jitter value.

**Root cause:** `CameraShake.kick(amount, duration)` runs a tween
that fades `Camera2D.offset` back to zero over `duration`. If a kick
fires immediately before a zone transit (e.g. boss crit lands as
the player walks into the portal), the tween is still in progress
when `_do_transit` runs. The transit doesn't touch the camera, so
the tween keeps running on the same Camera2D instance (Player + its
camera survive the zone swap), but the `_place_player_for_arrival`
teleport happens BEFORE the tween's final zero-restore step. Result:
a non-zero offset latched in.

**Prevention:** Reset CameraShake on every zone transit. Added
`CameraShake.reset()` — kills the running tween and zeroes
`Camera2D.offset` synchronously. `_place_player_for_arrival` calls
it as the last step of the immediate teleport.

**Recovery:** If a Maw spawn (or any zone transit) reads as "wrong
position" but the `[arrival]` / `[settle]` debug lines confirm the
player IS at the entry marker, suspect the camera offset. Print
`_player.get_node("Camera2D").offset` at that point — if non-zero,
CameraShake needs a reset call from your code path.

**First incident:** Stage 9.7 polish — boss combat in the crypt
immediately before The Maw portal interact. Repro: take damage from
boss in Phase 3 (frequent crit shakes), walk to portal, enter.
Camera offset persists into The Maw.

---

## #24 — In-function placement of class-body `var` declarations

**Symptom:** `Parse Error: Unexpected "Indent" in class body.` from
GDScript at a line that looks fine in isolation. As with failure
mode #22, the whole script fails to load and the host scene's
`_ready` doesn't run — sprite missing, input dead, etc.

**Root cause:** A `var x: T = ...` line meant to live at class
scope ends up *between* statements of a function, so the parser
sees the next function-body line as a continuation of class scope
with unexpected indentation. Common when editing with a small
context window: you append a tiny instrumentation block at the
end of one function and want to add backing fields for it, drop
the `var` lines below the block, but accidentally land them
*before* the closing line of the function instead of *after*.

**Prevention:**
1. Class-scope `var` declarations live ABOVE the first `func` in a
   file or grouped just before the function that uses them.
   Treat them as part of the function's "header," not its body.
2. After ANY edit that adds class-scope state alongside function
   logic, run `godot --headless --quit-after 200` (the boot smoke
   test) before claiming the change is done. It catches parse
   errors in < 2s and would have prevented this regression both
   times.

**Recovery:** Move misplaced `var` declarations above the function
body or to a class-scope block.

**First incident:** Stage 9.7 polish, second occurrence. Added a
movement watcher whose state fields got dropped mid-function in
`game.gd._place_player_for_arrival`.

---

## #25 — `add_child` before `global_position` teleports the player to enemy spawn anchor

**Symptom:** ~1-2 seconds after a wave begins (or any deferred spawn
fires), the player teleports to a spawn-anchor coordinate. Logs show
the position change happens BETWEEN physics ticks, with `vel=(0,0)`
and `intent=(0,0)`, and no script-level assignment to
`_player.global_position` fires. The destination is offset by a few
pixels in y from the anchor — that's depenetration shoving the
player just outside the enemy's collision shape.

**Root cause:** When a CharacterBody2D scene is instantiated and
`add_child`'d to the tree, its default `global_position` is `(0, 0)`
— the world origin. If the code path is

```gdscript
container.add_child(inst)         # collider registers at (0,0)
inst.global_position = anchor.gp  # moved next line, same frame
```

the enemy's collision shape registers with the physics server at
world `(0, 0)` for ONE FRAME, *even though the next line
synchronously reassigns the position*. The physics server captures
the contact between the new collider and any other CharacterBody2D
also at `(0, 0)` (the player, since they spawned at `DepthsEntry`
at the origin). On the NEXT physics tick, the engine resolves that
contact by depenetrating one body, and because the player has
`velocity=0` while the enemy has been programmatically moved to the
anchor, the engine teleports the player to the enemy's *new*
position to clear the contact.

**Prevention:** ALWAYS set position before `add_child` when
spawning a CharacterBody2D (or any Node2D with a collider) at a
world coordinate. The node treats `position` (local) as world
while not in the tree, and parent-transform is applied on
`add_child`. Pattern:

```gdscript
inst.position = anchor.global_position  # stages world value
container.add_child(inst)                # enters tree at correct spot
```

This holds whenever `container.global_position == (0, 0)` (true for
all current zones). If a future zone has a non-origin root, use
`inst.position = anchor.global_position - container.global_position`
instead.

**Recovery:** Find every `container.add_child(inst)` followed by
`inst.global_position = X` and swap the order. Surfaces in this
project:
- `scripts/systems/spawn_director.gd::_spawn_one`
- `scenes/game.gd::_spawn_enemy_snapshot`
- `scripts/zones/forsaken_crypt.gd::_spawn_room`

Future spawn paths must follow the same pattern.

**First incident:** Stage 9.7 polish — first Maw run after wave-
start grace expired. User repeatedly reported "teleporting to the
corner where monsters attack me." The debug log's
`_physics_process` watcher caught the jump between ticks with
`vel=0`, ruling out walking and direct assignment, then the absence
of any `[SITE:]` log narrowed it to the physics server itself.

---

---

## #N — Pending-snapshot check in a deferred init silently regresses zone-cache

**Symptom:** Returning to a previously-visited zone re-spawns the
zone's initial enemy roster on top of the cached entities. Player
reports "enemies reset when I return to town" — clearing-an-area
and corpse-recovery progress evaporate. Verifiers don't catch it
because the bug only manifests at runtime, in the second visit.

**Root cause:** SpawnDirector's _ready originally read
`SaveSystem.has_pending_enemy_snapshot()` synchronously. Stage 13
deferred the director's init to next idle so the zone's _ready
could populate procgen anchors first. But game.gd's _do_transit
consumes the pending snapshot in its own (synchronous) chain,
which runs BEFORE the deferred init fires next frame. By the time
the director checks "is a load queued?" the answer is always
false → initial spawn re-fires.

**Prevention:** Any pending-state query that gates "should I run
my normal init?" must be **captured synchronously in _ready** and
read from the captured bool in the deferred init. The general
pattern:

```gdscript
var _has_pending_X_at_ready: bool = false

func _ready() -> void:
    _has_pending_X_at_ready = SomeAutoload.has_pending_X()
    call_deferred("_init_after_setup")

func _init_after_setup() -> void:
    if _has_pending_X_at_ready:
        return  # caller is handling X; do not run default init
    ...
```

The verifier `--verify13::_verify_spawn_director_defer_safe`
asserts the capture-before-defer order at source level so the
pattern cannot silently regress.

**Recovery:** If you find a deferred init that queries pending
state, audit whether the answer survives the synchronous
consumption that happens between _ready and the next idle. Move
the query to _ready and stash it.

**First incident:** Stage 13, user playtest. "Monsters reset when I
return to town. This is not supposed to happen." Diagnosis took ~5
minutes once the deferred-init change was identified as the
prime suspect.

---

## #N — In-memory zone cache survives session but not save/load

**Symptom:** Player kills enemies in the wilderness, walks back to
town, saves, quits. On reload the wilderness's "last visited" state
is gone — initial spawn fires fresh on next entry. Player reports
"enemies reset when I load a save." Returning to a zone within the
same session works correctly (cache hit); the regression only
shows across the quit-relaunch boundary.

**Root cause:** `_zone_cache` lived on `scenes/game.gd` as an
in-memory dict only. The save snapshot captured only the *current*
zone's enemies/loot via `_snapshot_active_zone_enemies` —
everything else dropped on the floor at save time and never made
it to disk.

**Prevention:** Any in-memory cache that bridges per-zone state
across transits MUST also bridge across save/load. The pattern
(Stage 13 hotfix):

1. SaveSystem owns a `_pending_zone_caches: Dictionary` field.
2. SaveSystem.save_game queries SceneRouter.snapshot_zone_caches()
   automatically (no per-caller boilerplate).
3. SceneRouter forwards to host (game.gd) via
   `snapshot_zone_cache_for_save() -> Dictionary`.
4. SaveSystem._snapshot includes the duplicated cache under
   `"zone_caches"`. Schema bump.
5. SaveSystem._apply parks the loaded caches in
   `_pending_zone_caches`; game.gd consumes via
   `consume_pending_zone_caches()` in every load branch
   (auto-resume on entry, F9, endless rollback).
6. Add a schema migration that defaults legacy saves to `{}`.

The verifier `--verify13::_verify_zone_caches_persisted` asserts
the API + structural wires so this can't silently regress.

**Recovery:** If you find an in-memory cache that doesn't have a
corresponding `"<thing>_caches"` save key, audit whether the cache
state is reproducible from the rest of the save (then no fix
needed) or whether dropping it loses player-visible state (then
add it to the schema).

**First incident:** Stage 13, user playtest. "reloading resets the
enemies. they should remain unless a new game is created, not when
loading from a save." Diagnosis surfaced that `_zone_cache` had
never been wired to the save schema since it landed in Stage 7 —
the in-session bridge worked, but the persistence bridge was
missing.

---

## #N — In-zone interactable on the walls layer breaks enemy LOS

**Symptom:** After teleporting next to a small in-zone interactable
(brazier, shrine, future Maw entrance), nearby enemies stay idle
until the player moves a step. User reports "mobs are not hostile
until I move." The bug only surfaces post-teleport because the
player has had no chance to shift out of the interactable's LOS
shadow.

**Root cause:** Wilderness enemy AI's `_has_line_of_sight` raycasts
on `_WALL_MASK = 1` (the walls layer). Anything on physics layer 1
blocks LOS. Portals and Waypoints inherit a StaticBody2D root that
defaults to `collision_layer = 1` — meaning the interactable's own
collider blocks the enemy's view of the player whenever the ray's
chest-y line passes through it. Portals at zone edges don't
trigger this because no enemies are nearby; the Waypoint is the
first interactable that lives mid-zone surrounded by spawn rings.

**Prevention:** Small in-zone interactables should NOT carry
`collision_layer = 1`. Two viable patterns:

1. **collision_layer = 0** (chosen for Stage 14 Waypoint). The
   interactable becomes non-blocking; the player can walk through
   it visually. Acceptable when the interactable is small and the
   player rarely overlaps. One-line fix.
2. **Dedicated interactables layer** (Stage 19+ pattern when more
   in-zone interactables ship). New physics layer, e.g. layer 8,
   for "in-zone interactables." Player's `collision_mask` includes
   it (movement blocks); AI's `_WALL_MASK` does not (LOS ignores).

When adding a new Portal subclass or in-zone Static interactable,
explicitly decide which pattern applies and document the choice.

**Recovery:** Set `collision_layer = 0` on the offender, verify
nearby enemies aggro on the next frame. Add a structural verifier
asserting layer != 1 for the affected scene.

**First incident:** Stage 14 playtest, user-reported. The
Waypoint's brazier sat on layer 1 because the Portal scene it
extends from defaults to layer 1. Enemies behind the brazier
stayed idle on waypoint arrival. Fix: brazier `collision_layer = 0`.
Verifier `--verify14::_verify_waypoint_does_not_block_los` guards
against regression.

---

## When you spot a new failure mode

Add it here with: symptom, prevention, recovery. Future-you will thank you.
