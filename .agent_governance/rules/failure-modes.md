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

## When you spot a new failure mode

Add it here with: symptom, prevention, recovery. Future-you will thank you.
