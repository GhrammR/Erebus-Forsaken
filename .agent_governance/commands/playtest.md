# Playtest Command

A playtest is the only honest feedback. Every session ends with one.

## How to run

1. Open `project.godot` in Godot 4.
2. Press F5 (Play). Main scene should be `scenes/main.tscn`.
3. If first run, expect character select. Pick the class most affected by
   today's changes.
4. Run the path below for the current Act 1 stage.

## What to verify (by stage)

**Stage 0 — Bootstrap**
- Game launches to a black screen with a label reading the build version.
- Quit returns to OS cleanly.

**Stage 1 — Player movement**
- Pick a class. Spawn in test zone. Move with WASD (or click-to-move, TBD).
- Camera follows. Y-sort renders player behind/in front of props correctly.
- Pause menu (Esc) opens and resumes.

**Stage 2 — Combat core**
- Auto-attack hits a training dummy. Damage number appears.
- Damage number matches `Stats.compute_damage()` output (overlay shows).
- Dummy HP reaches 0 → dies → loot drops.

**Stage 3 — Itemization**
- Pick up dropped item. Inventory opens (I key).
- Equip item. Stat panel updates.
- Unequip. Stats revert exactly.

**Stage 4 — Skills**
- Each class's starter skill on hotkey 1. Casts. MP deducts. Cooldown.

**Stage 5 — Save/Load**
- Save (F6). Quit. Relaunch. Load. Position, HP, MP, inventory, equipped
  items, level, attributes all preserved.

**Stage 6 — Town & Wilderness**
- Walk from town to wilderness through portal. Walk back. No duplicates.
- Wilderness enemies spawn within bounds, do not chase past edges.

**Stage 7 — Dungeon**
- Enter dungeon entrance. Three rooms, increasing enemy count.
- Boss room locked until trash cleared. Boss fights with one unique mechanic.

**Stage 8 — Boss & Unique drop**
- Kill boss. Unique item drops, guaranteed. Item has named affixes.

## Capture format

Append to `playtest_notes.md` (repo root):

```
## YYYY-MM-DD — stage <N>
- [bug] one-line description
- [feel] subjective friction
- [idea] parking-lot candidate, do not act on this session
- [done] confirmed working: <feature>
```

Do not fix bugs found mid-playtest. Finish the play-through, then triage.
