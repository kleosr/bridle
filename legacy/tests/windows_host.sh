#!/usr/bin/env bash
# Windows host: Git Bash shim exit codes + skill-catalog leftovers.
# Behavioral PowerShell cases skip when powershell.exe is absent (macOS/Linux CI).

echo "--- Windows host (shim + skill catalog) ---"

SHIM="$PACK/Windows/hooks/bash-shim.ps1"
if [[ ! -f "$SHIM" ]]; then
  run_test "regression: Windows bash-shim references process ExitCode" "1" "missing-file"
else
  if EC_HITS="$(grep -c 'ExitCode' "$SHIM")"; then
    EC_HITS="$(printf '%s' "$EC_HITS" | tr -d ' ')"
  else
    _st=$?
    if [[ "$_st" -eq 1 ]]; then
      EC_HITS=0
    else
      EC_HITS="grep-error:$_st"
    fi
  fi
  run_test "regression: Windows bash-shim references process ExitCode" "1" "$EC_HITS"
fi

if grep -qF 'orphan.pre-kleos-bak' "$PACK/Windows/install.ps1" "$PACK/Windows/lib/"*.ps1; then
  WIN_BAD_BAK=1
else
  _st=$?
  if [[ "$_st" -eq 1 ]]; then
    WIN_BAD_BAK=0
  else
    WIN_BAD_BAK="grep-error:$_st"
  fi
fi
run_test "regression: Windows installer does not suffix-bak retired skills under skills/" "0" "$WIN_BAD_BAK"

BAK_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-skillbak.XXXXXX")"
mkdir -p "$BAK_HOME/.cursor/skills/now.pre-kleos-bak" \
  "$BAK_HOME/.cursor/skills/session-handoff.pre-kleos-bak" \
  "$BAK_HOME/.cursor/skills/user-notes.pre-kleos-bak"
printf '%s\n' '# leftover retired skill' > "$BAK_HOME/.cursor/skills/now.pre-kleos-bak/SKILL.md"
printf '%s\n' '# leftover retired skill' > "$BAK_HOME/.cursor/skills/session-handoff.pre-kleos-bak/SKILL.md"
printf '%s\n' '# foreign skill' > "$BAK_HOME/.cursor/skills/user-notes.pre-kleos-bak/SKILL.md"
INSTALL_EC=0
HOME="$BAK_HOME" FORCE=1 bash "$PACK/shared/hooks/fleet_sync.sh" install >/dev/null 2>&1 || INSTALL_EC=$?
if [[ "$INSTALL_EC" -ne 0 ]]; then
  rm -rf "$BAK_HOME"
  run_test "regression: install prunes pack skills/*.pre-kleos-bak leftover" "0" "install-exit:$INSTALL_EC"
else
  BAK_LEFT="$(if [[ -e "$BAK_HOME/.cursor/skills/now.pre-kleos-bak" || -e "$BAK_HOME/.cursor/skills/session-handoff.pre-kleos-bak" ]]; then echo yes; else echo no; fi)"
  BAK_KEEP="$(if [[ -e "$BAK_HOME/.cursor/skills/user-notes.pre-kleos-bak/SKILL.md" ]]; then echo yes; else echo no; fi)"
  rm -rf "$BAK_HOME"
  run_test "regression: install prunes pack skills/*.pre-kleos-bak leftover" "no" "$BAK_LEFT"
  run_test "regression: install keeps foreign skills/*.pre-kleos-bak" "yes" "$BAK_KEEP"
fi

UN_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-unbak.XXXXXX")"
mkdir -p "$UN_HOME/.cursor/skills/now.pre-kleos-bak" "$UN_HOME/.cursor/skills/user-notes.pre-kleos-bak"
printf '%s\n' '# leftover retired skill' > "$UN_HOME/.cursor/skills/now.pre-kleos-bak/SKILL.md"
printf '%s\n' '# foreign skill' > "$UN_HOME/.cursor/skills/user-notes.pre-kleos-bak/SKILL.md"
UN_EC=0
HOME="$UN_HOME" bash "$PACK/scripts/uninstall.sh" >/dev/null 2>&1 || UN_EC=$?
if [[ "$UN_EC" -ne 0 ]]; then
  rm -rf "$UN_HOME"
  run_test "regression: uninstall prunes pack skills/*.pre-kleos-bak leftover" "0" "uninstall-exit:$UN_EC"
else
  UN_LEFT="$(if [[ -e "$UN_HOME/.cursor/skills/now.pre-kleos-bak" ]]; then echo yes; else echo no; fi)"
  UN_KEEP="$(if [[ -e "$UN_HOME/.cursor/skills/user-notes.pre-kleos-bak/SKILL.md" ]]; then echo yes; else echo no; fi)"
  rm -rf "$UN_HOME"
  run_test "regression: uninstall prunes pack skills/*.pre-kleos-bak leftover" "no" "$UN_LEFT"
  run_test "regression: uninstall keeps foreign skills/*.pre-kleos-bak" "yes" "$UN_KEEP"
fi

PS_BIN=""
if command -v powershell.exe >/dev/null 2>&1; then PS_BIN="$(command -v powershell.exe)"
elif command -v powershell >/dev/null 2>&1; then PS_BIN="$(command -v powershell)"
fi

winpath() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1"
  fi
}

