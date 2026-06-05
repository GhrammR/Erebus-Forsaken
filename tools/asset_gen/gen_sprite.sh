#!/usr/bin/env bash
# gen_sprite.sh — generate an image asset via Replicate.
#
# Usage:
#   tools/asset_gen/gen_sprite.sh \
#       --out art/bitmap/enemies/bog_caller.png \
#       --model black-forest-labs/flux-1.1-pro \
#       --prompt "isometric ARPG enemy, bog caller, ..." \
#       --seed 1934872 \
#       --purpose "Bog Caller bitmap polish (Stage 11 pipeline test)"
#
# The wrapper does NOT call any model at this stage — Stage 11 ships
# the scaffolding only. Once the user drops a Replicate token at
# ~/.config/erebus-secrets/replicate.env, uncomment the REAL CALL block.
#
# Sidecar is always written, even in dry-run mode, so the verifier
# can exercise the contract end-to-end with a placeholder asset.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

OUT="" MODEL="black-forest-labs/flux-1.1-pro" PROMPT="" NEG=""
SEED="" WIDTH=256 HEIGHT=256 GUIDANCE=7.5 STEPS=30 PURPOSE="" DRY_RUN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out) OUT="$2"; shift 2 ;;
        --model) MODEL="$2"; shift 2 ;;
        --prompt) PROMPT="$2"; shift 2 ;;
        --negative) NEG="$2"; shift 2 ;;
        --seed) SEED="$2"; shift 2 ;;
        --width) WIDTH="$2"; shift 2 ;;
        --height) HEIGHT="$2"; shift 2 ;;
        --guidance) GUIDANCE="$2"; shift 2 ;;
        --steps) STEPS="$2"; shift 2 ;;
        --purpose) PURPOSE="$2"; shift 2 ;;
        --live) DRY_RUN=0; shift ;;
        *) err "unknown arg: $1" ;;
    esac
done

[[ -n "$OUT" ]]     || err "--out is required"
[[ -n "$PROMPT" ]]  || err "--prompt is required"
[[ -n "$PURPOSE" ]] || err "--purpose is required"
[[ -n "$SEED" ]]    || err "--seed is required (deterministic regen)"

mkdir -p "$(dirname "$OUT")"

if [[ "$DRY_RUN" == "1" ]]; then
    echo "(dry-run) would call replicate model=$MODEL seed=$SEED"
    # Write a 1x1 transparent PNG placeholder so sha256 + sidecar work.
    printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xbf\x9e\x95\x00\x00\x00\x00IEND\xaeB`\x82' > "$OUT"
    COST="0.00"
else
    load_secret replicate
    [[ -n "${REPLICATE_API_TOKEN:-}" ]] || err "REPLICATE_API_TOKEN not set after sourcing"
    # REAL CALL (commented until user runs --live with a key):
    # curl -sS -X POST "https://api.replicate.com/v1/predictions" \
    #     -H "Authorization: Token $REPLICATE_API_TOKEN" \
    #     -H "Content-Type: application/json" \
    #     -d "$(emit_sidecar_json version=$MODEL input=@j:{\"prompt\":\"$PROMPT\",\"seed\":$SEED,...})" \
    #     | tee /tmp/replicate-resp.json
    err "live mode not yet implemented — Stage 11 ships dry-run scaffolding"
fi

SHA="$(sha256_file "$OUT")"
GENERATED_AT="$(iso_now)"
GENERATED_BY="${EREBUS_USER:-unknown}"

SIDECAR_JSON="$(emit_sidecar_json \
    tool=replicate \
    model="$MODEL" \
    prompt="$PROMPT" \
    negative_prompt="$NEG" \
    seed="@n:$SEED" \
    params="@j:{\"width\":$WIDTH,\"height\":$HEIGHT,\"guidance\":$GUIDANCE,\"steps\":$STEPS}" \
    output_sha256="$SHA" \
    generated_at="$GENERATED_AT" \
    generated_by="$GENERATED_BY" \
    purpose="$PURPOSE" \
    license="Replicate ToS (commercial use OK on paid tier)" \
    cost_usd="@n:$COST")"

write_sidecar "$OUT" "$SIDECAR_JSON"
