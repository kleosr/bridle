#!/usr/bin/env bash

DIFF_SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|sh|bash|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs)'
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

diff_changed_files() {
  local root="$1"
  if diff_has_head "$root"; then
    git -C "$root" diff --name-only HEAD -- 2>/dev/null
  else
    git -C "$root" diff --name-only --cached -- 2>/dev/null
  fi
  git -C "$root" ls-files --others --exclude-standard 2>/dev/null
}

diff_additions() {
  local root="$1" f
  if diff_has_head "$root"; then
    git -C "$root" diff HEAD -- 2>/dev/null | grep -E '^\+[^+]' || true
  fi
  while IFS= read -r f; do
    [[ -n "$f" && -f "$root/$f" ]] || continue
    sed 's/^/+/' "$root/$f"
  done < <(git -C "$root" ls-files --others --exclude-standard 2>/dev/null)
}

diff_def_names() {
  sed -nE 's/^\+?(export[[:space:]]+)?(async[[:space:]]+)?(function|def|func|fn)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\4/p; s/^\+?([A-Za-z_][A-Za-z0-9_]*)\(\)[[:space:]]*\{.*/\1/p'
}

diff_changed_content() {
  local root="$1" f
  while IFS= read -r f; do
    [[ -n "$f" && -f "$root/$f" ]] || continue
    cat "$root/$f"
  done < <(diff_changed_files "$root")
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
    out="${out}rewrite: $f changed $changed of $total lines. Touch only the hunk of the defect (ponytail.mdc: reducing edits allowed, growth not).
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
    out="${out}format_churn: $f has $total diff lines but only $real are real (non-whitespace). Reindent is unrequested churn; revert to the hunk only.
"
  done < <(diff_tracked_src "$root")
  printf '%s' "$out"
}

gate_duplicate_helper() {
  local root="$1" name all dups=""
  all="$(diff_changed_content "$root" | diff_def_names | sort)"
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    if [[ "$(printf '%s\n' "$all" | grep -cx "$name")" -ge 2 ]]; then dups="$dups $name"; fi
  done < <(diff_additions "$root" | diff_def_names | sort -u)
  [[ -n "$dups" ]] || return 0
  printf 'duplicate_helper:%s defined more than once across changed files. Keep one definition and import it (ponytail Refactor).\n' "$dups"
}

gate_diff() {
  local root="$1" out
  out="$(gate_rewrite "$root")$(gate_format_churn "$root")$(gate_duplicate_helper "$root")"
  [[ -n "$out" ]] || return 0
  printf 'PONYTAIL STOP (stop.sh, runs once per turn). Fix, then run the repo proof.\n%s' "$out"
}