if [[ -n "$PS_BIN" ]]; then
  SHIM_DIR="$(mktemp -d "${TMPDIR:-/tmp}/kleos-shim.XXXXXX")"
  cp "$SHIM" "$SHIM_DIR/bash-shim.ps1"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 7' > "$SHIM_DIR/before_read_file.sh"
  SHIM_EC=0
  printf '%s' '{"file_path":"x"}' | "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$SHIM_DIR/bash-shim.ps1")" before_read_file.sh >/dev/null 2>&1 || SHIM_EC=$?
  printf '%s\n' '#!/usr/bin/env bash' 'echo "{\"permission\":\"allow\"}"' 'exit 0' > "$SHIM_DIR/before_read_file.sh"
  SHIM_OK=0
  printf '%s' '{"file_path":"x"}' | "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$SHIM_DIR/bash-shim.ps1")" before_read_file.sh >/dev/null 2>&1 || SHIM_OK=$?
  "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -Command \
    "\$p='$(winpath "$SHIM_DIR/bash-shim.ps1")'; \$l=Get-Content -LiteralPath \$p; \$o=New-Object System.Collections.Generic.List[string]; \$skip=\$false; foreach(\$line in \$l){ if(\$line -match '^function Find-GitBash'){ \$o.Add(\$line); \$o.Add('  return ''C:\\kleos-missing-bash.exe'''); \$o.Add('}'); \$skip=\$true; continue }; if(\$skip){ if(\$line -match '^}'){ \$skip=\$false }; continue }; \$o.Add(\$line) }; \$o | Set-Content -LiteralPath \$p"
  SHIM_MISS=0
  printf '%s' '{"file_path":"x"}' | "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -File "$(winpath "$SHIM_DIR/bash-shim.ps1")" before_read_file.sh >/dev/null 2>&1 || SHIM_MISS=$?
  rm -rf "$SHIM_DIR"
  run_test "regression: Windows bash-shim propagates hook exit code" "7" "$SHIM_EC"
  run_test "regression: Windows bash-shim keeps exit 0 on hook success" "0" "$SHIM_OK"
  if [[ "$SHIM_MISS" -eq 0 ]]; then
    run_test "regression: Windows bash-shim non-zero when bash cannot start" "nonzero" "0"
  else
    run_test "regression: Windows bash-shim non-zero when bash cannot start" "nonzero" "nonzero"
  fi

  if [[ -f "$PACK/Windows/lib/skills.ps1" ]]; then
    PS_HOME="$(mktemp -d "${TMPDIR:-/tmp}/kleos-pssk.XXXXXX")"
    mkdir -p "$PS_HOME/skills/now" "$PS_HOME/skills/now.pre-kleos-bak" \
      "$PS_HOME/skills/user-notes.pre-kleos-bak" "$PS_HOME/kleos-bak/skills/now"
    printf '%s\n' '---' 'name: now' '---' '# unsuffixed' > "$PS_HOME/skills/now/SKILL.md"
    printf '%s\n' '# leftover' > "$PS_HOME/skills/now.pre-kleos-bak/SKILL.md"
    printf '%s\n' '# foreign' > "$PS_HOME/skills/user-notes.pre-kleos-bak/SKILL.md"
    printf '%s\n' 'UNIQUE_EXISTING_BAK' > "$PS_HOME/kleos-bak/skills/now/SKILL.md"
    PS_EC=0
    "$PS_BIN" -NoProfile -ExecutionPolicy Bypass -Command \
      "\$ErrorActionPreference='Stop'; . '$(winpath "$PACK/Windows/lib/skills.ps1")'; Remove-KleosRetiredSkills -Pack '$(winpath "$PACK")' -HomeC '$(winpath "$PS_HOME")'" \
      >/dev/null 2>&1 || PS_EC=$?
    if [[ "$PS_EC" -ne 0 ]]; then
      rm -rf "$PS_HOME"
      run_test "regression: Windows leftover *.pre-kleos-bak leaves no catalog SKILL.md" "0" "ps-exit:$PS_EC"
    else
      PS_NOW="$(if [[ -e "$PS_HOME/skills/now/SKILL.md" ]]; then echo yes; else echo no; fi)"
      PS_CAT="$(if [[ -e "$PS_HOME/skills/now.pre-kleos-bak/SKILL.md" ]]; then echo yes; else echo no; fi)"
      PS_FOREIGN="$(if [[ -e "$PS_HOME/skills/user-notes.pre-kleos-bak/SKILL.md" ]]; then echo yes; else echo no; fi)"
      PS_OLD="$(if grep -q 'UNIQUE_EXISTING_BAK' "$PS_HOME/kleos-bak/skills/now/SKILL.md" 2>/dev/null; then echo yes; else echo no; fi)"
      PS_PARK="$(if [[ -e "$PS_HOME/kleos-bak/skills/now.2/SKILL.md" ]]; then echo yes; else echo no; fi)"
      rm -rf "$PS_HOME"
      run_test "regression: Windows unsuffixed retired name is left in skills/" "yes" "$PS_NOW"
      run_test "regression: Windows leftover *.pre-kleos-bak leaves no catalog SKILL.md" "no" "$PS_CAT"
      run_test "regression: Windows cleanup keeps foreign skills/*.pre-kleos-bak" "yes" "$PS_FOREIGN"
      run_test "regression: Windows cleanup does not overwrite existing kleos-bak" "yes" "$PS_OLD"
      run_test "regression: Windows leftover parks beside existing kleos-bak" "yes" "$PS_PARK"
    fi
  fi
else
  echo "[skip] powershell.exe not on PATH (shim/skills behavioral cases)"
fi
