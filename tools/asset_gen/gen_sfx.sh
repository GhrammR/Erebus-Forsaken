#!/usr/bin/env bash
# gen_sfx.sh — generate a sound-effect via ElevenLabs SFX or Stable
# Audio (via Replicate). Default backend is ElevenLabs SFX.
#
# Usage:
#   tools/asset_gen/gen_sfx.sh \
#       --out audio/sfx/hearth_ember_channel.ogg \
#       --prompt "warm fire crackle with subtle wind, looping ambience" \
#       --duration 2.0 \
#       --purpose "Hearth Ember channel SFX (Stage 9.8 placeholder fill)"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUT="" PROMPT="" DURATION=1.0 BACKEND="elevenlabs"
PURPOSE="" DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --backend) BACKEND="$2"; shift 2 ;;
        --purpose) PURPOSE="$2"; shift 2 ;;
        --live) DRY_RUN=0; shift ;;
        *) err "unknown arg: $1" ;;
    esac
done

[[ -n "$OUT" ]]     || err "--out is required"
[[ -n "$PROMPT" ]]  || err "--prompt is required"
[[ -n "$PURPOSE" ]] || err "--purpose is required"

mkdir -p "$(dirname "$OUT")"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "(dry-run) would call $BACKEND sfx duration=${DURATION}s"
    : > "$OUT"
    COST="0.00"
else
    case "$BACKEND" in
        elevenlabs) load_secret elevenlabs ;;
        replicate)  load_secret replicate ;;
        *) err "unknown backend: $BACKEND" ;;
    esac
    err "live mode not yet implemented — Stage 11 ships dry-run scaffolding"
fi

SHA="$(sha256_file "$OUT")"

SIDECAR_JSON="$(emit_sidecar_json \
    tool="$BACKEND" \
    model="${BACKEND}-sfx" \
    prompt="$PROMPT" \
    seed="@n:0" \
    params="@j:{\"duration\":$DURATION}" \
    output_sha256="$SHA" \
    generated_at="$(iso_now)" \
    generated_by="${EREBUS_USER:-unknown}" \
    purpose="$PURPOSE" \
    license="${BACKEND} ToS (commercial use OK on paid tier)" \
    cost_usd="@n:$COST")"

write_sidecar "$OUT" "$SIDECAR_JSON"
