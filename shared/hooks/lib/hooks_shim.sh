#!/usr/bin/env bash
# Windows: after merge, rewrite pack events to pwsh (or powershell.exe) + shim.

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

# pwsh when present; Windows PowerShell 5.1 otherwise. Unqualified `powershell`
# is the leftover form tests rewrite away. Non-Windows fixtures keep `pwsh`.
shim_ps_exe() {
  if command -v pwsh >/dev/null 2>&1; then
    printf 'pwsh'
    return 0
  fi
  if is_windows_host; then
    local p="${WINDIR:-/c/Windows}/System32/WindowsPowerShell/v1.0/powershell.exe"
    if [[ -f "$p" || -x "$p" ]]; then
      shim_file_win "$p"
      return 0
    fi
  fi
  printf 'pwsh'
}

apply_pwsh_shim_hooks() {
  local dest="$1" hookdir shim tmp p exe
  hookdir="$(dirname "$dest")/hooks"
  shim="$hookdir/git-bash-shim.ps1"
  [[ -f "$dest" && -f "$shim" ]] || return 0
  if ! jq -e '.. | strings | select(test("bash-shim\\.ps1"))' "$dest" >/dev/null 2>&1; then
    is_windows_host || return 0
  fi
  exe="$(shim_ps_exe)"
  # Do not quote the exe: Cursor's hook runner treats \"C:\\...\\powershell.exe\" as
  # a parse failure (process exit 1, failClosed). The -File path stays quoted.
  p="${exe} -NoProfile -ExecutionPolicy Bypass -File \"$(shim_file_win "$shim")\""
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
        + [{command: ($p + " before_submit_prompt.sh"), timeout: 30, failClosed: true}]
    | .hooks.beforeShellExecution = ((.hooks.beforeShellExecution // []) | keep)
        + [{command: ($p + " before_shell.sh"), timeout: 60, failClosed: true}]
    | .hooks.beforeReadFile = ((.hooks.beforeReadFile // []) | keep)
        + [{command: ($p + " before_read_file.sh"), timeout: 30, failClosed: true}]
    | .hooks.stop = ((.hooks.stop // []) | keep)
        + [{command: ($p + " stop.sh"), timeout: 30, failClosed: false, loop_limit: 1}]
  ' "$dest" >"$tmp"; then
    rm -f "$tmp"
    echo "[fail] hooks.json pwsh shim rewrite failed" >&2
    return 1
  fi
  mv "$tmp" "$dest"
}
