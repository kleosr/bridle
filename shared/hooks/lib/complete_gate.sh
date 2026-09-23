#!/usr/bin/env bash
# Stop-time unfinished-work sensor. Flags unresolved conflict markers and
# not-implemented stubs added in the change. No whole-repo scan. Never
# blocks completion.

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
  printf 'COMPLETION (advisory): the change looks unfinished.\n%s' "$out"
}
