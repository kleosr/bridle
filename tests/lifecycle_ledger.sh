#!/usr/bin/env bash
# Lifecycle ledger structural checks. Sourced by run.sh.
# Presence and placement only; these rows do NOT claim semantic completeness,
# behavior proof, or that the ledger is up to date. See docs/lifecycle-ledger.md.

LEDGER="$PACK/docs/lifecycle-ledger.md"

if [[ -f "$LEDGER" ]]; then LEDGER_EXISTS=yes; else LEDGER_EXISTS=no; fi
run_test "ledger exists outside injected context (structural presence, not completeness)" "yes" "$LEDGER_EXISTS"

run_test "ledger declares inventory scope (structural presence, not completeness)" "1" "$(grep -c '## 2. Inventory scope' "$LEDGER" | tr -d ' ')"

LEDGER_ROLES=ok
for role in boundary contract procedure workaround preference unclear; do
  grep -q "| $role |" "$LEDGER" || LEDGER_ROLES="missing:$role"
done
run_test "ledger declares all six roles (structural presence, not completeness)" "ok" "$LEDGER_ROLES"

LEDGER_HOT="$(cat "$PACK/shared/config/rules.global.txt" "$PACK/shared/config/skills.txt" "$PACK/shared/hooks/hooks.json" "$PACK/shared/config/manifest.json" 2>/dev/null | grep -c 'lifecycle-ledger' | tr -d ' ')"
run_test "ledger not referenced by hot path (structural presence, not completeness)" "0" "$LEDGER_HOT"

LEDGER_OVER="$(grep -c -e 'semantically complete' -e 'proves model behavior' "$LEDGER" | tr -d ' ')"
run_test "ledger makes no overclaim wording (structural presence, not completeness)" "0" "$LEDGER_OVER"

LEDGER_HOOKS=ok
for s in before_submit_prompt.sh before_shell.sh before_read_file.sh stop.sh; do
  grep -q "$s" "$LEDGER" || LEDGER_HOOKS="missing:$s"
done
run_test "ledger names the four hook scripts (structural presence, not completeness)" "ok" "$LEDGER_HOOKS"

if grep -q 'FORCE=1' "$LEDGER"; then LEDGER_FORCE=yes; else LEDGER_FORCE=no; fi
run_test "ledger retains FORCE=1 guidance (structural presence, not completeness)" "yes" "$LEDGER_FORCE"

if grep -q 'T1' "$LEDGER"; then LEDGER_T1=yes; else LEDGER_T1=no; fi
run_test "ledger marks T1-T5 unknown instead of inferring (structural presence, not completeness)" "yes" "$LEDGER_T1"
