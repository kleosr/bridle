hooks AGENTS nested map. Parent: ../AGENTS.md
Scope: Bash Cursor hooks for INTENT inject, lean size, stop audit, HANDOFF tail.
Scripts: sessionStart -> session_start.sh ; beforeSubmitPrompt -> before_submit_prompt.sh ; stop -> stop_gate.sh ; preToolUse Write|StrReplace -> lean_gate.sh
Install: fleet_sync.sh (not an event hook; LOC roof does not apply)
Policy wired: policy/intent.json , policy/lean.json
Registries: hooks.json , hooks.project.json
Done: chmod +x then bash -n on hook scripts
Hard stops: never updated_input ; never Rust or Python gate ; each event hook max 80 lines
