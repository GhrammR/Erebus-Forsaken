#!/usr/bin/env python3
"""Validate an AI-asset sidecar against the schema in
.agent_governance/rules/asset-generation.md.

Exit 0 = valid. Exit 1 = invalid (with explanation to stderr).

Used by:
  - tools/asset_gen/*.sh wrappers, after every write
  - test/stage11_verify.gd (via OS.execute), so the verifier exercises
    the same schema enforcement the wrappers do

Schema (required keys, type / non-empty constraint):
  tool             : str, non-empty, in known set
  model            : str, non-empty
  prompt           : str, non-empty
  seed             : int  (0 is allowed for tools that don't take a seed)
  params           : dict
  output_sha256    : str, 64 lowercase hex
  generated_at     : str, ISO-8601 UTC ("...Z")
  generated_by     : str, non-empty
  purpose          : str, non-empty
  license          : str, non-empty
  cost_usd         : number (int or float), >= 0

Optional keys (silently allowed): negative_prompt, notes.
Any unknown key triggers a warning to stderr but does not fail.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

KNOWN_TOOLS = {"replicate", "elevenlabs", "runway", "heygen", "stability"}
REQUIRED = {
    "tool":          str,
    "model":         str,
    "prompt":        str,
    "seed":          int,
    "params":        dict,
    "output_sha256": str,
    "generated_at":  str,
    "generated_by":  str,
    "purpose":       str,
    "license":       str,
    "cost_usd":      (int, float),
}
OPTIONAL = {"negative_prompt", "notes"}

ISO_RE = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")


def fail(msg: str) -> "None":
    print(f"sidecar invalid: {msg}", file=sys.stderr)
    sys.exit(1)


def validate(path: Path) -> None:
    if not path.exists():
        fail(f"file does not exist: {path}")
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError as e:
        fail(f"{path}: not valid JSON ({e})")

    if not isinstance(data, dict):
        fail(f"{path}: top-level value must be an object")

    for k, t in REQUIRED.items():
        if k not in data:
            fail(f"{path}: missing required key '{k}'")
        if not isinstance(data[k], t):
            fail(f"{path}: key '{k}' has wrong type "
                 f"(expected {t}, got {type(data[k]).__name__})")

    if data["tool"] not in KNOWN_TOOLS:
        fail(f"{path}: unknown tool '{data['tool']}' "
             f"(expected one of {sorted(KNOWN_TOOLS)})")

    for k in ("model", "prompt", "purpose", "license", "generated_by"):
        if not str(data[k]).strip():
            fail(f"{path}: key '{k}' must be non-empty")

    if not ISO_RE.match(data["generated_at"]):
        fail(f"{path}: generated_at must be ISO-8601 UTC ('...Z')")

    if not SHA_RE.match(data["output_sha256"]):
        fail(f"{path}: output_sha256 must be 64 lowercase hex chars")

    if data["cost_usd"] < 0:
        fail(f"{path}: cost_usd must be >= 0")

    unknown = set(data.keys()) - set(REQUIRED.keys()) - OPTIONAL
    if unknown:
        print(f"sidecar warning: {path}: unknown keys {sorted(unknown)}",
              file=sys.stderr)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: validate_sidecar.py <sidecar.json> [<sidecar.json> ...]",
              file=sys.stderr)
        return 2
    for arg in argv[1:]:
        validate(Path(arg))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
