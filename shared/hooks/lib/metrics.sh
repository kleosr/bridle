#!/usr/bin/env bash

_code_lines() {
  printf '%s' "$1" | awk '
    /^[[:space:]]*($|#|\/\/|\/\*|\*)/ { next }
    { print }
  '
}

# Apply a single old→new replacement (first match) for projected-file scoring.
_apply_one_edit() {
  local src="$1" old="$2" new="$3"
  jq -n --arg src "$src" --arg old "$old" --arg new "$new" '
    if ($old | length) == 0 then $src
    else ($src | index($old)) as $i
      | if $i == null then $src
        else $src[0:$i] + $new + $src[$i+($old|length):]
        end
    end
  ' -r 2>/dev/null || printf '%s' "$src"
}

# Project whole-file content after Write/Edit/MultiEdit/StrReplace.
project_edit_content() {
  local tool="$1" path="$2" input="$3"
  local content="" old new
  case "$tool" in
    Write)
      printf '%s' "$input" | jq -r '(.tool_input.content // empty) | if type=="array" then map((.text // .content // "")) | join("\n") else . end' 2>/dev/null || true
      return 0
      ;;
  esac
  if [[ -f "$path" ]]; then
    content="$(cat "$path" 2>/dev/null || true)"
  else
    content=""
  fi
  if [[ "$tool" == "MultiEdit" ]]; then
    local n i
    n="$(printf '%s' "$input" | jq -r '(.tool_input.edits // []) | length' 2>/dev/null || echo 0)"
    n="${n//[!0-9]}"; [[ -z "$n" ]] && n=0
    i=0
    while [[ "$i" -lt "$n" ]]; do
      old="$(printf '%s' "$input" | jq -r --argjson i "$i" '.tool_input.edits[$i].old_string // ""' 2>/dev/null || true)"
      new="$(printf '%s' "$input" | jq -r --argjson i "$i" '.tool_input.edits[$i].new_string // ""' 2>/dev/null || true)"
      content="$(_apply_one_edit "$content" "$old" "$new")"
      i=$((i + 1))
    done
  else
    old="$(printf '%s' "$input" | jq -r '.tool_input.old_string // ""' 2>/dev/null || true)"
    new="$(printf '%s' "$input" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)"
    content="$(_apply_one_edit "$content" "$old" "$new")"
  fi
  printf '%s' "$content"
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

# Machine-directive allowlist (not counted as prose comments).
_is_machine_directive() {
  printf '%s' "$1" | grep -qiE \
    '^[[:space:]]*(#!|//[[:space:]]*#?(region|endregion)|/\*[[:space:]]*(eslint|prettier|webpack|vite|@license|license|copyright|spdx)|#[[:space:]]*(pragma|region|endregion|ifndef|define|endif|elif|else|include)|//[[:space:]]*@?ts-(expect-error|ignore|nocheck|check)|//[[:space:]]*eslint|//[[:space:]]*prettier|//[[:space:]]*istanbul|//!|///[[:space:]]*<reference|#[[:space:]]*!)' \
    && return 0
  printf '%s' "$1" | grep -qiE '^[[:space:]]*/\*[*!]?[[:space:]]*(eslint|prettier|license|copyright|spdx|@license)' && return 0
  return 1
}

comment_ratio_check() {
  local content="$1" max_pct="$2"
  [[ "$max_pct" -le 0 ]] && return 0
  local total=0 comment_lines=0 code_lines pct in_block=0
  # Count line/block/JSDoc prose; skip allowlisted machine directives.
  while IFS= read -r line || [[ -n "$line" ]]; do
    printf '%s' "$line" | grep -qE '[[:alnum:]]' || continue
    total=$((total + 1))
    if _is_machine_directive "$line"; then
      continue
    fi
    if [[ "$in_block" -eq 1 ]]; then
      comment_lines=$((comment_lines + 1))
      printf '%s' "$line" | grep -q '\*/' && in_block=0
      continue
    fi
    if printf '%s' "$line" | grep -qE '^[[:space:]]*/\*'; then
      comment_lines=$((comment_lines + 1))
      printf '%s' "$line" | grep -q '\*/' || in_block=1
      continue
    fi
    if printf '%s' "$line" | grep -qE '^[[:space:]]*(\*|//|#|--|<!--)'; then
      comment_lines=$((comment_lines + 1))
    fi
  done <<EOF
$content
EOF
  [[ "$total" -lt 8 ]] && return 0
  code_lines=$(( total - comment_lines ))
  [[ "$code_lines" -le 0 ]] && return 0
  pct=$(( (comment_lines * 100) / total ))
  if [[ "$pct" -gt "$max_pct" ]]; then
    emit_deny "COMMENT DENY: prose-comment ratio ~${pct}% > ${max_pct}% roof (${comment_lines} comment lines / ${total} meaningful). Zero-comment doctrine — self-documenting names only; machine directives (shebang/pragma/license/build-guard/ts-expect-error) ok."
    return 1
  fi
  return 0
}
