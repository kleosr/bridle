#!/usr/bin/env bash
# Windows: after merge, rewrite pack events to pwsh + git-bash-shim.ps1.

is_windows_host() {
  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
  esac
  [[ -n "${MSYSTEM:-}" ]]
}

shim_file_win() {
  local s="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$s"
  else
    printf '%s' "$s"
  fi
}

apply_pwsh_shim_hooks() {
  local dest="$1" hookdir shim tmp p
  hookdir="$(dirname "$dest")/hooks"
  shim="$hookdir/git-bash-shim.ps1"
  [[ -f "$dest" && -f "$shim" ]] || return 0
  if ! jq -e '.. | strings | select(test("bash-shim\\.ps1"))' "$dest" >/dev/null 2>&1; then
    is_windows_host || return 0
  fi
  p="pwsh -NoProfile -ExecutionPolicy Bypass -File \"$(shim_file_win "$shim")\""
  tmp="$(mktemp "${TMPDIR:-/tmp}/kleos-shimjson.XXXXXX")"
  if ! jq --arg p "$p" '
    def pack_cmd:
      (.command // "") as $c
      | ($c | test("bash-shim\\.ps1"))
        or ($c | test("./hooks/(before_submit_prompt|before_shell|before_read_file|stop)\\.sh"))
        or ($c | test("[[:space:]](before_submit_prompt|before_shell|before_read_file|stop)\\.sh([[:space:]]|$)"));
    def keep: map(select(pack_cmd | not));
    del(.hooks.sessionStart)
    | .hooks.beforeSubmitPrompt = ((.hooks.beforeSubmitPrompt // []) | keep)
        + [{command: ($p + " before_submit_prompt.sh"), timeout: 10, failClosed: true}]
    | .hooks.beforeShellExecution = ((.hooks.beforeShellExecution // []) | keep)
        + [{command: ($p + " before_shell.sh"), timeout: 30, failClosed: true}]
    | .hooks.beforeReadFile = ((.hooks.beforeReadFile // []) | keep)
        + [{command: ($p + " before_read_file.sh"), timeout: 10, failClosed: true}]
    | .hooks.stop = ((.hooks.stop // []) | keep)
        + [{command: ($p + " stop.sh"), timeout: 30, failClosed: false, loop_limit: 1}]
  ' "$dest" >"$tmp"; then
    rm -f "$tmp"
    echo "[fail] hooks.json pwsh shim rewrite failed" >&2
    return 1
  fi
  mv "$tmp" "$dest"
}
