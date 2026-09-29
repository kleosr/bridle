#!/usr/bin/env bash
# Claude Code verdicts. PreToolUse allow is silence: an explicit "allow" would
# skip Claude's own permission prompt. Deny/ask go in hookSpecificOutput;
# UserPromptSubmit blocks with {"decision":"block"}. Claude fails open on any
# exit other than 0 and 2, so a crashed gate becomes exit 2 here.

trap 'rc=$?; if [[ $rc -ne 0 && $rc -ne 2 ]]; then echo "bridle: gate crashed (exit $rc); denied (failClosed)." >&2; exit 2; fi' EXIT

claude_decision() {
  json_str "[bridle $3] $2"
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"%s","permissionDecisionReason":%s}}\n' "$1" "$JSON_STR"
}

emit_allow() { :; }

emit_deny() { claude_decision deny "$1" "${3:-deny}"; }

emit_ask() { claude_decision ask "$1" "${3:-ask}"; }

emit_continue() {
  [[ "${1:-true}" == false ]] || return 0
  json_str "[bridle ${3:-block}] ${2:-}"
  printf '{"decision":"block","reason":%s}\n' "$JSON_STR"
}

# Cursor also runs ~/.claude/settings.json hooks and already gates these
# events natively; its payloads carry cursor_version.
host_skip() { [[ "$1" == *'"cursor_version"'* ]]; }
