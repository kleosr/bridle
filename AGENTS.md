AGENTS.md map of this pack

LAW vs MAP
- Law: rules paste + rules + registered hook scripts
- This file: navigation only

Overview
kleosrules V2 Bash hooks + local NOW.md memory. Brain equals NOW.md (local).
Muscle equals four registered hook scripts. No Rust. No Python pack tooling. No MCP core dependency.

Install scope
Local install is global-only: `FORCE=1 bash scripts/install.sh` writes `~/.cursor` (hooks, GLOBAL rules, skills, hunter/cut/prove). `sync` is opt-in via empty-by-default `shared/config/scan.roots`. Never install Lane-A into this pack.

Where to look
- Paste: shared/rules/USER-RULES.paste.txt
- Hooks: shared/hooks/session_start.sh before_submit_prompt.sh before_shell.sh before_read_file.sh
- Hook lib: shared/hooks/lib/common.sh shell_gate.sh shell_fleet.sh
- Install: shared/hooks/fleet_sync.sh install → ~/.cursor
- Agents: shared/agents/hunter.md cut.md prove.md
- Platform installers: MacOS/install.sh Linux/install.sh Windows/install.ps1 (+ Windows/hooks/wsl-shim.ps1)
- Scripts: scripts/doctor.sh scripts/install.sh scripts/sync.sh
- Tests: tests/run.sh + tests/fixtures/
- Architecture: docs/ARCHITECTURE.md
- Curator: docs/CURATOR.md
- Verify: docs/TOOLCHAIN.md
- NOW.md: bounded session state (compaction protocol)
- SECURITY.md: pnpm + cybersecurity SSOT

Done
chmod +x shared/hooks scripts then bash -n on hook scripts + bash scripts/doctor.sh

Hard stops
- Never reintroduce Rust kleos-gate or pack Python
- Never emit updated_input (this pack does not register preToolUse); inject via additional_context (sessionStart) or continue (beforeSubmitPrompt)
- Secrets never in paste hooks or chat
- Never make MCP a core dependency (optional only)
