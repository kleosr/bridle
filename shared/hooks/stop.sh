#!/usr/bin/env bash
# stop: one advisory churn/format/syntax note per turn, else {}. Never blocks.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/diff_gate.sh"
source "$HERE/lib/verify_gate.sh"
source "$HERE/lib/feature_gate.sh"
INPUT="$(hook_stdin)"
json_available || { emit_quiet; exit 0; }
if ! DECODE="$(printf '%s' "$INPUT" | json_run decode-stop)"; then
  emit_quiet; exit 0
fi
eval "$DECODE"
WR="$(posix_slashes "${WR:-}")"
if [[ "${STATUS:-}" != "completed" || "${LOOP:-0}" != "0" || -z "$WR" || ! -d "$WR" ]]; then
  emit_quiet; exit 0
fi
git -C "$WR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { emit_quiet; exit 0; }
MSG="$(gate_diff "$WR" || true)"
VER="$(gate_verify "$WR" || true)"
FEAT="$(gate_features "$WR" || true)"
MSG="${MSG}${VER}${FEAT}"
[[ -n "$MSG" ]] || { emit_quiet; exit 0; }
emit_followup "$MSG"
