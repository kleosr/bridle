#!/usr/bin/env bash
# stop: one advisory churn/format/syntax note per turn, else {}. Never blocks.
set -euo pipefail
_self="${BASH_SOURCE[0]//\\//}"
_dir="${_self%/*}"; [[ "$_dir" == "$_self" || -z "$_dir" ]] && _dir="."
# shellcheck source=lib/selfdir.sh
source "$_dir/lib/selfdir.sh"
HERE="$(kleos_abs_dir "$_self")"; unset _self _dir
source "$HERE/lib/common.sh"
source "$HERE/lib/diff_gate.sh"
source "$HERE/lib/verify_gate.sh"
source "$HERE/lib/feature_gate.sh"
source "$HERE/lib/complete_gate.sh"
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
COMP="$(gate_completion "$WR" || true)"
MSG="${MSG}${VER}${FEAT}${COMP}"
[[ -n "$MSG" ]] || { emit_quiet; exit 0; }
emit_followup "$MSG"
