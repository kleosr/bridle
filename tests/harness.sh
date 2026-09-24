#!/usr/bin/env bash
# Sourced by run.sh. Feature pass-state, handoff schema, eval index, map size.

# shellcheck source=shared/hooks/lib/fleet_scan.sh
source "$PACK/shared/hooks/lib/fleet_scan.sh"

HARNESS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kleos-harness.XXXXXX")"
STOP="$PACK/shared/hooks/stop.sh"
FEAT="$PACK/scripts/feature.sh"
HAND="$PACK/scripts/handoff.sh"

hf_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
}

hf_stop() {
  jq -n --arg w "$1" '{status:"completed",loop_count:0,workspace_roots:[$w]}' | bash "$STOP"
}

RESULT="$(bash "$FEAT" check >/dev/null && echo ok || echo fail)"
run_test "feature.sh check passes on pack features.json" "ok" "$RESULT"

RESULT="$(jq -e '.version == 1 and (.features | length) >= 1' "$PACK/shared/config/features.json" >/dev/null && echo ok || echo fail)"
run_test "features.json has version 1 and a features array" "ok" "$RESULT"

RESULT="$(jq -e '.runtime and .commands and .verification and .invariants and .requiredEvalDimensions and .layers and .extend' "$PACK/shared/config/harness.json" >/dev/null && echo ok || echo fail)"
run_test "harness.json exposes only the operational contract" "ok" "$RESULT"

RESULT="$(jq -e 'has("subsystems") or has("articleNine") or has("graph") or has("plugins") or has("failures") or has("reasons") or has("stopping")' "$PACK/shared/config/harness.json" >/dev/null && echo duplicated || echo clean)"
run_test "harness.json excludes descriptive indexes duplicated by docs" "clean" "$RESULT"

EVAL_OK=ok
while IFS= read -r proves; do
  [[ -z "$proves" ]] && continue
  [[ -f "$PACK/$proves" ]] || EVAL_OK="missing:$proves"
done < <(jq -r '.tasks[] | .proves' "$PACK/evals/tasks.json")
run_test "every evals/tasks.json proves path exists" "ok" "$EVAL_OK"

AGENTS_N="$(wc -l < "$PACK/AGENTS.md" | tr -d ' ')"
if [[ "$AGENTS_N" -le 120 ]]; then AGENTS_CAP=ok; else AGENTS_CAP="lines:$AGENTS_N"; fi
run_test "AGENTS.md is a directory page (≤120 lines)" "ok" "$AGENTS_CAP"

BAD="$HARNESS_TMP/features-bad.json"
jq -n '{version:1,features:[{id:"T01",priority:1,area:"x",title:"t",behavior:"b",verification:"true",status:"passing"}]}' > "$BAD"
RESULT="$(FEATURE_FILE="$BAD" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "regression: feature.sh check fails when passing has no evidence" "fail" "$RESULT"

BAD_STATUS="$HARNESS_TMP/features-status.json"
jq -n '{version:1,features:[{id:"T00",priority:1,area:"x",title:"t",behavior:"b",verification:"true",status:"done"}]}' > "$BAD_STATUS"
RESULT="$(FEATURE_FILE="$BAD_STATUS" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "regression: feature.sh check rejects an unknown status" "fail" "$RESULT"

TWO="$HARNESS_TMP/features-two.json"
jq -n '{version:1,features:[
  {id:"A",priority:1,area:"x",title:"a",behavior:"b",verification:"true",status:"in_progress"},
  {id:"B",priority:2,area:"x",title:"b",behavior:"b",verification:"true",status:"in_progress"}
]}' > "$TWO"
RESULT="$(FEATURE_FILE="$TWO" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "feature.sh check fails when two features are in_progress" "fail" "$RESULT"

OKF="$HARNESS_TMP/features-ok.json"
jq -n '{version:1,features:[{id:"T02",priority:1,area:"x",title:"t",behavior:"b",verification:"true",status:"not_started"}]}' > "$OKF"
RESULT="$(FEATURE_FILE="$OKF" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" pass T02 >/dev/null && echo ok || echo fail)"
run_test "feature.sh pass records evidence after verification exit 0" "ok" "$RESULT"
RESULT="$(jq -r '.features[0].status' "$OKF")"
run_test "feature.sh pass sets status passing" "passing" "$RESULT"
RESULT="$(jq -r '.features[0].evidence.exit' "$OKF")"
run_test "feature.sh pass records evidence.exit 0" "0" "$RESULT"

