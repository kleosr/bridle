#!/usr/bin/env bash
# Completion / integration sensor — the cheap half, safe on the per-turn stop
# hook. It reads the working tree vs HEAD and flags unambiguous unfinished-work
# markers (VCS conflict markers, not-implemented stubs, ownerless TODO/FIXME)
# without any whole-repo scan. It never executes repo code.
#
# The expensive graph/reference detectors (orphan, dangling, dependency
# integrity) live in complete_graph.sh and are CLI-only via scripts/complete.sh.
#
#   gate_completion ROOT   stop.sh: conflicts + not-implemented stubs as one
#                          advisory line. Never blocks completion.
# comp_added_lines and comp_has_head are shared primitives reused by
# complete_graph.sh, which sources this file first.

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
  n="$(comp_added_lines "$root" | grep -icE 'unimplemented!|NotImplementedError|todo!\(\)|unimplemented\(\)|throw new Error\((["'"'"'])[[:space:]]*(TODO|FIXME|not implemented|unimplemented)' 2>/dev/null || true)"
  printf '%s' "${n:-0}"
}

# Ownerless TODO/FIXME/XXX/HACK added in this change. Softer signal than a stub;
# CLI-only so the stop hook stays quiet on ordinary tracked TODOs.
comp_todo_count() {
  local root="$1" n
  n="$(comp_added_lines "$root" | grep -icE '(^|[^A-Za-z])(TODO|FIXME|XXX|HACK)([^A-Za-z(]|$)' 2>/dev/null || true)"
  printf '%s' "${n:-0}"
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
