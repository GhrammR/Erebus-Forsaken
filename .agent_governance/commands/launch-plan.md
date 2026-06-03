# Launch Plan — itch.io Demo → Steam Early Access

This file is the source of truth for the launch sequence. Decisions D1–D5
of the strategic review (locked in by user) are encoded here.

---

## Sequence

1. **Stages 1–9 complete** (per `act1-status.md`).
2. **itch.io free demo** ships first.
   - Content: Stages 1–9 (town + wilderness + dungeon + Act boss).
   - Build: same `main.tscn` as Steam build. The demo is the game,
     gated by a `FEATURE_FLAGS.demo_mode = true` in `project.godot`
     custom settings. Demo mode disables: endless mode, post-boss
     content, save export to Steam build.
   - License: free. No paywall, no donations gate. itch tip jar
     enabled.
3. **2-month feedback window minimum.**
   - Weekly patch cadence (build, notes on itch page).
   - Discord opens at itch launch (link on itch page).
   - Bug triage via itch comments + Discord #bugs channel.
4. **Stages 9.5, 9.7, 10, 11, 12** built during the feedback window.
5. **Steam EA launch** when:
   - Stage 12 complete AND
   - Discord ≥ 200 members OR 60 days since itch launch, whichever
     comes first.
6. **Save import** from itch demo to Steam EA: see Import section.
7. **Post-launch:** monthly content patches for 6 months minimum.

---

## Pricing

- itch: free.
- Steam EA: $9.99 USD. Anchored to V Rising and Path of Achra; both
  are positively-received indie ARPGs in adjacent niches at similar
  early prices.
- Steam 1.0: $14.99 USD. Bump on 1.0 to signal completion.
- Regional pricing: Steam defaults.
- **Never discount during EA.** First sale at 1.0 launch only. EA-era
  buyers must not feel front-run.

---

## Tag strategy

Primary Steam tags (in this order):
- Action RPG
- Roguelite
- Souls-like
- Dark Fantasy
- Singleplayer
- Procedural Generation
- Permadeath

Avoid: Hack and Slash (signals Diablo-clone expectations we can't
meet at Act 1 content density).

---

## Save import (itch → Steam)

itch demo saves write to `user://save_slot_1.json`. The Steam build
exposes a one-time "Import demo save" menu option at first launch:

1. User points the importer at the itch installation directory.
2. Steam build copies `save_slot_1.json` to its own `user://`.
3. SaveSystem migrations (AD-07) handle any schema bumps that landed
   between demo and EA.
4. Import is one-way. Imported save unlocks a cosmetic "Veteran of the
   Reach" glyph palette as a thank-you.

The migration chain (AD-07) is the contract that makes this safe. Do
not break it.

---

## What the itch demo MUST ship

- All audio (Feel Pass complete).
- Controller support (Stage 12 work).
- Tutorial first-30-seconds prompt.
- Crash-safe save (atomic write).
- A one-screen "Send feedback" prompt with the Discord invite + itch
  comments link.
- Optional anonymous telemetry: zone time, death zone, death cause.
  Off by default; opt-in checkbox in the first-launch prompt.

## What the itch demo MUST NOT ship

- Endless mode.
- Post-boss content.
- Anything not in `act1-status.md` Stages 1–9.

---

## What ends a stage during the launch window

The handoff prompt (`commands/stage-handoff.md`) still applies. In
addition, every patch during the itch feedback window must:
1. Bump `GameState.BUILD_VERSION`.
2. Update `act1-status.md` if checklist items closed.
3. Post patch notes to the itch page same-day.

---

## Discord setup checklist (build during Stage 12)

- #announcements (read-only)
- #patch-notes (auto-posted from a GitHub action; later)
- #general
- #bugs (with template)
- #builds (theorycraft + screenshot loadouts — viral seed)
- #feedback
- #off-topic

Server invite link permanent, set to never expire, posted on itch.
