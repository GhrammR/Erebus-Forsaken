# Audit Command

Full health check. Run weekly or when something feels off. Produces a
report; does not auto-fix.

## Sequence

1. **Charter & status sync**
   - Read `CLAUDE.md`. Confirm non-negotiables still hold.
   - Read `commands/act1-status.md`. Confirm every "done" item still runs.

2. **Forbidden-stat sweep**
   ```
   grep -rni -E "block_?chance|cast_?speed|hit_?recovery" \
     --include="*.gd" --include="*.tres" --include="*.tscn" --include="*.md" \
     -- :^.agent_governance
   ```
   Zero results required. (Governance files are allowed to name them as
   forbidden examples.)

3. **Stat-source-of-truth sweep**
   - `grep` for arithmetic on `strength|dexterity|vitality|pneuma` outside
     `scripts/systems/stats.gd`. Each hit is a violation.

4. **Run combat-validator skill.**

5. **Run scene-auditor skill.**

6. **Run class-balance skill.**

7. **Scene runtime check**
   - Launch the project from the main scene.
   - Click through character select, into test zone, kill one enemy,
     pick up loot, save, quit, reload.
   - No errors in output panel.

8. **Save format check**
   - Inspect newest save file in `user://`. Confirm `version` field present
     and matches `SaveSystem.SAVE_VERSION`.

9. **Asset pipeline check**
   - Confirm every active entity has either a procedural sprite script *or*
     a bitmap with the procedural fallback preserved (per
     `rules/asset-pipeline.md`).

10. **Hybrid-baseline assertion (Stage 11)**
    - Every sprite scene that exposes a bitmap layer MUST also keep a
      procedural fallback child node (per the hybrid contract in
      `rules/asset-pipeline.md` and `rules/asset-generation.md`).
    - Smoke this by launching with `--procedural-only`: the project
      must still render every entity legibly. Any entity that vanishes
      or shows obvious gaps is a hybrid-contract violation.
    - Every committed bitmap, audio, or video asset under `art/bitmap/`,
      `audio/`, or `video/` MUST have a `.json` sidecar of the same
      basename. Sweep with:
      ```
      find art/bitmap audio video -type f \
        \( -name '*.png' -o -name '*.ogg' -o -name '*.wav' \
           -o -name '*.mp3' -o -name '*.webm' -o -name '*.mp4' \) 2>/dev/null \
        | while read f; do
            sidecar="${f%.*}.json"
            [[ -f "$sidecar" ]] || echo "MISSING SIDECAR: $f"
          done
      ```
      Zero hits required. Each missing sidecar is a violation.
    - Sum `cost_usd` across sidecars added since the last stage close to
      confirm spend stayed under the stage's cost ceiling.

11. **Parking lot review**
    - Read `parking_lot.md`. Promote nothing into active scope unless it
      replaces a current Act 1 item.

## Output

Single markdown report appended to `audit_log.md` with sections per step,
PASS/FAIL/WARN, and an action list at the bottom (ordered by severity).
