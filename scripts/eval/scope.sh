#!/usr/bin/env bash
# Scope evals: did the agent make the change the ask needs, and only that?
#   scope.sh check [id]          scorer self-test on golden overlays; spends no tokens
#   scope.sh run <id>            copy the fixture, run $AGENT on the ask, score the result
#   scope.sh score <id> <dir>    score a git workdir that already holds an agent's changes
#   scope.sh churn <dir>         production lines and files changed against HEAD
# AGENT is a shell command that reads the ask from $ASK. Default drives Claude Code.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/../.." && pwd)"
TASKS="$PACK/evals/scope"
NOT_PROD='^(tests?|__tests__)/|\.(test|spec)\.|\.(md|mdx|txt)$'
DEFAULT_AGENT='printf "%s" "$ASK" | claude -p --permission-mode acceptEdits --allowedTools "Bash(node:*),Bash(git:*)"'

churn() {
  local dir="$1" added removed path lines=0 files=0
  while IFS=$'\t' read -r added removed path; do
    [[ "$added" != - && ! "$path" =~ $NOT_PROD ]] || continue
    lines=$((lines + added + removed)); files=$((files + 1))
  done < <(git -C "$dir" diff --numstat HEAD
           git -C "$dir" ls-files -o --exclude-standard | while IFS= read -r path; do
             printf '%s\t0\t%s\n' "$(wc -l <"$dir/$path" | tr -d ' ')" "$path"
           done)
  printf '%s %s\n' "$lines" "$files"
}

score() {
  local task="$TASKS/$1/task.json" dir="$2" lines files max failed=0 file text
  [[ -f "$task" ]] || { echo "no such task: $1" >&2; return 2; }
  read -r lines files < <(churn "$dir")
  max="$(jq -r .maxProdLines "$task")"
  if (( lines > max )); then echo "FAIL prod lines $lines > $max"; failed=1; else echo "ok   prod lines $lines <= $max"; fi
  max="$(jq -r .maxProdFiles "$task")"
  if (( files > max )); then echo "FAIL prod files $files > $max"; failed=1; else echo "ok   prod files $files <= $max"; fi
  if (cd "$dir" && bash -c "$(jq -r .verify "$task")") >/dev/null 2>&1; then echo "ok   verify"; else echo "FAIL verify"; failed=1; fi
  while IFS=$'\t' read -r file text; do
    if grep -qF -- "$text" "$dir/$file" 2>/dev/null; then echo "ok   contains $file: $text"; else echo "FAIL contains $file: $text"; failed=1; fi
  done < <(jq -r '.contains[]? | [.file, .text] | @tsv' "$task")
  while IFS=$'\t' read -r file text; do
    if grep -qF -- "$text" "$dir/$file" 2>/dev/null; then echo "FAIL absent $file: $text"; failed=1; else echo "ok   absent $file: $text"; fi
  done < <(jq -r '.absent[]? | [.file, .text] | @tsv' "$task")
  return "$failed"
}

workdir() {
  local dir; dir="$(mktemp -d "${TMPDIR:-/tmp}/kleos-scope.XXXXXX")"
  cp -a "$TASKS/$1/repo/." "$dir/"
  git -C "$dir" init -q
  git -C "$dir" add -A
  git -C "$dir" -c user.name=eval -c user.email=eval@local commit -qm base
  printf '%s' "$dir"
}

check() {
  local id dir bad=0
  for id in ${1:-$(ls "$TASKS")}; do
    dir="$(workdir "$id")"; cp -a "$TASKS/$id/good/." "$dir/"
    score "$id" "$dir" >/dev/null && echo "ok $id: golden change scores" || { echo "FAIL $id: golden change does not score"; bad=1; }
    rm -rf "$dir"
    dir="$(workdir "$id")"; cp -a "$TASKS/$id/bad/." "$dir/"
    score "$id" "$dir" >/dev/null && { echo "FAIL $id: golden over-edit scores"; bad=1; } || echo "ok $id: golden over-edit is rejected"
    rm -rf "$dir"
  done
  return "$bad"
}

run() {
  local dir rc=0
  dir="$(workdir "$1")"
  (cd "$dir" && ASK="$(jq -r .ask "$TASKS/$1/task.json")" bash -c "${AGENT:-$DEFAULT_AGENT}") || echo "agent exited non-zero" >&2
  score "$1" "$dir" || rc=$?
  echo "workdir: $dir"
  return "$rc"
}

case "${1:-}" in
  check) check "${2:-}" ;;
  run) run "${2:?usage: scope.sh run <id>}" ;;
  score) score "${2:?usage: scope.sh score <id> <dir>}" "${3:?usage: scope.sh score <id> <dir>}" ;;
  churn) churn "${2:?usage: scope.sh churn <dir>}" ;;
  *) echo "usage: scripts/eval/scope.sh {check [id]|run <id>|score <id> <dir>|churn <dir>}" >&2; exit 2 ;;
esac
