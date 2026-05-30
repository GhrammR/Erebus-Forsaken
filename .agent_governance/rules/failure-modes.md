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

## When you spot a new failure mode

Add it here with: symptom, prevention, recovery. Future-you will thank you.
