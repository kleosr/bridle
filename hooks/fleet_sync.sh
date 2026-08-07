#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/.." && pwd)"
HOME_C="${HOME}/.cursor"
FORCE="${FORCE:-${FORCE_SKILLS:-0}}"
CMD="${1:-all}"
SHARED=(agent types testing debugging native-lean-autoload ponytail context-curator vernacular)
GLOBAL=(native-lean-autoload ponytail agent context-curator vernacular testing)
HOOK_SCRIPTS=(session_start.sh before_submit_prompt.sh stop_gate.sh lean_gate.sh pre_tool_use.sh fleet_dispatch.sh)

load_lines() {
  local f="$1" line
  [[ -f "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    [[ -z "$line" ]] && continue
    [[ "${line:0:1}" == "$(printf '#')" ]] && continue
    printf '%s\n' "$line"
  done <"$f"
}

is_ignored() {
  local path="$1" base pat
  base="$(basename "$path")"
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    [[ "$base" == "$pat" ]] && return 0
    [[ "$path" == *"/$pat/"* ]] && return 0
    [[ "$path" == */"$pat" ]] && return 0
    [[ "$path" == "$pat"* ]] && return 0
  done < <(load_lines "$PACK/config/scan.ignore")
  return 1
}

is_project() {
  local d="$1"
  [[ -d "$d/.git" || -f "$d/package.json" || -f "$d/pnpm-workspace.yaml" \
    || -f "$d/Cargo.toml" || -f "$d/go.mod" || -f "$d/pyproject.toml" \
    || -f "$d/AGENTS.md" || -d "$d/.cursor/rules" ]]
}

discover() {
  local roots=() root child
  mapfile -t roots < <(load_lines "$PACK/config/scan.roots")
  if [[ ${#roots[@]} -eq 0 ]]; then
    roots=("$(dirname "$PACK")")
  fi
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    if is_project "$root" && ! is_ignored "$root"; then
      realpath "$root"
    fi
    for child in "$root"/*/; do
      [[ -d "$child" ]] || continue
      child="${child%/}"
      is_ignored "$child" && continue
      is_project "$child" || continue
      realpath "$child"
    done
  done | sort -u
}

symlink_force() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
}

copy_hook_scripts() {
  local dest="$1" s p
  mkdir -p "$dest/policy" "$dest/lib"
  for s in "${HOOK_SCRIPTS[@]}"; do
    cp -f "$PACK/hooks/$s" "$dest/$s"
    chmod +x "$dest/$s"
  done
  for s in "$PACK"/hooks/lib/*.sh; do
    [[ -f "$s" ]] || continue
    cp -f "$s" "$dest/lib/$(basename "$s")"
    chmod +x "$dest/lib/$(basename "$s")"
  done
  for p in "$PACK"/hooks/policy/*.json; do
    [[ -f "$p" ]] || continue
    cp -f "$p" "$dest/policy/$(basename "$p")"
  done
}

write_home_hooks_json() {
  jq '.hooks.preToolUse[].command |= sub("^\\./hooks/"; "bash '"${HOME_C}"'/hooks/")
    | .hooks.beforeSubmitPrompt[].command |= sub("^\\./hooks/"; "bash '"${HOME_C}"'/hooks/")
    | .hooks.sessionStart[].command |= sub("^\\./hooks/"; "bash '"${HOME_C}"'/hooks/")
    | .hooks.stop[].command |= sub("^\\./hooks/"; "bash '"${HOME_C}"'/hooks/")' \
    "$PACK/hooks/hooks.json" >"$HOME_C/hooks.json"
}

install_home_hooks() {
  mkdir -p "$HOME_C/hooks/policy" "$HOME_C/state"
  copy_hook_scripts "$HOME_C/hooks"
  for orphan in ask-gated-shell.sh backlog-on-read.sh block-dangerous-git.sh capture-mistake.sh deny-danger.sh install-user-hooks.sh; do
    rm -f "$HOME_C/hooks/$orphan"
  done
  rm -rf "$HOME_C/hooks/bin" "$HOME_C/hooks/__pycache__"
  write_home_hooks_json
  echo "[ok] ~/.cursor/hooks.json + hooks scripts"
}

install_global_rules() {
  local name orphan
  mkdir -p "$HOME_C/rules"
  cp -f "$PACK/rules/option-c-core.mdc" "$HOME_C/rules/option-c-core.mdc"
  for name in "${GLOBAL[@]}"; do
    cp -f "$PACK/rules/${name}.mdc" "$HOME_C/rules/${name}.mdc"
    echo "[ok] ~/.cursor/rules/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    [[ -e "$HOME_C/rules/$orphan" || -L "$HOME_C/rules/$orphan" ]] && rm -f "$HOME_C/rules/$orphan" && echo "[rm] ~/.cursor/rules/$orphan"
  done < <(load_lines "$PACK/config/retired.txt")
}

install_skills() {
  local skill src dst
  mkdir -p "$HOME_C/skills"
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    src="$PACK/skills/$skill"
    [[ -f "$src/SKILL.md" ]] || { echo "[fail] missing $src/SKILL.md"; return 1; }
    dst="$HOME_C/skills/$skill"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      if [[ "$FORCE" == "1" ]]; then
        rm -rf "$dst"
        echo "[force] replaced: $skill"
      else
        echo "[warn] skip non-symlink: $dst (FORCE=1)"
        continue
      fi
    fi
    symlink_force "$src" "$dst"
    echo "[ok] skill $skill"
  done < <(load_lines "$PACK/config/skills.txt")
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    dst="$HOME_C/skills/$skill"
    if [[ -L "$dst" ]]; then
      rm -f "$dst"
      echo "[rm] retired skill $skill"
    fi
  done < <(load_lines "$PACK/config/retired-skills.txt")
  return 0
}

link_pack_rules() {
  local dest="$PACK/.cursor/rules" name orphan
  mkdir -p "$dest"
  for name in "${SHARED[@]}"; do
    [[ -f "$PACK/rules/${name}.mdc" ]] || continue
    symlink_force "../../rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]] && rm -f "$dest/$orphan" && echo "[rm] pack/$orphan"
  done < <(load_lines "$PACK/config/retired.txt")
  echo "[ok] pack .cursor/rules → rules"
}

write_repo_hooks_json() {
  local out="$1"
  jq '.hooks.preToolUse[].command |= sub("^\\./hooks/"; ".cursor/hooks/")
    | .hooks.beforeSubmitPrompt[].command |= sub("^\\./hooks/"; ".cursor/hooks/")
    | .hooks.sessionStart[].command |= sub("^\\./hooks/"; ".cursor/hooks/")
    | .hooks.stop[].command |= sub("^\\./hooks/"; ".cursor/hooks/")' \
    "$PACK/hooks/hooks.json" >"$out"
}

gitignore_state() {
  local repo="$1" gi="$repo/.gitignore"
  [[ -f "$gi" ]] || touch "$gi"
  grep -qxF 'state/' "$gi" || printf '\n# kleosrules runtime state (velocity log, intent snapshots)\nstate/\n' >>"$gi"
}

sync_repo_hooks() {
  local repo="$1" label="$2" dest orphan
  dest="$repo/.cursor/hooks"
  copy_hook_scripts "$dest"
  for orphan in ask-gated-shell.sh block-dangerous-git.sh deny-danger.sh install-user-hooks.sh; do
    rm -f "$dest/$orphan"
  done
  rm -rf "$dest/bin" "$dest/__pycache__"
  write_repo_hooks_json "$repo/.cursor/hooks.json"
  gitignore_state "$repo"
  echo "[ok] hooks → $label"
}

sync_repo_rules() {
  local repo="$1" label="$2" dest name orphan
  dest="$repo/.cursor/rules"
  mkdir -p "$dest"
  for name in "${SHARED[@]}"; do
    [[ -f "$PACK/rules/${name}.mdc" ]] || continue
    rm -f "$dest/${name}.mdc"
    cp -f "$PACK/rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]] && rm -f "$dest/$orphan" && echo "[rm] $label/$orphan"
  done < <(load_lines "$PACK/config/retired.txt")
  echo "[ok] rules → $label"
}

sync_fleet() {
  local pack_c repos repo label
  pack_c="$(realpath "$PACK")"
  mapfile -t repos < <(discover)
  echo "[scan] ${#repos[@]} project(s)"
  link_pack_rules
  sync_repo_hooks "$PACK" "pack"
  for repo in "${repos[@]}"; do
    [[ "$repo" == "$pack_c" ]] && continue
    label="$(basename "$repo")"
    sync_repo_rules "$repo" "$label"
    sync_repo_hooks "$repo" "$label"
  done
}

verify_stop_gate() {
  local st="$PACK/state" snap rc=0
  mkdir -p "$st"
  snap="$(mktemp -d)"
  [[ -d "$st" ]] && cp -a "$st/." "$snap/" 2>/dev/null
  echo "2" >"$st/outcomes.md"
  rm -f "$st/allowed_files.md" "$st/session_ts"
  echo '{"status":"completed","transcript":[{"role":"user","content":"fix the bug and wire the api"},{"role":"assistant","content":"INTENT: fix bug, tag edit:x\nDone-when:\n- compiles\nDone-when: met"}]}' \
    | bash "$PACK/hooks/lib/stop_gate_core.sh" 2>/dev/null \
    | grep -q 'UNDER-SCOPE' || { echo "[fail] stop_gate accepts under-scoped Done-when (2 outcomes, 1 predicate)"; rc=1; }
  rm -rf "$st"
  cp -a "$snap/." "$st/" 2>/dev/null || rm -rf "$st"
  rm -rf "$snap"
  return $rc
}

verify_smoke() {
  local skill bad=0
  chmod +x "$PACK"/hooks/*.sh
  bash -n "$PACK/hooks/session_start.sh"
  bash -n "$PACK/hooks/before_submit_prompt.sh"
  bash -n "$PACK/hooks/stop_gate.sh"
  bash -n "$PACK/hooks/lean_gate.sh"
  bash -n "$PACK/hooks/pre_tool_use.sh"
  bash -n "$PACK/hooks/fleet_dispatch.sh"
  bash -n "$PACK/hooks/fleet_sync.sh"
  echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' \
    | bash "$PACK/hooks/before_submit_prompt.sh" | jq -e '.additionalContext' >/dev/null
  verify_stop_gate || bad=1
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ ! -L "$HOME_C/skills/$skill" ]]; then
      echo "[fail] skill not symlink: $skill"; bad=1
    elif [[ "$(readlink -f "$HOME_C/skills/$skill")" != "$(realpath "$PACK/skills/$skill")" ]]; then
      echo "[fail] skill wrong target: $skill -> $(readlink "$HOME_C/skills/$skill")"; bad=1
    fi
  done < <(load_lines "$PACK/config/skills.txt")
  [[ -f "$HOME_C/hooks.json" ]] || { echo "[fail] missing ~/.cursor/hooks.json"; bad=1; }
  if grep -q 'kleos-gate' "$HOME_C/hooks.json"; then
    echo "[fail] home hooks still kleos-gate"; bad=1
  fi
  [[ "$bad" -eq 0 ]] || return 1
  echo "[ok] verify smoke"
}

case "$CMD" in
  install)
    install_home_hooks
    install_global_rules
    install_skills
    ;;
  sync)
    sync_fleet
    ;;
  verify)
    verify_smoke
    ;;
  all)
    install_home_hooks
    install_global_rules
    install_skills
    sync_fleet
    verify_smoke
    echo "[done] fleet_sync all FORCE=$FORCE"
    echo "Manual: paste $PACK/rules/USER-RULES.paste.txt → Cursor Settings → User Rules"
    ;;
  *)
    echo "usage: FORCE=1 $0 {install|sync|verify|all}" >&2
    exit 2
    ;;
esac
