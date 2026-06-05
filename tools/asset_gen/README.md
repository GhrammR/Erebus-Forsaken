# Asset Generation Pipeline — operator guide

This is the **dev-only** AI asset pipeline. The shipping game never
calls these tools. They run at your terminal to produce bitmap, audio,
and video assets that land in the repo (with sidecars) and replace the
procedural fallbacks.

The contract lives in `.agent_governance/rules/asset-generation.md`.
This README covers the operator-side: keys, wrappers, sidecars.

## Setup (one-time)

1. Create the secrets directory and populate the keys you have:
   ```bash
   mkdir -p ~/.config/erebus-secrets
   chmod 700 ~/.config/erebus-secrets

   echo 'export REPLICATE_API_TOKEN=...' > ~/.config/erebus-secrets/replicate.env
   echo 'export ELEVENLABS_API_KEY=...' > ~/.config/erebus-secrets/elevenlabs.env
   # optional, only if generating video:
   echo 'export RUNWAY_API_KEY=...'     > ~/.config/erebus-secrets/runway.env

   chmod 600 ~/.config/erebus-secrets/*.env
   ```

   Stage 11 ships **dry-run** wrappers — you don't need keys to scaffold
   the pipeline or to run `--verify11`. Keys go in when you're ready
   to actually generate.

2. Install Git LFS if you haven't:
   ```bash
   git lfs install
   ```

   `.gitattributes` is already configured for `*.ogg`, `*.webm`, `*.mp4`,
   and PNGs over 1MB.

## Wrappers

All four wrappers run in dry-run mode by default. Pass `--live` once
keys are in place. Every successful run writes a sidecar; the sidecar
validator runs automatically on each write.

```bash
tools/asset_gen/gen_sprite.sh --out art/bitmap/enemies/bog_caller.png \
    --model black-forest-labs/flux-1.1-pro \
    --prompt "isometric ARPG enemy, bog caller, swamp witch, dark mossy robes, glowing green staff, 64px tall, pixel art, transparent background" \
    --seed 1934872 \
    --purpose "Bog Caller bitmap polish (Stage 11)"

tools/asset_gen/gen_voice.sh --out audio/voice/kallias_intro.ogg \
    --voice-id <eleven_voice_id> \
    --text "Pleased to meet you, traveler." \
    --purpose "Kallias intro (Stage 17)"

tools/asset_gen/gen_sfx.sh --out audio/sfx/hearth_ember_channel.ogg \
    --prompt "warm fire crackle with subtle wind, looping ambience" \
    --duration 2.0 \
    --purpose "Hearth Ember channel SFX"

tools/asset_gen/gen_video.sh --out video/intros/eurynome_intro.webm \
    --backend runway \
    --prompt "Eurynome facing camera, slow pan, dim torchlight" \
    --duration 5 \
    --purpose "Eurynome intro scene (Stage 17)"
```

## Sidecar contract

Every committed asset MUST have a `.json` sidecar of the same basename
in the same directory. Schema lives in
`.agent_governance/rules/asset-generation.md`. Validator:

```bash
tools/asset_gen/validate_sidecar.py path/to/asset.json
```

The validator is invoked automatically by each wrapper and by
`--verify11`. An asset without a passing sidecar is rejected.

## Cost discipline

- Default per-stage ceiling: **$20**
- Explicit user-approved ceiling: **$50**
- Above $50 requires stage-close justification

Sum the `cost_usd` field across sidecars added in a stage to audit.
Pay attention to: FLUX-1.1-pro ~ $0.04/image, ElevenLabs Creator
$22/month + per-char overage, Runway Gen-3 ~ $0.05/sec of video.

## What this pipeline does NOT do

- Run at game runtime. Ever.
- Approve borderline licensing questions — surface to the user.
- Generate explicit content or copyrighted likenesses.
- Replace the procedural baseline. Procedural ships either way;
  bitmaps are polish on top.
