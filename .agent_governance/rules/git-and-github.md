# Git & GitHub Governance

This project will live on GitHub. These rules exist so the history is
useful, the repo is safe to make public, and a future contributor (or
future-you after a six-month gap) can orient quickly.

## Repository layout

- Default branch: `main`. Always green (project runs, no editor errors).
- Long-lived branches: none. No `develop`, no `release/*`. Solo dev.
- Feature work: short-lived branches named `stage-NN-shortdesc`
  (e.g. `stage-03-combat-core`) or `fix/<scope>` / `chore/<scope>`.
- Tags: `v0.<stage>.<patch>` per completed stage in `act1-status.md`.
  First public tag is `v0.12.0` when Act 1 ships. Pre-launch is `v0.0.*`
  through `v0.11.*`.

## Commit hygiene

- Imperative subject line, ≤ 72 chars. No trailing period.
- Body wraps at 72. Explains **why** when the why is non-obvious.
- One logical change per commit. Mixing a stat refactor with a UI tweak
  is a review hazard.
- Reference the stage when relevant: `stage-3: ...`

Conventional-Commit-style prefixes are encouraged but not enforced:
`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `tune:`.

Example:
```
feat(stats): route all damage through DamageResolver

Previously skills computed damage inline. With Resolver as the single
entry point, future damage_type expansion (Act 2) becomes additive
rather than a rewrite. Closes act1-status stage 3 invariant C.
```

## Pull requests

Solo dev, but PRs against `main` are still useful for self-review and
GitHub history. PR template:

```
## What changed
- bullet list of the diff at a high level

## Why
- the motivation; cite the stage or rule if relevant

## Definition of done (rules/testing.md)
- [ ] Runs from editor, no errors/warnings
- [ ] Manual playtest captured in playtest_notes.md
- [ ] Save/load round-trip verified (if state changed)
- [ ] Relevant skill audits (combat-validator / scene-auditor / class-balance) pass
- [ ] act1-status.md updated

## Out of scope
- bullets to keep reviewers (and future-you) from expecting more
```

## What never gets committed

- `.godot/` (Godot 4 editor cache and import data)
- `.import/` (legacy import cache)
- `export.cfg`, `export_presets.cfg` containing credentials
- `user://` content — by design Godot writes it outside the repo
- `*.translation`, `*.import` autogen files (covered by `.gitignore`)
- Bitmap or audio assets without verified license — drop the license
  text into `art/bitmap/LICENSES.md` alongside the file
- API keys, Steam credentials, signing certs, anything from `secrets/`

If a commit contains any of the above, revert and rewrite history
before pushing publicly.

## Public-repo readiness

Before flipping the repo to public:
1. `git log --all -p | grep -i -E "password|secret|token|api[_-]?key"`
   returns nothing.
2. `LICENSE` file present at repo root. Default to `MIT` unless the
   user states otherwise (the user has not yet specified — confirm
   before adding the file).
3. `README.md` describes the project, status, and points at
   `.agent_governance/CLAUDE.md` for the development charter.
4. `CONTRIBUTING.md` either exists (if accepting PRs) or the README
   explicitly states "not accepting contributions during Early Access."
5. Every bitmap/audio asset has a license entry in
   `art/bitmap/LICENSES.md` or `audio/LICENSES.md`.

## CI (later, not now)

GitHub Actions is out of scope until Stage 11. When added, the
minimal pipeline is: headless Godot import + a project-validation
script that runs the `audit` checks listed in
`commands/audit.md`. No platform builds in CI until Stage 12.

## When the agent commits

- Never run `git commit`, `git push`, `git tag`, branch deletion, or
  force-push without explicit user instruction. See the harness rules
  in the system prompt.
- When asked to commit, follow `rules/testing.md` to verify the change
  before staging.
- Never `git add -A` or `git add .` — stage files by name so generated
  caches do not slip in.

## Commit message trailers — forbidden

- **No `Co-Authored-By:` trailer for the AI agent.** It is widely
  understood that AI assistance is part of this project's workflow;
  attributing co-authorship in every commit gives the agent
  disproportionate credit for what is one person's project.
- **No `Generated with Claude Code` / `Generated with <AI tool>` /
  similar footer lines.** Same reason.
- Other trailers (`Signed-off-by`, `Fixes #N`) remain allowed when
  applicable.

If the user explicitly asks for a Co-Authored-By line on a specific
commit (e.g., joint work with another human), include it. Default is
to omit.
