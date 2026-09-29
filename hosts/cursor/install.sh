#!/usr/bin/env bash
# Cursor: install or uninstall the user layer (~/.cursor), opt-in
# project-hooks for the cloud lane, verify. The pack itself gets no .cursor layer.
# Windows: run from Git Bash, not PowerShell.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_DIR="$PACK/hooks"
CURSOR_DIR="$PACK/hosts/cursor"
HOME_C="${HOME}/.cursor"
FORCE="${FORCE:-${FORCE_SKILLS:-0}}"
TARGET_REPO="${TARGET_REPO:-}"
CMD="${1:-install}"
source "$CURSOR_DIR/lib/fleet_scan.sh"
require_jq
source "$CURSOR_DIR/lib/fleet_install.sh"
source "$CURSOR_DIR/lib/fleet_verify.sh"
source "$CURSOR_DIR/lib/fleet_uninstall.sh"
GLOBAL=()
while IFS= read -r _g; do
  GLOBAL+=("$_g")
done < <(manifest_list '.rules[]')

case "$CMD" in
  install)
    install_home_hooks
    install_global_rules
    install_charter_rule
    install_skills
    install_agents
    ;;
  uninstall)
    uninstall_home
    ;;
  project-hooks)
    if [[ -z "$TARGET_REPO" ]]; then
      echo "[fail] TARGET_REPO required for project-hooks" >&2
      exit 2
    fi
    if [[ "$(canon "$TARGET_REPO")" == "$(canon "$PACK")" ]]; then
      echo "[fail] never install project hooks into the pack" >&2
      exit 2
    fi
    install_project_hooks "$TARGET_REPO" "target"
    echo "[done] project-hooks. Cloud got submit+shell+read and the full .mdc set."
    ;;
  verify)
    verify_smoke
    ;;
  all)
    install_home_hooks
    install_global_rules
    install_charter_rule
    install_skills
    install_agents
    verify_smoke
    echo "[done] install all FORCE=$FORCE (local ~/.cursor only)"
    echo "Charter installed once as ~/.cursor/rules/kleosr.mdc. If Cursor Settings → User Rules still holds a copy of charter.txt, remove it (double injection). Start a new chat."
    ;;
  *)
    echo "usage: [FORCE=1] bash hosts/cursor/install.sh {install|uninstall|project-hooks|verify|all}" >&2
    exit 2
    ;;
esac
