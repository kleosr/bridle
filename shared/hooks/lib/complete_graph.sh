#!/usr/bin/env bash
# Whole-repo reference analysis for the completion gate. This is the expensive,
# CLI-only half: it walks tracked + untracked files to answer graph questions a
# per-turn hook must not ask. scripts/complete.sh sources it after
# complete_gate.sh (whose primitives it reuses); the stop hook never loads it.
#
#   complete_scan ROOT   the full signal set, one "kind<TAB>detail" per line,
#                        scored into a confidence by scripts/complete.sh.
# Detectors: orphan (added but never referenced), dangling (declaration removed
# but still referenced), and the import extractor behind dependency integrity.

COMPLETE_SRC_EXT='(ts|tsx|js|jsx|mjs|cjs|py|go|rs|rb|java|kt|swift|c|cc|cpp|h|hpp|php|lua|ex|exs|scala|sh|bash)'
# Files discovered by path or convention (routing, migrations, entrypoints) are
# reachable without an import, so they are never "orphans".
COMPLETE_ENTRY_RE='(^|/)(index|main|mod|__init__|__main__|setup|conftest|app|server|cli|middleware|route|router|routes|page|layout|loading|error|not-found|handler|worker|__mocks__)\.'
COMPLETE_AUTODIR_RE='(^|/)(pages|app|routes|migrations|migrate|seeds|fixtures|__tests__|__mocks__|test|tests|spec|specs|e2e|cypress|stories|node_modules|dist|build|vendor|coverage)/'
COMPLETE_TEST_RE='(\.(test|spec|stories)\.|_test\.|_spec\.|_test$)'
COMPLETE_MAX_SCAN_FILES="${COMPLETE_MAX_SCAN_FILES:-5000}"
# Node core modules: reachable without a package.json entry. A leading `node:`
# is always core and is stripped before this check.
COMPLETE_NODE_BUILTINS=' assert async_hooks buffer child_process cluster console constants crypto dgram diagnostics_channel dns domain events fs http http2 https inspector module net os path perf_hooks process punycode querystring readline repl stream string_decoder sys timers tls trace_events tty url util v8 vm wasi worker_threads zlib '

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

# Bare (non-relative) package specifiers newly imported by this change in JS/TS
# files, normalized to the installable package name: subpaths are dropped
# (lodash/merge -> lodash; @scope/pkg/x -> @scope/pkg), a leading node: is
# stripped, relative paths (./ ../) and Node core modules are excluded. One
# package per line. Reuses comp_added_lines from complete_gate.sh.
comp_added_imports() {
  local root="$1" spec pkg
  comp_added_lines "$root" \
    | grep -oE "((import|export)[^\"']*from[[:space:]]*|import[[:space:]]*|require\(|import\()[[:space:]]*[\"'][^\"']+[\"']" 2>/dev/null \
    | grep -oE "[\"'][^\"']+[\"']" \
    | sed -E "s/^[\"']//; s/[\"']$//" \
    | while IFS= read -r spec; do
        [[ -n "$spec" ]] || continue
        case "$spec" in
          .*|/*) continue ;;
          node:*) continue ;;
        esac
        if [[ "$spec" == @*/* ]]; then
          pkg="$(printf '%s' "$spec" | cut -d/ -f1-2)"
        else
          pkg="${spec%%/*}"
        fi
        case "$COMPLETE_NODE_BUILTINS" in *" $pkg "*) continue ;; esac
        printf '%s\n' "$pkg"
      done | sort -u
}

# True when file $2 (path under root $1) references module name $3 as a word.
comp_file_refs() {
  local root="$1" file="$2" base="$3"
  [[ -f "$root/$file" ]] || return 1
  grep -Iqw -F -- "$base" "$root/$file" 2>/dev/null
}

# Iterate tracked + untracked working-tree files (untracked new files matter:
# a moved declaration lands in a not-yet-staged file). Bounded by file count.
comp_tree_files() {
  { git -C "$1" ls-files -- 2>/dev/null; git -C "$1" ls-files -o --exclude-standard -- 2>/dev/null; } | sort -u
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
    # Cap: treat remainder as present so an unscanned tree stays quiet.
    [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 0
  done < <(comp_tree_files "$root")
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
    | grep -oE '^export[[:space:]]+(default[[:space:]]+)?(async[[:space:]]+)?(function|class|const|let|var|interface|type|enum)[[:space:]]+[A-Za-z_][A-Za-z0-9_]+|^((async[[:space:]]+)?def|class|func)[[:space:]]+[A-Za-z_][A-Za-z0-9_]+' \
    | awk '{print $NF}' | sort -u
}

# True when $2 is still declared somewhere in the current tree (moved or
# redeclared, not deleted). Guards against flagging renames-in-place and moves.
comp_decl_present() {
  local root="$1" name="$2" f count=0
  local pat="(function|class|const|let|var|interface|type|enum|def|func)[[:space:]]+${name}([^A-Za-z0-9_]|\$)"
  while IFS= read -r f; do
    [[ -n "$f" && -f "$root/$f" ]] || continue
    grep -IqE -- "$pat" "$root/$f" 2>/dev/null && return 0
    count=$((count + 1))
    # Cap: assume the declaration remains so dangling stays silent.
    [[ "$count" -ge "$COMPLETE_MAX_SCAN_FILES" ]] && return 0
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

# scripts/complete.sh sensor: the full signal set as "kind<TAB>detail" lines.
# Reuses the cheap detectors from complete_gate.sh plus the graph detectors here.
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
