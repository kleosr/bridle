#!/usr/bin/env bash
# Completion / integration sensor. Advisory only. Reads the working tree vs
# HEAD and reports end-to-end incompleteness signals: VCS conflict markers,
# explicit not-implemented placeholders left in shipped code, ownerless
# TODO/FIXME added in this change, source modules added but never referenced
# anywhere (compiles-but-unwired), and declarations removed but still referenced
# by surviving code (dangling reference / incomplete refactor). It never
# executes repo code.
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

# True when file $2 (path under root $1) references module name $3 as a word.
comp_file_refs() {
  local root="$1" file="$2" base="$3"
  [[ -f "$root/$file" ]] || return 1
  grep -Iqw -F -- "$base" "$root/$file" 2>/dev/null
}

# True when $base is referenced by any file NOT in the added set (i.e. anchored
# to pre-existing code). Remaining args are the added paths to exclude, so a new
# file's only references coming from other new files do not count as anchoring.
comp_anchored_by_existing() {
  local root="$1" base="$2"; shift 2
  local -a added=("$@")
  local f a count=0
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    for a in ${added[@]+"${added[@]}"}; do [[ "$f" == "$a" ]] && continue 2; done
    comp_file_refs "$root" "$f" "$base" && return 0
    count=$((count + 1))
    [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 1
  done < <({ git -C "$root" ls-files -- 2>/dev/null; git -C "$root" ls-files -o --exclude-standard -- 2>/dev/null; } | sort -u)
  return 1
}

# Added source modules not reachable from pre-existing code: a single unimported
# file, or a whole island of new files that only reference each other. Anchors
# are added files referenced by existing code; reachability then propagates
# across the added set to its fixpoint. Remainder is unwired. One path per line.
comp_orphans() {
  local root="$1" f b i j n changed
  comp_has_head "$root" || return 0
  local -a added=() base=() anchored=()
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    b="${f##*/}"; b="${b%.*}"
    [[ "${#b}" -ge 3 ]] || continue
    added[${#added[@]}]="$f"; base[${#base[@]}]="$b"
  done < <(comp_added_sources "$root")
  n="${#added[@]}"
  [[ "$n" -gt 0 ]] || return 0
  for ((i = 0; i < n; i++)); do
    anchored[i]=0
    comp_anchored_by_existing "$root" "${base[i]}" ${added[@]+"${added[@]}"} && anchored[i]=1
  done
  changed=1
  while [[ "$changed" -eq 1 ]]; do
    changed=0
    for ((i = 0; i < n; i++)); do
      [[ "${anchored[i]}" -eq 1 ]] || continue
      for ((j = 0; j < n; j++)); do
        [[ "${anchored[j]}" -eq 0 ]] || continue
        [[ "$i" -eq "$j" ]] && continue
        if comp_file_refs "$root" "${added[i]}" "${base[j]}"; then
          anchored[j]=1; changed=1
        fi
      done
    done
  done
  for ((i = 0; i < n; i++)); do
    [[ "${anchored[i]}" -eq 0 ]] && printf '%s\n' "${added[i]}"
  done
  return 0
}

# Exported / top-level declarations removed by this change (JS/TS export, python
# def|class, go func). One symbol name per line. High-signal only — locals and
# non-exported members are intentionally out of scope to keep precision high.
comp_removed_symbols() {
  local root="$1"
  comp_has_head "$root" || return 0
  git -C "$root" diff --no-color HEAD -- 2>/dev/null \
    | grep -E '^-' | grep -vE '^---' | sed -E 's/^-//' \
    | grep -oE '(export[[:space:]]+(default[[:space:]]+)?)?(async[[:space:]]+)?(function|class|const|let|var|interface|type|enum|def|func)[[:space:]]+[A-Za-z_][A-Za-z0-9_]+' \
    | awk '{print $NF}' | sort -u
}

# Iterate tracked + untracked working-tree files (untracked new files matter:
# a moved declaration lands in a not-yet-staged file). Bounded by file count.
comp_tree_files() {
  { git -C "$1" ls-files -- 2>/dev/null; git -C "$1" ls-files -o --exclude-standard -- 2>/dev/null; } | sort -u
}

# True when $2 is still declared somewhere in the current tree (moved or
# redeclared, not deleted). Guards against flagging renames-in-place and moves.
comp_decl_present() {
  local root="$1" name="$2" f count=0
  local pat="(function|class|const|let|var|interface|type|enum|def|func)[[:space:]]+${name}([^A-Za-z0-9_]|\$)"
  while IFS= read -r f; do
    [[ -n "$f" && -f "$root/$f" ]] || continue
    grep -IqE -- "$pat" "$root/$f" 2>/dev/null && return 0
    count=$((count + 1)); [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 1
  done < <(comp_tree_files "$root")
  return 1
}

# True when $2 still appears as a whole word anywhere in the current tree.
comp_symbol_used() {
  local root="$1" name="$2" f count=0
  while IFS= read -r f; do
    [[ -n "$f" && -f "$root/$f" ]] || continue
    grep -Iqw -F -- "$name" "$root/$f" 2>/dev/null && return 0
    count=$((count + 1)); [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 1
  done < <(comp_tree_files "$root")
  return 1
}

# Symbols a declaration was removed for that no longer resolve anywhere yet are
# still referenced by surviving code: a deleted/renamed export with a caller
# left behind — the classic incomplete-refactor regression. One name per line.
comp_dangling() {
  local root="$1" name
  comp_has_head "$root" || return 0
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    [[ "${#name}" -ge 3 ]] || continue
    comp_decl_present "$root" "$name" && continue
    comp_symbol_used "$root" "$name" && printf '%s\n' "$name"
  done < <(comp_removed_symbols "$root")
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
  while IFS= read -r f; do
    [[ -n "$f" ]] && printf 'dangling\t%s (removed declaration still referenced)\n' "$f"
  done < <(comp_dangling "$root")
  n="$(comp_todo_count "$root")"
  [[ "$n" =~ ^[0-9]+$ && "$n" -gt 0 ]] && printf 'todo\t%s ownerless TODO/FIXME line(s)\n' "$n"
  return 0
}
