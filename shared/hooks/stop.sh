#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
source "$HERE/lib/diff_gate.sh"
INPUT="$(cat)"
STATUS="$(printf '%s' "$INPUT" | jq -r '.status // empty' 2>/dev/null || true)"
LOOP="$(printf '%s' "$INPUT" | jq -r '.loop_count // 0' 2>/dev/null || echo 0)"
WR="$(printf '%s' "$INPUT" | jq -r '.workspace_roots[0] // empty' 2>/dev/null || true)"
if [[ "$STATUS" != "completed" || "$LOOP" != "0" || -z "$WR" || ! -d "$WR" ]]; then
  emit_quiet; exit 0
fi
git -C "$WR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { emit_quiet; exit 0; }
MSG="$(gate_diff "$WR" || true)"
[[ -n "$MSG" ]] || { emit_quiet; exit 0; }
jq -n --arg m "$MSG" '{followup_message:$m}'
