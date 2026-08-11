#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
HOME_C="${HOME}/.cursor"
FORCE="${FORCE:-${FORCE_SKILLS:-0}}"
CMD="${1:-all}"
SHARED=(agent types testing debugging native-lean-autoload ponytail vernacular)
GLOBAL=(native-lean-autoload ponytail agent vernacular testing)
HOOK_SCRIPTS=(session_start.sh session_end.sh before_submit_prompt.sh stop_gate.sh lean_gate.sh pre_tool_use.sh before_shell.sh subagent_start.sh subagent_stop.sh after_shell.sh before_read_file.sh fleet_dispatch.sh)

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
  done < <(load_lines "$PACK/shared/config/scan.ignore")
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
  while IFS= read -r line; do roots+=("$line"); done < <(load_lines "$PACK/shared/config/scan.roots")
  if [[ ${#roots[@]} -eq 0 ]]; then
    roots=("$(dirname "$PACK")")
  fi
  for root in "${roots[@]}"; do
    [[ -d "$root" ]] || continue
    if is_project "$root" && ! is_ignored "$root"; then
      canon "$root"
    fi
    for child in "$root"/*/; do
      [[ -d "$child" ]] || continue
      child="${child%/}"
      is_ignored "$child" && continue
      is_project "$child" || continue
      canon "$child"
    done
  done | sort -u
}

symlink_force() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  ln -sfn "$src" "$dst"
}

# realpath(1)/readlink -f are not on older macOS; pwd -P resolves symlinks portably.
canon() { (cd "$1" 2>/dev/null && pwd -P) || printf '%s\n' "$1"; }

copy_hook_scripts() {
  local dest="$1" s p
  mkdir -p "$dest/policy" "$dest/lib"
  for s in "${HOOK_SCRIPTS[@]}"; do
    cp -f "$HOOKS_DIR/$s" "$dest/$s"
    chmod +x "$dest/$s"
  done
  for s in "$HOOKS_DIR"/lib/*.sh; do
    [[ -f "$s" ]] || continue
    cp -f "$s" "$dest/lib/$(basename "$s")"
    chmod +x "$dest/lib/$(basename "$s")"
  done
  for p in "$HOOKS_DIR"/policy/*.json; do
    [[ -f "$p" ]] || continue
    cp -f "$p" "$dest/policy/$(basename "$p")"
  done
}

write_home_hooks_json() {
  jq '(.hooks[]?[]?.command) |= sub("^\\./hooks/"; "bash '"${HOME_C}"'/hooks/")' \
    "$HOOKS_DIR/hooks.json" >"$HOME_C/hooks.json"
}

# Single registration layer: global ~/.cursor/hooks.json only.
# A repo-level .cursor/hooks.json fires ALONGSIDE the global one (double injection
# per prompt — measured 2× DEBERES 2026-08-10). Hooks spawn with cwd = workspace
# root, so resolve_root keeps HANDOFF/state per-project under the global layer.
install_home_hooks() {
  mkdir -p "$HOME_C/hooks/policy" "$HOME_C/state"
  copy_hook_scripts "$HOME_C/hooks"
  for orphan in ask-gated-shell.sh backlog-on-read.sh block-dangerous-git.sh capture-mistake.sh deny-danger.sh install-user-hooks.sh; do
    rm -f "$HOME_C/hooks/$orphan"
  done
  rm -rf "$HOME_C/hooks/bin" "$HOME_C/hooks/__pycache__"
  write_home_hooks_json
  echo "[ok] ~/.cursor/hooks.json + hooks scripts (global single layer)"
}

install_global_rules() {
  local name orphan
  mkdir -p "$HOME_C/rules"
  for name in "${GLOBAL[@]}"; do
    cp -f "$PACK/shared/rules/${name}.mdc" "$HOME_C/rules/${name}.mdc"
    echo "[ok] ~/.cursor/rules/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$HOME_C/rules/$orphan" || -L "$HOME_C/rules/$orphan" ]]; then
      rm -f "$HOME_C/rules/$orphan"
      echo "[rm] ~/.cursor/rules/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
}

install_skills() {
  local skill src dst
  mkdir -p "$HOME_C/skills"
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    src="$PACK/shared/skills/$skill"
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
  done < <(load_lines "$PACK/shared/config/skills.txt")
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    dst="$HOME_C/skills/$skill"
    if [[ -L "$dst" ]]; then
      rm -f "$dst"
      echo "[rm] retired skill $skill"
    fi
  done < <(load_lines "$PACK/shared/config/retired-skills.txt")
  return 0
}

link_pack_rules() {
  local dest="$PACK/.cursor/rules" name orphan
  mkdir -p "$dest"
  for name in "${SHARED[@]}"; do
    [[ -f "$PACK/shared/rules/${name}.mdc" ]] || continue
    symlink_force "../../shared/rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]]; then
      rm -f "$dest/$orphan"
      echo "[rm] pack/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
  echo "[ok] pack .cursor/rules → shared/rules"
}

gitignore_state() {
  local repo="$1" gi="$repo/.gitignore"
  [[ -f "$gi" ]] || touch "$gi"
  grep -qxF 'state/' "$gi" || printf '\n# kleosrules runtime state (velocity log, intent snapshots)\nstate/\n' >>"$gi"
}

sync_repo_hooks() {
  local repo="$1" label="$2"
  if [[ -e "$repo/.cursor/hooks.json" || -d "$repo/.cursor/hooks" ]]; then
    rm -f "$repo/.cursor/hooks.json"
    rm -rf "$repo/.cursor/hooks"
    echo "[rm] repo-level hooks → $label (global ~/.cursor layer owns registration)"
  fi
  gitignore_state "$repo"
}

sync_repo_rules() {
  local repo="$1" label="$2" dest name orphan
  dest="$repo/.cursor/rules"
  mkdir -p "$dest"
  for name in "${SHARED[@]}"; do
    [[ -f "$PACK/shared/rules/${name}.mdc" ]] || continue
    rm -f "$dest/${name}.mdc"
    cp -f "$PACK/shared/rules/${name}.mdc" "$dest/${name}.mdc"
  done
  while IFS= read -r orphan; do
    [[ -z "$orphan" ]] && continue
    if [[ -e "$dest/$orphan" || -L "$dest/$orphan" ]]; then
      rm -f "$dest/$orphan"
      echo "[rm] $label/$orphan"
    fi
  done < <(load_lines "$PACK/shared/config/retired.txt")
  echo "[ok] rules → $label"
}

sync_fleet() {
  local pack_c repos=() repo label line
  pack_c="$(canon "$PACK")"
  while IFS= read -r line; do repos+=("$line"); done < <(discover)
  echo "[scan] ${#repos[@]} project(s)"
  link_pack_rules
  sync_repo_hooks "$PACK" "pack"
  for repo in ${repos[@]+"${repos[@]}"}; do
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
    | bash "$HOOKS_DIR/lib/stop_gate_core.sh" 2>/dev/null \
    | grep -q 'UNDER-SCOPE' || { echo "[fail] stop_gate accepts under-scoped Done-when (2 outcomes, 1 predicate)"; rc=1; }
  rm -rf "$st"
  cp -a "$snap/." "$st/" 2>/dev/null || rm -rf "$st"
  rm -rf "$snap"
  return $rc
}

verify_smoke() {
  local skill bad=0
  chmod +x "$HOOKS_DIR"/*.sh
  for s in "${HOOK_SCRIPTS[@]}"; do bash -n "$HOOKS_DIR/$s"; done
  bash -n "$HOOKS_DIR/fleet_sync.sh"
  echo '{"prompt":"test code","hook_event_name":"beforeSubmitPrompt"}' \
    | bash "$HOOKS_DIR/before_submit_prompt.sh" | jq -e '.continue == true' >/dev/null
  echo '{"session_id":"verify","composer_mode":"agent"}' \
    | bash "$HOOKS_DIR/session_start.sh" | jq -e '.additional_context' >/dev/null
  echo '{"tool_name":"Shell","tool_input":{"command":"rm -rf /"}}' \
    | bash "$HOOKS_DIR/pre_tool_use.sh" | jq -e '.permission == "deny"' >/dev/null
  echo '{"command":"rm -rf /"}' \
    | bash "$HOOKS_DIR/before_shell.sh" | jq -e '.permission == "deny"' >/dev/null
  verify_stop_gate || bad=1
  while IFS= read -r skill; do
    [[ -z "$skill" ]] && continue
    if [[ ! -L "$HOME_C/skills/$skill" ]]; then
      echo "[fail] skill not symlink: $skill"; bad=1
    elif [[ "$(canon "$HOME_C/skills/$skill")" != "$(canon "$PACK/shared/skills/$skill")" ]]; then
      echo "[fail] skill wrong target: $skill -> $(readlink "$HOME_C/skills/$skill")"; bad=1
    fi
  done < <(load_lines "$PACK/shared/config/skills.txt")
  if ! grep -q 'hooks/before_submit_prompt.sh' "$HOME_C/hooks.json" 2>/dev/null; then
    echo "[fail] ~/.cursor/hooks.json missing beforeSubmitPrompt (global layer broken)"; bad=1
  fi
  if grep -q 'kleos-gate' "$HOME_C/hooks.json" 2>/dev/null; then
    echo "[fail] home hooks still kleos-gate"; bad=1
  fi
  if [[ -e "$PACK/.cursor/hooks.json" || -d "$PACK/.cursor/hooks" ]]; then
    echo "[fail] pack has repo-level hooks (double injection risk)"; bad=1
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
    echo "Manual: paste $PACK/shared/rules/USER-RULES.paste.txt → Cursor Settings → User Rules"
    ;;
  *)
    echo "usage: FORCE=1 $0 {install|sync|verify|all}" >&2
    exit 2
    ;;
esac
