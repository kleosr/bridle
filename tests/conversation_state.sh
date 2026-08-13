#!/usr/bin/env bash

rm -rf "$PACK/state"

cat "$PACK/tests/fixtures/sessionStart_conversation.json" | bash "$PACK/shared/hooks/session_start.sh" >/dev/null 2>&1
CONV1_DIR="$PACK/state/conv-test-001"
CONV1_MODE="$(cat "$CONV1_DIR/mode" 2>/dev/null || echo "")"
run_test "conv1 state dir created at conv-scoped path" "conv-test-001" "$(basename "$CONV1_DIR" 2>/dev/null || echo missing)"
run_test "conv1 mode persisted" "agent" "$CONV1_MODE"

printf 'src/from-conv1.ts\n' > "$CONV1_DIR/allowed_files.md"
mkdir -p "$PACK/state/conv-test-002"
printf 'src/from-conv2.ts\n' > "$PACK/state/conv-test-002/allowed_files.md"
CONV2_LEAK="$(grep -c 'from-conv2' "$CONV1_DIR/allowed_files.md" 2>/dev/null || true)"
CONV2_LEAK="${CONV2_LEAK//[!0-9]}"; [[ -z "$CONV2_LEAK" ]] && CONV2_LEAK=0
run_test "conv2 write does not leak into conv1" "0" "$CONV2_LEAK"

rm -rf "$PACK/state/conv-test-001" "$PACK/state/conv-test-002"

DEFAULT_DIR="$(HERE="$PACK/shared/hooks" bash -c '
  source "$0/lib/common.sh" && resolve_root && CONV_ID="default" && state_dir
' "$PACK/shared/hooks" 2>/dev/null)"
run_test "default conv_id falls back to legacy state/" "$PACK/state" "$DEFAULT_DIR"

rm -rf "$PACK/state"
