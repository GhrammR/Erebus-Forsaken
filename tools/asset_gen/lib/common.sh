#!/usr/bin/env bash
# Shared helpers for tools/asset_gen/* wrappers. Source this from each
# wrapper. Provides: secrets loading, sha256, sidecar write, validation,
# common error reporting.
#
# Contract lives in .agent_governance/rules/asset-generation.md. Edits
# here that drift from that rule are bugs.

set -euo pipefail

SECRETS_DIR="${EREBUS_SECRETS_DIR:-$HOME/.config/erebus-secrets}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/tools/asset_gen/validate_sidecar.py"

err() { echo "error: $*" >&2; exit 1; }

load_secret() {
    # load_secret replicate  -> sources ~/.config/erebus-secrets/replicate.env
    local name="$1"
    local f="$SECRETS_DIR/${name}.env"
    [[ -f "$f" ]] || err "missing secrets file $f
    create it with the API token export, e.g.:
      mkdir -p $SECRETS_DIR
      echo 'export ${name^^}_API_TOKEN=...' > $f
      chmod 600 $f"
    # shellcheck disable=SC1090
    source "$f"
}

sha256_file() {
    local f="$1"
    [[ -f "$f" ]] || err "sha256_file: $f does not exist"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$f" | awk '{print $1}'
    else
        shasum -a 256 "$f" | awk '{print $1}'
    fi
}

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# write_sidecar <asset_path> <json>
# Writes <asset_path>.json next to the asset, then validates.
write_sidecar() {
    local asset="$1"
    local json="$2"
    local sidecar="${asset%.*}.json"
    printf '%s\n' "$json" > "$sidecar"
    validate_sidecar "$sidecar"
    echo "wrote sidecar: $sidecar"
}

validate_sidecar() {
    local sidecar="$1"
    [[ -x "$VALIDATOR" ]] || err "validator not executable: $VALIDATOR"
    "$VALIDATOR" "$sidecar"
}

# emit_sidecar_json — convenience JSON builder. Caller passes flat
# key=value pairs; values are treated as strings unless prefixed with
# `@n:` (number) or `@b:` (bool) or `@j:` (raw json fragment).
emit_sidecar_json() {
    python3 - "$@" <<'PY'
import json, sys
out = {}
for arg in sys.argv[1:]:
    if "=" not in arg:
        continue
    k, v = arg.split("=", 1)
    if v.startswith("@n:"):
        try: out[k] = int(v[3:])
        except ValueError: out[k] = float(v[3:])
    elif v.startswith("@b:"):
        out[k] = (v[3:].lower() == "true")
    elif v.startswith("@j:"):
        out[k] = json.loads(v[3:])
    else:
        out[k] = v
print(json.dumps(out, indent=2, sort_keys=True))
PY
}
