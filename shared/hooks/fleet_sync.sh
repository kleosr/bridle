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
SHARED=(types)
GLOBAL=(ponytail agent vernacular testing mario-engineering-team vibe postgres next vite astro complexity)
source "$HOOKS_DIR/lib/fleet_scan.sh"
source "$HOOKS_DIR/lib/fleet_install.sh"
source "$HOOKS_DIR/lib/fleet_sync_repos.sh"
source "$HOOKS_DIR/lib/fleet_verify.sh"

case "$CMD" in
  install)
    install_home_hooks
    install_global_rules
    install_skills
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
    sync_fleet
    if [[ "$PROJECT_HOOKS" == "1" && -n "$TARGET_REPO" ]] \
      && [[ "$(canon "$TARGET_REPO")" != "$(canon "$PACK")" ]]; then
      install_project_hooks "$TARGET_REPO" "target"
    fi
    verify_smoke
    echo "[done] fleet_sync all FORCE=$FORCE PROJECT_HOOKS=$PROJECT_HOOKS"
    echo "Manual: paste $PACK/shared/rules/USER-RULES.paste.txt → Cursor Settings → User Rules"
    ;;
  *)
    echo "usage: FORCE=1 [CLOUD=1|PROJECT_HOOKS=1] [TARGET_REPO=path] $0 {install|sync|project-hooks|verify|all}" >&2
    exit 2
    ;;
esac
