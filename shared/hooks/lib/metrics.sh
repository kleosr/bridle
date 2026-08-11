#!/usr/bin/env bash

_code_lines() {
  printf '%s' "$1" | awk '
    /^[[:space:]]*($|#|\/\/|\/\*|\*)/ { next }
    { print }
  '
}

complexity_check() {
  local content="$1" max_file="$2" max_func="$3"
  local code; code="$(_code_lines "$content")"
  local points; points="$(printf '%s' "$code" | grep -oiE '\b(if|for|while|switch|case|catch|elif)\b|\?[[:space:]]+[^:[:space:]]|&&|\|\|' | wc -l || true)"
  points="${points//[!0-9]}"
  [[ -z "$points" ]] && points=0
  local cc=$(( points + 1 ))
  if [[ "$cc" -gt "$max_file" ]]; then
    emit_deny "COMPLEXITY DENY: file cyclomatic complexity ~${cc} > ${max_file} roof (decision points: ${points}). Extract functions to reduce decision paths."
    return 1
  fi
  local hot; hot="$(printf '%s' "$code" | awk '{
    n = split($0, tok, /[^A-Za-z0-9_]+/)
    hits = 0
    for (i = 1; i <= n; i++) if (tok[i] ~ /^(if|for|while|switch|case|catch|elif)$/) hits++
    if (hits >= 4) c++
  } END { print c + 0 }')"
  if [[ "${hot:-0}" -gt 0 && "$max_func" -gt 0 ]]; then
    emit_deny "COMPLEXITY DENY: a line packs 4+ branching keywords. Split the condition or extract a helper."
    return 1
  fi
  return 0
}

coupling_check() {
  local content="$1" max_imports="$2"
  local imports
  imports="$(printf '%s' "$content" | grep -vE '^[[:space:]]*($|//|/\*|\*)' \
    | grep -cE '^[[:space:]]*(import|from[[:space:]].*[[:space:]]import|require\(|include!|use[[:space:]].+::|#include)' 2>/dev/null || echo 0)"
  imports="${imports//[!0-9]}"
  [[ -z "$imports" ]] && imports=0
  if [[ "$imports" -gt "$max_imports" ]]; then
    emit_deny "COUPLING DENY: ${imports} import/include statements > ${max_imports} roof. This file knows too much — extract a facade or split concerns."
    return 1
  fi
  return 0
}

nesting_check() {
  local content="$1" max_depth="$2"
  local code; code="$(_code_lines "$content")"
  local found; found="$(printf '%s' "$code" | awk '
    BEGIN { depth=0; max=0 }
    {
      o = gsub(/{/, "{"); c = gsub(/}/, "}")
      depth += o - c
      if (depth < 0) depth = 0
      if (depth > max) max = depth
    }
    END { print max }
  ')"
  found="${found:-0}"
  if [[ "$found" -gt "$max_depth" ]]; then
    emit_deny "NESTING DENY: max brace depth ${found} > ${max_depth} roof. Extract nested blocks into functions."
    return 1
  fi
  return 0
}

comment_ratio_check() {
  local content="$1" max_pct="$2"
  [[ "$max_pct" -le 0 ]] && return 0
  local total comment_lines code_lines pct
  total="$(printf '%s\n' "$content" | grep -cE '[[:alnum:]]' || true)"
  total="${total//[!0-9]}"; [[ -z "$total" ]] && total=0
  [[ "$total" -lt 8 ]] && return 0
  comment_lines="$(printf '%s\n' "$content" | grep -cE '^[[:space:]]*(//|/\*|\*|#|<!--|--)' || true)"
  comment_lines="${comment_lines//[!0-9]}"; [[ -z "$comment_lines" ]] && comment_lines=0
  code_lines=$(( total - comment_lines ))
  [[ "$code_lines" -le 0 ]] && return 0
  pct=$(( (comment_lines * 100) / total ))
  if [[ "$pct" -gt "$max_pct" ]]; then
    emit_deny "COMMENT DENY: prose-comment ratio ~${pct}% > ${max_pct}% roof (${comment_lines} comment lines / ${total} meaningful). Code must be self-documenting — drop narration; keep only machine directives (shebangs, pragmas, license headers, build guards)."
    return 1
  fi
  return 0
}
