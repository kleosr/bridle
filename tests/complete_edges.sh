#!/usr/bin/env bash
# Sourced by run.sh. Completion-confidence gate: stop-hook advisory (cheap
# signals), scripts/complete.sh scoring/verdict, and the benchmark.

CE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kleos-ce.XXXXXX")"
STOP="$PACK/shared/hooks/stop.sh"
COMPLETE="$PACK/scripts/complete.sh"
BENCH="$PACK/scripts/bench.sh"

ce_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}
ce_commit() { git -C "$1" add -A && git -C "$1" -c user.email=t@t -c user.name=t commit -q -m "$2"; }
ce_stop() { jq -n --arg w "$1" '{status:"completed",loop_count:0,workspace_roots:[$w]}' | bash "$STOP"; }

# --- stop-hook advisory: conflict markers are named as integration ---
ce_repo "$CE_TMP/conflict"
printf 'export const port = 3000\n' > "$CE_TMP/conflict/config.ts"
ce_commit "$CE_TMP/conflict" base
printf '<<<<<<< HEAD\na\n=======\nb\n>>>>>>> x\n' > "$CE_TMP/conflict/config.ts"
RESULT="$(ce_stop "$CE_TMP/conflict" | jq -r '.followup_message // "" | test("unresolved conflict markers")')"
run_test "stop: unresolved conflict markers are an integration advisory" "true" "$RESULT"

# --- stop-hook advisory: not-implemented stub is named ---
ce_repo "$CE_TMP/stub"
printf 'export const run = 1\n' > "$CE_TMP/stub/billing.ts"
ce_commit "$CE_TMP/stub" base
printf "export function refund() { throw new Error('TODO: not implemented') }\n" > "$CE_TMP/stub/billing.ts"
RESULT="$(ce_stop "$CE_TMP/stub" | jq -r '.followup_message // "" | test("not-implemented stub")')"
run_test "stop: not-implemented stub is a completion advisory" "true" "$RESULT"

# --- stop stays quiet on an orphan alone (orphan is CLI-only, low FP at hook) ---
ce_repo "$CE_TMP/orphan"
printf 'export const app = 1\n' > "$CE_TMP/orphan/app.ts"
ce_commit "$CE_TMP/orphan" base
printf 'export class PaymentService {}\n' > "$CE_TMP/orphan/PaymentService.ts"
RESULT="$(ce_stop "$CE_TMP/orphan" | jq -c .)"
run_test "stop: an orphan module alone does not fire the stop hook (quiet)" "{}" "$RESULT"

# --- stop stays quiet on a clean wired edit ---
ce_repo "$CE_TMP/clean"
printf 'export const a = 1\n' > "$CE_TMP/clean/a.ts"
printf "import { a } from './a'\nexport const b = a\n" > "$CE_TMP/clean/b.ts"
ce_commit "$CE_TMP/clean" base
printf "import { a } from './a'\nexport const b = a + 1\n" > "$CE_TMP/clean/b.ts"
RESULT="$(ce_stop "$CE_TMP/clean" | jq -c .)"
run_test "stop: clean wired edit is quiet" "{}" "$RESULT"

# --- prose "not implemented" is not a stub (near-zero-false-positive subset) ---
ce_repo "$CE_TMP/prose"
printf 'export const a = 1\n' > "$CE_TMP/prose/a.ts"
printf "import { a } from './a'\nexport const b = a\n" > "$CE_TMP/prose/b.ts"
ce_commit "$CE_TMP/prose" base
printf "import { a } from './a'\nexport const b = a + 1 // not implemented in older runtimes\n" > "$CE_TMP/prose/b.ts"
RESULT="$(ce_stop "$CE_TMP/prose" | jq -c .)"
run_test "regression: stub detector does not match ordinary not-implemented prose (stop quiet)" "{}" "$RESULT"
CE_PROSE_OUT="$(bash "$COMPLETE" check "$CE_TMP/prose"; echo "exit=$?")"
run_test "regression: stub detector does not match ordinary not-implemented prose (exit 0)" "exit=0" "$(printf '%s' "$CE_PROSE_OUT" | tail -1)"
run_test "regression: stub detector does not match ordinary not-implemented prose (no stub)" "0" "$(printf '%s' "$CE_PROSE_OUT" | sed '$d' | jq -r '.counts.stub')"
run_test "regression: stub detector does not match ordinary not-implemented prose (act)" "act" "$(printf '%s' "$CE_PROSE_OUT" | sed '$d' | jq -r '.verdict')"

