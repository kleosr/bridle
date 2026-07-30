TASK
INTENT as CS job card — postcondition + invariants + decidable predicates

FILES
hooks/policy/intent.json
hooks/before_submit_prompt.sh
hooks/session_start.sh
hooks/stop_gate.sh
user-rules/USER-RULES.paste.txt
user-rules/option-c-core.mdc
project-rules/context-curator.mdc
project-rules/agent.mdc
project-rules/vernacular.mdc
docs/CURATOR.md
docs/ARCHITECTURE.md

STATUS
Done-when: met — duty/paste/companions use postcondition/invariant/predicate vocabulary; bash -n + inject smoke green

NEXT
Re-paste USER-RULES.paste.txt; FORCE=1 bash hooks/fleet_sync.sh all