FAILF="$HARNESS_TMP/features-fail.json"
jq -n '{version:1,features:[{id:"T03",priority:1,area:"x",title:"t",behavior:"b",verification:"exit 1",status:"in_progress"}]}' > "$FAILF"
RESULT="$(FEATURE_FILE="$FAILF" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" pass T03 >/dev/null 2>&1 && echo ok || echo fail)"
run_test "feature.sh pass does not mark passing when verification fails" "fail" "$RESULT"
RESULT="$(jq -r '.features[0].status' "$FAILF")"
run_test "failed pass leaves status in_progress" "in_progress" "$RESULT"

HO="$HARNESS_TMP/handoff.json"
RESULT="$(HANDOFF_FILE="$HO" bash "$HAND" check >/dev/null && echo ok || echo fail)"
run_test "handoff.sh check treats absence as ok" "ok" "$RESULT"

printf '%s\n' '{"version":1,"task":"t","verified":{"command":"true","exit":0},"remaining":["x"],"nextAction":"continue"}' \
  | HANDOFF_FILE="$HO" bash "$HAND" write >/dev/null
RESULT="$(HANDOFF_FILE="$HO" bash "$HAND" check >/dev/null && echo ok || echo fail)"
run_test "handoff.sh write+check accepts a schema-valid snapshot" "ok" "$RESULT"

printf '%s\n' '{"version":1,"task":"t"}' | HANDOFF_FILE="$HARNESS_TMP/bad-handoff.json" bash "$HAND" write >/dev/null 2>&1 \
  && RESULT=ok || RESULT=fail
run_test "handoff.sh write rejects a snapshot missing verified/remaining/nextAction" "fail" "$RESULT"

printf '%s\n' '{"version":1,"task":"t","verified":{"command":"true","exit":0},"remaining":[1],"nextAction":"continue"}' \
  | HANDOFF_FILE="$HARNESS_TMP/bad-handoff-array.json" bash "$HAND" write >/dev/null 2>&1 \
  && RESULT=ok || RESULT=fail
run_test "handoff.sh write rejects non-string arrays" "fail" "$RESULT"

hf_repo "$HARNESS_TMP/falsewin"
printf 'echo ok\n' > "$HARNESS_TMP/falsewin/ok.sh"
git -C "$HARNESS_TMP/falsewin" add ok.sh
git -C "$HARNESS_TMP/falsewin" -c user.email=t@t -c user.name=t commit -q -m base
mkdir -p "$HARNESS_TMP/falsewin/.cursor/bridle"
printf '%s\n' '{"version":1,"features":[{"id":"F01","priority":1,"area":"x","title":"t","behavior":"b","verification":"true","status":"passing"}]}' \
  > "$HARNESS_TMP/falsewin/.cursor/bridle/features.json"
RESULT="$(hf_stop "$HARNESS_TMP/falsewin" | jq -r '.followup_message // "" | test("passing without evidence")')"
run_test "regression: stop advisory when the workspace ledger is passing without evidence" "true" "$RESULT"

# Ledger follows the workspace: pack cwd -> pack ledger; any other repo ->
# <root>/.cursor/bridle. Passing means passing for the tree as it is now.
RESULT="$(cd "$PACK" && bash "$FEAT" list | cut -f1 | head -1)"
run_test "feature.sh in the pack reads the pack ledger" "H01" "$RESULT"
EXT="$HARNESS_TMP/ext"
hf_repo "$EXT"
printf 'echo ok\n' > "$EXT/ok.sh"
git -C "$EXT" add ok.sh
git -C "$EXT" -c user.email=t@t -c user.name=t commit -q -m base
mkdir -p "$EXT/.cursor/bridle"
jq -n '{version:1,activeLimit:1,features:[
  {id:"F01",priority:1,area:"x",title:"first",behavior:"b",verification:"true",status:"not_started"},
  {id:"F02",priority:2,area:"x",title:"second",behavior:"b",verification:"true",status:"not_started"}
]}' > "$EXT/.cursor/bridle/features.json"
RESULT="$(cd "$EXT" && bash "$FEAT" list | cut -f1 | head -1)"
run_test "regression: feature.sh in another repo reads <root>/.cursor/bridle/features.json" "F01" "$RESULT"
RESULT="$(cd "$EXT" && bash "$FEAT" pass F01 >/dev/null && echo ok || echo fail)"
run_test "external workspace: feature.sh pass records passing" "ok" "$RESULT"
RESULT="$(jq -r '.features[0].evidence.tree // "" | length > 20' "$EXT/.cursor/bridle/features.json")"
run_test "external workspace: pass records evidence.tree" "true" "$RESULT"
RESULT="$(cd "$EXT" && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "external workspace: check passes right after pass" "ok" "$RESULT"
RESULT="$(hf_stop "$EXT" | jq -c .)"
run_test "stop is quiet when the workspace ledger is fresh and the tree is clean" "{}" "$RESULT"

