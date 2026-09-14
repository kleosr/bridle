#!/usr/bin/env bash
# Stop-time feature-list sensor. Advisory only. Never executes feature
# verification commands — those belong to scripts/feature.sh / the agent.

feature_file() {
  local root="$1"
  if [[ -f "$root/shared/config/features.json" ]]; then
    printf '%s' "$root/shared/config/features.json"
    return 0
  fi
  if [[ -f "$root/feature_list.json" ]]; then
    printf '%s' "$root/feature_list.json"
    return 0
  fi
  return 1
}

gate_features() {
  local root="$1" file ids n_active
  file="$(feature_file "$root")" || return 0
  jq empty "$file" >/dev/null 2>&1 || {
    printf 'FEATURE (advisory): feature list is not valid JSON (%s).\nFix the file or restore it before claiming done.\n' "$file"
    return 0
  }
  n_active="$(jq '[.features[]? | select((.status // .state) == "in_progress" or (.status // .state) == "active")] | length' "$file" 2>/dev/null || echo 0)"
  if [[ "$n_active" =~ ^[0-9]+$ ]] && [[ "$n_active" -gt 1 ]]; then
    printf 'FEATURE (advisory): %s features are in_progress (limit 1). Finish or block extras before claiming done.\n' "$n_active"
  fi
  ids="$(jq -r '
    .features[]? |
    select((.status // .state) == "passing" or (.status // .state) == "pass") |
    select(
      .evidence == null
      or .evidence == ""
      or (
        (.evidence | type) == "object"
        and ((.evidence.proves // "") == "")
        and ((.evidence.command // "") == "")
      )
    ) | .id // "unknown"
  ' "$file" 2>/dev/null || true)"
  if [[ -n "$ids" ]]; then
    printf 'FEATURE (advisory): passing without evidence: %s.\nRun `bash scripts/feature.sh pass <id>` (or the listed verification) before claiming done. Editing JSON to passing is not done.\n' "$(printf '%s' "$ids" | tr '\n' ' ')"
  fi
}
