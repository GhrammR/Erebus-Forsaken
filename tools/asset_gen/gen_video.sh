#!/usr/bin/env bash
# gen_video.sh — generate a short video / talking-portrait clip via
# Runway Gen-3 or HeyGen. Stage 11 scaffolding only (dry-run); the
# first live call lands when an intro scene actually needs it.
#
# Usage:
#   tools/asset_gen/gen_video.sh \
#       --out video/intros/eurynome_intro.webm \
#       --backend runway \
#       --prompt "Eurynome facing camera, slow pan, dim torchlight" \
#       --duration 5 \
#       --purpose "Eurynome intro scene (Stage 17)"

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUT="" BACKEND="replicate" MODEL="lightricks/ltx-video"
PROMPT="" DURATION=4 SEED=0 PURPOSE="" DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --backend) BACKEND="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --duration) DURATION="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
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
    echo "(dry-run) would call $BACKEND video model=$MODEL duration=${DURATION}s"
    : > "$OUT"
    COST="0.00"
else
    case "$BACKEND" in
        replicate) load_secret replicate ;;
        runway)    load_secret runway ;;
        heygen)    load_secret heygen ;;
        *) err "unknown backend: $BACKEND" ;;
    esac
    err "live mode not yet implemented — Stage 11 ships dry-run scaffolding"
fi

SHA="$(sha256_file "$OUT")"

SIDECAR_JSON="$(emit_sidecar_json \
    tool="$BACKEND" \
    model="$MODEL" \
    prompt="$PROMPT" \
    seed="@n:$SEED" \
    params="@j:{\"duration\":$DURATION}" \
    output_sha256="$SHA" \
    generated_at="$(iso_now)" \
    generated_by="${EREBUS_USER:-unknown}" \
    purpose="$PURPOSE" \
    license="${BACKEND} ToS (commercial use OK on paid tier)" \
    cost_usd="@n:$COST")"

write_sidecar "$OUT" "$SIDECAR_JSON"