# --- orphan reachability: a disconnected island of new files is caught ---
ce_repo "$CE_TMP/island"
printf 'export const app = 1\n' > "$CE_TMP/island/app.ts"
ce_commit "$CE_TMP/island" base
printf "import { Ctl } from './Ctl'\nexport class Svc { c() { return new Ctl() } }\n" > "$CE_TMP/island/Svc.ts"
printf "import { Svc } from './Svc'\nexport class Ctl { s() { return new Svc() } }\n" > "$CE_TMP/island/Ctl.ts"
run_test "complete: disconnected new-file island counts 2 orphans" "2" "$(bash "$COMPLETE" check "$CE_TMP/island" | jq -r '.counts.orphan')"

# --- orphan reachability: new modules chained through existing code stay clean ---
ce_repo "$CE_TMP/chain"
printf 'export const app = 1\n' > "$CE_TMP/chain/app.ts"
ce_commit "$CE_TMP/chain" base
printf "import { Alpha } from './Alpha'\nexport const app = new Alpha()\n" > "$CE_TMP/chain/app.ts"
printf "import { Beta } from './Beta'\nexport class Alpha { b() { return new Beta() } }\n" > "$CE_TMP/chain/Alpha.ts"
printf 'export class Beta {}\n' > "$CE_TMP/chain/Beta.ts"
run_test "complete: new modules reachable from existing code are not orphans" "0" "$(bash "$COMPLETE" check "$CE_TMP/chain" | jq -r '.counts.orphan')"

# --- reference integrity: removed export with a caller left behind is dangling ---
ce_repo "$CE_TMP/dangling"
printf 'export function refund() { return 1 }\nexport const rate = 2\n' > "$CE_TMP/dangling/billing.ts"
printf "import { refund } from './billing'\nexport const run = () => refund()\n" > "$CE_TMP/dangling/api.ts"
ce_commit "$CE_TMP/dangling" base
printf 'export const rate = 2\n' > "$CE_TMP/dangling/billing.ts"
run_test "complete: removed export with surviving caller is dangling" "1" "$(bash "$COMPLETE" check "$CE_TMP/dangling" | jq -r '.counts.dangling')"
run_test "complete: dangling reference escalates" "escalate" "$(bash "$COMPLETE" check "$CE_TMP/dangling" | jq -r '.verdict')"

# --- reference integrity: a symbol moved to a new file is not dangling ---
ce_repo "$CE_TMP/moved"
printf 'export function refund() { return 1 }\n' > "$CE_TMP/moved/billing.ts"
printf "import { refund } from './billing'\nexport const run = () => refund()\n" > "$CE_TMP/moved/api.ts"
ce_commit "$CE_TMP/moved" base
printf 'export const rate = 2\n' > "$CE_TMP/moved/billing.ts"
printf 'export function refund() { return 1 }\n' > "$CE_TMP/moved/refunds.ts"
printf "import { refund } from './refunds'\nexport const run = () => refund()\n" > "$CE_TMP/moved/api.ts"
run_test "complete: a moved (still-declared) symbol is not dangling" "0" "$(bash "$COMPLETE" check "$CE_TMP/moved" | jq -r '.counts.dangling')"

# --- reference integrity: renaming with all callers updated is clean ---
ce_repo "$CE_TMP/rename"
printf 'export function refund() { return 1 }\n' > "$CE_TMP/rename/billing.ts"
printf "import { refund } from './billing'\nexport const run = () => refund()\n" > "$CE_TMP/rename/api.ts"
ce_commit "$CE_TMP/rename" base
printf 'export function reimburse() { return 1 }\n' > "$CE_TMP/rename/billing.ts"
printf "import { reimburse } from './billing'\nexport const run = () => reimburse()\n" > "$CE_TMP/rename/api.ts"
run_test "complete: rename with all callers updated is not dangling" "0" "$(bash "$COMPLETE" check "$CE_TMP/rename" | jq -r '.counts.dangling')"

# --- reference integrity: a removed local is not a dangling export ---
ce_repo "$CE_TMP/local"
printf 'export function refund() {\n  const result = 1\n  return result\n}\nexport const note = "result is cached"\n' > "$CE_TMP/local/billing.ts"
printf "import { refund } from './billing'\nexport const run = () => refund()\n" > "$CE_TMP/local/api.ts"
ce_commit "$CE_TMP/local" base
printf 'export function refund() { return 1 }\nexport const note = "result is cached"\n' > "$CE_TMP/local/billing.ts"
run_test "regression: removed local const is not a dangling symbol" "0" "$(bash "$COMPLETE" check "$CE_TMP/local" | jq -r '.counts.dangling')"
run_test "regression: removed local const does not escalate" "act" "$(bash "$COMPLETE" check "$CE_TMP/local" | jq -r '.verdict')"

