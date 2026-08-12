#!/usr/bin/env bash

comment_ratio_check() {
  local content="$1" max_pct="$2"
  [[ "$max_pct" -le 0 ]] && return 0
  local result status pct comment_lines total
  result="$(printf '%s' "$content" | awk -v max_pct="$max_pct" '
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
      if (total < 8 || (total - comments) <= 0) { print "allow"; exit }
      pct = int((comments * 100) / total)
      if (pct > max_pct) printf "deny %d %d %d\n", pct, comments, total
      else print "allow"
    }
  ')"
  set -- $result
  status="${1:-}"
  [[ "$status" == "allow" ]] && return 0
  pct="${2:-0}"; comment_lines="${3:-0}"; total="${4:-0}"
  emit_deny "COMMENT DENY: prose-comment ratio ~${pct}% > ${max_pct}% roof (${comment_lines} comment lines / ${total} meaningful). Zero-comment doctrine — self-documenting names only; machine directives (shebang/pragma/license/build-guard/ts-expect-error) ok."
  return 1
}
