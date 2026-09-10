#!/usr/bin/env bash
# Fleet sync: install user layer (~/.cursor), opt-in project-hooks for the
# cloud lane, verify, dry-run. The pack checkout itself gets no .cursor layer.
set -euo pipefail
PACK="$(cd "$(dirname "$0")/../.." && pwd)"
HOOKS_DIR="$PACK/shared/hooks"
HOME_C="${HOME}/.cursor"
FORCE="${FORCE:-${FORCE_SKILLS:-0}}"
CLOUD="${CLOUD:-0}"
PROJECT_HOOKS="${PROJECT_HOOKS:-$CLOUD}"
TARGET_REPO="${TARGET_REPO:-}"
CMD="${1:-all}"
source "$HOOKS_DIR/lib/fleet_scan.sh"
GLOBAL=()
while IFS= read -r _g; do
  GLOBAL+=("$_g")
done < <(load_lines "$PACK/shared/config/rules.global.txt")
source "$HOOKS_DIR/lib/fleet_install.sh"
source "$HOOKS_DIR/lib/fleet_verify.sh"

dry_run() {
  echo "[dry-run] HOME_C=$HOME_C FORCE=$FORCE (no files written)"
  echo "[dry-run] merge hooks.json; copy four hook scripts + runtime libs + policy"
  echo "[dry-run] global rules: ${GLOBAL[*]}"
  echo "[dry-run] skills from shared/config/skills.txt; agents hunter cut prove"
}

case "$CMD" in
  install)
    if [[ "${DRY_RUN:-0}" == "1" ]]; then dry_run; exit 0; fi
    install_home_hooks
    install_global_rules
    install_skills
    install_agents
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
    echo "[done] project-hooks. Cloud got submit+shell+read and the full .mdc set."
    ;;
  verify)
    verify_smoke
    ;;
  all)
    if [[ "${DRY_RUN:-0}" == "1" ]]; then dry_run; exit 0; fi
    install_home_hooks
    install_global_rules
    install_skills
    install_agents
    verify_smoke
    echo "[done] fleet_sync all FORCE=$FORCE (local ~/.cursor only)"
    echo "Manual: paste $PACK/shared/rules/USER-RULES.paste.txt → Cursor Settings → User Rules"
    ;;
  *)
    echo "usage: FORCE=1 $0 {install|project-hooks|verify|all}" >&2
    exit 2
    ;;
esac