# Rows recorded before evidence.tree existed are accepted by feature.sh check.
# Calling them "workspace changed since pass" is false and fires on every stop.
NOTREE="$HARNESS_TMP/notree"
hf_repo "$NOTREE"
printf 'echo ok\n' > "$NOTREE/ok.sh"
git -C "$NOTREE" add ok.sh
git -C "$NOTREE" -c user.email=t@t -c user.name=t commit -q -m base
mkdir -p "$NOTREE/.cursor/bridle"
jq -n '{version:1,features:[{id:"F01",priority:1,area:"x",title:"t",behavior:"b",verification:"true",status:"passing",evidence:{command:"true",exit:0,proves:"ok.sh"}}]}' \
  > "$NOTREE/.cursor/bridle/features.json"
RESULT="$(cd "$NOTREE" && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "feature.sh check accepts passing evidence that predates evidence.tree" "ok" "$RESULT"
RESULT="$(hf_stop "$NOTREE" | jq -r '.followup_message // "" | test("stale evidence")')"
run_test "regression: stop does not call pre-tree evidence stale" "false" "$RESULT"

printf 'echo changed\n' > "$EXT/ok.sh"
RESULT="$(cd "$EXT" && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "regression: an edit after pass makes check reject the stale passing row" "fail" "$RESULT"
RESULT="$(hf_stop "$EXT" | jq -r '.followup_message // "" | test("stale evidence")')"
run_test "regression: stop names passing rows with stale evidence" "true" "$RESULT"
git -C "$EXT" add ok.sh
git -C "$EXT" -c user.email=t@t -c user.name=t commit -q -m change
RESULT="$(cd "$EXT" && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "committing the edit does not refresh stale evidence" "fail" "$RESULT"
RESULT="$(cd "$EXT" && bash "$FEAT" pass F01 >/dev/null && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "re-running pass after the edit makes check pass again" "ok" "$RESULT"
RESULT="$(hf_stop "$EXT" | jq -c .)"
run_test "stop is quiet again after re-pass on a clean tree" "{}" "$RESULT"

RESULT="$(cd "$EXT" && bash "$FEAT" start F02 >/dev/null && echo ok || echo fail)"
run_test "external workspace: feature.sh start sets in_progress" "ok" "$RESULT"
RESULT="$(hf_stop "$EXT" | jq -c .)"
run_test "stop is quiet with in_progress work on a clean tree" "{}" "$RESULT"
printf 'echo wip\n' > "$EXT/ok.sh"
RESULT="$(hf_stop "$EXT" | jq -r '.followup_message // "" | test("F02 is in_progress and the working tree has uncommitted changes")')"
run_test "regression: stop names in_progress work left on a dirty tree" "true" "$RESULT"

RESULT="$(cd "$EXT" && bash "$HAND" check)"
run_test "handoff.sh in another repo treats absence as ok" "handoff absent (ok)" "$RESULT"
printf '%s\n' '{"version":1,"task":"t","verified":{"command":"true","exit":0},"remaining":["x"],"nextAction":"continue"}' \
  | (cd "$EXT" && bash "$HAND" write >/dev/null)
RESULT="$(test -f "$EXT/.cursor/bridle/handoff.json" && echo yes || echo no)"
run_test "handoff.sh in another repo writes <root>/.cursor/bridle/handoff.json" "yes" "$RESULT"
RESULT="$(cd "$EXT" && bash "$FEAT" pass F02 >/dev/null && bash "$FEAT" pass F01 >/dev/null && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "external workspace: both rows fresh after re-pass on the dirty tree" "ok" "$RESULT"
printf '%s\n' '{"version":1,"task":"t2","verified":{"command":"true","exit":0},"remaining":[],"nextAction":"done"}' \
  | (cd "$EXT" && bash "$HAND" write >/dev/null)
