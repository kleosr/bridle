#!/usr/bin/env bash
# Startup readiness (course L06). JSON on stdout. Does not run the test suite.
# Bootstrap contract: can start, can test, can see progress, can pick up next steps.
set -euo pipefail

PACK="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=shared/hooks/lib/common.sh
source "$PACK/shared/hooks/lib/common.sh"

if ! jq_available; then
  printf '%s\n' '{"canStart":false,"canTest":true,"canSeeProgress":false,"canHandoff":false,"init":"bash scripts/ready.sh","inventory":"DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh","verify":"bash tests/run.sh","fixes":"install jq or set KLEOS_JQ_BIN; "}'
  echo "ready: jq executable not found; set KLEOS_JQ_BIN or install jq." >&2
  exit 1
fi

can_start=true
can_test=true
can_see=true
can_hand=true
fixes=""

if [[ ! -f "$PACK/AGENTS.md" || ! -f "$PACK/shared/config/harness.json" ]]; then
  can_start=false
  fixes="${fixes}restore AGENTS.md and shared/config/harness.json; "
fi
if [[ ! -f "$PACK/tests/run.sh" ]]; then
  can_test=false
  fixes="${fixes}restore tests/run.sh; "
fi
if ! bash "$PACK/scripts/feature.sh" check >/dev/null 2>&1; then
  can_see=false
  fixes="${fixes}bash scripts/feature.sh check; "
fi
if ! bash "$PACK/scripts/handoff.sh" check >/dev/null 2>&1; then
  can_hand=false
  fixes="${fixes}bash scripts/handoff.sh check; "
fi
if [[ ! -f "$PACK/shared/schema/handoff.schema.json" ]]; then
  can_hand=false
  fixes="${fixes}restore shared/schema/handoff.schema.json; "
fi

jq -n \
  --argjson canStart "$can_start" \
  --argjson canTest "$can_test" \
  --argjson canSeeProgress "$can_see" \
  --argjson canHandoff "$can_hand" \
  --arg init "bash scripts/ready.sh" \
  --arg inventory "DOCTOR_SKIP_LIVE=1 bash scripts/doctor.sh" \
  --arg verify "bash tests/run.sh" \
  --arg fixes "$fixes" \
  '{canStart:$canStart,canTest:$canTest,canSeeProgress:$canSeeProgress,canHandoff:$canHandoff,init:$init,inventory:$inventory,verify:$verify,fixes:$fixes}'

if [[ "$can_start" == true && "$can_test" == true && "$can_see" == true && "$can_hand" == true ]]; then
  exit 0
fi
echo "ready: bootstrap contract failed (canStart=$can_start canTest=$can_test canSeeProgress=$can_see canHandoff=$can_hand)." >&2
echo "fix: $fixes" >&2
exit 1
