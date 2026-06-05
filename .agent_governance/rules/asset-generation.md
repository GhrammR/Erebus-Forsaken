# Asset Generation Pipeline

This rule governs **AI-generated bitmap, audio, and video** assets in the
project. It does not change `rules/asset-pipeline.md` — procedural is
still the always-shippable baseline. This document describes how the
optional polish layer arrives without poisoning the repo, the workflow,
or the reproducibility of the project.

The pipeline is intentionally **wrapper-thin**. Shell scripts in
`tools/asset_gen/` call third-party APIs and write outputs into the
project's bitmap/audio directories. There is no Godot-side runtime
dependency on any AI service — assets land at dev time, not at game
runtime.

## Locked tool choices (2026-06-04, revised)

**Replicate is the default backend for every asset type.** One API
key, one billing surface, one wrapper pattern, one ToS to track.
ElevenLabs / Runway / HeyGen stay in the table as approved fallbacks
for specific cases where Replicate quality isn't sufficient (e.g. a
hero NPC whose voice carries the act).

| Asset type | Default tool / model | Deferred fallback | Rationale |
|---|---|---|---|
| Images (sprites, icons, portraits) | **Replicate** — `black-forest-labs/flux-2-pro` ($0.015/run + per-MP) | FLUX 1.1-pro ($0.04/img) for the rare case 2-pro misses | Same vendor as other asset types; ~63% cheaper baseline than 1.1-pro for small outputs. |
| NPC voice | **Replicate** — `jaaari/kokoro-82m` default; `lucataco/xtts-v2` for cloning | **ElevenLabs** for hero NPCs only | Consolidates onto one key. ElevenLabs is per-NPC opt-in. |
| Sound effects | **Replicate** — `stackadoc/stable-audio-open-1.0` (or current Stable Audio variant) | ElevenLabs SFX | Audio-shaped prompting; same key as everything else. |
| Music | **Replicate** — Stable Audio (interim) | Revisit when Suno has a public API | Suno has no API yet; do not block on it. |
| Video / portraits with motion | **Replicate** — `lightricks/ltx-video` (cheap default), `kwaivgi/kling-v2.1` (quality) | Runway Gen-3 or HeyGen (talking avatars) | Video is opt-in; only for hero scenes (intros, boss reveals). |

A new tool can be added with explicit user approval and a sidecar update.
Don't silently introduce a fifth service.

## Directory layout

```
tools/asset_gen/                ← shell wrappers, executable
  gen_sprite.sh                 ← image gen (Replicate)
  gen_voice.sh                  ← voice gen (ElevenLabs)
  gen_sfx.sh                    ← SFX gen (ElevenLabs SFX / Stable Audio)
  gen_video.sh                  ← video gen (Runway / HeyGen)
  lib/                          ← shared helpers (auth, sidecar write, sha)
  README.md                     ← end-user instructions for keys

art/bitmap/<category>/<name>.png       ← the asset (LFS if >1MB)
art/bitmap/<category>/<name>.json      ← REQUIRED sidecar
audio/<bucket>/<name>.ogg              ← bucket = sfx | voice | music | ambient
audio/<bucket>/<name>.json             ← REQUIRED sidecar
video/<category>/<name>.webm           ← LFS
video/<category>/<name>.json           ← REQUIRED sidecar
```

## Reproducibility sidecar — required for every committed asset

Every generated asset (image, audio, video) MUST land alongside a JSON
sidecar with the same basename. The sidecar is committed to plain git
even when the asset itself goes to LFS. Schema:

```json
{
  "tool": "replicate",
  "model": "black-forest-labs/flux-1.1-pro",
  "prompt": "isometric ARPG enemy, bog caller, swamp witch, dark mossy robes, glowing green staff, 64px tall, pixel art, transparent background",
  "negative_prompt": "modern, photographic, watermark",
  "seed": 1934872,
  "params": { "width": 256, "height": 256, "guidance": 7.5, "steps": 30 },
  "output_sha256": "8f3a...e1",
  "generated_at": "2026-06-04T17:42:11Z",
  "generated_by": "human:reghramm@gmail.com",
  "purpose": "Bog Caller bitmap polish layer (Stage 11 pipeline test)",
  "license": "Replicate ToS (commercial use OK for paid tier)",
  "cost_usd": 0.04
}
```

