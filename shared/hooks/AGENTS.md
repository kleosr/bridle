hooks AGENTS nested map. Parent: ../../AGENTS.md
Platform: macOS + Linux natively, Windows via WSL shim — bash 3.2-safe (no flock/mapfile/realpath reliance; mkdir locks).
Scope: Bash Cursor hooks for INTENT inject, lean size/zero-comment, autonomy gate, stop audit, HANDOFF tail.

Layers
- Steering (soft law): shared/rules/*.mdc + skills — vernacular/ponytail/agent. sessionStart grounding checklist + FILE_MAP nudges (no deny).
- Steel (mechanical): hooks + policy/lean.json + policy/intent.json.

Roofs (lean.json)
- comment_ratio_max=2 (≈ zero prose; machine directives excluded)
- file_loc_soft=150 (allow + agent_message), file_loc_max=700 (deny)
- complexity/coupling/nesting/velocity — see lean.json
Scoring uses **projected whole file** after Write/edit (lib/metrics.sh project_edit_content).

Emit (Cursor-native; exit 0 so messages survive)
- deny/allow → permission (+ user_message/agent_message)
- sessionStart → additional_context (GROUNDING + DEBERES)
- beforeSubmitPrompt → continue (secret may continue:false; FILE_MAP nudge = continue:true + user_message)
- preCompact → user_message (re-Read HANDOFF/INTENT)
- stop → followup_message (incl. one soft TOOLCHAIN evidence nudge; then fail open)
- quiet → {}

Scripts
sessionStart→session_start.sh ; beforeSubmitPrompt→before_submit_prompt.sh ; stop→stop_gate.sh (transcript_path) ; preToolUse Write→lean_gate+pre_tool_use ; beforeShellExecution→before_shell.sh ; beforeReadFile+beforeTabFileRead→before_read_file.sh ; beforeMCPExecution→before_mcp.sh ; preCompact→pre_compact.sh

Install / cloud
- Default: global ~/.cursor only (fleet_sync install|all). Removes per-repo hooks to avoid double sessionStart DUTY.
- Cloud: `CLOUD=1 bash shared/hooks/fleet_sync.sh project-hooks` → hooks.cloud.json (lean/shell/read/tab/mcp/submit/preCompact/stop; **no sessionStart**).

Done: chmod +x ; bash -n ; bash tests/run.sh
Hard stops: never updated_input ; never Rust/Python gate ; event hooks ≤80 LOC ; Cursor tool names Shell/Write primary
