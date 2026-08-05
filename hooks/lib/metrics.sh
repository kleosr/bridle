#!/usr/bin/env bash
# hooks/lib/metrics.sh — code quality gates (no external deps; pure bash/awk).
# Sourced by lean_gate.sh. Provides complexity_check, coupling_check, nesting_check.
# All thresholds come from lean.json via the caller.

# Strip comment/string lines for heuristic scans (reduces false positives).
# Keeps code lines only: drops full-line comments (#, //, /* */) and docstrings.
_code_lines() {
  printf '%s' "$1" | awk '
    /^[[:space:]]*($|#|\/\/|\/\*|\*)/ { next }
    { print }
  '
}

# Cyclomatic complexity: count decision points in code-only lines.
# Decision points: if for while switch case catch ? && || elif
# Threshold: max_file (per-file CC) and max_func (per-function CC, heuristic).
complexity_check() {
  local content="$1" max_file="$2" max_func="$3"
  local code; code="$(_code_lines "$content")"
  local points; points="$(printf '%s' "$code" | grep -oiE '\b(if|for|while|switch|case|catch|elif)\b|\?\s*[^:]|&&|\|\|' | wc -l || true)"
  points="${points//[!0-9]}"
  [[ -z "$points" ]] && points=0
  # Base complexity 1 + decision points.
  local cc=$(( points + 1 ))
  if [[ "$cc" -gt "$max_file" ]]; then
    emit_deny "COMPLEXITY DENY: file cyclomatic complexity ~${cc} > ${max_file} roof (decision points: ${points}). Extract functions to reduce decision paths."
    return 1
  fi
  # Heuristic per-function: if any single line has 4+ decision keywords, flag.
  local hot; hot="$(printf '%s' "$code" | awk '{ n=gsub(/\<(if|for|while|switch|case|catch|elif)\>/,"&"); if (n>=4) c++ } END{print c+0}')"
  if [[ "${hot:-0}" -gt 0 && "$max_func" -gt 0 ]]; then
    emit_deny "COMPLEXITY DENY: a line packs 4+ branching keywords (exceeds func roof ${max_func}). Split the condition or extract a helper."
    return 1
  fi
  return 0
}

# Coupling: count import/include/require/use statements (god-file detector).
coupling_check() {
  local content="$1" max_imports="$2"
  local imports; imports="$(printf '%s' "$content" | grep -cE '^[[:space:]]*(import|from[[:space:]].*[[:space:]]import|require\(|include!|use[[:space:]].+::|#include)' 2>/dev/null || echo 0)"
  imports="${imports//[!0-9]}"
  [[ -z "$imports" ]] && imports=0
  if [[ "$imports" -gt "$max_imports" ]]; then
    emit_deny "COUPLING DENY: ${imports} import/include statements > ${max_imports} roof. This file knows too much — extract a facade or split concerns."
    return 1
  fi
  return 0
}

# Nesting depth: max brace depth in code-only lines.
nesting_check() {
  local content="$1" max_depth="$2"
  local code; code="$(_code_lines "$content")"
  local found; found="$(printf '%s' "$code" | awk '
    BEGIN { depth=0; max=0 }
    {
      # Count opens and closes per line, ignore string-balance edge cases.
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
