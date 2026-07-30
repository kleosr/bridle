# Toolchain: Bash & jq Validation

No Rust. No Cargo. No Python. Mechanical checks are Bash.

## Prerequisites

- `bash` (v4+)
- `jq` (JSON parsing in hooks)
- Cursor IDE (runs the hooks)
- Obsidian MCP configured locally

## Syntax check

```bash
chmod +x hooks/*.sh

bash -n hooks/session_start.sh
bash -n hooks/before_submit_prompt.sh
bash -n hooks/stop_gate.sh
bash -n hooks/lean_gate.sh
bash -n hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash hooks/before_submit_prompt.sh
```

Expect JSON with `additional_context` (and, on stop fixtures, `followup_message` when INTENT is missing).

## Fleet install / sync

```bash
FORCE=1 bash hooks/fleet_sync.sh all
FORCE=1 bash hooks/fleet_sync.sh verify
```

Installs `~/.cursor` hooks+rules+skills, syncs `.cursor/rules` + Bash hooks to every project under `config/scan.roots`.

## Size roofs

Keep each **event** hook under 80 LOC (`session_start`, `before_submit_prompt`, `stop_gate`, `lean_gate`). `fleet_sync.sh` is install tooling, not an event hook. Fail closed: bad parse or failed exec should block or return deny JSON. Review catches the rest.

Wired policy only: `hooks/policy/intent.json` (INTENT roofs) and `hooks/policy/lean.json` (`file_loc_max`).
