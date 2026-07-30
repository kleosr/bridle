TASK
Aligned INTENT prompts — OBJECTIVE↔code-surface + full-ask Done-when

FILES
hooks/policy/intent.json
hooks/before_submit_prompt.sh
hooks/session_start.sh
hooks/stop_gate.sh
user-rules/USER-RULES.paste.txt
user-rules/option-c-core.mdc
project-rules/context-curator.mdc
project-rules/agent.mdc
docs/CURATOR.md
docs/ARCHITECTURE.md

STATUS
Done-when: met — duty/paste/companions/stop messages require OBJECTIVE→code surface and ≤5 disk/TOOLCHAIN anchors covering full ask; bash -n + inject smoke green

NEXT
Re-paste USER-RULES.paste.txt; FORCE=1 bash hooks/fleet_sync.sh all on workstation
