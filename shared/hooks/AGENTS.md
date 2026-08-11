hooks AGENTS nested map. Parent: ../../AGENTS.md
Platform: macOS + Linux natively, Windows via WSL shim (Windows/hooks/wsl-shim.ps1) — no flock/mapfile/realpath/stat -c/awk \< word boundaries; bash 3.2-safe (stock macOS bash works).
Scope: Bash Cursor hooks for INTENT inject, lean size, autonomy gate, stop audit, HANDOFF tail.
Scripts: sessionStart -> session_start.sh (additional_context duties) ; beforeSubmitPrompt -> before_submit_prompt.sh (continue + route/state) ; stop -> stop_gate.sh (transcript_path) ; preToolUse Write|… -> lean_gate.sh ; preToolUse Write|…|Shell|Bash -> pre_tool_use.sh ; beforeShellExecution -> before_shell.sh
Install: fleet_sync.sh (not an event hook; LOC roof does not apply). Backlog: fleet_dispatch.sh.
Policy wired: policy/intent.json , policy/lean.json
Registry: hooks.json (canonical source — fleet_sync generates the global ~/.cursor/hooks.json from this; single registration layer, no per-repo hooks.json)
Done: chmod +x then bash -n on hook scripts
Hard stops: never updated_input ; never Rust or Python gate ; each event hook max 80 lines ; Cursor-native emit only — permission/user_message/agent_message (deny-allow), additional_context (sessionStart), continue (beforeSubmitPrompt), followup_message (stop) ; tool names Cursor-primary (Shell, Write, Read, …) with Claude aliases optional
Cursor tools: Shell Write Read Delete Grep Task (matchers must use these; Bash/Edit/MultiEdit/StrReplace are optional fall-through aliases only)
