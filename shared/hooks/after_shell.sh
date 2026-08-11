#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
resolve_root
INPUT="$(cat)"
CONV_ID="$(extract_conv_id "$INPUT")"
STATE="$(state_dir)"
mkdir -p "$STATE"
CMD="$(echo "$INPUT" | jq -r '.command // empty' 2>/dev/null || true)"
DURATION="$(echo "$INPUT" | jq -r '.duration // "?"' 2>/dev/null || echo "?")"
SANDBOX="$(echo "$INPUT" | jq -r '.sandbox // "?"' 2>/dev/null || echo "?")"
OUT_LEN="$(echo "$INPUT" | jq -r '(.output // "") | length' 2>/dev/null || echo 0)"
OUT_SNIP="$(echo "$INPUT" | jq -r '(.output // "")[0:400]' 2>/dev/null || true)"
TAG=""
if printf '%s' "$CMD" | grep -qiE '(tests/run\.sh|scripts/doctor|npm test|pnpm test|yarn test|bun test|pytest|cargo test|go test|TOOLCHAIN)'; then
  TAG=" VERIFY"
fi
if printf '%s' "$OUT_SNIP" | grep -qiE '(ALL CHECKS PASSED|PASS:.*FAIL: 0|FAIL: 0$|tests? passed|ok \(|✓)'; then
  TAG="${TAG} GREEN"
fi
printf '%s | SHELL%s | duration=%s sandbox=%s out_len=%s | %s\n' \
  "$(date +%Y-%m-%d\ %H:%M:%S)" "$TAG" "$DURATION" "$SANDBOX" "$OUT_LEN" "${CMD:0:200}" >>"$STATE/session.log" 2>/dev/null || true
emit_quiet
