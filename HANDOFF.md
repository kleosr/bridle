TASK
Fix INTENT declaration bugs — prose-only detect, no shell poison, no drip

FILES
edit:hooks/stop_gate.sh
edit:hooks/before_submit_prompt.sh
edit:hooks/session_start.sh
edit:hooks/policy/intent.json
edit:user-rules/USER-RULES.paste.txt
edit:user-rules/option-c-core.mdc
edit:project-rules/agent.mdc
edit:project-rules/context-curator.mdc
edit:project-rules/vernacular.mdc
edit:docs/CURATOR.md
edit:docs/ARCHITECTURE.md
edit:.github/workflows/gates.yml

STATUS
Done-when: met — stop greps assistant prose only (strips tools/fences); rejects drip; pending_files reinjected on followup; accept clears state; bash -n + poison smokes green

NEXT
Re-paste USER-RULES.paste.txt; FORCE=1 bash hooks/fleet_sync.sh all
