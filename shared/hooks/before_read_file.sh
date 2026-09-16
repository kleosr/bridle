#!/usr/bin/env bash
# beforeReadFile: screening deny for sensitive paths (best effort, not
# confidentiality — see SECURITY.md). Fail closed on malformed input or
# missing policy.
#
# Hot path: the host sends the whole file `content` in this payload and calls
# this hook on every native Read (median 2 KB, p90 13 KB, 1.3k reads per log
# window on 2026-09-15). Only `file_path` matters here. Every `file_path` value
# in the payload (top level plus attachments[]) is lifted with a bash regex;
# when none matches the policy the read is allowed with zero spawns. The JSON
# codec runs only when the verdict depends on which key is the top-level one
# (a candidate matched), when no key was found, or when an escape sequence
# is outside what the regex decodes. Verdicts are identical to the codec path.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/common.sh"
INPUT="$(hook_stdin)"
POL="$HERE/policy/secret_paths.ere"
if [[ ! -f "$POL" ]]; then
  emit_deny "kleosrules: policy/secret_paths.ere is missing; read denied (failClosed). Run FORCE=1 bash scripts/install.sh." "" missing-policy
  exit 0
fi

# fast_paths INPUT: fills FAST_PATHS with every unescaped "file_path" and
# "path" value (the same keys decode-read honors, at any depth). Inside JSON
# strings every quote is \" so a bare "file_path" is always a key. Returns 1
# when no key is found or a value uses an escape other than \\ or \/.
fast_paths() {
  local key rest raw bs='\' two='\\'
  local re='^[[:space:]]*:[[:space:]]*"(([^"\\]|\\\\|\\/)*)"'
  FAST_PATHS=()
  for key in '"file_path"' '"path"'; do
    rest="$1"
    while [[ "$rest" == *"$key"* ]]; do
      rest="${rest#*"$key"}"
      [[ "$rest" =~ $re ]] || return 1
      raw="${BASH_REMATCH[1]}"
      raw="${raw//"$two"/$bs}"
      raw="${raw//"$bs/"//}"
      FAST_PATHS+=("$raw")
    done
  done
  (( ${#FAST_PATHS[@]} > 0 ))
}

fast_all_clean() {
  local p
  for p in "${FAST_PATHS[@]}"; do
    p="$(canon_secret_path "$p")"
    [[ -n "$p" ]] && policy_match_i "$p" "$POL" && return 1
  done
  return 0
}

FAST_PATHS=()
if fast_paths "$INPUT" && fast_all_clean; then
  emit_allow
  exit 0
fi

if ! json_available; then
  emit_deny "kleosrules: Python or Node is unavailable; read denied (failClosed). Install python3 or node." "" missing-json
  exit 0
fi
if ! DECODE="$(printf '%s' "$INPUT" | json_run decode-read)"; then
  emit_deny "kleosrules: beforeReadFile payload is not JSON; read denied (failClosed). Run bash scripts/doctor.sh." "" malformed
  exit 0
fi
FILE_PATH=""
eval "$DECODE"
FILE_PATH="$(canon_secret_path "${FILE_PATH:-}")"
if [[ -n "$FILE_PATH" ]] && policy_match_i "$FILE_PATH" "$POL"; then
  emit_deny "AUTONOMY BLOCK: reading a sensitive path is blocked to protect secrets from model context. Read it yourself if needed." "" secret-path
  exit 0
fi
emit_allow