Why the sidecar exists:
- **Regen on demand** — if the file is lost, prompt + seed + params let
  you reproduce it (best-effort; model versions drift).
- **Cost accounting** — sum the `cost_usd` field across sidecars to know
  the spend per stage.
- **Provenance** — the public repo can prove what was generated, by what
  tool, when. Defensible if a license question ever arises.
- **Prompt history** — what prompts worked for this project is itself an
  asset.

**Rule:** an asset with no sidecar is invalid. Reject the commit.

## Commit policy

- Sidecars **always** commit to plain git.
- Assets ≤ 1MB commit to plain git.
- Assets > 1MB go through Git LFS (configured via `.gitattributes`).
- Generated assets are committed. They are **not** regenerated at game
  runtime. The shipped game ships the committed bitmaps; the procedural
  fallback is there only for missing-file safety.
- No raw API key in the repo. Keys live in `~/.config/erebus-secrets/`
  (gitignored, user-owned). The shell wrappers source them at run time.

## Secrets layout

```
~/.config/erebus-secrets/
  replicate.env       ← export REPLICATE_API_TOKEN=...
  elevenlabs.env      ← export ELEVENLABS_API_KEY=...
  runway.env          ← optional; only if video gen is in flight
```

The wrappers `source` these. If a key file is missing, the wrapper
errors out cleanly with instructions — it does not silently no-op.

## Workflow contract (agent-side)

When asked to generate an asset:

1. **Confirm procedural baseline exists.** If the entity has no
   procedural form, write that first — generation does not skip past
   the hybrid contract in `rules/asset-pipeline.md`.
2. **Compose the prompt.** Include style anchors: isometric ARPG,
   palette family, silhouette cue from procedural form, target px size.
3. **Pick a deterministic seed.** Record it in the sidecar.
4. **Invoke the wrapper via Bash.** Never inline an API call.
5. **Verify the output.** Open the file, check it's not corrupt, check
   the silhouette reads at gameplay zoom.
6. **Write the sidecar.** Mandatory. The wrapper does this for you;
   verify before committing.
7. **Commit asset + sidecar together.** Never split across commits.
8. **Note cost** in the sidecar's `cost_usd` field if the API returned it.

## Cost discipline

Solo dev. Cost per stage ceiling: $20 default, $50 with explicit
user approval, $100+ requires a stage-close justification. Sidecars'
`cost_usd` sum is the audit trail. If a stage runs over, log it and stop.

Replicate reference rates (revised 2026-06-04, verify before each
batch — these age):
- FLUX-2-pro: $0.015/run + $0.015/MP input + $0.015/MP output.
  64×64 sprite is ~0.004 MP, so per-image cost is dominated by the
  $0.015 run fee — ~67 images per $1.
- FLUX-1.1-pro: ~$0.04/image (fallback only if 2-pro misses).
- Kokoro TTS: a few cents per minute of speech.
- LTX video: ~$0.02/sec at 768×512.
- Kling 2.1: ~$0.28/sec at 720p (quality tier).

ElevenLabs Creator (deferred fallback) is $22/mo + per-char overage.

## Failure modes prevented

- **Asset drift from prompt** — sidecar means we can regenerate, not
  re-prompt from memory.
- **Repo bloat** — LFS for binaries; sidecars stay tiny.
- **Untracked spend** — every asset records its cost.
- **Runtime dependency on a third-party** — the shipped game never
  calls the AI APIs. Generation is dev-time only.
- **Mid-stage rabbit hole** — when generation isn't producing what you
  need, stop and ship the procedural form. The hybrid contract has your
  back.

## What the agent cannot do unaided

- Approve a license question on borderline AI output. Surface it to the
  user.
- Spend over the per-stage ceiling without approval.
- Add a new tool not in the locked list above. Propose it; await approval.
- Generate explicit content, copyrighted character likenesses, or
  trademark-conflicting names. Refuse and explain.
