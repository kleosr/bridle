#!/usr/bin/env bash
# Feature ledger: workspace paths, evidence tree, and the stop-time sensor.
# Advisory at stop. Never executes feature verification commands — those
# belong to scripts/feature.sh / the agent.

# Workspace root for the ledger: the git toplevel of the cwd, else the cwd.
ledger_root() {
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null || pwd -P)"
  (cd "$top" 2>/dev/null && pwd -P) || printf '%s' "$top"
}

# ledger_paths ROOT: sets LEDGER_FILE, LEDGER_HANDOFF, LEDGER_EXCLUDE.
# This pack keeps its own ledger under shared/config; every other workspace
# gets <root>/.cursor/bridle/. LEDGER_EXCLUDE is the pathspec ledger_tree
# leaves out so recording evidence or a handoff never stales the evidence.
ledger_paths() {
  local root="$1"
  if [[ -f "$root/shared/config/harness.json" && -f "$root/scripts/feature.sh" && -f "$root/shared/hooks/stop.sh" ]]; then
    LEDGER_FILE="$root/shared/config/features.json"
    LEDGER_HANDOFF="$root/state/handoff.json"
    LEDGER_EXCLUDE="shared/config/features.json"
  else
    LEDGER_FILE="$root/.cursor/bridle/features.json"
    LEDGER_HANDOFF="$root/.cursor/bridle/handoff.json"
    LEDGER_EXCLUDE=".cursor/bridle"
  fi
}

# ledger_rel ROOT PATH: PATH relative to ROOT, or empty when outside it.
ledger_rel() {
  case "$2" in
    "$1"/*) printf '%s' "${2#"$1"/}" ;;
    *) printf '' ;;
  esac
}

# ledger_tree ROOT EXCLUDE: content hash of the workspace as a verification
# saw it — index blobs, unstaged diff, untracked file names and contents —
# minus EXCLUDE. Commit ids are deliberately absent: a commit that changes no
# content keeps the same tree. Outside git this hashes empty input, so
# non-git workspaces compare equal to themselves.
ledger_tree() {
  local root="$1" ex="${2:-}" names
  local -a spec=()
  [[ -n "$ex" ]] && spec=(":(exclude)$ex")
  (
    cd "$root" 2>/dev/null || exit 0
    git ls-files -s -- . ${spec[@]+"${spec[@]}"} 2>/dev/null
    git diff -- . ${spec[@]+"${spec[@]}"} 2>/dev/null
    names="$(git ls-files -o --exclude-standard -- . ${spec[@]+"${spec[@]}"} 2>/dev/null)"
    if [[ -n "$names" ]]; then
      printf '%s\n' "$names"
      printf '%s\n' "$names" | git hash-object --stdin-paths 2>/dev/null
    fi
  ) | git hash-object --stdin 2>/dev/null || printf 'none'
}

# ledger_dirty ROOT EXCLUDE: true when the working tree has uncommitted
# changes outside the ledger.
ledger_dirty() {
  local ex="${2:-}"
  local -a spec=()
  [[ -n "$ex" ]] && spec=(":(exclude)$ex")
  [[ -n "$(git -C "$1" status --porcelain -- . ${spec[@]+"${spec[@]}"} 2>/dev/null)" ]]
}

gate_features() {
  local root="$1" tree dirty=0
  ledger_paths "$root"
  [[ -f "$LEDGER_FILE" ]] || return 0
  if ! json_run file-valid "$LEDGER_FILE"; then
    printf 'FEATURE (advisory): feature list is not valid JSON (%s).\nFix the file or restore it before claiming done.\n' "$LEDGER_FILE"
    return 0
  fi
  tree="$(ledger_tree "$root" "$LEDGER_EXCLUDE")"
  ledger_dirty "$root" "$LEDGER_EXCLUDE" && dirty=1
  json_run features-advise "$LEDGER_FILE" "$tree" "$dirty" || true
}
