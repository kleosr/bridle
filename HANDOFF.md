TASK
Prompt-engineer file map — ground, tag edit|NEW, follow-up re-Read

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
Done-when: met — FILE_MAP inject + duty/paste/companions require ground→tag→StrReplace/NEW→re-Read follow-up; bash -n + smoke green

NEXT
Re-paste USER-RULES.paste.txt; FORCE=1 bash hooks/fleet_sync.sh all
