# Launch Plan — Single Dual Release (Steam + itch.io)

**Rewritten 2026-06-04.** The previous plan (itch.io free demo → Steam
EA) is superseded. Decision: ship Act 1 content-complete as a single
dual launch on Steam and itch.io the same day. No staged free demo.
No Early Access split.

This decision was made after Stage 9.8 with the explicit acknowledgement
that it adds significant scope to Act 1 (Stages 11–21 in the rewritten
execution order in `act1-status.md`) and pushes the launch date
substantially. The trade-off the user accepted: a smaller game shipped
quickly, vs. a meatier 2+ hour ARPG shipped when ready.

---

## Sequence

1. **Stages 1–9.8 complete** (already true as of 2026-06-04).
2. **Stage 9.8.1 hotfix** — Ember Maw-route bug. Required before any
   new content stage opens.
3. **Stage 11** — AI asset-generation pipeline. Everything after this
   stage can pull on it for procedural-plus-AI hybrid art and voice.
4. **Stages 12–17** — town-to-wilderness walk, procgen seeds,
   waypoints, paper-doll equipment, item icons, NPC voice + portraits.
5. **Stage 18** — Forsaken Boss demote + final-boss state-machine.
6. **Stage 19** — The Maw entrance moves to town, gated behind
   first-quest completion.
7. **Stage 20** — Wilderness content authorship: 10+ areas, 5+
   dungeons, 5+ quests, final boss. Target time-to-final-boss = 2+ hours.
8. **Stage 21** — Feel pass at scale; balance polish across all new
   content.
9. **Stage 22** — Save/load hardening (was Stage 11).
10. **Stage 23** — Pre-launch polish (was Stage 12).
11. **Launch readiness gate** — see below.
12. **Single dual launch** — Steam + itch.io same day.
13. **Post-launch** — monthly content patches for 6 months minimum.

---

## Launch readiness gate

Single dual launch fires only when ALL of the following are true:

- Every box in `act1-status.md` is `[x]`.
- All headless verifiers PASS (currently 13; expect 22+ by launch).
- `audit.md` produces all PASS.
- 30-minute play session: no `push_error`, no `push_warning`,
  no parse-error popups.
- Time-to-final-boss measured on a fresh save with median play ≥ 2 hours.
- Title screen, options menu, controller support all functional.
- Steam page approved + Steamworks paperwork complete.
- itch.io page ready: description, screenshots, trailer, build uploaded.
- Discord ≥ 100 organic members (no purchased traffic).
- Build version frozen to `v1.0.0` for the launch tag.

---

## Pricing

- **Steam: $14.99 USD** at launch. (Was previously planned at $9.99 EA
  → $14.99 at 1.0; the dual-release model collapses this to a single
  price.) Anchored to V Rising and Path of Achra; both are
  positively-received indie ARPGs at adjacent prices.
- **itch.io: $14.99 USD**. Same price. Pay-what-you-want above the
  minimum permitted. itch tip jar enabled.
- Regional pricing: Steam defaults; itch.io mirrors where Steam allows.
- **Launch-week discount: none.** Pre-purchase via wishlist convert at
  full price. First sale at 6 months post-launch.

---

## Tag strategy

Primary Steam tags (in this order):
- Action RPG
- Souls-like
- Dark Fantasy
- Singleplayer
- Procedural Generation
- Roguelite (only if the new-game seeded wilderness reads as
  roguelite-flavoured; defer the call until Stage 13 lands)
- Permadeath (only if the corpse-run penalty meaningfully matters at
  the new content scale; defer call until Stage 20 lands)

Avoid: **Hack and Slash** unless and until the final content density
warrants the Diablo-clone expectation.

---

## What every shipped build MUST include

- Full audio (procedural baseline + AI-generated layer per Stage 17/21).
- Controller support (Stage 23).
- Tutorial first-30-seconds prompt.
- Crash-safe save (atomic write — Stage 22).
- A one-screen "Send feedback" prompt with the Discord invite.
- Optional anonymous telemetry: zone time, death zone, death cause.
  Off by default; opt-in checkbox in the first-launch prompt.
- Title screen + main menu + options + credits.

## What the launch build MUST NOT include

- Any reference to Act 2 content (per `rules/scope-lock.md`).
- Any AI-generated asset without its provenance sidecar (per
  `rules/asset-generation.md`).
- Any third-party API call at runtime — generation is dev-time only.
- A demo gate or `FEATURE_FLAGS.demo_mode` branch. The branch can
  remain in code for testing but must be off for shipped builds.

---

## What ends a stage during the build window

The handoff prompt (`commands/stage-handoff.md`) still applies. In
addition:
1. Bump `GameState.BUILD_VERSION`.
2. Update `act1-status.md` if checklist items closed.
3. Update `README.md` if user-visible state changed (per
   `rules/git-and-github.md` § Documentation sync).

---

## Discord setup checklist (build during Stage 23)

- #announcements (read-only)
- #patch-notes (auto-posted from a GitHub action; later)
- #general
- #bugs (with template)
- #builds (theorycraft + screenshot loadouts — viral seed)
- #feedback
- #off-topic

Server invite link permanent, set to never expire, posted on itch.io
and the Steam page.

---

## Post-launch cadence

- Month 1: hotfix patches as bugs surface. No new content.
- Months 2–6: monthly content patch (new zone seed templates, new
  unique items, balance tuning). Each patch updates `act1-status.md`'s
  post-launch addendum (TBD as a follow-on section once we get there).
- Month 6+: decision point on Act 2 work. The Act-2 scope lock in
  `rules/scope-lock.md` does not lift until this point.
