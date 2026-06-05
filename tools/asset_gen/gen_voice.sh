#!/usr/bin/env bash
# gen_voice.sh — generate an NPC voice line via Replicate TTS.
#
# Default model: jaaari/kokoro-82m (fast, multi-voice, cheap).
# Alternates worth trying: lucataco/xtts-v2 (voice cloning),
# minimax/speech-02-hd (higher quality, higher cost). ElevenLabs
# stays as a deferred fallback (rules/asset-generation.md) for cases
# where Replicate TTS quality isn't sufficient on a specific NPC.
#
# Usage:
#   tools/asset_gen/gen_voice.sh \
#       --out audio/voice/kallias_intro.ogg \
#       --voice af_bella \
#       --text "Pleased to meet you, traveler." \
#       --purpose "Kallias intro (Stage 17)"
#
# Stage 11 ships dry-run only: no live call, writes a silent OGG stub
# and a complete sidecar so the verifier and the audio bank can wire up
# end-to-end before any spend.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUT="" VOICE="af_bella" TEXT="" MODEL="jaaari/kokoro-82m"
BACKEND="replicate" PURPOSE="" DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --voice) VOICE="$2"; shift 2 ;;
        --text) TEXT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --backend) BACKEND="$2"; shift 2 ;;
        --purpose) PURPOSE="$2"; shift 2 ;;
        --live) DRY_RUN=0; shift ;;
        *) err "unknown arg: $1" ;;
    esac
done

[[ -n "$OUT" ]]     || err "--out is required"
[[ -n "$TEXT" ]]    || err "--text is required"
[[ -n "$PURPOSE" ]] || err "--purpose is required"

mkdir -p "$(dirname "$OUT")"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "(dry-run) would call $BACKEND voice=$VOICE model=$MODEL"
    # Empty file stub; AudioBank's placeholder-tolerance handles it.
    : > "$OUT"
    COST="0.00"
else
    case "$BACKEND" in
        replicate)  load_secret replicate ;;
        elevenlabs) load_secret elevenlabs ;;
        *) err "unknown backend: $BACKEND" ;;
    esac
    err "live mode not yet implemented — Stage 11 ships dry-run scaffolding"
fi

SHA="$(sha256_file "$OUT")"

SIDECAR_JSON="$(emit_sidecar_json \
    tool="$BACKEND" \
    model="$MODEL" \
    prompt="$TEXT" \
    seed="@n:0" \
    params="@j:{\"voice\":\"$VOICE\"}" \
    output_sha256="$SHA" \
    generated_at="$(iso_now)" \
    generated_by="${EREBUS_USER:-unknown}" \
    purpose="$PURPOSE" \
    license="${BACKEND} ToS (commercial use OK on paid tier)" \
    cost_usd="@n:$COST")"

write_sidecar "$OUT" "$SIDECAR_JSON"
