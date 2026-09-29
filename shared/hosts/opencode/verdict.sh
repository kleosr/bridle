#!/usr/bin/env bash
# opencode verdicts for plugin/bridle.js:
# {"decision": allow|deny|ask|block, "reason", "message"}.

opencode_decision() {
  if [[ "$1" == allow ]]; then
    echo '{"decision":"allow"}'
    return 0
  fi
  json_str "$2"
  local msg="$JSON_STR"
  json_str "$3"
  printf '{"decision":"%s","reason":%s,"message":%s}\n' "$1" "$JSON_STR" "$msg"
}

emit_allow() { opencode_decision allow; }

emit_deny() { opencode_decision deny "$1" "${3:-deny}"; }

# opencode has no approval dialog for a plugin verdict, so the person runs
# the command themselves.
emit_ask() {
  opencode_decision ask "Command needs the user's approval. Ask them to approve the concrete action, target, and scope; they can run it themselves with \`!\`. Command not echoed to avoid secret leakage." "${3:-ask}"
}

emit_continue() {
  if [[ "${1:-true}" == false ]]; then
    opencode_decision block "${2:-}" "${3:-block}"
  else
    opencode_decision allow
  fi
}

host_skip() { return 1; }
