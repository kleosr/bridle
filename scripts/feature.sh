#!/usr/bin/env bash
# Pass-state gate for shared/config/features.json (or FEATURE_FILE).
# The agent may start/block features. Only this script sets passing.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"
require_jq
FILE="${FEATURE_FILE:-$PACK/shared/config/features.json}"
ROOT="${FEATURE_ROOT:-$PACK}"
CMD="${1:-}"

usage() {
  echo "usage: bash scripts/feature.sh {list|next|check|start <id>|pass <id>|note <id> <hypothesis>|block <id> <reason>}" >&2
  echo "note: replaces lastFailure.nextExperiment with the agent's diagnosis. Requires a recorded failure." >&2
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

active_limit() {
  jq -r '.activeLimit // 1' "$FILE"
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
  local dup n_active limit invalid
  need_file
  dup="$(jq -r '.features | group_by(.id) | map(select(length > 1)[0].id) | .[]?' "$FILE")"
  [[ -z "$dup" ]] || { echo "duplicate feature id: $dup" >&2; exit 1; }
  jq -e '
    .version == 1
    and (.features | type == "array")
    and ((.activeLimit // 1) | type == "number" and floor == . and . >= 1)
    and ([.features[] | (
      (.id | type == "string" and length > 0)
      and (.priority | type == "number" and floor == . and . >= 1)
      and (.area | type == "string" and length > 0)
      and (.title | type == "string" and length > 0)
      and (.behavior | type == "string" and length > 0)
      and (.verification | type == "string" and length > 0)
      and (.status == "not_started" or .status == "in_progress" or .status == "blocked" or .status == "passing")
      and ((has("evidence") | not) or (.evidence | type == "object"))
      and ((has("lastFailure") | not) or (
        .lastFailure | type == "object"
        and (.command | type == "string" and length > 0)
        and (.exit | type == "number" and floor == .)
        and (.recordedAt | type == "string" and length > 0)
        and (.nextExperiment | type == "string" and length > 0)
      ))
    )] | all)
  ' "$FILE" >/dev/null || { echo "features.json failed schema" >&2; exit 1; }
  n_active="$(active_count)"
  limit="$(active_limit)"
  if [[ "$n_active" -gt "$limit" ]]; then
    echo "too many in_progress features: $n_active (limit $limit)" >&2
    exit 1
  fi
  invalid="$(jq -r '
    .features[] |
    select(.status == "passing") |
    select(
      .evidence.exit != 0
      or (
        ((.evidence.proves // "") == "")
        and ((.evidence.command // "") == "")
      )
    ) | .id
  ' "$FILE")"
  [[ -z "$invalid" ]] || { echo "passing feature lacks valid evidence: $invalid" >&2; exit 1; }
  while IFS= read -r proves; do
    [[ -z "$proves" ]] && continue
    [[ -e "$ROOT/$proves" ]] || { echo "evidence.proves missing: $proves" >&2; exit 1; }
  done < <(jq -r '.features[] | select(.status == "passing") | .evidence.proves // empty' "$FILE")
  echo "features ok"
}

cmd_start() {
  local id="$1" limit
  [[ -n "$id" ]] || usage
  need_file
  has_id "$id" || { echo "unknown feature: $id" >&2; exit 1; }
  limit="$(active_limit)"
  if [[ "$(active_count)" -ge "$limit" ]]; then
    if jq -e --arg id "$id" '.features | any(.id == $id and .status == "in_progress")' "$FILE" >/dev/null; then
      echo "$id already in_progress"
      return 0
    fi
    echo "active feature limit reached ($limit)" >&2
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

# Reflexion as data: the failure signal is machine-written by `pass`; the
# reflection on it is agent-written here. Read on the next attempt, not graded.
cmd_note() {
  local id="$1"
  shift || true
  local text="$*"
  [[ -n "$id" && -n "$text" ]] || usage
  need_file
  has_id "$id" || { echo "unknown feature: $id" >&2; exit 1; }
  jq -e --arg id "$id" '.features | any(.id == $id and .lastFailure != null)' "$FILE" >/dev/null \
    || { echo "$id has no lastFailure; run pass first, note the failure it records" >&2; exit 1; }
  jq --arg id "$id" --arg t "$text" '
    .features |= map(if .id == $id then .lastFailure.nextExperiment = $t else . end)
  ' "$FILE" | write_json
  echo "noted $id"
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
  note)
    [[ -n "${2:-}" ]] || usage
    id="$2"
    shift 2
    cmd_note "$id" "$@"
    ;;
  block)
    [[ -n "${2:-}" ]] || usage
    id="$2"
    shift 2
    cmd_block "$id" "$@"
    ;;
  *) usage ;;
esac
