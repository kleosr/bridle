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
printf '%s\n' '{"version":1,"features":[{"id":"F01","priority":1,"area":"x","title":"t","behavior":"b","verification":"true","status":"passing"}]}' \
  > "$HARNESS_TMP/falsewin/feature_list.json"
RESULT="$(hf_stop "$HARNESS_TMP/falsewin" | jq -r '.followup_message // "" | test("FEATURE")')"
run_test "regression: stop advisory when feature_list.json is passing without evidence" "true" "$RESULT"

hf_repo "$HARNESS_TMP/truewin"
printf 'echo ok\n' > "$HARNESS_TMP/truewin/ok.sh"
git -C "$HARNESS_TMP/truewin" add ok.sh
git -C "$HARNESS_TMP/truewin" -c user.email=t@t -c user.name=t commit -q -m base
printf '%s\n' '{"version":1,"features":[{"id":"F01","priority":1,"area":"x","title":"t","behavior":"b","verification":"true","status":"passing","evidence":{"command":"true","exit":0}}]}' \
  > "$HARNESS_TMP/truewin/feature_list.json"
RESULT="$(hf_stop "$HARNESS_TMP/truewin" | jq -c .)"
run_test "stop is quiet when feature_list.json passing has evidence and no other sensor hits" "{}" "$RESULT"

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

RESULT="$(jq -r '.verification.default' "$PACK/shared/config/harness.json")"
run_test "verify default is scoped, not whole-suite" "scoped" "$RESULT"
RESULT="$(jq -r '.invariants.hooksFrozen' "$PACK/shared/config/harness.json")"
run_test "hooksFrozen keeps the four-event freeze" "true" "$RESULT"

rm -rf "$HARNESS_TMP"
