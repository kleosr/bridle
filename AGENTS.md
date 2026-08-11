AGENTS.md map of this pack

LAW vs MAP
- Law: rules paste + rules + hooks scripts
- This file: navigation only

Overview
kleosrules V2 Bash hooks + local HANDOFF memory. Brain equals HANDOFF.md (local).
Muscle equals hooks scripts. No Rust. No Python pack tooling. No MCP core dependency.

Where to look
- Paste: shared/rules/USER-RULES.paste.txt
- Hooks: shared/hooks/session_start.sh before_submit_prompt.sh stop_gate.sh lean_gate.sh pre_tool_use.sh
- Hook lib: shared/hooks/lib/common.sh stop_gate_core.sh pre_tool_use_core.sh
- Install: shared/hooks/fleet_sync.sh → ~/.cursor (global). Cloud agents: CLOUD=1 … project-hooks (thin Lane-A, no sessionStart — no double DUTY)
- Platform installers: MacOS/install.sh Linux/install.sh Windows/install.ps1 (+ Windows/hooks/wsl-shim.ps1)
- Scripts: scripts/doctor.sh scripts/install.sh scripts/sync.sh
- Tests: tests/run.sh + tests/fixtures/
- Architecture: docs/ARCHITECTURE.md
- Curator: docs/CURATOR.md
- Verify: docs/TOOLCHAIN.md
- HANDOFF: HANDOFF.md (bounded session state with compaction protocol)

Done
chmod +x shared/hooks scripts then bash -n on hook scripts + bash scripts/doctor.sh

Hard stops
- Never reintroduce Rust kleos-gate or pack Python
- Never use updated_input in hooks; inject via additional_context (sessionStart) or continue (beforeSubmitPrompt)
- Secrets never in paste hooks or chat
- Never make MCP a core dependency (optional only)
