# Erebus Forsaken

A dark-fantasy, Greek-mythology isometric ARPG. Solo development in Godot 4.

> **Status:** Pre-alpha. Stage 0 (bootstrap) complete. Stage 1 (Stats foundation) up next.
> The project is being built in public from the very first commit.

---

## What it is

Erebus Forsaken is a single-player isometric action RPG drawing on the spirit
of *Diablo II* and the atmosphere of Greek underworld myth. Loot, classes,
dungeons, an act boss, and one focused vertical slice — that is the entire
pre-launch goal. No multiplayer, no live-service, no roadmap promises beyond
what is checked off in the project's own status file.

Four classes are planned for Act 1:

- **Myrmidon** — front-line warrior, spear and buckler
- **Pythia** — oracle-mage, staff and elemental arts
- **Shade-Hunter** — ranged hunter of escaped underworld spirits
- **Ossuary Priest** — death-rite summoner

## Why this exists

I wanted to build the ARPG I keep wishing someone else would: small, dark,
tightly-tuned, and *finished*. A polished one-act game beats a sprawling
half-built four-act game every time.

## How development is run

This repository is governed by [`.agent_governance/CLAUDE.md`](.agent_governance/CLAUDE.md)
and the rule files alongside it. The governance folder is not decoration —
it is the binding charter that AI tooling and future-me must follow before
touching code. If you are curious how a solo developer can use AI agents
without the project drifting into mush, that folder is the answer.

Highlights worth a look:

- [Act 1 status checklist](.agent_governance/commands/act1-status.md) — the
  living definition of "done."
- [Scope lock](.agent_governance/rules/scope-lock.md) — what is explicitly
  *not* in Act 1.
- [Architecture decisions](.agent_governance/rules/architecture-decisions.md)
  — locked design calls (AD-01 … AD-11).
- [Failure modes](.agent_governance/rules/failure-modes.md) — known ways
  solo ARPGs collapse, and how this one tries not to.

## Current state

- Godot 4.6.3 project, GDScript, GL Compatibility renderer.
- Boots to a placeholder splash from `scenes/main.tscn`.
- Five autoloads in place: `GameState`, `SaveSystem` (versioned, AD-07),
  `EventBus` (whitelisted signals, AD-08), `SceneRouter`, `Database` (AD-03).
- No gameplay yet. Stage 1 will add the stat system.

There are no screenshots yet because there is nothing yet to screenshot
beyond a dark window and a label. That will change.

## Running it

```bash
godot --path .
```

Requires Godot 4.6 or newer. No build steps, no package install.

## Tech

- Godot 4.6 (GDScript only — no C#, no GDExtension)
- Target platform: Windows / Steam
- Procedural sprites first (drawn from code); bitmap art replaces them only
  after each mechanic is finished — see [`asset-pipeline.md`](.agent_governance/rules/asset-pipeline.md).

## Roadmap

There is no roadmap beyond Act 1. Act 1 ships when every box in
[`act1-status.md`](.agent_governance/commands/act1-status.md) is checked.
Anything past Act 1 is parked until then.

## Contributing

Not accepting external contributions during Early Access development. Issues
and feedback are welcome once the project is further along.

## License

No license is committed yet, so default copyright applies: all rights
reserved by the author. A license will be selected and added before any
binary distribution.

## Acknowledgements

- Built with [Godot Engine](https://godotengine.org/).
- Procedural-art-first workflow influenced by countless solo devs who
  shipped despite not being artists.
