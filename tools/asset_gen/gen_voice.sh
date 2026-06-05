#!/usr/bin/env bash
# gen_voice.sh — generate an NPC voice line via ElevenLabs TTS.
#
# Usage:
#   tools/asset_gen/gen_voice.sh \
#       --out audio/voice/kallias_intro.ogg \
#       --voice-id <eleven_voice_id> \
#       --text "Pleased to meet you, traveler." \
#       --purpose "Kallias intro (Stage 17)"
#
# Stage 11 ships dry-run only: no live call, writes a silent OGG stub
# and a complete sidecar so the verifier and the audio bank can wire up
# end-to-end before any spend.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUT="" VOICE_ID="" TEXT="" MODEL="eleven_multilingual_v2"
PURPOSE="" DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --voice-id) VOICE_ID="$2"; shift 2 ;;
        --text) TEXT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --purpose) PURPOSE="$2"; shift 2 ;;
        --live) DRY_RUN=0; shift ;;
        *) err "unknown arg: $1" ;;
    esac
done

[[ -n "$OUT" ]]      || err "--out is required"
[[ -n "$VOICE_ID" ]] || err "--voice-id is required"
[[ -n "$TEXT" ]]     || err "--text is required"
[[ -n "$PURPOSE" ]]  || err "--purpose is required"

mkdir -p "$(dirname "$OUT")"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "(dry-run) would call elevenlabs voice=$VOICE_ID model=$MODEL"
    # Empty file stub; AudioBank's placeholder-tolerance handles it.
    : > "$OUT"
    COST="0.00"
else
    load_secret elevenlabs
    [[ -n "${ELEVENLABS_API_KEY:-}" ]] || err "ELEVENLABS_API_KEY not set after sourcing"
    err "live mode not yet implemented — Stage 11 ships dry-run scaffolding"
fi

SHA="$(sha256_file "$OUT")"

SIDECAR_JSON="$(emit_sidecar_json \
    tool=elevenlabs \
    model="$MODEL" \
    prompt="$TEXT" \
    seed="@n:0" \
    params="@j:{\"voice_id\":\"$VOICE_ID\"}" \
    output_sha256="$SHA" \
    generated_at="$(iso_now)" \
    generated_by="${EREBUS_USER:-unknown}" \
    purpose="$PURPOSE" \
    license="ElevenLabs commercial license (paid tier)" \
    cost_usd="@n:$COST")"

write_sidecar "$OUT" "$SIDECAR_JSON"
