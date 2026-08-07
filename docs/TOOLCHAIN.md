# Toolchain: Bash & jq Validation

No Rust. No Cargo. No Python. Mechanical checks are Bash.

## Prerequisites

- `bash` (v4+)
- `jq` (JSON parsing in hooks)
- Cursor IDE (runs the hooks)

## Syntax check

```bash
chmod +x hooks/*.sh hooks/lib/*.sh

bash -n hooks/session_start.sh
bash -n hooks/before_submit_prompt.sh
bash -n hooks/stop_gate.sh
bash -n hooks/lean_gate.sh
bash -n hooks/pre_tool_use.sh
bash -n hooks/fleet_sync.sh
```

## Smoke test

```bash
echo '{"prompt": "test code", "hook_event_name": "beforeSubmitPrompt"}' \
  | bash hooks/before_submit_prompt.sh
```

Expect JSON with `additionalContext` (and, on stop fixtures, `followup_message` when INTENT is missing).

## Doctor + Tests

```bash
bash scripts/doctor.sh    # environment + repo health checks
bash tests/run.sh         # syntax + JSON + hook fixtures (44 tests)
```

## Fleet install / sync

```bash
FORCE=1 bash hooks/fleet_sync.sh all
FORCE=1 bash hooks/fleet_sync.sh verify
```

Installs `~/.cursor` hooks+rules+skills, syncs `.cursor/rules` + Bash hooks to every project under `config/scan.roots`.

## Size roofs

Keep each **event** hook under 80 LOC (`session_start`, `before_submit_prompt`, `stop_gate`, `lean_gate`, `pre_tool_use`). Core logic lives in `hooks/lib/`. `fleet_sync.sh` is install tooling, not an event hook. Fail closed: bad parse or failed exec should block or return deny JSON.

Wired policy only: `hooks/policy/intent.json` (INTENT roofs) and `hooks/policy/lean.json` (`file_loc_max`, `complexity_max`, `func_complexity_max`, `coupling_max`, `nesting_max`, `edit_velocity_max`).
