hooks AGENTS nested map. Parent: ../../AGENTS.md
Platform: macOS + Linux natively, Windows via WSL shim — bash 3.2-safe (no flock/mapfile/realpath reliance; mkdir locks).
Scope: Bash Cursor hooks for INTENT inject, lean size/zero-comment, autonomy gate, stop audit, HANDOFF tail, post-edit scorecard.

Layers
- Steering (soft law): shared/rules/*.mdc + skills — vernacular/ponytail/agent. sessionStart grounding checklist + FILE_MAP nudges (no deny).
- Steel (mechanical): hooks + policy/lean.json + policy/intent.json.
- Feedback (second brain): postToolUse additional_context scorecard on dirty writes; afterFileEdit stamps on-disk truth.

Roofs (lean.json)
- comment_ratio_max=2 (≈ zero prose; machine directives excluded)
- file_loc_soft=120 (allow + agent_message), file_loc_max=300 (deny growth)
- file_loc_legacy_emergency=700 (rewrite into modules ≤300 + update imports; reducing extract allowed)
- complexity/coupling/nesting/velocity — see lean.json
Scoring uses **projected whole file** after Write/StrReplace (lib/metrics.sh project_edit_content).

Emit (Cursor-native; exit 0 so messages survive)
- deny/allow → permission (+ user_message/agent_message)
- sessionStart → additional_context (GROUNDING + DEBERES + HANDOFF tail; no ponytail essay)
- beforeSubmitPrompt → continue (secret may continue:false; FILE_MAP/JOB CARD/culture nudge = continue:true + user_message)
- postToolUse → additional_context (SCORECARD when dirty; {} when clean)
- preCompact → user_message (re-Read HANDOFF/INTENT)
- stop → followup_message (OBJECTIVE quality, >700 rewrite until split, evidence, culture; then fail open)
- quiet → {}

Scripts
sessionStart→session_start.sh (JOB CARD template + HANDOFF; no ponytail essay) ; beforeSubmitPrompt→before_submit_prompt.sh ; stop→stop_gate.sh (transcript_path) ; preToolUse Write|StrReplace→lean_gate ; preToolUse Write|StrReplace|Shell|Delete|EditNotebook|Read|Grep|Glob→pre_tool_use ; postToolUse Write|StrReplace|Delete|EditNotebook→post_tool_use ; afterFileEdit/afterTabFileEdit→after_file_edit ; beforeShellExecution→before_shell.sh ; beforeReadFile+beforeTabFileRead→before_read_file.sh ; beforeMCPExecution→before_mcp.sh ; preCompact→pre_compact.sh

Install / cloud
- Local: global ~/.cursor only (fleet_sync install|all). Removes per-repo hooks to avoid double sessionStart DUTY.
- Cloud: `CLOUD=1 bash shared/hooks/fleet_sync.sh project-hooks` → hooks.cloud.json (lean/shell/read/tab/mcp/submit/preCompact/stop/postToolUse/afterFileEdit; **no sessionStart**).

Done: chmod +x ; bash -n ; bash tests/run.sh
Hard stops: never updated_input ; never Rust/Python gate ; event hooks ≤80 LOC ; Cursor tools Write|StrReplace|Shell|Delete|EditNotebook|Read|Grep|Glob ; stock macOS bash 3.2 + BSD grep (no GNU \\b)