# --- scan cap fail-open: a wired module past the cap is not an orphan ---
ce_repo "$CE_TMP/scanlim"
printf 'export const other = 1\n' > "$CE_TMP/scanlim/aaa.ts"
printf 'export const app = 1\n' > "$CE_TMP/scanlim/app.ts"
ce_commit "$CE_TMP/scanlim" base
printf "import { PaymentService } from './PaymentService'\nexport const app = new PaymentService()\n" > "$CE_TMP/scanlim/app.ts"
printf 'export class PaymentService {}\n' > "$CE_TMP/scanlim/PaymentService.ts"
run_test "regression: scan limit does not orphan a wired module" "0" "$(COMPLETE_MAX_SCAN_FILES=1 bash "$COMPLETE" check "$CE_TMP/scanlim" | jq -r '.counts.orphan')"

# --- scan cap fail-open: a still-declared symbol past the cap is not dangling ---
ce_repo "$CE_TMP/scanlimd"
printf 'export const note = "refund later"\n' > "$CE_TMP/scanlimd/aaa.ts"
printf 'export function refund() { return 1 }\n' > "$CE_TMP/scanlimd/billing.ts"
printf "import { refund } from './billing'\nexport const run = () => refund()\n" > "$CE_TMP/scanlimd/api.ts"
ce_commit "$CE_TMP/scanlimd" base
printf 'export const rate = 2\n' > "$CE_TMP/scanlimd/billing.ts"
printf 'export function refund() { return 1 }\n' > "$CE_TMP/scanlimd/zzz.ts"
printf "import { refund } from './zzz'\nexport const run = () => refund()\n" > "$CE_TMP/scanlimd/api.ts"
run_test "regression: scan limit does not flag a moved symbol as dangling" "0" "$(COMPLETE_MAX_SCAN_FILES=1 bash "$COMPLETE" check "$CE_TMP/scanlimd" | jq -r '.counts.dangling')"

# --- dependency integrity: a package imported but not declared is flagged ---
ce_repo "$CE_TMP/undeclared"
printf '{ "name": "app", "dependencies": { "react": "^18" } }\n' > "$CE_TMP/undeclared/package.json"
printf "import { useState } from 'react'\nexport const app = useState\n" > "$CE_TMP/undeclared/app.ts"
ce_commit "$CE_TMP/undeclared" base
printf "import { S3Client } from '@aws-sdk/client-s3'\nexport const app = new S3Client({})\n" > "$CE_TMP/undeclared/app.ts"
run_test "complete: undeclared import is flagged" "1" "$(bash "$COMPLETE" check "$CE_TMP/undeclared" | jq -r '.counts.undeclared')"
run_test "complete: undeclared import escalates" "escalate" "$(bash "$COMPLETE" check "$CE_TMP/undeclared" | jq -r '.verdict')"

# --- dependency integrity: declared deps, subpaths, builtins, relatives clean ---
ce_repo "$CE_TMP/declared"
printf '{ "name": "app", "dependencies": { "react": "^18", "lodash": "^4" } }\n' > "$CE_TMP/declared/package.json"
printf 'export const app = 1\n' > "$CE_TMP/declared/app.ts"
printf "import { app } from './app'\nexport const run = app\n" > "$CE_TMP/declared/main.ts"
ce_commit "$CE_TMP/declared" base
printf "import { app } from './app'\nimport { useState } from 'react'\nimport merge from 'lodash/merge'\nimport fs from 'node:fs'\nexport const run = merge(app, useState, fs)\n" > "$CE_TMP/declared/main.ts"
run_test "complete: declared deps + subpath + builtin are not undeclared" "0" "$(bash "$COMPLETE" check "$CE_TMP/declared" | jq -r '.counts.undeclared')"

