AGENTS.md map of this pack

LAW vs MAP
- Law: rules paste + rules + hooks scripts
- This file: navigation only

Overview
kleosrules V2 Bash hooks + local HANDOFF memory. Brain equals HANDOFF.md (local).
Muscle equals hooks scripts. No Rust. No Python pack tooling. No MCP core dependency.

Where to look
- Paste: rules/USER-RULES.paste.txt
- Hooks: MacOS/hooks/session_start.sh before_submit_prompt.sh stop_gate.sh lean_gate.sh pre_tool_use.sh
- Hook lib: MacOS/hooks/lib/common.sh stop_gate_core.sh pre_tool_use_core.sh
- Install: MacOS/hooks/fleet_sync.sh (syncs hooks + rules + skills to ~/.cursor and fleet repos)
- Scripts: scripts/doctor.sh scripts/install.sh scripts/sync.sh
- Tests: tests/run.sh + tests/fixtures/
- Architecture: docs/ARCHITECTURE.md
- Curator: docs/CURATOR.md
- Verify: docs/TOOLCHAIN.md
- HANDOFF: HANDOFF.md (bounded session state with compaction protocol)

Done
chmod +x MacOS/hooks scripts then bash -n on hook scripts + bash scripts/doctor.sh

Hard stops
- Never reintroduce Rust kleos-gate or pack Python
- Never use updated_input in hooks only additionalContext
- Secrets never in paste hooks or chat
- Never make MCP a core dependency (optional only)
