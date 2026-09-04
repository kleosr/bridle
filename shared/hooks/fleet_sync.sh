#!/usr/bin/env bash
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
HOME_C="${HOME}/.cursor"
FORCE="${FORCE:-${FORCE_SKILLS:-0}}"
CLOUD="${CLOUD:-0}"
PROJECT_HOOKS="${PROJECT_HOOKS:-$CLOUD}"
TARGET_REPO="${TARGET_REPO:-}"
CMD="${1:-all}"
SHARED=()
GLOBAL=(ponytail agent testing vibe postgres next vite astro complexity pnpm types)
source "$HOOKS_DIR/lib/fleet_scan.sh"
source "$HOOKS_DIR/lib/fleet_install.sh"
source "$HOOKS_DIR/lib/fleet_sync_repos.sh"
source "$HOOKS_DIR/lib/fleet_verify.sh"

case "$CMD" in
  install)
    install_home_hooks
    install_global_rules
    install_skills
    install_agents
    link_pack_rules
    ;;
  sync)
    sync_fleet
    ;;
  project-hooks)
    PROJECT_HOOKS=1
    if [[ -z "$TARGET_REPO" ]]; then
      echo "[fail] TARGET_REPO required for project-hooks" >&2
      exit 2
    fi
    if [[ "$(canon "$TARGET_REPO")" == "$(canon "$PACK")" ]]; then
      echo "[fail] never install project hooks into the pack" >&2
      exit 2
    fi
    install_project_hooks "$TARGET_REPO" "target"
    echo "[done] project-hooks (Lane-A; no sessionStart). Cloud got full .mdc set."
    ;;
  verify)
    verify_smoke
    ;;
  all)
    install_home_hooks
    install_global_rules
    install_skills
    install_agents
    link_pack_rules
    verify_smoke
    echo "[done] fleet_sync all FORCE=$FORCE (local ~/.cursor only; no fleet scan)"
    echo "Manual: paste $PACK/shared/rules/USER-RULES.paste.txt → Cursor Settings → User Rules"
    ;;
  *)
    echo "usage: FORCE=1 $0 {install|sync|project-hooks|verify|all}" >&2
    exit 2
    ;;
esac
