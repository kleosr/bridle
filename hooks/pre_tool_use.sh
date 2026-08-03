#!/usr/bin/env bash
# hooks/pre_tool_use.sh — Selective Autonomy gate (V17.2)
#
# Goal: let the agent act autonomously on SAFE operations, block DESTRUCTIVE
# ones pending human approval. Corrected from a naive draft that (1) used
# invented tool names (write_file/edit_file) so its deny branch never ran,
# (2) whitelisted all *.md as "safe" — which defeats the FILE_MAP topology
# sandbox, and (3) ignored state/allowed_files.md entirely.
#
# This version:
#   - uses real tool names (Write|Edit|MultiEdit|StrReplace for file edits,
#     Bash for shell),
#   - respects the FILE_MAP snapshotted by before_submit_prompt.sh —
#     if the user scoped a path, edits outside it are denied (TOPOLOGY),
#   - blocks DESTRUCTIVE intent regardless of extension: rm -rf, git push
#     --force, drop table, migrations on prod, auth-rewrite patterns,
#   - allows safe autonomous writes (docs/todos/stubs) ONLY when not scoped
#     away by the FILE_MAP.
#
# Output formats:
#   Cursor  -> {action:"deny", user_message:"..."}  (exit 0)
#   Claude  -> {hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:"..."}}
#
# Hooks are invoked with the SAME payload shape by both clients, so we detect
# the client by the presence of hookSpecificOutput expectations: Claude passes
# hook_event_name; Cursor does not. We emit whichever the caller understands.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
INPUT="$(cat)"
TOOL_NAME="$(echo "$INPUT" | jq -r '.tool_name // .name // empty')"

# Resolve ROOT + STATE the same way the other hooks do (HERE/.. has HANDOFF/AGENTS).
ROOT=""
for d in "$HERE/.." "$HERE/../.." "$HERE/../../.."; do
  if [[ -f "$d/HANDOFF.md" || -f "$d/AGENTS.md" ]]; then ROOT="$(cd "$d" && pwd)"; break; fi
done
[[ -z "$ROOT" ]] && ROOT="$(cd "$HERE/.." && pwd)"
STATE="$ROOT/state"
ALLOWED="$STATE/allowed_files.md"

# Deny helper emits the right envelope for the calling client.
is_claude() { echo "$INPUT" | jq -e '.hook_event_name // empty' >/dev/null 2>&1; }
deny() {
  local msg="$1"
  if is_claude; then
    jq -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$m}}'
  else
    jq -n --arg m "$msg" '{action:"deny", user_message:$m}'
  fi
  exit 0
}

# Non-mutating tools: always allow.
case "$TOOL_NAME" in
  Read|Grep|Glob|LS|BashOutput|WebFetch|WebSearch|TodoWrite|Task|TaskOutput) echo '{}'; exit 0 ;;
esac

# ── File-edit tools (Write / Edit / MultiEdit / StrReplace) ────────────────
case "$TOOL_NAME" in
  Write|Edit|MultiEdit|StrReplace)
    FILE_PATH="$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')"
    [[ -z "$FILE_PATH" ]] && { echo '{}'; exit 0; }

    # Respect FILE_MAP: if the user scoped paths this turn, anything outside is
    # a topology violation — deny unless it is an explicitly allowed path.
    if [[ -s "$ALLOWED" ]]; then
      base="$(basename "$FILE_PATH")"
      if ! grep -qxF "$FILE_PATH" "$ALLOWED" 2>/dev/null && ! grep -qxF "$base" "$ALLOWED" 2>/dev/null; then
        deny "TOPOLOGY BLOCK: '$FILE_PATH' is outside your declared FILE_MAP. Expand your INTENT or remove the scope restriction before editing it."
      fi
    fi

    # Destructive-content guard: reject edits that rewrite auth/credentials or
    # drop schemas, even inside an allowed path.
    NEW_CONTENT=""
    case "$TOOL_NAME" in
      Write) NEW_CONTENT="$(echo "$INPUT" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true)" ;;
      Edit|MultiEdit) NEW_CONTENT="$(echo "$INPUT" | jq -r '[.tool_input.new_string // "", (.tool_input.edits[]?.new_string // "")] | join("\n")' 2>/dev/null || true)" ;;
      StrReplace) NEW_CONTENT="$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)" ;;
    esac
    if echo "$NEW_CONTENT" | grep -qiE '(DROP TABLE|DELETE FROM .* WHERE 1=1|rm -rf /|password\s*=\s*["'\''][^"'\'']+["'\'']|API_KEY\s*=\s*["'\''][^"'\'']+["'\'']|secret\s*=\s*["'\''][^"'\'']+["'\''])'; then
      deny "AUTONOMY BLOCK: edit contains a destructive/credential pattern (drop/delete-all/secret write). Human approval required."
    fi

    echo '{}'; exit 0
    ;;
esac

# ── Bash tool: block destructive commands, allow the rest ──────────────────
if [[ "$TOOL_NAME" == "Bash" || "$TOOL_NAME" == "bash" ]]; then
  CMD="$(echo "$INPUT" | jq -r '.tool_input.command // .tool_input.cmd // .command // empty')"
  [[ -z "$CMD" ]] && { echo '{}'; exit 0; }

  # Refuse recursive/forced destruction and force-push.
  if echo "$CMD" | grep -qiE '(rm -rf? /|rm -rf? ~|mkfs|dd if=|git push --force|git push -f|drop database|truncate table|>:.*\/dev\/sd|shred )'; then
    deny "AUTONOMY BLOCK: command matches a destructive pattern. Human approval required. CMD: ${CMD:0:120}"
  fi
  # Refuse mutations to prod DBs / cloud infra without explicit scope.
  if echo "$CMD" | grep -qiE '(psql|mysql|mongosh|supabase db|terraform apply|kubectl delete|docker rm -f|systemctl stop)'; then
    deny "AUTONOMY BLOCK: command mutates infra/DB. Human approval required. CMD: ${CMD:0:120}"
  fi
  echo '{}'; exit 0
fi

# Unknown tool: allow (fail-open is acceptable here; lean_gate/stop_gate cover
# the file-write and intent paths).
echo '{}'
exit 0
