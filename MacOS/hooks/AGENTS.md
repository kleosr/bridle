hooks AGENTS nested map. Parent: ../../AGENTS.md
Platform: macOS + Linux — no flock/mapfile/realpath/stat -c/awk \< word boundaries; bash 3.2-safe (stock macOS bash works).
Scope: Bash Cursor hooks for INTENT inject, lean size, autonomy gate, stop audit, HANDOFF tail.
Scripts: sessionStart -> session_start.sh ; beforeSubmitPrompt -> before_submit_prompt.sh ; stop -> stop_gate.sh ; preToolUse Write|Edit|MultiEdit|StrReplace -> lean_gate.sh ; preToolUse Write|Edit|MultiEdit|StrReplace|Bash -> pre_tool_use.sh
Install: fleet_sync.sh (not an event hook; LOC roof does not apply). Backlog: fleet_dispatch.sh.
Policy wired: policy/intent.json , policy/lean.json
Registry: hooks.json (canonical source — fleet_sync generates per-repo and home configs from this)
Done: chmod +x then bash -n on hook scripts
Hard stops: never updated_input ; never Rust or Python gate ; each event hook max 80 lines ; Cursor-only hook output (action/additionalContext JSON — no Claude hookSpecificOutput branches)
