#!/usr/bin/env bash

_scorecard_count_lines() {
  [[ -z "$1" ]] && { echo 0; return; }
  printf '%s\n' "$1" | wc -l
}

_scorecard_once() {
  local key="$1" log="${STATE:-}/scorecarded"
  [[ -z "${STATE:-}" ]] && return 1
  mkdir -p "$STATE"
  grep -qxF "$key" "$log" 2>/dev/null && return 1
  printf '%s\n' "$key" >>"$log"
  return 0
}

scorecard_message() {
  local path="$1" policy="${2:-$HERE/policy/lean.json}"
  local content lines pct comments total max soft legacy cmax msg=""
  [[ -f "$path" ]] || return 0
  is_executable_src "$path" || return 0
  content="$(cat "$path" 2>/dev/null || true)"
  lines="$(_scorecard_count_lines "$content")"
  lines="${lines//[!0-9]}"; [[ -z "$lines" ]] && lines=0
  max="$(jq -r '.file_loc_max // 300' "$policy" 2>/dev/null || echo 300)"
  soft="$(jq -r '.file_loc_soft // 120' "$policy" 2>/dev/null || echo 120)"
  legacy="$(jq -r '.file_loc_legacy_emergency // 700' "$policy" 2>/dev/null || echo 700)"
  cmax="$(jq -r '.comment_ratio_max // 2' "$policy" 2>/dev/null || echo 2)"
  set -- $(comment_ratio_stats "$content")
  pct="${1:-0}"; comments="${2:-0}"; total="${3:-0}"
  if [[ "$lines" -gt "$legacy" ]]; then
    printf 'SCORECARD %s: %s LOC (legacy >%s). REWRITE into modules ≤%s via Write; StrReplace original + callers to imports; prefer deletion. Zero prose comments.\n' \
      "$path" "$lines" "$legacy" "$max"
    return 0
  fi
  if [[ "$lines" -gt "$max" ]]; then
    _scorecard_once "hard:$path" || return 0
    printf 'SCORECARD %s: %s LOC > hard %s. Extract subatomic modules (Write new, StrReplace original imports).\n' \
      "$path" "$lines" "$max"
    return 0
  fi
  if [[ "${total:-0}" -ge 8 && $((total - comments)) -gt 0 && "${pct:-0}" -gt "$cmax" ]]; then
    _scorecard_once "comments:$path" || return 0
    printf 'SCORECARD %s: prose comments ~%s%% > %s%% roof. Strip narrating comments; keep machine directives only.\n' \
      "$path" "$pct" "$cmax"
    return 0
  fi
  if [[ "$lines" -gt "$soft" ]]; then
    _scorecard_once "soft:$path" || return 0
    printf 'SCORECARD %s: %s LOC > soft %s. Prefer extract (one job/file) before growing.\n' \
      "$path" "$lines" "$soft"
    return 0
  fi
}
