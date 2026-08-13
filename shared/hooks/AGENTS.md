hooks AGENTS nested map. Parent: ../../AGENTS.md
Platform: macOS + Linux natively, Windows via WSL shim — bash 3.2-safe (no flock/mapfile/realpath reliance; mkdir locks).
Scope: Four registered Cursor user hooks. Secrets + shell deny + HANDOFF tail. Law (INTENT / GROUND / ponytail) stays in .mdc / skills.

Layers
- Steering (soft law): shared/rules/*.mdc + skills — vernacular/ponytail/agent.
- Steel (mechanical): before_shell.sh + before_read_file.sh + before_submit_prompt.sh secret block + policy/*.ere.
- Feedback: none registered. HANDOFF tail is the session brain.

Roofs (lean.json)
- Numbers for ponytail.mdc. Not enforced by a registered hook.

Emit (Cursor-native; exit 0 so messages survive)
- deny/allow/ask → permission (+ user_message/agent_message)
- sessionStart → additional_context (HANDOFF tail)
- beforeSubmitPrompt → continue (secret may continue:false)
- quiet → {}

Scripts
sessionStart→session_start.sh (HANDOFF tail) ; beforeSubmitPrompt→before_submit_prompt.sh (failClosed:false) ; beforeShellExecution→before_shell.sh (failClosed:false) ; beforeReadFile→before_read_file.sh (failClosed:true)

Install / cloud
- Local: global ~/.cursor only (`FORCE=1 bash scripts/install.sh`). Native `./hooks/*.sh`. Does not copy or delete other repos’ `.cursor/hooks`.
- Cloud: `CLOUD=1 TARGET_REPO=/path/to/workspace bash shared/hooks/fleet_sync.sh project-hooks` → hooks.cloud.json (shell/read/submit; **no sessionStart**). TARGET_REPO required. Never install Lane-A into the pack.

Done: chmod +x ; bash -n ; bash tests/run.sh
Hard stops: never updated_input ; never Rust/Python gate ; event hooks ≤80 LOC ; stock macOS bash 3.2 + BSD grep (no GNU \\b)
