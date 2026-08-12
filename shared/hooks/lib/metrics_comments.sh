#!/usr/bin/env bash

comment_ratio_stats() {
  printf '%s' "$1" | awk '
    function is_machine(l, t) {
      t = tolower(l)
      if (t ~ /^[[:space:]]*#!/) return 1
      if (t ~ /^[[:space:]]*\/\/[[:space:]]*(#?region|#?endregion)/) return 1
      if (t ~ /^[[:space:]]*\/\*[[:space:]]*(eslint|prettier|webpack|vite|@license|license|copyright|spdx)/) return 1
      if (t ~ /^[[:space:]]*#[[:space:]]*(pragma|region|endregion|ifndef|define|endif|elif|else|include)/) return 1
      if (t ~ /^[[:space:]]*\/\/[[:space:]]*@?ts-(expect-error|ignore|nocheck|check)/) return 1
      if (t ~ /^[[:space:]]*\/\/[[:space:]]*(eslint|prettier|istanbul)/) return 1
      if (t ~ /^[[:space:]]*\/\/!/) return 1
      if (t ~ /^[[:space:]]*\/\/\/[[:space:]]*<reference/) return 1
      if (t ~ /^[[:space:]]*#[[:space:]]*!/) return 1
      if (t ~ /^[[:space:]]*\/\*[*!]?[[:space:]]*(eslint|prettier|license|copyright|spdx|@license)/) return 1
      return 0
    }
    BEGIN { total=0; comments=0; in_block=0 }
    {
      if ($0 !~ /[[:alnum:]]/) next
      total++
      if (is_machine($0)) next
      if (in_block) {
        comments++
        if ($0 ~ /\*\//) in_block=0
        next
      }
      if ($0 ~ /^[[:space:]]*\/\*/) {
        comments++
        if ($0 !~ /\*\//) in_block=1
        next
      }
      if ($0 ~ /^[[:space:]]*(\*|\/\/|#|--|<!--)/) comments++
    }
    END {
      if (total <= 0) { print "0 0 0"; exit }
      pct = int((comments * 100) / total)
      printf "%d %d %d\n", pct, comments, total
    }
  '
}

comment_ratio_check() {
  local content="$1" max_pct="$2"
  [[ "$max_pct" -le 0 ]] && return 0
  local pct comment_lines total
  set -- $(comment_ratio_stats "$content")
  pct="${1:-0}"; comment_lines="${2:-0}"; total="${3:-0}"
  if [[ "$total" -lt 8 || $((total - comment_lines)) -le 0 ]]; then
    return 0
  fi
  if [[ "$pct" -gt "$max_pct" ]]; then
    emit_deny "COMMENT DENY: prose-comment ratio ~${pct}% > ${max_pct}% roof (${comment_lines} comment lines / ${total} meaningful). Zero-comment doctrine — self-documenting names only; machine directives (shebang/pragma/license/build-guard/ts-expect-error) ok."
    return 1
  fi
  return 0
}
