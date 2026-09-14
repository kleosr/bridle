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
  local root="$1" file
  file="$(feature_file "$root")" || return 0
  if ! json_run file-valid "$file"; then
    printf 'FEATURE (advisory): feature list is not valid JSON (%s).\nFix the file or restore it before claiming done.\n' "$file"
    return 0
  fi
  json_run features-advise "$file" || true
}
