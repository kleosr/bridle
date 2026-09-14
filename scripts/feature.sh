#!/usr/bin/env bash
# Pass-state gate for shared/config/features.json (or FEATURE_FILE).
# The agent may start/block features. Only this script sets passing.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
FILE="${FEATURE_FILE:-$PACK/shared/config/features.json}"
ROOT="${FEATURE_ROOT:-$PACK}"
CMD="${1:-}"

usage() {
  echo "usage: bash scripts/feature.sh {list|next|check|start <id>|pass <id>|block <id> <reason>}" >&2
  exit 2
}

need_file() {
  [[ -f "$FILE" ]] || { echo "feature file missing: $FILE" >&2; exit 1; }
  jq empty "$FILE" >/dev/null 2>&1 || { echo "feature file is not JSON: $FILE" >&2; exit 1; }
}

write_json() {
  local tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/kleos-feat.XXXXXX")"
  if ! cat >"$tmp"; then
    rm -f "$tmp"
    return 1
  fi
  jq empty "$tmp" >/dev/null 2>&1 || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$FILE"
}

active_count() {
  jq '[.features[]? | select(.status == "in_progress")] | length' "$FILE"
}

has_id() {
  jq -e --arg id "$1" '.features | any(.id == $id)' "$FILE" >/dev/null
}

cmd_list() {
  need_file
  jq -r '.features[] | [.id, .status, .title] | @tsv' "$FILE"
}

cmd_next() {
  need_file
  jq -r '[.features[] | select(.status == "not_started")] | sort_by(.priority) | .[0].id // empty' "$FILE"
}

cmd_check() {
  local dup n_active missing root_ok
  need_file
  dup="$(jq -r '.features | group_by(.id) | map(select(length > 1)[0].id) | .[]?' "$FILE")"
  [[ -z "$dup" ]] || { echo "duplicate feature id: $dup" >&2; exit 1; }
  jq -e '.version == 1 and (.features | type == "array")' "$FILE" >/dev/null \
    || { echo "features.json must have version 1 and a features array" >&2; exit 1; }
  missing="$(jq -r '.features[] | select((.id // "") == "" or (.behavior // "") == "" or (.verification // "") == "" or (.status // "") == "") | .id // "unknown"' "$FILE")"
  [[ -z "$missing" ]] || { echo "feature missing required fields: $missing" >&2; exit 1; }
  n_active="$(active_count)"
  if [[ "$n_active" -gt 1 ]]; then
    echo "too many in_progress features: $n_active (limit 1)" >&2
    exit 1
  fi
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    echo "passing without evidence: $id" >&2
    root_ok=1
  done < <(jq -r '
    .features[] |
    select(.status == "passing") |
    select(
      .evidence == null
      or (
        ((.evidence.proves // "") == "")
        and ((.evidence.command // "") == "")
      )
    ) | .id
  ' "$FILE")
  [[ -z "${root_ok:-}" ]] || exit 1
  while IFS= read -r proves; do
    [[ -z "$proves" ]] && continue
    [[ -e "$ROOT/$proves" ]] || { echo "evidence.proves missing: $proves" >&2; exit 1; }
  done < <(jq -r '.features[] | select(.status == "passing") | .evidence.proves // empty' "$FILE")
  missing="$(jq -r '.features[] | select(.lastFailure != null) | select((.lastFailure.command // "") == "" or ((.lastFailure.exit | type) != "number") or ((.lastFailure.recordedAt // "") == "") or ((.lastFailure.nextExperiment // "") == "")) | .id // "unknown"' "$FILE")"
  [[ -z "$missing" ]] || { echo "feature lastFailure missing command/exit/recordedAt/nextExperiment: $missing" >&2; exit 1; }
  echo "features ok"
}

cmd_start() {
  local id="$1"
  [[ -n "$id" ]] || usage
  need_file
  has_id "$id" || { echo "unknown feature: $id" >&2; exit 1; }
  if [[ "$(active_count)" -ge 1 ]]; then
    if jq -e --arg id "$id" '.features | any(.id == $id and .status == "in_progress")' "$FILE" >/dev/null; then
      echo "$id already in_progress"
      return 0
    fi
    echo "another feature is in_progress (limit 1)" >&2
    exit 1
  fi
  jq --arg id "$id" '.features |= map(if .id == $id then .status = "in_progress" else . end)' "$FILE" | write_json
  echo "started $id"
}

cmd_pass() {
  local id="$1" verify ec now
  [[ -n "$id" ]] || usage
  need_file
  has_id "$id" || { echo "unknown feature: $id" >&2; exit 1; }
  verify="$(jq -r --arg id "$id" '.features[] | select(.id == $id) | .verification' "$FILE")"
  [[ -n "$verify" ]] || { echo "feature $id has empty verification" >&2; exit 1; }
  set +e
  ( cd "$ROOT" && bash -c "$verify" )
  ec=$?
  set -e
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "$ec" -ne 0 ]]; then
    jq --arg id "$id" --arg cmd "$verify" --argjson exit "$ec" --arg at "$now" --arg next "re-run: $verify" '
      .features |= map(
        if .id == $id then
          .lastFailure = {command: $cmd, exit: $exit, recordedAt: $at, nextExperiment: $next}
        else . end
      )
    ' "$FILE" | write_json
    echo "verification failed for $id (exit $ec): $verify" >&2
    echo "fix: $verify ; then bash scripts/feature.sh pass $id" >&2
    exit "$ec"
  fi
  jq --arg id "$id" --arg cmd "$verify" --argjson exit "$ec" --arg at "$now" '
    .features |= map(
      if .id == $id then
        del(.lastFailure) |
        .status = "passing" |
        .evidence = ((.evidence // {}) + {command: $cmd, exit: $exit, recordedAt: $at})
      else . end
    )
  ' "$FILE" | write_json
  echo "passed $id"
}

cmd_block() {
  local id="$1"
  shift || true
  local reason="${*:-blocked}"
  [[ -n "$id" ]] || usage
  need_file
  has_id "$id" || { echo "unknown feature: $id" >&2; exit 1; }
  jq --arg id "$id" --arg r "$reason" '
    .features |= map(if .id == $id then .status = "blocked" | .blockedReason = $r else . end)
  ' "$FILE" | write_json
  echo "blocked $id"
}

case "$CMD" in
  list) cmd_list ;;
  next) cmd_next ;;
  check) cmd_check ;;
  start) cmd_start "${2:-}" ;;
  pass) cmd_pass "${2:-}" ;;
  block)
    [[ -n "${2:-}" ]] || usage
    id="$2"
    shift 2
    cmd_block "$id" "$@"
    ;;
  *) usage ;;
esac
