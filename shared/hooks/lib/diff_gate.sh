#!/usr/bin/env bash

DIFF_SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|zsh|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
DIFF_REWRITE_MIN=80
DIFF_REWRITE_RATIO=50
DIFF_FORMAT_MIN=20
DIFF_FORMAT_RATIO=33

diff_has_head() { git -C "$1" rev-parse --verify -q HEAD >/dev/null 2>&1; }

diff_numstat() {
  local root="$1" f="$2" w="${3:-}"
  git -C "$root" diff ${w:+-w} --numstat HEAD -- "$f" 2>/dev/null | awk '{print $1, $2; exit}'
}

diff_tracked_src() {
  local root="$1" f
  diff_has_head "$root" || return 0
  git -C "$root" diff --name-only HEAD -- 2>/dev/null | while IFS= read -r f; do
    printf '%s' "$f" | grep -qE "\.${DIFF_SRC_EXT}$" && printf '%s\n' "$f"
  done
}

gate_rewrite() {
  local root="$1" f out="" stat a d changed total
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    stat="$(diff_numstat "$root" "$f")"
    [[ -n "$stat" ]] || continue
    a="${stat%% *}"; [[ "$a" =~ ^[0-9]+$ ]] || continue
    d="${stat##* }"; [[ "$d" =~ ^[0-9]+$ ]] || continue
    changed=$((a + d))
    total="$(git -C "$root" show HEAD:"$f" 2>/dev/null | wc -l | tr -d ' ')"
    [[ -n "$total" && "$total" -ge "$DIFF_REWRITE_MIN" ]] || continue
    [[ "$changed" -ge $((total * DIFF_REWRITE_RATIO / 100)) ]] || continue
    out="${out}churn: $f diff $changed lines vs $total baseline (added+deleted). Baseline is HEAD; may include pre-existing changes. Narrow your hunks; never revert others.
"
  done < <(diff_tracked_src "$root")
  printf '%s' "$out"
}

gate_format_churn() {
  local root="$1" f out="" stat sw a d aw dw total real
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    stat="$(diff_numstat "$root" "$f")"
    [[ -n "$stat" ]] || continue
    sw="$(diff_numstat "$root" "$f" -w)"
    a="${stat%% *}"; [[ "$a" =~ ^[0-9]+$ ]] || continue
    d="${stat##* }"; [[ "$d" =~ ^[0-9]+$ ]] || continue
    aw="${sw%% *}"; dw="${sw##* }"; aw="${aw:-0}"; dw="${dw:-0}"
    total=$((a + d)); real=$((aw + dw))
    [[ "$total" -ge "$DIFF_FORMAT_MIN" && "$real" -le $((total * DIFF_FORMAT_RATIO / 100)) ]] || continue
    out="${out}format_churn: $f has $total diff lines but only $real non-whitespace. Advisory only; if the reindent is yours narrow it, else leave others.
"
  done < <(diff_tracked_src "$root")
  printf '%s' "$out"
}

gate_diff() {
  local root="$1" out
  out="$(gate_rewrite "$root")$(gate_format_churn "$root")"
  [[ -n "$out" ]] || return 0
  printf 'PONYTAIL STOP (advisory, once per turn). Fix your hunks, then run the repo proof.\n%s' "$out"
}
