TASK
Hooks/rules audit — Bash V2 fully wired, dead Rust surface removed

FILES
hooks/session_start.sh
hooks/before_submit_prompt.sh
hooks/stop_gate.sh
hooks/lean_gate.sh
hooks/policy/intent.json
hooks/policy/lean.json
user-rules/USER-RULES.paste.txt
user-rules/option-c-core.mdc
project-rules/agent.mdc
docs/DECISIONS/hooks-architecture.md
docs/ARCHITECTURE.md
docs/TOOLCHAIN.md
docs/CURATOR.md
README.md
config/AGENTS.md
skills/*

STATUS
Done-when: met — event hooks bash -n + smoke green; project `.cursor/hooks` ROOT resolves to repo; policy wired only intent+lean; ADR supersedes Rust; paste/companions aligned; fleet_sync verify ok

NEXT
Re-paste USER-RULES.paste.txt into Cursor User Rules; FORCE=1 bash hooks/fleet_sync.sh all on workstation; vault_write Session + refresh wiki/hot.md (Obsidian MCP not in this cloud env)