# --- dependency integrity: a dep declared in any package.json (monorepo) is clean ---
ce_repo "$CE_TMP/mono"
mkdir -p "$CE_TMP/mono/packages/api"
printf '{ "name": "root", "workspaces": ["packages/*"] }\n' > "$CE_TMP/mono/package.json"
printf '{ "name": "api", "dependencies": { "express": "^4" } }\n' > "$CE_TMP/mono/packages/api/package.json"
printf 'export const s = 1\n' > "$CE_TMP/mono/packages/api/server.ts"
ce_commit "$CE_TMP/mono" base
printf "import express from 'express'\nexport const s = express()\n" > "$CE_TMP/mono/packages/api/server.ts"
run_test "complete: dep declared in a sub-package manifest is not undeclared" "0" "$(bash "$COMPLETE" check "$CE_TMP/mono" | jq -r '.counts.undeclared')"

# --- complete.sh: clean wired edit scores 100 / act / exit 0 ---
RESULT="$(bash "$COMPLETE" check "$CE_TMP/clean"; echo "exit=$?")"
run_test "complete: clean wired edit exits 0 (act)" "exit=0" "$(printf '%s' "$RESULT" | tail -1)"
run_test "complete: clean wired edit confidence 100" "100" "$(printf '%s' "$RESULT" | sed '$d' | jq -r '.confidence')"
run_test "complete: clean wired edit verdict act" "act" "$(printf '%s' "$RESULT" | sed '$d' | jq -r '.verdict')"

# --- complete.sh: orphan module escalates (exit 3) without a critical flag ---
CE_ORPHAN_OUT="$(bash "$COMPLETE" check "$CE_TMP/orphan" || true)"
run_test "complete: orphan module verdict escalate" "escalate" "$(printf '%s' "$CE_ORPHAN_OUT" | jq -r '.verdict')"
run_test "complete: orphan module counts one orphan" "1" "$(printf '%s' "$CE_ORPHAN_OUT" | jq -r '.counts.orphan')"
CE_ORPHAN_EC=0; bash "$COMPLETE" check "$CE_TMP/orphan" >/dev/null 2>&1 || CE_ORPHAN_EC=$?
run_test "complete: escalate returns exit 3" "3" "$CE_ORPHAN_EC"

# --- complete.sh: conflict is a critical escalation with confidence 0 ---
CE_CONF_OUT="$(bash "$COMPLETE" check "$CE_TMP/conflict" || true)"
run_test "complete: conflict is critical" "true" "$(printf '%s' "$CE_CONF_OUT" | jq -r '.critical')"
run_test "complete: conflict confidence 0" "0" "$(printf '%s' "$CE_CONF_OUT" | jq -r '.confidence')"

# --- complete.sh: changed-file syntax error escalates (critical) ---
ce_repo "$CE_TMP/syntax"
printf 'echo ok\n' > "$CE_TMP/syntax/deploy.sh"
ce_commit "$CE_TMP/syntax" base
printf 'echo ok\nif then\n' > "$CE_TMP/syntax/deploy.sh"
run_test "complete: changed-file syntax error is critical" "true" "$(bash "$COMPLETE" check "$CE_TMP/syntax" | jq -r '.critical')"

# --- complete.sh: threshold is configurable ---
RESULT="$(COMPLETE_MIN_CONFIDENCE=60 bash "$COMPLETE" check "$CE_TMP/orphan" | jq -r '.verdict')"
run_test "complete: raising the bar below the score flips orphan to act" "act" "$RESULT"

# --- complete.sh: non-git dir is a usage error (exit 2) ---
mkdir -p "$CE_TMP/nogit"
CE_NOGIT_EC=0; bash "$COMPLETE" check "$CE_TMP/nogit" >/dev/null 2>&1 || CE_NOGIT_EC=$?
run_test "complete: non-git dir exits 2 (usage)" "2" "$CE_NOGIT_EC"

# --- benchmark: the labelled corpus meets its accuracy / FP target ---
CE_BENCH="$(bash "$BENCH" 2>/dev/null || true)"
run_test "bench: corpus meets target (pass)" "true" "$(printf '%s' "$CE_BENCH" | jq -r '.pass')"
run_test "bench: no false positives on the negative corpus" "0" "$(printf '%s' "$CE_BENCH" | jq -r '.confusionMatrix.fp')"
run_test "bench: recall 1 on the incomplete corpus" "1" "$(printf '%s' "$CE_BENCH" | jq -r '.after.recall | floor')"
CE_BENCH_EC=0; bash "$BENCH" >/dev/null 2>&1 || CE_BENCH_EC=$?
run_test "bench: exits 0 when the target is met" "0" "$CE_BENCH_EC"

rm -rf "$CE_TMP"
