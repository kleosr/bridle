#!/usr/bin/env bash
# Completion / integration sensor. Advisory only. Reads the working tree vs
# HEAD and reports end-to-end incompleteness signals: VCS conflict markers,
# explicit not-implemented placeholders left in shipped code, ownerless
# TODO/FIXME added in this change, and source modules added but never
# referenced anywhere (compiles-but-unwired). It never executes repo code.
#
# Two entry points share the detectors:
#   gate_completion ROOT   stop.sh: cheap, near-zero-false-positive signals
#                          (conflicts + not-implemented stubs) as advisory text.
#   complete_scan ROOT     scripts/complete.sh: the full signal set, printed one
#                          "kind<TAB>detail" per line, scored into a confidence.

COMPLETE_SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs|scala|sh|bash)'
# Files discovered by path or convention (routing, migrations, entrypoints) are
# reachable without an import, so they are never "orphans".
COMPLETE_ENTRY_RE='(^|/)(index|main|mod|__init__|__main__|setup|conftest|app|server|cli|middleware|route|router|routes|page|layout|loading|error|not-found|handler|worker|__mocks__)\.'
COMPLETE_AUTODIR_RE='(^|/)(pages|app|routes|migrations|migrate|seeds|fixtures|__tests__|__mocks__|test|tests|spec|specs|e2e|cypress|stories|node_modules|dist|build|vendor|coverage)/'
COMPLETE_TEST_RE='(\.(test|spec|stories)\.|_test\.|_spec\.|_test$)'
COMPLETE_MAX_SCAN_FILES=5000

comp_has_head() { git -C "$1" rev-parse --verify -q HEAD >/dev/null 2>&1; }

# Tracked files changed vs HEAD plus untracked files, unique. Empty outside git.
comp_changed_paths() {
  local root="$1"
  comp_has_head "$root" || { git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null; return 0; }
  {
    git -C "$root" diff --name-only HEAD -- 2>/dev/null
    git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null
  } | sort -u
}

# Source files added by this change (status A vs HEAD, or untracked), filtered
# to wireable code and excluding entrypoints, auto-discovered dirs, and tests.
comp_added_sources() {
  local root="$1" f
  {
    comp_has_head "$root" && git -C "$root" diff --name-only --diff-filter=A HEAD -- 2>/dev/null
    git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null
  } | sort -u | while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    printf '%s' "$f" | grep -qE "\.${COMPLETE_SRC_EXT}$" || continue
    printf '%s' "$f" | grep -qE "$COMPLETE_AUTODIR_RE" && continue
    printf '%s' "$f" | grep -qE "$COMPLETE_ENTRY_RE" && continue
    printf '%s' "$f" | grep -qE "$COMPLETE_TEST_RE" && continue
    printf '%s\n' "$f"
  done
}

# Added content of this change: '+' lines of the tracked diff plus every line of
# each untracked file. Used for marker scanning (only new lines, never context).
comp_added_lines() {
  local root="$1" f
  if comp_has_head "$root"; then
    git -C "$root" diff --no-color HEAD -- 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+'
  fi
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$root/$f" ]] || continue
    sed 's/^/+/' "$root/$f" 2>/dev/null
  done < <(git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null)
}

# Files that contain BOTH opening and closing VCS conflict markers (a genuine
# unresolved merge, not a stray divider). One path per line.
comp_conflicts() {
  local root="$1" f
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$root/$f" ]] || continue
    if grep -qE '^<<<<<<< ' "$root/$f" 2>/dev/null && grep -qE '^>>>>>>> ' "$root/$f" 2>/dev/null; then
      printf '%s\n' "$f"
    fi
  done < <(comp_changed_paths "$root")
}

# Explicit not-implemented stubs added in this change. Near-zero false positive:
# these are sentinels that mean "this path is unfinished".
comp_stub_count() {
  local root="$1" n
  n="$(comp_added_lines "$root" | grep -icE 'not[ _-]?implemented|unimplemented!|NotImplementedError|todo!\(\)|unimplemented\(\)|throw new Error\((["'"'"'])[[:space:]]*(TODO|FIXME|not implemented|unimplemented)' 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

# Ownerless TODO/FIXME/XXX/HACK added in this change. Softer signal than a stub;
# CLI-only so the stop hook stays quiet on ordinary tracked TODOs.
comp_todo_count() {
  local root="$1" n
  n="$(comp_added_lines "$root" | grep -icE '(^|[^A-Za-z])(TODO|FIXME|XXX|HACK)([^A-Za-z(]|$)' 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

# True when $base (a module name) is referenced as a whole word by any file in
# the repo other than $self. Scans tracked + untracked; bounded by file count.
comp_referenced() {
  local root="$1" base="$2" self="$3" f count=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ "$f" == "$self" ]] && continue
    [[ -f "$root/$f" ]] || continue
    if grep -Iqw -F -- "$base" "$root/$f" 2>/dev/null; then
      return 0
    fi
    count=$((count + 1))
    [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 0
  done < <({ git -C "$root" ls-files -- 2>/dev/null; git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null; } | sort -u)
  return 1
}

# Added source modules whose basename is never referenced elsewhere: added but
# not imported, registered, or otherwise wired in. One path per line.
comp_orphans() {
  local root="$1" f base
  comp_has_head "$root" || return 0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    base="${f##*/}"; base="${base%.*}"
    [[ "${#base}" -ge 3 ]] || continue
    comp_referenced "$root" "$base" "$f" || printf '%s\n' "$f"
  done < <(comp_added_sources "$root")
  return 0
}

# stop.sh sensor: only the unambiguous signals. Emit advisory text or nothing.
gate_completion() {
  local root="$1" out="" f stubs
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    out="${out}integration: $f has unresolved conflict markers (<<<<<<< / >>>>>>>). Resolve before claiming done.
"
  done < <(comp_conflicts "$root")
  stubs="$(comp_stub_count "$root")"
  if [[ "$stubs" =~ ^[0-9]+$ && "$stubs" -gt 0 ]]; then
    out="${out}integration: $stubs not-implemented stub(s) added in this change. Finish the path or remove the dead branch before claiming done.
"
  fi
  [[ -n "$out" ]] || return 0
  printf 'COMPLETION (advisory): the change looks unfinished.\n%sRun `bash scripts/complete.sh check` for the full completion score.\n' "$out"
}

# scripts/complete.sh sensor: the full signal set as "kind<TAB>detail" lines.
complete_scan() {
  local root="$1" f n
  git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  while IFS= read -r f; do
    [[ -n "$f" ]] && printf 'conflict\t%s\n' "$f"
  done < <(comp_conflicts "$root")
  n="$(comp_stub_count "$root")"
  [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]] && printf 'stub\t%s not-implemented stub line(s)\n' "$n"
  while IFS= read -r f; do
    [[ -n "$f" ]] && printf 'orphan\t%s\n' "$f"
  done < <(comp_orphans "$root")
  n="$(comp_todo_count "$root")"
  [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]] && printf 'todo\t%s ownerless TODO/FIXME line(s)\n' "$n"
  return 0
}
