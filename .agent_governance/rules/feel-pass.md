# Feel Pass — Sensory Contract for Player-Affecting Events

This rule exists because a stage can pass 30/30 verifier checks and still
feel like a demo. Verifiers prove correctness. They do not prove fun.

Every event the player causes, suffers, or witnesses must carry at least
one audio cue and one visual cue. Silent events are the single biggest
reason a finished-but-feel-less game gets called "unfinished" in reviews.

This is a binding rule from the moment the Audio Mini-Stage (new Stage
7.5) closes onward. Stages closed before that date are grandfathered;
new code from that date forward must comply.

---

## The contract

For every event in the table below, the implementing scene/script must
provide both columns. Missing either side is a failure-mode logged
against the implementing PR.

| Event                         | Audio cue                  | Visual cue                          |
|-------------------------------|----------------------------|-------------------------------------|
| Basic attack swing            | swing.ogg                  | weapon arc / hitbox flash           |
| Hit landed (player → enemy)   | hit_flesh.ogg              | DamageNumber (existing)             |
| Crit hit landed               | hit_crit.ogg               | golden DamageNumber + 3-frame hit-stop |
| Hit taken (enemy → player)    | player_hurt.ogg            | red modulate flash (existing) + camera shake |
| Player death                  | death_player.ogg           | DeathScreen overlay (existing)      |
| Enemy death                   | death_enemy.ogg            | sprite fade + corpse drop           |
| Skill cast                    | skill_cast.ogg             | per-skill VFX (existing)            |
| Skill ready (cooldown ends)   | skill_ready.ogg (soft tick)| cooldown-ring snap to full          |
| Item picked up                | pickup_item.ogg            | name-label rise (existing)          |
| Gold picked up                | pickup_gold.ogg            | gold-amount pulse                   |
| Rare drop spawned             | drop_rare.ogg              | column of light + 2px outline       |
| Level up                      | levelup.ogg                | screen-wide ring + +N popup         |
| Zone enter                    | zone_amb_<id>.ogg loop     | zone-name fade-in (top-right)       |
| Quest accepted                | quest_accept.ogg           | HUD chip slides in                  |
| Quest complete                | quest_complete.ogg         | HUD chip flashes gold then clears   |
| Save / load                   | save.ogg / load.ogg        | top-left "SAVED" / "LOADED" toast   |

## Scope discipline

- A single SFX bank covers the entire shipping table. Picking 16
  intentional sounds is the work — picking 200 is feature creep.
- The procedural-art rule (asset-pipeline.md) applies to audio too:
  placeholder sfx ship. Never block a mechanic on final audio.
- Audio assets live under `audio/sfx/` and `audio/ambient/`. Resource
  references go through a single `AudioBank` autoload so renames don't
  ripple. (AudioBank is added in the Audio Mini-Stage.)

## Verification

- `scene-auditor` gains check #10: every emitter of an EventBus signal
  on the contract list must reference `AudioBank` and a visual hook.
- Stage 9.5 (Feel Pass) verifier walks every event above and asserts the
  call site exists. Missing call sites fail the stage.

## Camera shake

One implementation. Lives on the Camera2D autoload-adjacent helper
(`scripts/systems/camera_shake.gd`). API: `CameraShake.kick(amount,
duration)`. No script does shake math inline (this is the AD-04 lesson
applied to feel).

## Hit-stop

One implementation. `Engine.time_scale` pulse, 3 frames at 0.0, restored
to 1.0. Wrapper at `scripts/systems/hit_stop.gd`: `HitStop.pulse(frames
:= 3)`. Crit hits call it; nothing else does, in Act 1.

## What this rule does NOT permit

- "Juice" is not a license to ignore scope-lock. No new gameplay mechanics
  smuggled in as feel.
- No procedural particle system rewrites. Built-in `GPUParticles2D` with
  hand-tuned defaults is the ceiling for Act 1.
- No music. Ambient loop per zone only. Music is post-launch.