RESULT="$(cd "$EXT" && bash "$FEAT" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "handoff write does not stale the ledger (excluded from the tree)" "ok" "$RESULT"

RESULT="$(jq -r '.hooks.stop[0].loop_limit' "$PACK/shared/hooks/hooks.json")"
run_test "stop remains advisory (loop_limit 1; no new hook events)" "1" "$RESULT"

RESULT="$(jq -e '.hooks|has("sessionStart")|not' "$PACK/shared/hooks/hooks.json" >/dev/null && echo yes || echo no)"
run_test "hooks.json still omits sessionStart" "yes" "$RESULT"

RESULT="$(jq -e '.invariants.hookEventCount==4 and .invariants.hooksFrozen==true and .invariants.noSessionStart==true and .invariants.noPreToolUse==true and .invariants.noPackLoop==true' "$PACK/shared/config/harness.json" >/dev/null && echo ok || echo fail)"
run_test "harness.json invariants freeze the small runtime" "ok" "$RESULT"

HOOK_KEYS="$(jq -r '.hooks | keys | sort | join(",")' "$PACK/shared/hooks/hooks.json")"
run_test "hooks.json registers exactly the four Cursor events" "beforeReadFile,beforeShellExecution,beforeSubmitPrompt,stop" "$HOOK_KEYS"

RESULT="$(jq -e '.hooks | (has("preToolUse") | not) and (has("postToolUse") | not)' "$PACK/shared/hooks/hooks.json" >/dev/null && echo yes || echo no)"
run_test "hooks.json omits preToolUse and postToolUse" "yes" "$RESULT"

ANTI=ok
for f in NOW.md PROGRESS.md LEARNING.md claude-progress.md; do
  [[ -e "$PACK/$f" ]] && ANTI="present:$f"
done
run_test "pack root has no NOW.md/PROGRESS.md/LEARNING.md/claude-progress.md" "ok" "$ANTI"

[[ -e "$PACK/scripts/loop.sh" ]] && LOOPF=present || LOOPF=absent
run_test "pack does not ship a second ReAct loop script" "absent" "$LOOPF"

RESULT="$(bash "$PACK/scripts/ready.sh" >/dev/null && echo ok || echo fail)"
run_test "scripts/ready.sh reports L06 bootstrap contract" "ok" "$RESULT"

READY_NO_JQ="$(KLEOS_JQ_BIN=/nonexistent bash "$PACK/scripts/ready.sh" 2>/dev/null || true)"
run_test "ready without jq reports canStart=false" "false" "$(printf '%s' "$READY_NO_JQ" | jq -r '.canStart')"
run_test "ready without jq reports canTest=false" "false" "$(printf '%s' "$READY_NO_JQ" | jq -r '.canTest')"

HOOK_NO_JQ="$(printf '%s' '{"prompt":"hello"}' | KLEOS_JQ_BIN=/nonexistent bash "$PACK/shared/hooks/before_submit_prompt.sh")"
run_test "regression: submit hook without jq continues when Python or Node is present" "true" "$(printf '%s' "$HOOK_NO_JQ" | jq -r '.continue')"

HOOK_NO_JSON="$(printf '%s' '{"prompt":"hello"}' | KLEOS_JSON_BIN=/nonexistent bash "$PACK/shared/hooks/before_submit_prompt.sh")"
run_test "submit hook without Python/Node fails closed with missing-json" "missing-json" "$(printf '%s' "$HOOK_NO_JSON" | jq -r '.reason')"

RESULT="$(bash "$PACK/scripts/eval.sh" check >/dev/null && echo ok || echo fail)"
run_test "scripts/eval.sh check covers required eval dimensions" "ok" "$RESULT"

if grep -Eq '(^|[[:space:]])bash[[:space:]]+tests/run\.sh' "$PACK/scripts/eval.sh"; then EVAL_REC=recurse; else EVAL_REC=ok; fi
run_test "eval.sh does not invoke tests/run.sh" "ok" "$EVAL_REC"

BAD_EVAL="$HARNESS_TMP/tasks-bad.json"
jq '{version:.version,note:.note,dimensions:.dimensions,tasks:[.tasks[] | select(.dimension != "regression")]}' \
  "$PACK/evals/tasks.json" > "$BAD_EVAL"
