#!/usr/bin/env bash

_code_lines() {
  printf '%s' "$1" | awk '
    /^[[:space:]]*($|#|\/\/|\/\*|\*)/ { next }
    { print }
  '
}

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
  old="$(printf '%s' "$input" | jq -r '.tool_input.old_string // ""' 2>/dev/null || true)"
  new="$(printf '%s' "$input" | jq -r '.tool_input.new_string // ""' 2>/dev/null || true)"
  content="$(_apply_one_edit "$content" "$old" "$new")"
  printf '%s' "$content"
}

complexity_check() {
  local content="$1" max_file="$2" max_func="$3"
  local code; code="$(_code_lines "$content")"
  local points kw ops
  kw="$(printf '%s' "$code" | grep -oiE "$(wb_alt 'if|for|while|switch|case|catch|elif')" | wc -l || true)"
  ops="$(printf '%s' "$code" | grep -oE '\?[[:space:]]+[^:[:space:]]|&&|\|\|' | wc -l || true)"
  kw="${kw//[!0-9]}"; [[ -z "$kw" ]] && kw=0
  ops="${ops//[!0-9]}"; [[ -z "$ops" ]] && ops=0
  points=$((kw + ops))
  points="${points//[!0-9]}"
  [[ -z "$points" ]] && points=0
  local cc=$(( points + 1 ))
  if [[ "$cc" -gt "$max_file" ]]; then
    emit_deny "COMPLEXITY DENY: file cyclomatic complexity ~${cc} > ${max_file} roof (decision points: ${points}). Extract into subatomic helpers to cut decision paths."
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
    emit_deny "COUPLING DENY: ${imports} import/include statements > ${max_imports} roof. Extract a facade or split into subatomic modules."
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

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/metrics_comments.sh"
