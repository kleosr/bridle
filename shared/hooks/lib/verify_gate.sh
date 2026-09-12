#!/usr/bin/env bash
# Stop-time verification sensor. Advisory only. Never executes repo test
# suites or package scripts — those are untrusted in a global hook.

verify_changed_files() {
  local root="$1"
  git -C "$root" diff --name-only HEAD -- 2>/dev/null
}

# Syntax only: bash -n on changed *.sh; jq empty on changed *.json.
gate_verify_syntax() {
  local root="$1" f out=""
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    [[ -f "$root/$f" ]] || continue
    case "$f" in
      *.sh)
        bash -n "$root/$f" 2>/dev/null || out="${out}syntax: $f (bash -n failed)
"
        ;;
      *.json)
        jq empty "$root/$f" >/dev/null 2>&1 || out="${out}syntax: $f (jq empty failed)
"
        ;;
    esac
  done < <(verify_changed_files "$root")
  printf '%s' "$out"
}

resolve_verify_hint() {
  local root="$1"
  if [[ -f "$root/docs/TOOLCHAIN.md" && -f "$root/tests/run.sh" ]]; then
    printf '%s' "bash tests/run.sh"
    return 0
  fi
  if [[ -f "$root/package.json" ]] && jq -e '.scripts.test' "$root/package.json" >/dev/null 2>&1; then
    printf '%s' "package.json scripts.test (cite a real run; hook does not execute it)"
    return 0
  fi
  if [[ -f "$root/Makefile" ]] && grep -qE '^test:' "$root/Makefile"; then
    printf '%s' "make test"
    return 0
  fi
  return 1
}

# Emit followup text when syntax is red. Do not nag every dirty tree: citation
# of a test run stays law (testing.mdc). The hook does not invent a suite.
gate_verify() {
  local root="$1" files syn hint=""
  diff_has_head "$root" || return 0
  files="$(verify_changed_files "$root")"
  [[ -n "$files" ]] || return 0
  syn="$(gate_verify_syntax "$root")"
  [[ -n "$syn" ]] || return 0
  hint="$(resolve_verify_hint "$root" || true)"
  printf 'VERIFY (advisory): syntax red on the working tree.\n%s' "$syn"
  if [[ -n "$hint" ]]; then
    printf 'Candidate verify (not executed by this hook): `%s`.\n' "$hint"
  fi
  printf 'Cite a real run of the repo verify before claiming done.\n'
}