RESULT="$(EVAL_FILE="$BAD_EVAL" bash "$PACK/scripts/eval.sh" check >/dev/null 2>&1 && echo ok || echo fail)"
run_test "regression: eval.sh check fails when a required dimension is missing" "fail" "$RESULT"

RESULT="$(jq -r '.features[0].lastFailure.exit' "$FAILF")"
run_test "failed feature.sh pass records lastFailure.exit" "1" "$RESULT"
RESULT="$(jq -r '.features[0].lastFailure.nextExperiment' "$FAILF")"
run_test "failed feature.sh pass records lastFailure.nextExperiment" "re-run: exit 1" "$RESULT"
RESULT="$(jq -r '.features[0].lastFailure // "none"' "$OKF")"
run_test "successful feature.sh pass clears lastFailure" "none" "$RESULT"

RESULT="$(FEATURE_FILE="$FAILF" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" note T03 "hypothesis: exit 1 is the stub" >/dev/null && echo ok || echo fail)"
run_test "feature.sh note records an agent-written reflection on a recorded failure" "ok" "$RESULT"
RESULT="$(jq -r '.features[0].lastFailure.nextExperiment' "$FAILF")"
run_test "feature.sh note replaces nextExperiment with the hypothesis" "hypothesis: exit 1 is the stub" "$RESULT"
RESULT="$(jq -r '.features[0].status' "$FAILF")"
run_test "feature.sh note does not change status" "in_progress" "$RESULT"
RESULT="$(FEATURE_FILE="$OKF" FEATURE_ROOT="$HARNESS_TMP" bash "$FEAT" note T02 "no failure here" >/dev/null 2>&1 && echo ok || echo fail)"
run_test "regression: feature.sh note refuses when there is no lastFailure to reflect on" "fail" "$RESULT"

RESULT="$(jq -r '[.features[] | select(.verification == "bash tests/run.sh")] | length' "$PACK/shared/config/features.json")"
run_test "no pack feature cites the whole gauntlet as its verification (scoped evidence)" "0" "$RESULT"

CORE_N="$(wc -l < "$PACK/shared/rules/core.mdc" | tr -d ' ')"
TEST_N="$(wc -l < "$PACK/shared/rules/testing.mdc" | tr -d ' ')"
ON_CAP="$(jq -r '.invariants.alwaysOnMaxLines' "$PACK/shared/config/harness.json")"
if [[ "$((CORE_N + TEST_N))" -le "$ON_CAP" ]]; then ON_OK=ok; else ON_OK="lines:$((CORE_N + TEST_N))>$ON_CAP"; fi
run_test "always-on core.mdc+testing.mdc stay under alwaysOnMaxLines" "ok" "$ON_OK"

# Lines undercount paragraph prose; bytes track the per-request token cost.
ON_BYTES="$(cat "$PACK/shared/rules/charter.txt" "$PACK/shared/rules/core.mdc" "$PACK/shared/rules/testing.mdc" | wc -c | tr -d ' ')"
BYTE_CAP="$(jq -r '.invariants.alwaysOnMaxBytes' "$PACK/shared/config/harness.json")"
if [[ "$ON_BYTES" -le "$BYTE_CAP" ]]; then ON_OK=ok; else ON_OK="bytes:$ON_BYTES>$BYTE_CAP"; fi
run_test "always-on charter+core+testing stay under alwaysOnMaxBytes" "ok" "$ON_OK"
COST="$(bash "$PACK/scripts/context_cost.sh")"
RESULT="$(printf '%s\n' "$COST" | awk '/^always_on_bytes:/{print $2; exit}')"
run_test "context_cost always-on bytes match charter+core+testing" "$ON_BYTES" "$RESULT"
RESULT="$(printf '%s\n' "$COST" | awk '/^volatile:/{print $2; exit}')"
run_test "always-on prefix has no dates or command substitutions" "none" "$RESULT"

RESULT="$(jq -r '.verification.default' "$PACK/shared/config/harness.json")"
run_test "verify default is scoped, not whole-suite" "scoped" "$RESULT"
RESULT="$(jq -r '.invariants.hooksFrozen' "$PACK/shared/config/harness.json")"
run_test "hooksFrozen keeps the four-event freeze" "true" "$RESULT"

rm -rf "$HARNESS_TMP"
